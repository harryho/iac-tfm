# ADR 0001: OIDC-only CI/CD

## Status

Accepted.

## Context

CI/CD for Terraform requires AWS credentials. Two common approaches:

1. **Long-lived access keys** stored in GitHub Secrets. Easy to set up
   but creates a long-lived blast radius if the secret leaks.
2. **OIDC federation** — GitHub Actions assumes a short-lived IAM role
   per workflow run. No static credentials; the trust policy is the
   only attack surface.

## Decision

`iac-tfm` ships with OIDC-only CI/CD. No `AWS_ACCESS_KEY_ID` or
`AWS_SECRET_ACCESS_KEY` should ever be committed or stored in GitHub
Secrets. The `modules/team-iam` module provisions the OIDC provider
and per-env IAM roles.

A `precondition` block in `modules/team-iam/main.tf` fails the plan
if the GitHub org or repo are still the `YOUR_*` placeholders, so a
new user can't accidentally ship the default trust policy to a real
account.

## Consequences

- New users need to set up OIDC roles before CI can run. The
  `GETTING_STARTED.md` covers this.
- The OIDC trust policy constrains workflows to specific GitHub
  Environments (per env), preventing a workflow running in `staging`
  from assuming a `prod` role.
- Slightly more setup than static keys, but eliminates the static-key
  attack surface.

## Alternatives considered

- **Static keys with rotation.** Hard to enforce, easy to forget.
  Rejected.
- **OIDC + static key fallback.** Considered, but introduces
  documentation burden and undermines the security story. Rejected.
