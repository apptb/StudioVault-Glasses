import { NextRequest, NextResponse } from "next/server";
import {
  setMemory,
  appendDailyLog,
  setNamedMemory,
  deleteNamedMemory,
} from "@/lib/memory-store";

export const dynamic = "force-dynamic";

/**
 * POST /api/memory/write
 * Body: { userId, file: "core"|"log"|"<name>", content: "...", delete?: true }
 *
 * Write to persistent memory.
 * - file: "core"   -- full replace of main memory
 * - file: "log"    -- append to today's daily log
 * - file: "<name>" -- create/overwrite a named memory file
 * - delete: true   -- delete a named memory file (content not required)
 */
export async function POST(request: NextRequest) {
  const apiToken = request.headers.get("x-api-token");
  if (process.env.AGENT_TOKEN && apiToken !== process.env.AGENT_TOKEN) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const body = await request.json();
  const { userId, file, content } = body;

  if (!userId) {
    return NextResponse.json(
      { error: "userId is required" },
      { status: 400 }
    );
  }

  // Delete a named file
  if (body.delete && file && file !== "core" && file !== "log") {
    await deleteNamedMemory(userId, file);
    return NextResponse.json({ ok: true, type: "deleted", file });
  }

  if (!content) {
    return NextResponse.json(
      { error: "content is required" },
      { status: 400 }
    );
  }

  if (file === "log") {
    await appendDailyLog(userId, content);
    return NextResponse.json({ ok: true, type: "log" });
  }

  if (file === "core") {
    await setMemory(userId, content);
    return NextResponse.json({ ok: true, type: "core" });
  }

  // Named memory file
  await setNamedMemory(userId, file, content);
  return NextResponse.json({ ok: true, type: "named", file });
}
