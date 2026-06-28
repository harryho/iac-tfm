# iac-tfm

Multi-cloud Terraform templates for static-site hosting. Each cloud lives
in its own self-contained folder that follows the same shape:

```
<cloud>/
├── bootstrap/    state backend (run once per cloud account)
├── modules/      reusable Terraform modules
├── envs/<env>/   per-environment stacks
├── scripts/      deploy / verify / teardown helpers
└── content/<env>/<site>/dist/   static content
```

## Implementations

| Folder | Cloud | Status |
|---|---|---|
| [`aws-edge/`](aws-edge/) | AWS (CloudFront + S3 + ACM + Lambda + SES) | Original implementation, has known issues from a 2026-06-22 audit |
| [`az-swa/`](az-swa/) | Azure (Static Web Apps) | Synthesized reference pattern — clone this shape for new clouds |

## Conventions

- **One state backend per cloud account** — `bootstrap/` provisions it once.
- **Directory-based envs** — `envs/<env>/` is self-contained, easy to compare, easy to tear down. See [ADR 0001](docs/decisions/0001-multi-cloud-layout.md).
- **OIDC-only CI/CD** — no long-lived cloud credentials in GitHub. AWS side documents this in [`aws-edge/docs/decisions/0001-oidc-only.md`](aws-edge/docs/decisions/0001-oidc-only.md); the same pattern applies to any cloud.
- **Per-site contact form is optional** — each env's `sites` map can turn it on per site.

## Adding a new cloud

1. Copy `az-swa/` as the starting shape.
2. Replace the provider in `bootstrap/`, `modules/`, and `envs/<env>/`.
3. Rename modules to match your cloud's naming (the az-swa reference uses generic module names; adapt to your service).
4. Update scripts for the cloud's deploy/verify/teardown commands.
5. Add `.github/workflows/` modeled on `aws-edge/.github/workflows/`.
6. Add a row to the table above and link to the new folder's README.

## Repo-wide docs

- [`ARCHITECTURE.md`](ARCHITECTURE.md) — multi-cloud layout conventions.
- [`docs/decisions/0001-multi-cloud-layout.md`](docs/decisions/0001-multi-cloud-layout.md) — why each cloud is self-contained.
- [`CONTRIBUTING.md`](CONTRIBUTING.md), [`SECURITY.md`](SECURITY.md) — apply repo-wide.

## License

[MIT](LICENSE). No warranty; you own what you ship.