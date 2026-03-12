import { NextRequest, NextResponse } from "next/server";
import { getMemory, listLogDates, listNamedMemories } from "@/lib/memory-store";

export const dynamic = "force-dynamic";

/**
 * GET /api/memory/list?userId={userId}
 *
 * List available memory files (core + named files + daily log dates).
 */
export async function GET(request: NextRequest) {
  const apiToken = request.headers.get("x-api-token");
  if (process.env.AGENT_TOKEN && apiToken !== process.env.AGENT_TOKEN) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const userId = request.nextUrl.searchParams.get("userId");
  if (!userId) {
    return NextResponse.json(
      { error: "userId is required" },
      { status: 400 }
    );
  }

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
