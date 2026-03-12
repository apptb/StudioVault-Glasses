import { NextRequest, NextResponse } from "next/server";
import { getAllMemoryContent } from "@/lib/memory-store";

export const dynamic = "force-dynamic";

/**
 * GET /api/memory/search?userId={userId}&query={query}
 *
 * Keyword search across all memory files.
 * Returns top-5 matching chunks with file name, snippet, and score.
 */
export async function GET(request: NextRequest) {
  const apiToken = request.headers.get("x-api-token");
  if (process.env.AGENT_TOKEN && apiToken !== process.env.AGENT_TOKEN) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const userId = request.nextUrl.searchParams.get("userId");
  const query = request.nextUrl.searchParams.get("query");

  if (!userId || !query) {
    return NextResponse.json(
      { error: "userId and query are required" },
      { status: 400 }
    );
  }

  const allContent = await getAllMemoryContent(userId);
  if (allContent.length === 0) {
    return NextResponse.json({ results: [] });
  }

  // Tokenize query into lowercase words
  const queryWords = query
    .toLowerCase()
    .split(/\s+/)
    .filter((w) => w.length > 1);
  const queryLower = query.toLowerCase();

  if (queryWords.length === 0) {
    return NextResponse.json({ results: [] });
  }

  // Split all content into chunks and score them
  const scored: { file: string; snippet: string; score: number }[] = [];

  for (const { file, content } of allContent) {
    // Split on double newlines (paragraphs) or single newlines for short content
    const chunks =
      content.includes("\n\n")
        ? content.split(/\n\n+/)
        : content.split(/\n/);

    for (const chunk of chunks) {
      const trimmed = chunk.trim();
      if (trimmed.length < 5) continue;

      const chunkLower = trimmed.toLowerCase();
      let score = 0;

      // Word match scoring
      for (const word of queryWords) {
        const regex = new RegExp(`\\b${escapeRegex(word)}`, "gi");
        const matches = chunkLower.match(regex);
        if (matches) {
          score += matches.length / queryWords.length;
        }
      }

      // Exact phrase boost
      if (chunkLower.includes(queryLower)) {
        score += 2;
      }

      // Recency boost for dated logs
      if (/^\d{4}-\d{2}-\d{2}$/.test(file)) {
        const daysSinceEpoch =
          (Date.now() - new Date(file).getTime()) / (1000 * 60 * 60 * 24);
        if (daysSinceEpoch < 7) score *= 1.5;
        else if (daysSinceEpoch < 30) score *= 1.2;
      }

      // Normalize by chunk length (prefer concise, relevant chunks)
      const words = trimmed.split(/\s+/).length;
      if (words > 10) {
        score = score / Math.log2(words);
      }

      if (score > 0) {
        scored.push({
          file,
          snippet: trimmed.slice(0, 200),
          score: Math.round(score * 100) / 100,
        });
      }
    }
  }

  // Sort by score descending, return top 5
  scored.sort((a, b) => b.score - a.score);
  const results = scored.slice(0, 5);

  return NextResponse.json({ results });
}

function escapeRegex(str: string): string {
  return str.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
