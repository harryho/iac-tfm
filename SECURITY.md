# Security Policy

## Supported versions

The latest released version of `iac-tfm` is supported with security
updates. Older versions are not.

## Reporting a vulnerability

Please report security issues to **`security@your-domain.example`**
(replace with your address in your fork) — **do not open a public issue**.

We aim to acknowledge reports within 3 business days and to ship a fix
within 30 days for critical issues.

## Security stance

- **OIDC only** for CI/CD. Never commit long-lived AWS keys.
- **S3 buckets are private** by default. Public access is blocked.
- **Lambda Function URLs** are public by design (CORS locked to site
  domain). Use Turnstile to mitigate abuse.
- **State files** in S3 are encrypted at rest (AES256) and versioned.
- **No warranty.** This is a template; you own what you ship.