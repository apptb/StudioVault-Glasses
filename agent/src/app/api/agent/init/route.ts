import { NextRequest, NextResponse } from "next/server";
import { getOrCreateSandbox } from "@/lib/sandbox";
import { log } from "@/lib/logger";

export const dynamic = "force-dynamic";
export const maxDuration = 60;

/**
 * POST /api/agent/init
 *
 * Called once per session by iOS to get the sandbox URL + auth token.
 * iOS then talks directly to the E2B sandbox for all subsequent messages,
 * bypassing Vercel from the hot path.
 */
export async function POST(request: NextRequest) {
  let sessionKey = "unknown";
  try {
    // Auth check
    const apiToken = request.headers.get("x-api-token");
    if (process.env.AGENT_TOKEN && apiToken !== process.env.AGENT_TOKEN) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    // Verify E2B is configured
    if (!process.env.E2B_API_KEY || !process.env.E2B_TEMPLATE_ID) {
      return NextResponse.json(
        { error: "Agent backend not configured" },
        { status: 503 }
      );
    }

    sessionKey =
      request.headers.get("x-agent-session-key") ||
      `anonymous:${Date.now()}`;
    const userId = request.headers.get("x-agent-user-id") || "";

    console.log(`[Init] Session: ${sessionKey}, userId: ${userId.slice(0, 8)}...`);

    const handle = await getOrCreateSandbox(sessionKey, userId || undefined);

    // Build the public sandbox URL that iOS can call directly
    const sandboxHost = handle.sandbox.getHost(3000);
    const sandboxUrl = `https://${sandboxHost}`;

    await log(
      "init",
      {
        sandboxId: handle.sandbox.sandboxId,
        sandboxUrl,
        isNew: handle.isNewSandbox,
      },
      sessionKey,
      userId || undefined
    );

    return NextResponse.json({
      sandboxUrl,
      authToken: handle.authToken,
      sessionKey,
      isNew: handle.isNewSandbox,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("[Init] Error:", message);
    await log("error", { error: message, source: "init" }, sessionKey, undefined);
    return NextResponse.json(
      { error: `Init error: ${message}` },
      { status: 502 }
    );
  }
}
