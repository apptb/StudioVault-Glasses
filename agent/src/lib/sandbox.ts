import { Sandbox } from "e2b";
import {
  getSandboxMapping,
  saveSandboxMapping,
  deleteSandboxMapping,
  getMessages,
  formatMessagesAsContext,
} from "./session-store";
import crypto from "crypto";

const SANDBOX_TIMEOUT_MS = 30 * 60 * 1000; // 30 minutes
const AGENT_TIMEOUT_MS = 90_000; // 90 seconds per agent run
const SERVER_PORT = 3000;
const SERVER_STARTUP_TIMEOUT_MS = 10_000; // 10s to wait for server to be ready

interface SandboxHandle {
  sandbox: Sandbox;
  agentSessionId: string | null;
  authToken: string;
  lastActive: number;
  isNewSandbox: boolean;
  serverUrl: string; // http://localhost:3000 inside sandbox
}

export interface AgentResult {
  result: string;
  sessionId: string | null;
  costUsd: number | null;
  durationMs: number | null;
}

// In-memory hot cache (avoids Redis round-trip for consecutive requests).
const sandboxCache = new Map<string, SandboxHandle>();

/**
 * Get or create an E2B sandbox for a given session key.
 * Tries: in-memory cache -> Redis mapping -> create new.
 */
export async function getOrCreateSandbox(
  sessionKey: string
): Promise<SandboxHandle> {
  // 1. Check in-memory cache
  const cached = sandboxCache.get(sessionKey);
  if (cached) {
    try {
      const sandbox = await Sandbox.connect(cached.sandbox.sandboxId);
      cached.sandbox = sandbox;
      cached.lastActive = Date.now();
      cached.isNewSandbox = false;
      // Verify server is still running
      if (await isServerHealthy(sandbox, cached.authToken)) {
        return cached;
      }
      // Server died, restart it
      console.log(`[Sandbox] Server not healthy, restarting`);
      await startServer(sandbox, cached.authToken);
      return cached;
    } catch {
      sandboxCache.delete(sessionKey);
    }
  }

  // 2. Check Redis for persisted sandbox mapping
  const mapping = await getSandboxMapping(sessionKey);
  if (mapping) {
    try {
      console.log(
        `[Sandbox] Resuming sandbox ${mapping.sandboxId} for session ${sessionKey}`
      );
      const sandbox = await Sandbox.connect(mapping.sandboxId);
      const authToken = crypto.randomUUID();

      // Start server in resumed sandbox (previous server process is gone after pause/resume)
      await startServer(sandbox, authToken);

      const handle: SandboxHandle = {
        sandbox,
        agentSessionId: mapping.agentSessionId,
        authToken,
        lastActive: Date.now(),
        isNewSandbox: false,
        serverUrl: `http://localhost:${SERVER_PORT}`,
      };
      sandboxCache.set(sessionKey, handle);

      await saveSandboxMapping(
        sessionKey,
        sandbox.sandboxId,
        mapping.agentSessionId
      );

      return handle;
    } catch {
      console.log(
        `[Sandbox] Failed to resume ${mapping.sandboxId}, creating new`
      );
      await deleteSandboxMapping(sessionKey);
    }
  }

  // 3. Create new sandbox
  return createSandbox(sessionKey);
}

/**
 * Run the agent by POSTing to the persistent server inside the sandbox.
 * Much faster than spawning a new Node process each time.
 */
export async function runAgent(
  handle: SandboxHandle,
  prompt: string,
  systemPrompt?: string,
  _agentSessionId?: string | null,
  sessionKey?: string
): Promise<AgentResult> {
  // Build system prompt, potentially with recovery context
  let finalSystemPrompt = systemPrompt || "";

  if (handle.isNewSandbox && sessionKey) {
    const priorMessages = await getMessages(sessionKey);
    if (priorMessages.length > 0) {
      const context = formatMessagesAsContext(priorMessages);
      const recoveryPrefix = `[Previous conversation history -- the user may refer to this]\n${context}`;
      finalSystemPrompt = finalSystemPrompt
        ? `${recoveryPrefix}\n\n${finalSystemPrompt}`
        : recoveryPrefix;
      console.log(
        `[Agent] Injected ${priorMessages.length} prior messages as recovery context`
      );
    }
  }

  console.log(
    `[Agent] Sending to server in sandbox ${handle.sandbox.sandboxId}, prompt: ${prompt.slice(0, 100)}...`
  );

  // POST to the persistent server inside the sandbox
  const payload: Record<string, string> = {
    prompt,
    token: handle.authToken,
  };
  if (finalSystemPrompt) {
    payload.systemPrompt = finalSystemPrompt;
  }

  const url = handle.sandbox.getHost(SERVER_PORT);
  const response = await fetch(`https://${url}/message`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
    signal: AbortSignal.timeout(AGENT_TIMEOUT_MS),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(
      `Agent server error (${response.status}): ${errorText.slice(0, 200)}`
    );
  }

  const output = (await response.json()) as Record<string, unknown>;

  console.log(
    `[Agent] Completed. session=${output.session_id}, cost=$${output.cost_usd}, duration=${output.duration_ms}ms`
  );

  return {
    result: (output.result as string) || "Agent completed with no response.",
    sessionId: (output.session_id as string) || null,
    costUsd: (output.cost_usd as number) || null,
    durationMs: (output.duration_ms as number) || null,
  };
}

