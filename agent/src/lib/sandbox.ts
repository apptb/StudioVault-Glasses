import { Sandbox } from "e2b";

const SANDBOX_TIMEOUT_MS = 30 * 60 * 1000; // 30 minutes
const AGENT_TIMEOUT_MS = 90_000; // 90 seconds per agent run

interface SandboxHandle {
  sandbox: Sandbox;
  agentSessionId: string | null;
  lastActive: number;
}

interface AgentResult {
  result: string;
  sessionId: string | null;
  costUsd: number | null;
  durationMs: number | null;
}

// In-memory sandbox tracking (no Supabase).
// Sandboxes are ephemeral (30min TTL) and Map resets on cold start.
const activeSandboxes = new Map<string, SandboxHandle>();

/**
 * Get or create an E2B sandbox for a given session key.
 */
export async function getOrCreateSandbox(
  sessionKey: string
): Promise<SandboxHandle> {
  const existing = activeSandboxes.get(sessionKey);
  if (existing) {
    try {
      // Verify sandbox is still alive
      const sandbox = await Sandbox.connect(existing.sandbox.sandboxId);
      existing.sandbox = sandbox;
      existing.lastActive = Date.now();
      return existing;
    } catch {
      // Sandbox expired, remove from map
      activeSandboxes.delete(sessionKey);
    }
  }

  return createSandbox(sessionKey);
}

/**
 * Run the Claude Agent SDK inside the sandbox.
 * Passes the prompt as an env var and captures JSON output.
 */
export async function runAgent(
  sandbox: Sandbox,
  prompt: string,
  systemPrompt?: string,
  agentSessionId?: string | null
): Promise<AgentResult> {
  const envs: Record<string, string> = {
    AGENT_PROMPT: prompt,
  };
  if (systemPrompt) {
    envs.AGENT_SYSTEM_PROMPT = systemPrompt;
  }
  if (agentSessionId) {
    envs.AGENT_SESSION_ID = agentSessionId;
  }

  console.log(
    `[Agent] Running agent in sandbox ${sandbox.sandboxId}, prompt: ${prompt.slice(0, 100)}...`
  );

  const result = await sandbox.commands.run(
    "node /home/user/agent/run.mjs",
    { envs, timeoutMs: AGENT_TIMEOUT_MS }
  );

  if (result.exitCode !== 0) {
    const errorOutput = result.stderr || result.stdout;
    console.error(
      `[Agent] Script failed (exit ${result.exitCode}): ${errorOutput.slice(0, 500)}`
    );

    try {
      const parsed = JSON.parse(
        errorOutput.trim().split("\n").pop() || "{}"
      );
      throw new Error(
        parsed.error ||
          `Agent script failed with exit code ${result.exitCode}`
      );
    } catch (parseErr) {
      if (parseErr instanceof SyntaxError) {
        throw new Error(
          `Agent script failed (exit ${result.exitCode}): ${errorOutput.slice(0, 200)}`
        );
      }
      throw parseErr;
    }
  }

  // Parse the last line of stdout as JSON
  const lines = result.stdout.trim().split("\n");
  const lastLine = lines[lines.length - 1];

  try {
    const output = JSON.parse(lastLine);
    console.log(
      `[Agent] Completed. session=${output.session_id}, cost=$${output.cost_usd}, duration=${output.duration_ms}ms`
    );
    return {
      result: output.result || "Agent completed with no response.",
      sessionId: output.session_id || null,
      costUsd: output.cost_usd || null,
      durationMs: output.duration_ms || null,
    };
  } catch {
    console.error(
      `[Agent] Failed to parse output: ${lastLine.slice(0, 300)}`
    );
    return {
      result:
        result.stdout.trim() ||
        "Agent completed but output was not parsable.",
      sessionId: null,
      costUsd: null,
      durationMs: null,
    };
  }
}

/**
 * Update the agent session ID for multi-turn resume.
 */
export function updateAgentSession(
  sessionKey: string,
  agentSessionId: string
): void {
  const handle = activeSandboxes.get(sessionKey);
  if (handle) {
    handle.agentSessionId = agentSessionId;
    handle.lastActive = Date.now();
  }
}

async function createSandbox(sessionKey: string): Promise<SandboxHandle> {
  const templateId = process.env.E2B_TEMPLATE_ID;
  if (!templateId) {
    throw new Error("E2B_TEMPLATE_ID not configured");
  }

  console.log(`[Sandbox] Creating sandbox from template: ${templateId}`);

  const sandbox = await Sandbox.create(templateId, {
    timeoutMs: SANDBOX_TIMEOUT_MS,
    envs: {
      ANTHROPIC_API_KEY: process.env.ANTHROPIC_API_KEY || "",
    },
  });

  console.log(`[Sandbox] Created: ${sandbox.sandboxId}`);

  const handle: SandboxHandle = {
    sandbox,
    agentSessionId: null,
    lastActive: Date.now(),
  };
  activeSandboxes.set(sessionKey, handle);

  return handle;
}
