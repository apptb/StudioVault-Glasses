import { NextRequest, NextResponse } from "next/server";
import { getMemory, listLogDates, listNamedMemories } from "@/lib/memory-store";
import { authorizeRequest, authorizeUserScope } from "@/lib/api-auth";

export const dynamic = "force-dynamic";

/**
 * GET /api/memory/list?userId={userId}
 *
 * List available memory files (core + named files + daily log dates).
 */
export async function GET(request: NextRequest) {
  const auth = await authorizeRequest(request, {
    action: "memory.list",
    resource: "/api/memory/list",
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
    "memory.list",
    "/api/memory/list"
  );
  if (scopeError) return scopeError;

  const files: string[] = [];

  // Check if core memory exists
  const core = await getMemory(userId);
  if (core) {
    files.push("core");
  }

  // Named memory files
  const named = await listNamedMemories(userId);
  files.push(...named);

  // Daily log dates
  const dates = await listLogDates(userId);
  files.push(...dates);

  return NextResponse.json({ files });
}
