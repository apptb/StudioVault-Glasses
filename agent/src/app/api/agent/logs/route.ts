import { NextRequest, NextResponse } from "next/server";
import { getUserLogs, log } from "@/lib/logger";
import { authorizeRequest } from "@/lib/api-auth";

export const dynamic = "force-dynamic";

// GET /api/agent/logs?count=50 — fetch recent logs
export async function GET(request: NextRequest) {
  const auth = await authorizeRequest(request, {
    action: "agent.logs.read",
    resource: "/api/agent/logs",
    requireUser: true,
    requireSession: false,
  });
  if (!auth.ok) {
    return auth.response;
  }

  const count = parseInt(request.nextUrl.searchParams.get("count") || "50");
  const logs = await getUserLogs(auth.context.actor, Math.min(count, 200));
  return NextResponse.json({ logs, count: logs.length });
}

// POST /api/agent/logs — iOS app can send client-side events
export async function POST(request: NextRequest) {
  const auth = await authorizeRequest(request, {
    action: "agent.logs.write",
    resource: "/api/agent/logs",
    requireUser: true,
    requireSession: false,
  });
  if (!auth.ok) {
    return auth.response;
  }

  const body = await request.json();
  await log(
    body.type || "event",
    body.data || body,
    body.session || auth.context.sessionKey || "ios-client",
    auth.context.actor
  );
  return NextResponse.json({ ok: true });
}
