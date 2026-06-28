# Security Policy

This document covers cross-cutting security policy for the whole repo.
Cloud-specific security notes (state backend encryption, public/private
defaults, function-URL vs SES, etc.) live in each cloud folder's own
`SECURITY.md` once that cloud adds one.

## Supported versions

The latest released version of `iac-tfm` is supported with security
updates. Older versions are not.

## Reporting a vulnerability

Please report security issues to **`security@example.com`** — replace
this with your domain before publishing — **do not open a public
issue**.

We aim to acknowledge reports within 3 business days and to ship a fix
within 30 days for critical issues.

## Cross-cutting security stance

- **OIDC only** for CI/CD across every cloud. No long-lived cloud
  credentials in GitHub.
- **State files** in the cloud provider's managed backend; never
  committed to git.
- **Per-cloud secrets** (OIDC client IDs, ACS connection strings,
  SES keys) flow through GitHub Secrets or, when set locally for
  `terraform apply`, through sensitive variables — never through
  `terraform.tfvars` that gets committed.
- **No warranty.** This is a template; you own what you ship.