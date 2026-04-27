import { NextRequest, NextResponse } from "next/server";
import { getUserSessions, getMessages, getMessageCount } from "@/lib/session-store";
import { authorizeRequest, authorizeUserScope } from "@/lib/api-auth";

export const dynamic = "force-dynamic";

interface SessionSummary {
  sessionKey: string;
  timestamp: string;
  prompt: string;
  result: string;
  messageCount: number;
}

/**
 * GET /api/agent/sessions?userId=xxx&limit=20
 *
 * List recent sessions for a user with first user message and last assistant response.
 */
export async function GET(request: NextRequest) {
  const auth = await authorizeRequest(request, {
    action: "agent.sessions.read",
    resource: "/api/agent/sessions",
    requireUser: true,
    requireSession: false,
  });
  if (!auth.ok) {
    return auth.response;
  }

  const userId = request.nextUrl.searchParams.get("userId");
  if (!userId) {
    return NextResponse.json(
      { error: "userId is required" },
      { status: 400 }
    );
  }
  const scopeError = await authorizeUserScope(
    auth.context,
    userId,
    "agent.sessions.read",
    "/api/agent/sessions"
  );
  if (scopeError) return scopeError;

  const limit = Math.min(
    parseInt(request.nextUrl.searchParams.get("limit") || "20", 10),
    50
  );

  const sessionKeys = await getUserSessions(userId, limit);
  const sessions: SessionSummary[] = [];

  for (const key of sessionKeys) {
    try {
      const count = await getMessageCount(key);
      if (count === 0) continue;

      const messages = await getMessages(key);
      const firstUser = messages.find((m) => m.role === "user");
      const lastAssistant = [...messages]
        .reverse()
        .find((m) => m.role === "assistant");

      sessions.push({
        sessionKey: key,
        timestamp: firstUser?.ts || messages[0]?.ts || "",
        prompt: firstUser?.content.slice(0, 200) || "",
        result: lastAssistant?.content.slice(0, 500) || "",
        messageCount: count,
      });
    } catch {
      // Skip broken sessions
    }
  }

  return NextResponse.json({ sessions });
}
