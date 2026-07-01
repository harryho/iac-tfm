"use strict";

const crypto = require("crypto");
const { Firestore } = require("@google-cloud/firestore");
const nodemailer = require("nodemailer");
const sgTransport = require("nodemailer-sendgrid-transport");

const SITE_DOMAIN = process.env.SITE_DOMAIN;
const RECIPIENT_EMAIL = process.env.RECIPIENT_EMAIL;
const SENDER_EMAIL = process.env.SENDER_EMAIL;
const TURNSTILE_SECRET = process.env.TURNSTILE_SECRET || "";
const SENDGRID_API_KEY = process.env.SENDGRID_API_KEY || "";
const COLLECTION = process.env.FIRESTORE_COLLECTION || "contact_submissions";

const firestore = new Firestore();
let transporter = null;
function getTransporter() {
  if (!transporter) {
    transporter = nodemailer.createTransport(
      sgTransport({ auth: { api_key: SENDGRID_API_KEY } })
    );
  }
  return transporter;
}

/**
 * HTTP entry point for Cloud Functions 2nd gen (Functions Framework).
 * Validates Turnstile, writes a Firestore doc, sends email via SendGrid.
 *
 * @param {import('@google-cloud/functions-framework').Request} req
 * @param {import('express').Response} res
 */
exports.contactForm = async (req, res) => {
  res.set("Access-Control-Allow-Origin", `https://${SITE_DOMAIN}`);
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }

  if (req.method !== "POST") {
    return res.status(405).json({ ok: false, error: "Method not allowed" });
  }

  const origin = req.headers.origin || "";
  if (origin !== `https://${SITE_DOMAIN}`) {
    return res.status(403).json({ ok: false, error: "Origin not allowed" });
  }

  const { name, email, message, "cf-turnstile-response": turnstileToken } =
    req.body || {};

  if (!name || !email || !message) {
    return res
      .status(400)
      .json({ ok: false, error: "Missing required fields: name, email, message" });
  }

  const emailValid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  if (!emailValid) {
    return res.status(400).json({ ok: false, error: "Invalid email address" });
  }

  if (TURNSTILE_SECRET) {
    if (!turnstileToken) {
      return res
        .status(400)
        .json({ ok: false, error: "Missing captcha token" });
    }
    const verified = await verifyTurnstile(turnstileToken, req.ip);
    if (!verified) {
      return res.status(403).json({ ok: false, error: "Captcha verification failed" });
    }
  }

  try {
    await getTransporter().sendMail({
      from: SENDER_EMAIL,
      to: RECIPIENT_EMAIL,
      replyTo: email,
      subject: `[Contact Form] ${name} <${email}>`,
      text: `Name: ${name}\nEmail: ${email}\n\n${message}`,
    });
  } catch (err) {
    console.error("SendGrid send failed:", err);
    return res.status(500).json({ ok: false, error: "Failed to send email" });
  }

  try {
    const ipHash = crypto
      .createHash("sha256")
      .update(req.ip || "")
      .digest("hex");
    await firestore.collection(COLLECTION).add({
      site_domain: SITE_DOMAIN,
      timestamp: Firestore.FieldValue.serverTimestamp(),
      name,
      email,
      message,
      turnstile_verified: !!TURNSTILE_SECRET,
      ip_hash: ipHash,
    });
  } catch (err) {
    console.error("Firestore write failed:", err);
  }

  return res.status(200).json({ ok: true });
};

async function verifyTurnstile(token, remoteIp) {
  try {
    const params = new URLSearchParams({
      secret: TURNSTILE_SECRET,
      response: token,
    });
    if (remoteIp) params.set("remoteip", remoteIp);

    const r = await fetch(
      "https://challenges.cloudflare.com/turnstile/v0/siteverify",
      { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: params }
    );
    const data = await r.json();
    return data.success === true;
  } catch (err) {
    console.error("Turnstile verification failed:", err);
    return false;
  }
}