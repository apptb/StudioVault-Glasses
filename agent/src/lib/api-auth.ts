import { NextRequest, NextResponse } from "next/server";
import { logSecurityEvent } from "@/lib/logger";

export interface AuthContext {
  actor: string;
  sessionKey: string;
}

interface AuthorizeOptions {
  action: string;
  resource: string;
  requireUser: boolean;
  requireSession: boolean;
}

type AuthResult =
  | { ok: true; context: AuthContext }
  | { ok: false; response: NextResponse };

function deny(reason: string): NextResponse {
  return NextResponse.json({ error: "Unauthorized", reason }, { status: 401 });
}

export async function authorizeRequest(
  request: NextRequest,
  options: AuthorizeOptions
): Promise<AuthResult> {
  const apiToken = request.headers.get("x-api-token");
  const actor = request.headers.get("x-agent-user-id") || "anonymous";
  const sessionKey = request.headers.get("x-agent-session-key") || "";

  if (process.env.AGENT_TOKEN && apiToken !== process.env.AGENT_TOKEN) {
    await logSecurityEvent({
      actor,
      action: options.action,
      resource: options.resource,
      decision: "deny",
      reason: "invalid_shared_token",
      session: sessionKey || undefined,
    });
    return { ok: false, response: deny("invalid_token") };
  }

  if (options.requireUser && actor === "anonymous") {
    await logSecurityEvent({
      actor,
      action: options.action,
      resource: options.resource,
      decision: "deny",
      reason: "missing_actor",
      session: sessionKey || undefined,
    });
    return { ok: false, response: deny("missing_actor") };
  }

  if (options.requireSession && !sessionKey) {
    await logSecurityEvent({
      actor,
      action: options.action,
      resource: options.resource,
      decision: "deny",
      reason: "missing_session",
    });
    return { ok: false, response: deny("missing_session") };
  }

  if (options.requireUser && options.requireSession && !sessionKey.startsWith(`${actor}:`)) {
    await logSecurityEvent({
      actor,
      action: options.action,
      resource: options.resource,
      decision: "deny",
      reason: "session_scope_mismatch",
      session: sessionKey || undefined,
    });
    return { ok: false, response: deny("session_scope_mismatch") };
  }

  await logSecurityEvent({
    actor,
    action: options.action,
    resource: options.resource,
    decision: "allow",
    session: sessionKey || undefined,
  });

  return {
    ok: true,
    context: {
      actor,
      sessionKey,
    },
  };
}

export async function authorizeUserScope(
  context: AuthContext,
  userId: string | null | undefined,
  action: string,
  resource: string,
  sessionOverride?: string
): Promise<NextResponse | null> {
  if (!userId || userId !== context.actor) {
    await logSecurityEvent({
      actor: context.actor,
      action,
      resource,
      decision: "deny",
      reason: "user_scope_mismatch",
      session: sessionOverride || context.sessionKey || undefined,
      metadata: { requestedUserId: userId || null },
    });
    return deny("user_scope_mismatch");
  }
  return null;
}
