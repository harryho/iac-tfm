import { SESClient, SendEmailCommand } from "@aws-sdk/client-ses";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand } from "@aws-sdk/lib-dynamodb";

const ses = new SESClient({});
const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));

const SITE_DOMAIN = process.env.SITE_DOMAIN;
const RECIPIENT_EMAIL = process.env.RECIPIENT_EMAIL;
const SENDER_EMAIL = process.env.SENDER_EMAIL;
const TURNSTILE_SECRET = process.env.TURNSTILE_SECRET;
const DYNAMODB_TABLE = process.env.DYNAMODB_TABLE;

export const handler = async (event) => {
  const origin = event.headers?.origin || event.headers?.Origin || "";

  if (origin !== `https://${SITE_DOMAIN}`) {
    return json(403, { error: "Origin not allowed" });
  }

  let body;
  try {
    body = JSON.parse(event.body || "{}");
  } catch {
    return json(400, { error: "Invalid JSON body" });
  }

  const { name, email, message, "cf-turnstile-response": turnstileToken } = body;

  if (!name || !email || !message) {
    return json(400, { error: "Missing required fields: name, email, message" });
  }

  if (TURNSTILE_SECRET && turnstileToken) {
    const verified = await verifyTurnstile(turnstileToken);
    if (!verified) {
      return json(403, { error: "Captcha verification failed" });
    }
  }

  try {
    await ses.send(new SendEmailCommand({
      Source: SENDER_EMAIL,
      Destination: { ToAddresses: [RECIPIENT_EMAIL] },
      Message: {
        Subject: { Data: `[Contact Form] ${name} <${email}>` },
        Body: {
          Text: { Data: `Name: ${name}\nEmail: ${email}\n\n${message}` },
        },
      },
    }));
  } catch (err) {
    console.error("SES send failed:", err);
    return json(500, { error: "Failed to send email" });
  }

  if (DYNAMODB_TABLE) {
    const ts = new Date().toISOString();
    try {
      await ddb.send(new PutCommand({
        TableName: DYNAMODB_TABLE,
        Item: {
          site_domain: SITE_DOMAIN,
          timestamp: ts,
          name,
          email,
          message,
          ip: event.requestContext?.http?.sourceIp || "",
        },
      }));
    } catch (err) {
      console.error("DynamoDB log failed:", err);
    }
  }

  return json(200, { success: true });
};

async function verifyTurnstile(token) {
  try {
    const res = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        secret: TURNSTILE_SECRET,
        response: token,
      }),
    });
    const data = await res.json();
    return data.success === true;
  } catch (err) {
    console.error("Turnstile verification failed:", err);
    return false;
  }
}

function json(statusCode, body) {
  return {
    statusCode,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  };
}
