import {
  redisGet,
  redisSet,
  redisExpire,
  redis,
} from "./redis";

const MEMORY_TTL = 90 * 24 * 60 * 60; // 90 days

export async function getMemory(userId: string): Promise<string | null> {
  return await redisGet(`mem:${userId}:core`);
}

export async function setMemory(
  userId: string,
  content: string
): Promise<void> {
  await redisSet(`mem:${userId}:core`, content, MEMORY_TTL);
}

export async function appendDailyLog(
  userId: string,
  entry: string
): Promise<void> {
  const date = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
  const key = `mem:${userId}:log:${date}`;
  await redis(["RPUSH", key, entry]);
  await redisExpire(key, MEMORY_TTL);
  // Track date in sorted set
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
