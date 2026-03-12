import {
  redisGet,
  redisSet,
  redisExpire,
  redisDel,
  redis,
} from "./redis";

const MEMORY_TTL = 90 * 24 * 60 * 60; // 90 days

// --- Core memory (backward compatible) ---

export async function getMemory(userId: string): Promise<string | null> {
  return await redisGet(`mem:${userId}:core`);
}

export async function setMemory(
  userId: string,
  content: string
): Promise<void> {
  await redisSet(`mem:${userId}:core`, content, MEMORY_TTL);
}

// --- Named memory files ---

export async function getNamedMemory(
  userId: string,
  name: string
): Promise<string | null> {
  const result = await redisGet(`mem:${userId}:file:${name}`);
  if (result !== null) {
    await redisExpire(`mem:${userId}:file:${name}`, MEMORY_TTL);
  }
  return result;
}

export async function setNamedMemory(
  userId: string,
  name: string,
  content: string
): Promise<void> {
  await redisSet(`mem:${userId}:file:${name}`, content, MEMORY_TTL);
  await redis(["SADD", `mem:${userId}:files`, name]);
  await redisExpire(`mem:${userId}:files`, MEMORY_TTL);
}

export async function deleteNamedMemory(
  userId: string,
  name: string
): Promise<void> {
  await redisDel(`mem:${userId}:file:${name}`);
  await redis(["SREM", `mem:${userId}:files`, name]);
}

export async function listNamedMemories(
  userId: string
): Promise<string[]> {
  const result = await redis(["SMEMBERS", `mem:${userId}:files`]);
  return Array.isArray(result) ? (result as string[]) : [];
}

// --- Daily logs ---

export async function appendDailyLog(
  userId: string,
  entry: string
): Promise<void> {
  const date = new Date().toISOString().slice(0, 10);
  const key = `mem:${userId}:log:${date}`;
  await redis(["RPUSH", key, entry]);
  await redisExpire(key, MEMORY_TTL);
  const score = parseInt(date.replace(/-/g, ""));
  await redis([
    "ZADD",
    `mem:${userId}:dates`,
    String(score),
    date,
  ]);
  await redisExpire(`mem:${userId}:dates`, MEMORY_TTL);
}

export async function getDailyLog(
  userId: string,
  date: string
): Promise<string[]> {
  const result = await redis([
    "LRANGE",
    `mem:${userId}:log:${date}`,
    "0",
    "-1",
  ]);
  return Array.isArray(result) ? (result as string[]) : [];
}

export async function listLogDates(userId: string): Promise<string[]> {
  const result = await redis([
    "ZRANGE",
    `mem:${userId}:dates`,
    "0",
    "-1",
  ]);
  return Array.isArray(result) ? (result as string[]) : [];
}

// --- Bulk read (for search + system prompt injection) ---

export async function getAllMemoryContent(
  userId: string
): Promise<{ file: string; content: string }[]> {
  const results: { file: string; content: string }[] = [];

  // Core memory
  const core = await getMemory(userId);
  if (core) results.push({ file: "core", content: core });

  // Named files
  const names = await listNamedMemories(userId);
  for (const name of names) {
    const content = await getNamedMemory(userId, name);
    if (content) results.push({ file: name, content });
  }

  // Recent daily logs (last 7 days)
  const dates = await listLogDates(userId);
  const recentDates = dates.slice(-7);
  for (const date of recentDates) {
    const entries = await getDailyLog(userId, date);
    if (entries.length > 0) {
      results.push({ file: date, content: entries.join("\n") });
    }
  }

  return results;
}
