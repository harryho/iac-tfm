# ADR 0001: Multi-cloud layout with self-contained per-cloud folders

## Status

Accepted.

## Context

The repo started as a single AWS template (`iac-tfm`). It now hosts
templates for multiple clouds (AWS today, Azure Static Web Apps today,
more later). Each cloud has its own primitives, naming, state backend,
and OIDC story, but they share the same operational shape:
bootstrap-once state backend, multiple envs, reusable modules, OIDC CI/CD.

Two ways to organize a multi-cloud Terraform repo:

1. **Shared modules, per-cloud envs.** Modules live at the root
   (`modules/static-site/`, `modules/contact-form/`); each cloud
   `envs/<env>/` picks the modules it needs. Common interface enforced
   by the modules' variable contracts.
2. **Self-contained per-cloud folders.** Each cloud owns its own
   `bootstrap/`, `modules/`, `envs/`, `scripts/`, `.github/`,
   `docs/`. Cross-cloud sharing only via docs at the root.

The AWS implementation's modules hardcode AWS-only primitives (S3,
CloudFront, ACM, Lambda, SES, DynamoDB). A `static-site` module that
works on both AWS and Azure would be a leaky abstraction — CloudFront
behaviour and Azure Static Web Apps behaviour differ enough that the
variable surface would either expose all of one cloud's options or hide
important details.

## Decision

Per-cloud folders, self-contained. No shared modules across clouds at
this stage. Each cloud folder is independent: it can be cloned out,
modified, and re-deployed without touching anything else in the repo.

The `az-swa/` folder is the cleaner reference pattern. `aws-edge/` is
the original implementation, kept for its existing users and as the
historical baseline. New clouds should clone `az-swa/` shape, not
`aws-edge/` shape, because `aws-edge/` has known issues from a
2026-06-22 audit that haven't been fixed in this pass.

Cross-cloud conventions live at the repo root
(`README.md`, `ARCHITECTURE.md`, `docs/decisions/`). Cloud-specific
ADRs live under each cloud folder's `docs/decisions/`.

## Consequences

- **Easy to teach.** Each cloud folder reads top-to-bottom on its own.
- **Easy to evolve.** Adding a new cloud doesn't touch the others. A
  cloud can adopt a new Terraform pattern without rippling across the
  repo.
- **Duplication is the cost.** Each cloud re-declares provider config,
  backend config, OIDC setup. That's acceptable for the independence it
  buys.
- **No shared module surface.** When two clouds happen to need the same
  Terraform snippet, copy-paste is preferred over a generic shared
  module. Promotes extraction later, when a third cloud needs the same
  thing and the shape is clear.
- **CI workflows are per-cloud.** A change to AWS workflows doesn't
  touch Azure workflows. New clouds ship their own CI without depending
  on existing ones.

## Alternatives considered

- **Shared modules with cloud-specific implementations under
  `modules/<name>/aws/` and `modules/<name>/azure/`.** Rejected: leaky
  abstractions, harder to evolve one cloud without breaking the others.
- **One repo per cloud, monorepo of repos.** Rejected: more ceremony
  for what is, today, two folders. If a third cloud lands and patterns
  start to align, we can revisit.
- **Single shared `bootstrap/`** (one state backend across all clouds).
  Rejected: each cloud has its own account structure; sharing a
  backend would couple unrelated blast radii.