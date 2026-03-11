import { NextRequest, NextResponse } from "next/server";
import { getMemory, getDailyLog } from "@/lib/memory-store";

export const dynamic = "force-dynamic";

/**
 * GET /api/memory/read?userId={userId}&file={core|YYYY-MM-DD}
 *
 * Read persistent memory content.
 */
export async function GET(request: NextRequest) {
  const apiToken = request.headers.get("x-api-token");
  if (process.env.AGENT_TOKEN && apiToken !== process.env.AGENT_TOKEN) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const userId = request.nextUrl.searchParams.get("userId");
  const file = request.nextUrl.searchParams.get("file") || "core";

  if (!userId) {
    return NextResponse.json(
      { error: "userId is required" },
      { status: 400 }
    );
  }

  if (file === "core") {
    const content = await getMemory(userId);
    return NextResponse.json({ content: content || "" });
  }

  // Treat as daily log date (YYYY-MM-DD)
  const entries = await getDailyLog(userId, file);
  return NextResponse.json({ content: entries.join("\n") });
}
