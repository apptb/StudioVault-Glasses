import { NextRequest, NextResponse } from "next/server";
import { getMemory, getDailyLog, getNamedMemory } from "@/lib/memory-store";
import { authorizeRequest, authorizeUserScope } from "@/lib/api-auth";

export const dynamic = "force-dynamic";

/**
 * GET /api/memory/read?userId={userId}&file={core|YYYY-MM-DD|<name>}
 *
 * Read persistent memory content.
 */
export async function GET(request: NextRequest) {
  const auth = await authorizeRequest(request, {
    action: "memory.read",
    resource: "/api/memory/read",
    requireUser: true,
    requireSession: false,
  });
  if (!auth.ok) {
    return auth.response;
  }

  const userId = request.nextUrl.searchParams.get("userId");
  const file = request.nextUrl.searchParams.get("file") || "core";

  if (!userId) {
    return NextResponse.json(
      { error: "userId is required" },
      { status: 400 }
    );
  }
  const scopeError = await authorizeUserScope(
    auth.context,
    userId,
    "memory.read",
    "/api/memory/read"
  );
  if (scopeError) return scopeError;

  if (file === "core") {
    const content = await getMemory(userId);
    return NextResponse.json({ content: content || "" });
  }

  // Check if it's a date (YYYY-MM-DD format)
  if (/^\d{4}-\d{2}-\d{2}$/.test(file)) {
    const entries = await getDailyLog(userId, file);
    return NextResponse.json({ content: entries.join("\n") });
  }

  // Named memory file
  const content = await getNamedMemory(userId, file);
  return NextResponse.json({ content: content || "" });
}
