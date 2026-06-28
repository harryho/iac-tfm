# iac-tfm

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

## Implementations

| Folder | Cloud | Stack |
|---|---|---|
| [`aws-edge/`](aws-edge/) | AWS | CloudFront + S3 (private, OAC) + ACM, Lambda + SES + DynamoDB for per-site contact forms, IAM groups + OIDC roles for CI/CD, CloudWatch dashboard + AWS Budget + SNS alerts. Original implementation — has known issues from a 2026-06-22 audit that haven't been fixed |
| [`az-swa/`](az-swa/) | Azure | Static Web Apps (managed CDN + HTTPS + Functions), ACS Email for contact-form primary with AWS SES fallback, user-assigned identities + federated credentials for CI/CD, consumption-budget alerts. Synthesized reference pattern — clone this shape for new clouds |

## Conventions

- **One state backend per cloud account** — `<cloud>/bootstrap/` provisions it once.
- **Directory-based envs** — `<cloud>/envs/<env>/` is self-contained, easy to compare, easy to tear down. See [ADR 0001](docs/decisions/0001-multi-cloud-layout.md).
- **OIDC-only CI/CD** — no long-lived cloud credentials in GitHub. AWS side documents this in [`aws-edge/docs/decisions/0001-oidc-only.md`](aws-edge/docs/decisions/0001-oidc-only.md); the same pattern applies to any cloud.
- **Per-site contact form is optional** — each env's `sites` map turns it on per site; contact-form resources only exist when enabled.
- **Lambdas, Functions, and other serverless compute** ship inside the contact-form module — no separate "compute" folder. The pattern is: per-site API surface, configured via app settings.

## Adding a new cloud

1. Copy `az-swa/` as the starting shape.
2. Replace the provider in `bootstrap/`, `modules/`, and `envs/<env>/`.
3. Rename modules to match your cloud's primitive names (az-swa uses
   generic names: `static-hosting`, `contact-form`, `workload-identity`;
   adapt to whatever your cloud calls them).
4. Update scripts for the cloud's native deploy/verify/teardown.
5. Add `<cloud>/.github/workflows/` modeled on `aws-edge/.github/workflows/`
   or `az-swa/.github/workflows/` — pick whichever cloud is closest.
6. Add a row to the table above and link to the new folder's README.

## Repo-wide docs

- [`ARCHITECTURE.md`](ARCHITECTURE.md) — multi-cloud layout conventions.
- [`docs/decisions/0001-multi-cloud-layout.md`](docs/decisions/0001-multi-cloud-layout.md) — why each cloud is self-contained.
- [`CONTRIBUTING.md`](CONTRIBUTING.md), [`SECURITY.md`](SECURITY.md) — apply repo-wide.

## License

[MIT](LICENSE). No warranty; you own what you ship.