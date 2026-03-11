import { NextRequest, NextResponse } from "next/server";
import { setMemory, appendDailyLog } from "@/lib/memory-store";

export const dynamic = "force-dynamic";

/**
 * POST /api/memory/write
 * Body: { userId, file: "core"|"log", content: "..." }
 *
 * Write to persistent memory.
 * - file: "core" -- full replace of MEMORY.md
 * - file: "log"  -- append to today's daily log
 */
export async function POST(request: NextRequest) {
  const apiToken = request.headers.get("x-api-token");
  if (process.env.AGENT_TOKEN && apiToken !== process.env.AGENT_TOKEN) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const body = await request.json();
  const { userId, file, content } = body;

  if (!userId || !content) {
    return NextResponse.json(
      { error: "userId and content are required" },
      { status: 400 }
    );
  }

  if (file === "log") {
    await appendDailyLog(userId, content);
    return NextResponse.json({ ok: true, type: "log" });
  }

  // Default: core memory
  await setMemory(userId, content);
  return NextResponse.json({ ok: true, type: "core" });
}
