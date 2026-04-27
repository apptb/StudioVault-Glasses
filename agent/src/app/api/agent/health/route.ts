import { NextRequest, NextResponse } from "next/server";
import { authorizeRequest } from "@/lib/api-auth";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  const auth = await authorizeRequest(request, {
    action: "agent.health.read",
    resource: "/api/agent/health",
    requireUser: false,
    requireSession: false,
  });
  if (!auth.ok) {
    return auth.response;
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
