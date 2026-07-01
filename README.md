# Terraform Iac Multi-Cloud templates

Multi-cloud Terraform templates for **static-site hosting and adjacent
web stacks**. Each cloud is a self-contained folder: a state backend,
reusable modules, per-environment stacks, deploy scripts, and OIDC-only
CI/CD.

## What you get per cloud

Each `<cloud>/` folder is a complete, opinionated starting point —
clone it, swap the provider, rename modules to match your services.
The shape:

```
<cloud>/
├── bootstrap/                       state backend (one-time per cloud account)
├── modules/                         reusable Terraform modules
│   ├── static-hosting/              CDN + storage + custom domain
│   ├── contact-form/                API/Function for per-site forms
│   └── workload-identity/           OIDC federated credentials for CI/CD
├── envs/<env>/                      wires modules for one env
├── scripts/                         deploy / verify / teardown
├── content/<env>/<site>/dist/       static content (placeholders ship)
└── .github/workflows/               CI/CD (plan, apply, deploy-content)
```

The modules listed above are the **generic** names from `az-swa/`.
Concrete cloud folders may use cloud-specific names — `gcp-edge/`
uses `static-site-cdn`, `contact-form-fn`, `team-iam`, and `ops`.
The **shape** is what matters.

## Implementations

| Folder | Cloud | Stack |
|---|---|---|
| [`aws-edge/`](aws-edge/) | AWS | CloudFront + S3 (private, OAC) + ACM, Lambda + SES + DynamoDB for per-site contact forms, IAM groups + OIDC roles for CI/CD, CloudWatch dashboard + AWS Budget + SNS alerts. Original implementation — has known issues from a 2026-06-22 audit that haven't been fixed |
| [`az-swa/`](az-swa/) | Azure | Static Web Apps (managed CDN + HTTPS + Functions), ACS Email for contact-form primary with AWS SES fallback, user-assigned identities + federated credentials for CI/CD, consumption-budget alerts. Synthesized reference pattern — clone this shape for new clouds |
| [`gcp-edge/`](gcp-edge/) | GCP | Global External HTTPS LB + Cloud CDN + backend buckets + GCS (private), Cloud Functions 2nd gen + SendGrid + Firestore for per-site contact forms, Workload Identity Federation for CI/CD, Cloud Monitoring dashboard + billing budget. Generic template — values are placeholders |

## Conventions

- **One state backend per cloud account** — `<cloud>/bootstrap/` provisions it once.
- **Directory-based envs** — `<cloud>/envs/<env>/` is self-contained, easy to compare, easy to tear down.
- **OIDC-only CI/CD** — no long-lived cloud credentials in GitHub. Each
  cloud's `GETTING_STARTED.md` walks you through the cloud-specific
  setup:
  [`aws-edge/`](aws-edge/GETTING_STARTED.md),
  [`az-swa/`](az-swa/GETTING_STARTED.md),
  [`gcp-edge/`](gcp-edge/GETTING_STARTED.md).
- **Per-site contact form is optional** — each env's `sites` map turns it on per site; contact-form resources only exist when enabled.
- **Lambdas, Functions, and other serverless compute** ship inside the contact-form module — no separate "compute" folder. The pattern is: per-site API surface, configured via app settings.

## Adding a new cloud

1. Copy `az-swa/` (generic module names: `static-hosting`,
   `contact-form`, `workload-identity`) or `gcp-edge/` (cloud-specific
   names: `static-site-cdn`, `contact-form-fn`, `team-iam`, `ops`) as
   the starting shape.
2. Replace the provider in `bootstrap/`, `modules/`, and `envs/<env>/`.
3. Rename modules to match your cloud's primitive names — pick
   whichever set (generic vs cloud-specific) reads more naturally for
   your cloud.
4. Update scripts for the cloud's native deploy/verify/teardown.
5. Add `<cloud>/.github/workflows/` modeled on `aws-edge/.github/workflows/`,
   `az-swa/.github/workflows/`, or `gcp-edge/.github/workflows/` —
   pick whichever cloud is closest.
6. Add a row to the table above and link to the new folder's README.

## Local development

Install [pre-commit](https://pre-commit.com/) and enable the repo hooks:

```bash
pre-commit install
```

Run all hooks manually against every file:

```bash
pre-commit run --all-files
```

This runs the same checks used in CI: Terraform formatting and validation,
YAML/shell linting, and whitespace checks.

## Repo-wide docs

- [`ARCHITECTURE.md`](ARCHITECTURE.md) — multi-cloud layout conventions and
  why each cloud is self-contained.
- [`CONTRIBUTING.md`](CONTRIBUTING.md), [`SECURITY.md`](SECURITY.md) — apply repo-wide.

## License

[MIT](LICENSE). No warranty; you own what you ship.