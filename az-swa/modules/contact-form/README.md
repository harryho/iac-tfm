# contact-form

Per-site contact form, deployed as a SWA linked API. **This module has no
Terraform.** The function source lives here and is deployed by the
`swa deploy` step in `../../scripts/deploy-site.sh`. Configuration
(SMTP credentials, recipient, etc.) is passed to the SWA via
`app_settings` from the env's `sites.tf`.

## Files

- `src/index.mjs` — function handler (Node 20, ESM). Receives a POST,
  forwards to ACS Email (primary) or AWS SES (fallback), logs the
  submission.
- `src/function.json` — SWA function binding config.
- `package.json` — dependencies (none at runtime; the SES SDK is
  dynamically imported).

## App settings expected by the handler

| Key | Purpose |
|---|---|
| `RECIPIENT_EMAIL` | Where to send the email |
| `SENDER_EMAIL` | From address (`noreply@<domain>`) |
| `ACS_CONNECTION_STRING` | Azure Communication Services connection string (primary) |
| `SES_ACCESS_KEY` / `SES_SECRET_KEY` / `SES_REGION` | AWS SES fallback |
| `TURNSTILE_SECRET` | Cloudflare Turnstile verification (optional) |

The env's `sites.tf` builds a `contact_settings_for` map keyed by site
that has a contact form enabled, and merges those into each site's
`app_settings`.

## Build

The SWA CLI builds and bundles this function automatically during
`swa deploy`. No separate build step needed.

## Customize

Replace `src/index.mjs` with your own handler. Keep the same app-settings
contract, or update both the handler and `envs/<env>/sites.tf` together.