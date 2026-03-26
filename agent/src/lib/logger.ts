import { redis, redisLTrim } from "./redis";

const MAX_LOGS = 200; // keep last 200 entries
const LOG_KEY = "agent:logs";

interface LogEntry {
  ts: string;
  type: "request" | "response" | "error" | "event" | "init";
  session?: string;
  userId?: string;
  data: Record<string, unknown>;
}

export async function log(
  type: LogEntry["type"],
  data: Record<string, unknown>,
  session?: string,
  userId?: string
): Promise<void> {
  try {
    const entry: LogEntry = {
      ts: new Date().toISOString(),
      type,
      session,
      userId,
      data,
    };
    const json = JSON.stringify(entry);

    // Global log (backwards compat)
    await redis(["LPUSH", LOG_KEY, json]);
    await redisLTrim(LOG_KEY, 0, MAX_LOGS - 1);

    // Per-user log
    if (userId) {
      const userKey = `logs:${userId}`;
      await redis(["LPUSH", userKey, json]);
      await redisLTrim(userKey, 0, MAX_LOGS - 1);
    }
  } catch {
    // logging should never break the request
  }
}

export async function getLogs(count = 50): Promise<LogEntry[]> {
  const result = await redis(["LRANGE", LOG_KEY, "0", String(count - 1)]);
  if (!Array.isArray(result)) return [];
  return result.map((s: string) => JSON.parse(s));
}

export async function getUserLogs(
  userId: string,
  count = 50
): Promise<LogEntry[]> {
  const result = await redis([
    "LRANGE",
    `logs:${userId}`,
    "0",
    String(count - 1),
  ]);
  if (!Array.isArray(result)) return [];
  return result.map((s: string) => JSON.parse(s));
}
