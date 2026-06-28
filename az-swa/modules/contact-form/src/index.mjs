// Contact-form handler for Azure Static Web Apps.
//
// POST body: { name, email, message, turnstileToken? }
// Required app settings:
//   RECIPIENT_EMAIL, SENDER_EMAIL
//   ACS_CONNECTION_STRING   (primary; ACS Email)
//   SES_ACCESS_KEY, SES_SECRET_KEY, SES_REGION  (fallback; AWS SES)
//   TURNSTILE_SECRET        (optional; Cloudflare Turnstile)
//
// Behavior:
//   1. Verify Turnstile if TURNSTILE_SECRET is set.
//   2. Validate input shape.
//   3. Try ACS Email first. If ACS not configured or fails, fall back to SES.
//
// This is a minimal scaffold — replace with your handler and keep the
// app-settings contract, or update sites.tf together with the handler.

import { randomUUID } from "node:crypto";

const json = (status, body) => ({
  status,
  headers: { "content-type": "application/json" },
  body: JSON.stringify(body),
});

const validEmail = (s) => typeof s === "string" && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s);

export default async function (context) {
  const { req } = context;

  if (req.method === "OPTIONS") {
    return { status: 204, headers: corsHeaders(req) };
  }

  if (req.method !== "POST") {
    return json(405, { error: "method_not_allowed" });
  }

  let body;
  try {
    body = typeof req.body === "string" ? JSON.parse(req.body) : req.body ?? {};
  } catch {
    return json(400, { error: "invalid_json" });
  }

  const { name, email, message, turnstileToken } = body;

  if (!validEmail(email) || !message || !name) {
    return json(400, { error: "invalid_input" });
  }

  const settings = process.env;
  if (!settings.RECIPIENT_EMAIL || !settings.SENDER_EMAIL) {
    return json(500, { error: "missing_app_settings" });
  }

  if (settings.TURNSTILE_SECRET) {
    const ok = await verifyTurnstile(turnstileToken, settings.TURNSTILE_SECRET);
    if (!ok) return json(400, { error: "turnstile_failed" });
  }

  const subject = `[contact] ${name}`;
  const text = `From: ${name} <${email}>\n\n${message}`;

  if (settings.ACS_CONNECTION_STRING) {
    const ok = await sendViaAcs(settings.ACS_CONNECTION_STRING, settings.SENDER_EMAIL, settings.RECIPIENT_EMAIL, subject, text);
    if (ok) return json(200, { id: randomUUID(), provider: "acs" });
  }

  if (settings.SES_ACCESS_KEY && settings.SES_SECRET_KEY && settings.SES_REGION) {
    const ok = await sendViaSes(settings, settings.SENDER_EMAIL, settings.RECIPIENT_EMAIL, subject, text);
    if (ok) return json(200, { id: randomUUID(), provider: "ses" });
  }

  return json(500, { error: "no_email_provider_configured" });
}

function corsHeaders(req) {
  const origin = req.headers?.origin ?? "*";
  return {
    "access-control-allow-origin": origin,
    "access-control-allow-methods": "POST, OPTIONS",
    "access-control-allow-headers": "content-type",
  };
}

async function verifyTurnstile(token, secret) {
  if (!token) return false;
  const res = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
    method: "POST",
    body: new URLSearchParams({ secret, response: token }),
  });
  const data = await res.json();
  return data.success === true;
}

async function sendViaAcs(connectionString, sender, recipient, subject, text) {
  try {
    const { EmailClient } = await import("@azure/communication-email");
    const client = new EmailClient(connectionString);
    const poller = await client.beginSend({
      senderAddress: sender,
      content: { subject, plainText: text },
      recipients: { to: [{ address: recipient }] },
    });
    const result = await poller.pollUntilDone();
    return result.status === "Succeeded";
  } catch {
    return false;
  }
}

async function sendViaSes(settings, sender, recipient, subject, text) {
  try {
    const { SESClient, SendEmailCommand } = await import("@aws-sdk/client-ses");
    const ses = new SESClient({
      region: settings.SES_REGION,
      credentials: {
        accessKeyId: settings.SES_ACCESS_KEY,
        secretAccessKey: settings.SES_SECRET_KEY,
      },
    });
    await ses.send(new SendEmailCommand({
      Source: sender,
      Destination: { ToAddresses: [recipient] },
      Message: {
        Subject: { Data: subject },
        Body: { Text: { Data: text } },
      },
    }));
    return true;
  } catch {
    return false;
  }
}