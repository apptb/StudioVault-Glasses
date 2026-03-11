import { createServer } from "node:http";
import Anthropic from "@anthropic-ai/sdk";
import { readFileSync, writeFileSync, mkdirSync, readdirSync, statSync } from "node:fs";
import { execSync } from "node:child_process";
import { dirname, basename } from "node:path";

// --- Config ---
const PORT = 3000;
const AUTH_TOKEN = process.env.AUTH_TOKEN || "";
const WORKSPACE = "/home/user/workspace";
const MAX_TOOL_ITERATIONS = 20;
const MAX_TOKENS = 8192;
const MODEL = "claude-sonnet-4-6";

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

// --- Conversation state (in-memory, one per sandbox) ---
let conversationMessages = [];
let systemBlocks = null; // cached system prompt blocks with cache_control

// --- Serialization queue ---
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

// --- Tool definitions (Anthropic API format) ---
const TOOLS = [
  {
    name: "shell_exec",
    description: "Execute a shell command in the workspace. Returns stdout/stderr.",
    input_schema: {
      type: "object",
      properties: {
        command: { type: "string", description: "The shell command to execute" },
      },
      required: ["command"],
    },
  },
  {
    name: "file_read",
    description: "Read the contents of a file.",
    input_schema: {
      type: "object",
      properties: {
        path: { type: "string", description: "Absolute path to the file" },
      },
      required: ["path"],
    },
  },
  {
    name: "file_write",
    description: "Write content to a file. Creates parent directories if needed.",
    input_schema: {
      type: "object",
      properties: {
        path: { type: "string", description: "Absolute path to the file" },
        content: { type: "string", description: "Content to write" },
      },
      required: ["path", "content"],
    },
  },
  {
    name: "file_str_replace",
    description: "Replace a specific string in a file. Use for targeted edits.",
    input_schema: {
      type: "object",
      properties: {
        path: { type: "string", description: "Absolute path to the file" },
        old_str: { type: "string", description: "The exact string to find" },
        new_str: { type: "string", description: "The replacement string" },
      },
      required: ["path", "old_str", "new_str"],
    },
  },
  {
    name: "file_list",
    description: "List files and directories at a given path.",
    input_schema: {
      type: "object",
      properties: {
        path: { type: "string", description: "Absolute path to the directory" },
      },
      required: ["path"],
    },
  },
  {
    name: "file_find_in_content",
    description: "Search for a regex pattern in file contents. Returns matching lines with paths and line numbers.",
    input_schema: {
      type: "object",
      properties: {
        path: { type: "string", description: "Directory or file to search in" },
        pattern: { type: "string", description: "Regex pattern to search for" },
      },
      required: ["path", "pattern"],
    },
  },
  {
    name: "file_find_by_name",
    description: "Find files matching a glob pattern in a directory tree.",
    input_schema: {
      type: "object",
      properties: {
        path: { type: "string", description: "Directory to search in" },
        glob: { type: "string", description: "Glob pattern (e.g. '*.js', 'test_*')" },
      },
      required: ["path", "glob"],
    },
  },
  { type: "web_search_20250305", name: "web_search" },
];

// --- Tool execution ---
async function executeTool(name, input) {
  switch (name) {
    case "shell_exec": {
      try {
        const output = execSync(input.command, {
          cwd: WORKSPACE,
          timeout: 60_000,
          encoding: "utf-8",
          maxBuffer: 1024 * 1024,
        });
        return output || "(no output)";
      } catch (err) {
        return `Exit code ${err.status || 1}: ${err.stderr || err.message}`;
      }
    }
    case "file_read": {
      try {
        return readFileSync(input.path, "utf-8");
      } catch (err) {
        return `Error: ${err.message}`;
      }
    }
    case "file_write": {
      try {
        mkdirSync(dirname(input.path), { recursive: true });
        writeFileSync(input.path, input.content, "utf-8");
        return `File written: ${input.path} (${input.content.length} bytes)`;
      } catch (err) {
        return `Error: ${err.message}`;
      }
    }
    case "file_str_replace": {
      try {
        const content = readFileSync(input.path, "utf-8");
        if (!content.includes(input.old_str)) {
          return `Error: old_str not found in ${input.path}`;
        }
        const newContent = content.replace(input.old_str, input.new_str);
        writeFileSync(input.path, newContent, "utf-8");
        return `Replaced in ${input.path}`;
      } catch (err) {
        return `Error: ${err.message}`;
      }
    }
    case "file_list": {
      try {
        const entries = readdirSync(input.path, { withFileTypes: true });
        return entries
          .map((e) => `${e.isDirectory() ? "[dir]" : "[file]"} ${e.name}`)
          .join("\n") || "(empty directory)";
      } catch (err) {
        return `Error: ${err.message}`;
      }
    }
    case "file_find_in_content": {
      try {
        const output = execSync(
          `grep -rn --include='*' -E ${JSON.stringify(input.pattern)} ${JSON.stringify(input.path)}`,
          { cwd: WORKSPACE, timeout: 30_000, encoding: "utf-8", maxBuffer: 1024 * 1024 }
        );
        return output || "(no matches)";
      } catch (err) {
        if (err.status === 1) return "(no matches)";
        return `Error: ${err.stderr || err.message}`;
      }
    }
    case "file_find_by_name": {
      try {
        const output = execSync(
          `find ${JSON.stringify(input.path)} -name ${JSON.stringify(input.glob)} -type f 2>/dev/null | head -200`,
          { cwd: WORKSPACE, timeout: 30_000, encoding: "utf-8", maxBuffer: 1024 * 1024 }
        );
        return output || "(no matches)";
      } catch (err) {
        return `Error: ${err.stderr || err.message}`;
      }
    }
    default:
      return `Unknown tool: ${name}`;
  }
}

