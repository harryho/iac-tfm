# Architecture (multi-cloud)

This repo hosts Terraform templates for several clouds. Each cloud lives
in its own folder (`aws-edge/`, `az-swa/`, …) and follows the same shape.
This document describes the cross-cutting conventions; each cloud folder
has its own `README.md` and `ARCHITECTURE.md` for cloud-specific detail.

## Layers

| Layer | Location | State | Run by |
|---|---|---|---|
| Bootstrap | `<cloud>/bootstrap/` | `<cloud>` state backend | Once per cloud account |
| Environment | `<cloud>/envs/<env>/` | `<cloud>` state backend, per-env key | Once per env per cloud |
| Module | `<cloud>/modules/<name>/` | (no state) | Called by envs |

`<cloud>/bootstrap/` is independent. `<cloud>/envs/<env>/` reads bootstrap
outputs via `terraform_remote_state`. Modules are pure code.

## Conventions

### Directory-based envs

Each env is a self-contained `<cloud>/envs/<env>/` folder with its own
`.tf` files and its own state file in the shared backend under
`<cloud>/envs/<env>/terraform.tfstate`.

Why: easy to teach, easy to compare (`diff` between two envs shows
exactly what differs), easy to tear down, one env's failure cannot
corrupt another's state. Slight duplication (each env repeats
provider/backend config) is the cost of that explicitness.

Why not workspaces or Terragrunt: see
[`aws-edge/docs/decisions/0002-directory-based-envs.md`](aws-edge/docs/decisions/0002-directory-based-envs.md)
(decision rationale carries over to other clouds — the same arguments
apply).

### OIDC-only CI/CD

No long-lived cloud credentials in GitHub. Each cloud folder owns its
own CI workflows (`<cloud>/.github/workflows/`) that assume short-lived
roles/identities via OIDC federated credentials. AWS-side detail in
[`aws-edge/docs/decisions/0001-oidc-only.md`](aws-edge/docs/decisions/0001-oidc-only.md);
the same pattern applies to other clouds.

### Per-site contact form is optional

Each env's `sites` map lets you turn a contact form on or off per site.
The contact form module lives under `<cloud>/modules/contact-form*`
(cloud-specific naming). When off, no contact-form resources are
created.

## How to add a new cloud

1. **Copy the shape from `az-swa/`**, not from `aws-edge/`. `az-swa/`
   is the cleaner reference; `aws-edge/` is the older implementation
   with known issues from a 2026-06-22 audit that haven't been fixed.
2. Pick a folder name that matches your cloud + offering
   (e.g., `az-swa/` for Azure Static Web Apps, `gcp-cdn/` for GCP, etc.).
3. Replace provider blocks in `bootstrap/`, `modules/`, and `envs/<env>/`.
4. Rename modules to match your cloud's primitive names — `az-swa/`
   uses generic names (`static-hosting`, `workload-identity`, `contact-form`);
   adapt to whatever your cloud calls them.
5. Replace `scripts/` with the cloud's native deploy/verify/teardown
   commands.
6. Add `<cloud>/.github/workflows/` modeled on `aws-edge/.github/workflows/`,
   adjusting for the cloud's OIDC setup.
7. Add a row to the table in [`README.md`](README.md).
8. Optionally add a cloud-specific `<cloud>/ARCHITECTURE.md` and
   `<cloud>/docs/decisions/` for ADRs that don't carry across clouds.

## What the root owns vs. what each cloud folder owns

**Root** (`README.md`, `ARCHITECTURE.md`, `docs/decisions/`,
`CONTRIBUTING.md`, `SECURITY.md`, `LICENSE`, `.editorconfig`, `.gitignore`,
`.pre-commit-config.yaml`):

- Multi-cloud conventions.
- ADRs that affect more than one cloud.
- Repo-wide contributor / security policy.

**Each cloud folder** (`<cloud>/README.md`, `<cloud>/ARCHITECTURE.md`,
`<cloud>/bootstrap/`, `<cloud>/modules/`, `<cloud>/envs/`,
`<cloud>/scripts/`, `<cloud>/content/`, `<cloud>/.github/`,
`<cloud>/docs/decisions/`):

- Everything cloud-specific: provider, modules, envs, scripts, workflows.
- ADRs that only matter for that cloud.