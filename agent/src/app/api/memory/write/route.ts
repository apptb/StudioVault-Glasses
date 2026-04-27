import { NextRequest, NextResponse } from "next/server";
import {
  setMemory,
  appendDailyLog,
  setNamedMemory,
  deleteNamedMemory,
} from "@/lib/memory-store";
import { authorizeRequest, authorizeUserScope } from "@/lib/api-auth";

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
  const auth = await authorizeRequest(request, {
    action: "memory.write",
    resource: "/api/memory/write",
    requireUser: true,
    requireSession: false,
  });
  if (!auth.ok) {
    return auth.response;
  }

  const body = await request.json();
  const { userId, file, content } = body;

  if (!userId) {
    return NextResponse.json(
      { error: "userId is required" },
      { status: 400 }
    );
  }
  const scopeError = await authorizeUserScope(
    auth.context,
    userId,
    "memory.write",
    "/api/memory/write"
  );
  if (scopeError) return scopeError;

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