// --- SSE helpers ---
function sendSSE(res, event, data) {
  if (res.writableEnded) return;
  res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
}

// --- System prompt setup ---
function getSystemBlocks(customSystemPrompt) {
  const base = customSystemPrompt || "You are a helpful coding assistant. You have access to a workspace at /home/user/workspace. Use the tools available to help the user with their tasks.";
  // cache_control on system prompt so it's cached across turns
  return [{ type: "text", text: base, cache_control: { type: "ephemeral" } }];
}

// --- Core agent loop ---
async function runAgent(prompt, customSystemPrompt, stream) {
  const startTime = Date.now();
  let totalInputTokens = 0;
  let totalOutputTokens = 0;
  let cacheReadTokens = 0;
  let cacheCreationTokens = 0;

  // Initialize system blocks on first call or if custom prompt provided
  if (!systemBlocks || customSystemPrompt) {
    systemBlocks = getSystemBlocks(customSystemPrompt);
  }

  // Add user message
  conversationMessages.push({ role: "user", content: prompt });

  // Add cache_control to the last user message before the new one (conversation prefix caching)
  if (conversationMessages.length >= 3) {
    const prevMsg = conversationMessages[conversationMessages.length - 2];
    if (typeof prevMsg.content === "string") {
      prevMsg.content = [
        { type: "text", text: prevMsg.content, cache_control: { type: "ephemeral" } },
      ];
    } else if (Array.isArray(prevMsg.content)) {
      // Mark last block with cache_control
      const lastBlock = prevMsg.content[prevMsg.content.length - 1];
      if (lastBlock && !lastBlock.cache_control) {
        lastBlock.cache_control = { type: "ephemeral" };
      }
    }
  }

  let fullTextContent = "";

  for (let iteration = 0; iteration < MAX_TOOL_ITERATIONS; iteration++) {
    const messageStream = anthropic.messages.stream({
      model: MODEL,
      max_tokens: MAX_TOKENS,
      system: systemBlocks,
      messages: conversationMessages,
      tools: TOOLS,
    });

    // Stream text deltas if streaming response
    if (stream) {
      messageStream.on("text", (text) => {
        fullTextContent += text;
        sendSSE(stream, "token", { text });
      });
    }

    const finalMsg = await messageStream.finalMessage();

    // Track token usage
    totalInputTokens += finalMsg.usage?.input_tokens || 0;
    totalOutputTokens += finalMsg.usage?.output_tokens || 0;
    cacheReadTokens += finalMsg.usage?.cache_read_input_tokens || 0;
    cacheCreationTokens += finalMsg.usage?.cache_creation_input_tokens || 0;

    // Append assistant message to conversation
    conversationMessages.push({ role: "assistant", content: finalMsg.content });

    // If not streaming, collect text from the response
    if (!stream) {
      for (const block of finalMsg.content) {
        if (block.type === "text") {
          fullTextContent += block.text;
        }
      }
    }

    // Check stop reason
    if (finalMsg.stop_reason !== "tool_use") {
      // end_turn or max_tokens -- done
      break;
    }

    // Execute tools
    const toolUseBlocks = finalMsg.content.filter((b) => b.type === "tool_use");
    const toolResults = [];

    for (const block of toolUseBlocks) {
      if (stream) {
        sendSSE(stream, "tool_start", { tool: block.name, input: summarizeInput(block.input) });
      }

      try {
        const result = await executeTool(block.name, block.input);
        const truncated = typeof result === "string" && result.length > 10000
          ? result.slice(0, 10000) + "\n... [truncated]"
          : result;

        toolResults.push({
          type: "tool_result",
          tool_use_id: block.id,
          content: typeof truncated === "string" ? truncated : JSON.stringify(truncated),
        });

        if (stream) {
          sendSSE(stream, "tool_done", { tool: block.name, success: true });
        }
      } catch (err) {
        const errorMsg = err instanceof Error ? err.message : String(err);
        toolResults.push({
          type: "tool_result",
          tool_use_id: block.id,
          content: `Error: ${errorMsg}`,
          is_error: true,
        });

        if (stream) {
          sendSSE(stream, "tool_done", { tool: block.name, success: false, error: errorMsg });
        }
      }
    }

    // Append tool results as user message
    conversationMessages.push({ role: "user", content: toolResults });
  }

  const durationMs = Date.now() - startTime;
  const costUsd =
    (totalInputTokens * 3) / 1_000_000 +
    (totalOutputTokens * 15) / 1_000_000;

  console.log(
    `[Agent] Done. tokens: ${totalInputTokens}in/${totalOutputTokens}out, cache: ${cacheReadTokens}read/${cacheCreationTokens}write, cost: $${costUsd.toFixed(4)}, duration: ${durationMs}ms`
  );

  return {
    result: fullTextContent || "Agent completed with no response.",
    cost_usd: costUsd,
    duration_ms: durationMs,
    input_tokens: totalInputTokens,
    output_tokens: totalOutputTokens,
    cache_read_tokens: cacheReadTokens,
    cache_creation_tokens: cacheCreationTokens,
  };
}

