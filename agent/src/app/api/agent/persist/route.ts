import { NextRequest, NextResponse } from "next/server";
import { appendMessage } from "@/lib/session-store";
import { log } from "@/lib/logger";

export const dynamic = "force-dynamic";

/**
 * POST /api/agent/persist
 *
 * Called by iOS/Android after receiving a response from the direct sandbox path.
 * Persists both user and assistant messages to Redis so they survive sandbox recycling.
 */
export async function POST(request: NextRequest) {
  try {
    const apiToken = request.headers.get("x-api-token");
    if (process.env.AGENT_TOKEN && apiToken !== process.env.AGENT_TOKEN) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const body = await request.json();
    const { sessionKey, userId, userMessage, assistantMessage, costUsd, durationMs } = body;

    if (!sessionKey) {
      return NextResponse.json(
        { error: "sessionKey required" },
        { status: 400 }
      );
    }

    const uid = userId || undefined;

    if (userMessage) {
      await appendMessage(sessionKey, { role: "user", content: userMessage }, uid);
    }

    if (assistantMessage) {
      await appendMessage(
        sessionKey,
        {
          role: "assistant",
          content: assistantMessage,
          costUsd: costUsd ?? undefined,
          durationMs: durationMs ?? undefined,
        },
        uid
      );
    }

    await log(
      "response",
      {
        source: "persist",
        prompt: userMessage?.slice(0, 200) ?? "",
        response: assistantMessage?.slice(0, 500) ?? "",
        costUsd,
        durationMs,
      },
      sessionKey,
      uid
    );

    return NextResponse.json({ ok: true });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("[Persist] Error:", message);
    return NextResponse.json(
      { error: `Persist error: ${message}` },
      { status: 500 }
    );
  }
}
