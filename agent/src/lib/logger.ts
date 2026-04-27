import { redis, redisLTrim } from "./redis";

const MAX_LOGS = 200; // keep last 200 entries
const LOG_KEY = "agent:logs";

interface LogEntry {
  ts: string;
  type: "request" | "response" | "error" | "event" | "init" | "security";
  session?: string;
  userId?: string;
  data: Record<string, unknown>;
}

export interface SecurityEvent {
  actor: string;
  action: string;
  resource: string;
  decision: "allow" | "deny";
  reason?: string;
  session?: string;
  metadata?: Record<string, unknown>;
}

/**
 * PHI-safe logging rules:
 * 1) Never log full prompts, responses, medical notes, diagnoses, meds, labs, IDs, or raw payloads.
 * 2) Prefer stable identifiers (user/session ids), short enums, and aggregate metrics.
 * 3) Redact likely PHI tokens (emails, phone-like values, SSN-like values) before persistence.
 * 4) Keep security telemetry structured: actor/action/resource/decision/timestamp.
 * 5) On errors, log class and summary only, not stack traces with request data.
 */
function redactValue(value: unknown): unknown {
  if (typeof value !== "string") return value;

  return value
    .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, "[REDACTED_EMAIL]")
    .replace(/\b(?:\+?1[-.\s]?)?(?:\(?\d{3}\)?[-.\s]?)\d{3}[-.\s]?\d{4}\b/g, "[REDACTED_PHONE]")
    .replace(/\b\d{3}-\d{2}-\d{4}\b/g, "[REDACTED_SSN]");
}

function redactData(data: Record<string, unknown>): Record<string, unknown> {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => {
      if (typeof value === "string") {
        return [key, redactValue(value)];
      }
      if (Array.isArray(value)) {
        return [key, value.map((item) => redactValue(item))];
      }
      return [key, value];
    })
  );
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
      data: redactData(data),
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

export async function logSecurityEvent(event: SecurityEvent): Promise<void> {
  await log(
    "security",
    {
      actor: event.actor,
      action: event.action,
      resource: event.resource,
      decision: event.decision,
      reason: event.reason,
      timestamp: new Date().toISOString(),
      ...(event.metadata ?? {}),
    },
    event.session,
    event.actor !== "anonymous" ? event.actor : undefined
  );
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
