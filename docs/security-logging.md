# Security Logging and PHI-Safe Redaction

This project uses structured security event logging for all sensitive API routes under `agent/src/app/api`.

## Security event schema

Every authorization decision should emit a security event containing:

- `actor`: authenticated user identifier (or `anonymous` when unavailable)
- `action`: operation name (for example, `memory.read`, `agent.chat`)
- `resource`: API route/resource identifier
- `decision`: `allow` or `deny`
- `timestamp`: ISO-8601 timestamp
- Optional: `reason`, `session`, and constrained metadata

## PHI-safe logging rules

1. **Do not log raw PHI**
   - Never persist full prompts, notes, diagnoses, medications, lab values, or full document payloads.
2. **Prefer identifiers and aggregates**
   - Log user/session identifiers, event names, and counts instead of full content.
3. **Apply redaction to string fields**
   - Redact email addresses, phone numbers, and SSN-like values before persistence.
4. **Use structured logs**
   - Emit machine-readable records (JSON/object fields), not ad-hoc concatenated strings.
5. **Keep error logs minimal**
   - Capture error summaries and classes; avoid stack traces that may include request content.

## Authorization telemetry expectations

- Route-level authorization middleware must log both allow and deny decisions.
- User scope checks (for `userId` query/body parameters) must deny and log mismatches.
- Session scope checks (for `x-agent-session-key`) must deny and log mismatches.

## Operational notes

- Security logs are retained in Redis using existing capped log behavior.
- Redaction is best-effort and should be treated as defense-in-depth, not a substitute for careful logging discipline.
