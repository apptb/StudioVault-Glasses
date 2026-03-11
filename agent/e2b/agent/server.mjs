import { createServer } from "node:http";
import { query } from "@anthropic-ai/claude-agent-sdk";

const PORT = 3000;
const AUTH_TOKEN = process.env.AUTH_TOKEN || "";

// Track agent session ID for multi-turn resume
let agentSessionId = null;

// Serialize requests to prevent concurrent agent runs
let processing = false;
const queue = [];

function enqueue(handler) {
  return new Promise((resolve, reject) => {
    queue.push({ handler, resolve, reject });
    processQueue();
  });
}

async function processQueue() {
  if (processing || queue.length === 0) return;
  processing = true;
  const { handler, resolve, reject } = queue.shift();
  try {
    resolve(await handler());
  } catch (e) {
    reject(e);
  } finally {
    processing = false;
    processQueue();
  }
}

// Run the Claude Agent SDK
async function runAgent(prompt, systemPrompt) {
  let resultSessionId = null;
  let resultContent = null;
  let resultCost = null;
  let resultDuration = null;

  const options = {
    model: "claude-sonnet-4-6",
    allowedTools: [
      "Read",
      "Write",
      "Edit",
      "Bash",
      "Glob",
      "Grep",
      "WebSearch",
      "WebFetch",
    ],
    permissionMode: "bypassPermissions",
    allowDangerouslySkipPermissions: true,
    cwd: "/home/user/workspace",
  };

  if (systemPrompt) options.systemPrompt = systemPrompt;
  if (agentSessionId) options.resume = agentSessionId;

  for await (const message of query({ prompt, options })) {
    if (message.type === "system" && message.subtype === "init") {
      resultSessionId = message.session_id;
    }
    if (message.type === "result") {
      resultContent = message.result;
      resultCost = message.total_cost_usd;
      resultDuration = message.duration_ms;
    }
  }

  // Update session ID for next turn
  if (resultSessionId) {
    agentSessionId = resultSessionId;
  }

  return {
    result: resultContent || "Agent completed with no response.",
    session_id: agentSessionId,
    cost_usd: resultCost,
    duration_ms: resultDuration,
  };
}

// HTTP server
const server = createServer(async (req, res) => {
  // CORS / preflight
  res.setHeader("Content-Type", "application/json");

  if (req.method === "GET" && req.url === "/health") {
    res.writeHead(200);
    res.end(JSON.stringify({ status: "ok", sessionId: agentSessionId }));
    return;
  }

  if (req.method === "POST" && req.url === "/message") {
    let body = "";
    for await (const chunk of req) body += chunk;

    let parsed;
    try {
      parsed = JSON.parse(body);
    } catch {
      res.writeHead(400);
      res.end(JSON.stringify({ error: "Invalid JSON" }));
      return;
    }

    // Auth check
    if (AUTH_TOKEN && parsed.token !== AUTH_TOKEN) {
      res.writeHead(401);
      res.end(JSON.stringify({ error: "Unauthorized" }));
      return;
    }

    const { prompt, systemPrompt } = parsed;
    if (!prompt) {
      res.writeHead(400);
      res.end(JSON.stringify({ error: "prompt is required" }));
      return;
    }

    try {
      const result = await enqueue(() => runAgent(prompt, systemPrompt));
      res.writeHead(200);
      res.end(JSON.stringify(result));
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      console.error("[Server] Agent error:", msg);
      res.writeHead(500);
      res.end(JSON.stringify({ error: msg }));
    }
    return;
  }

  res.writeHead(404);
  res.end(JSON.stringify({ error: "Not found" }));
});

server.listen(PORT, () => {
  console.log(`Agent server listening on port ${PORT}`);
});