/**
 * Update the agent session ID for multi-turn resume.
 */
export async function updateAgentSession(
  sessionKey: string,
  agentSessionId: string
): Promise<void> {
  const handle = sandboxCache.get(sessionKey);
  if (handle) {
    handle.agentSessionId = agentSessionId;
    handle.lastActive = Date.now();

    await saveSandboxMapping(
      sessionKey,
      handle.sandbox.sandboxId,
      agentSessionId
    );
  }
}

// --- Internal helpers ---

async function createSandbox(sessionKey: string): Promise<SandboxHandle> {
  const templateId = process.env.E2B_TEMPLATE_ID;
  if (!templateId) {
    throw new Error("E2B_TEMPLATE_ID not configured");
  }

  console.log(`[Sandbox] Creating sandbox from template: ${templateId}`);

  const authToken = crypto.randomUUID();

  const sandbox = await Sandbox.create(templateId, {
    timeoutMs: SANDBOX_TIMEOUT_MS,
    envs: {
      ANTHROPIC_API_KEY: process.env.ANTHROPIC_API_KEY || "",
    },
  });

  console.log(`[Sandbox] Created: ${sandbox.sandboxId}`);

  // Start the persistent agent server
  await startServer(sandbox, authToken);

  await saveSandboxMapping(sessionKey, sandbox.sandboxId, null);

  const handle: SandboxHandle = {
    sandbox,
    agentSessionId: null,
    authToken,
    lastActive: Date.now(),
    isNewSandbox: true,
    serverUrl: `http://localhost:${SERVER_PORT}`,
  };
  sandboxCache.set(sessionKey, handle);

  return handle;
}

/**
 * Start the persistent server.mjs inside the sandbox.
 * Kills any existing server first, then starts a new one in the background.
 */
async function startServer(sandbox: Sandbox, authToken: string): Promise<void> {
  // Kill any existing server
  try {
    await sandbox.commands.run(
      "pkill -f 'node /home/user/agent/server.mjs' 2>/dev/null; sleep 0.2",
      { timeoutMs: 5000 }
    );
  } catch {
    // Nothing to kill
  }

  // Start server in background
  console.log(`[Sandbox] Starting agent server...`);
  await sandbox.commands.run("node /home/user/agent/server.mjs", {
    background: true,
    envs: {
      AUTH_TOKEN: authToken,
      ANTHROPIC_API_KEY: process.env.ANTHROPIC_API_KEY || "",
    },
  });

  // Wait for server to be ready
  const startTime = Date.now();
  while (Date.now() - startTime < SERVER_STARTUP_TIMEOUT_MS) {
    try {
      const url = sandbox.getHost(SERVER_PORT);
      const healthRes = await fetch(`https://${url}/health`, {
        signal: AbortSignal.timeout(2000),
      });
      if (healthRes.ok) {
        console.log(`[Sandbox] Agent server ready`);
        return;
      }
    } catch {
      // Server not ready yet
    }
    await new Promise((r) => setTimeout(r, 300));
  }

  throw new Error("Agent server failed to start within timeout");
}

/**
 * Check if the server inside the sandbox is still healthy.
 */
async function isServerHealthy(
  sandbox: Sandbox,
  _authToken: string
): Promise<boolean> {
  try {
    const url = sandbox.getHost(SERVER_PORT);
    const res = await fetch(`https://${url}/health`, {
      signal: AbortSignal.timeout(3000),
    });
    return res.ok;
  } catch {
    return false;
  }
}
