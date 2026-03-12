import { NextRequest, NextResponse } from "next/server";
import { getAllMemoryContent } from "@/lib/memory-store";
import {
  isEmbeddingAvailable,
  embed,
  cosineSimilarity,
} from "@/lib/embeddings";

export const dynamic = "force-dynamic";

interface ScoredChunk {
  file: string;
  text: string;
  keywordScore: number;
  score: number;
}

/**
 * GET /api/memory/search?userId={userId}&query={query}
 *
 * Hybrid keyword + vector search across all memory files.
 * Falls back to keyword-only if OPENAI_API_KEY is not set.
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

  // Build chunk list from all memory content
  const chunks: ScoredChunk[] = [];

  for (const { file, content } of allContent) {
    const parts = content.includes("\n\n")
      ? content.split(/\n\n+/)
      : content.split(/\n/);

    for (const part of parts) {
      const trimmed = part.trim();
      if (trimmed.length < 5) continue;

      const chunkLower = trimmed.toLowerCase();
      let keywordScore = 0;

      // Word match scoring
      for (const word of queryWords) {
        const regex = new RegExp(`\\b${escapeRegex(word)}`, "gi");
        const matches = chunkLower.match(regex);
        if (matches) {
          keywordScore += matches.length / queryWords.length;
        }
      }

      // Exact phrase boost
      if (chunkLower.includes(queryLower)) {
        keywordScore += 2;
      }

      // Recency boost for dated logs
      if (/^\d{4}-\d{2}-\d{2}$/.test(file)) {
        const daysSince =
          (Date.now() - new Date(file).getTime()) / (1000 * 60 * 60 * 24);
        if (daysSince < 7) keywordScore *= 1.5;
        else if (daysSince < 30) keywordScore *= 1.2;
      }

      // Normalize by chunk length
      const wordCount = trimmed.split(/\s+/).length;
      if (wordCount > 10) {
        keywordScore = keywordScore / Math.log2(wordCount);
      }

      chunks.push({
        file,
        text: trimmed,
        keywordScore,
        score: keywordScore, // will be overwritten if vector search available
      });
    }
  }

  if (chunks.length === 0) {
    return NextResponse.json({ results: [] });
  }

  // Hybrid scoring: keyword (0.3) + vector (0.7) if embeddings available
  if (isEmbeddingAvailable()) {
    try {
      // Batch embed: [query, chunk0, chunk1, ...]
      const textsToEmbed = [query, ...chunks.map((c) => c.text.slice(0, 500))];
      const embeddings = await embed(textsToEmbed);
      const queryEmb = embeddings[0];

      for (let i = 0; i < chunks.length; i++) {
        const vectorScore = cosineSimilarity(queryEmb, embeddings[i + 1]);
        // Hybrid: 30% keyword + 70% vector
        chunks[i].score =
          0.3 * chunks[i].keywordScore + 0.7 * vectorScore;
      }
    } catch (err) {
      // Embedding failed, fall back to keyword-only scores
      console.error("[Search] Embedding failed, using keyword-only:", err);
    }
  }

  // Sort by score descending, return top 5
  chunks.sort((a, b) => b.score - a.score);
  const results = chunks.slice(0, 5).map((c) => ({
    file: c.file,
    snippet: c.text.slice(0, 200),
    score: Math.round(c.score * 100) / 100,
  }));

  return NextResponse.json({ results });
}

function escapeRegex(str: string): string {
  return str.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