/** Summarize tool input for SSE events (avoid sending huge payloads) */
function summarizeInput(input) {
  if (!input) return {};
  const summary = {};
  for (const [k, v] of Object.entries(input)) {
    if (typeof v === "string" && v.length > 200) {
      summary[k] = v.slice(0, 200) + "...";
    } else {
      summary[k] = v;
    }
  }
  return summary;
}

// --- HTTP server ---
const server = createServer(async (req, res) => {
  // Health check
  if (req.method === "GET" && req.url === "/health") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({
      status: "ok",
      messageCount: conversationMessages.length,
    }));
    return;
  }

  // Parse body for POST endpoints
  if (req.method === "POST" && (req.url === "/message" || req.url === "/stream" || req.url === "/context")) {
    let body = "";
    for await (const chunk of req) body += chunk;

    let parsed;
    try {
      parsed = JSON.parse(body);
    } catch {
      res.writeHead(400, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "Invalid JSON" }));
      return;
    }

    // Auth check
    if (AUTH_TOKEN && parsed.token !== AUTH_TOKEN) {
      res.writeHead(401, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "Unauthorized" }));
      return;
    }

    // --- POST /context (inject voice session context into system prompt) ---
    if (req.url === "/context") {
      const { messages } = parsed;
      if (!Array.isArray(messages)) {
        res.writeHead(400, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "messages array is required" }));
        return;
      }

      // Format voice transcripts as system-level context (not fake conversation)
      const contextLines = messages
        .filter((m) => m.role && m.content)
        .map((m) => `${m.role === "user" ? "User" : "Assistant"}: ${m.content}`)
        .join("\n");

      if (contextLines) {
        // Rebuild system blocks with voice context appended
        const basePrompt = systemBlocks?.[0]?.text || getSystemBlocks().text;
        const updatedPrompt = basePrompt +
          "\n\n[Voice conversation that just happened -- the user may refer to this. " +
          "You were the assistant in this conversation and performed any actions mentioned.]\n" +
          contextLines;
        systemBlocks = [{ type: "text", text: updatedPrompt, cache_control: { type: "ephemeral" } }];
      }

      console.log(`[Server] Injected ${messages.length} voice context messages into system prompt`);
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ ok: true, contextLines: messages.length }));
      return;
    }

    const { prompt, systemPrompt } = parsed;
    if (!prompt) {
      res.writeHead(400, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "prompt is required" }));
      return;
    }

    // --- POST /message (non-streaming, backward compatible) ---
    if (req.url === "/message") {
      try {
        const result = await enqueue(() => runAgent(prompt, systemPrompt, null));
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify(result));
      } catch (error) {
        const msg = error instanceof Error ? error.message : String(error);
        console.error("[Server] Agent error:", msg);
        res.writeHead(500, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: msg }));
      }
      return;
    }

    // --- POST /stream (SSE streaming) ---
    if (req.url === "/stream") {
      res.writeHead(200, {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        "Connection": "keep-alive",
        "Access-Control-Allow-Origin": "*",
      });

      try {
        const result = await enqueue(() => runAgent(prompt, systemPrompt, res));
        sendSSE(res, "done", {
          result: result.result,
          cost_usd: result.cost_usd,
          duration_ms: result.duration_ms,
          cache_read_tokens: result.cache_read_tokens,
        });
      } catch (error) {
        const msg = error instanceof Error ? error.message : String(error);
        console.error("[Server] Agent error:", msg);
        sendSSE(res, "error", { error: msg });
      }
      res.end();
      return;
    }
  }

  // CORS preflight
  if (req.method === "OPTIONS") {
    res.writeHead(204, {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    });
    res.end();
    return;
  }

  res.writeHead(404, { "Content-Type": "application/json" });
  res.end(JSON.stringify({ error: "Not found" }));
});

server.listen(PORT, () => {
  console.log(`Agent server listening on port ${PORT}`);
});
