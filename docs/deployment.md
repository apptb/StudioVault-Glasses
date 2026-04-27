# Deployment Runbook (`agent/`)

This document defines the **authoritative deployment path** for the `agent/` service.

## Platform Decision (Authoritative)

- **Standard platform:** **Vercel**
- **Status:** Netlify is **not** part of the supported deployment path for `agent/`.

The repository currently ships with Next.js + `vercel.json` configuration under `agent/`, and team runbooks should treat Vercel as the source of truth.

## Canonical Deployment Flow

From the repository root:

```bash
cd agent
npm ci
npm run build
vercel deploy
```

For production:

```bash
vercel deploy --prod
```

## Runbook Guardrails

When validating deployments for `agent/`, use only Vercel-oriented checks:

- Verify Vercel deployment status and environment variables.
- Verify Next.js build output (`npm run build`) before deploy.
- Verify runtime endpoints on the Vercel deployment URL.

Do **not** require Netlify-specific checks (for example, Netlify function logs or Netlify CLI deploy checks) for `agent/`.

## OAuth Redirect URI Examples

`agent/src/app/api/notion/auth/route.ts` and `agent/src/app/api/notion/callback/route.ts` derive redirect URIs from the request host and expect:

`/api/notion/callback`

Use environment-specific app URLs like:

- **Development (local):** `http://localhost:3000/api/notion/callback`
- **Staging (Vercel preview):** `https://staging-agent.studiovault.ai/api/notion/callback`
- **Production (Vercel):** `https://agent.studiovault.ai/api/notion/callback`

If your OAuth provider allows multiple redirect URIs, register each environment explicitly. For the mobile handoff after token exchange, the callback remains:

- `matcha://notion-callback`
