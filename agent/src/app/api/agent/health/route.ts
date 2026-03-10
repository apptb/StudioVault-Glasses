import { NextRequest, NextResponse } from "next/server";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  // Auth check (optional -- allow health check without token for connectivity test)
  const apiToken = request.headers.get("x-api-token");
  if (process.env.AGENT_TOKEN && apiToken && apiToken !== process.env.AGENT_TOKEN) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  if (process.env.E2B_API_KEY && process.env.E2B_TEMPLATE_ID) {
    return NextResponse.json({
      status: "connected",
      mode: "e2b",
    });
  }

  return NextResponse.json(
    { status: "not_configured", error: "E2B not configured" },
    { status: 503 }
  );
}
