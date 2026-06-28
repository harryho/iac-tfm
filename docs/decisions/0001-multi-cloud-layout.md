# ADR 0001: Multi-cloud layout with self-contained per-cloud folders

## Status

Accepted.

## Context

Repo started as a single AWS template (`iac-tfm`); now hosts templates
for multiple clouds. Each cloud has its own primitives, naming, state
backend, and OIDC story, but they share the same operational shape:
bootstrap-once state backend, multiple envs, reusable modules, OIDC CI/CD.

## Decision

Per-cloud folders, self-contained. Each cloud owns its own
`bootstrap/`, `modules/`, `envs/`, `scripts/`, `.github/`, `docs/`.

`az-swa/` is the cleaner reference pattern; `aws-edge/` is the older
implementation, kept for its existing users and as the historical
baseline. New clouds clone `az-swa/` shape, not `aws-edge/` shape.

Cross-cloud conventions live at the repo root; cloud-specific ADRs
live under each cloud's `docs/decisions/`.

## Consequences

- **Easy to teach.** Each cloud reads top-to-bottom on its own.
- **Easy to evolve.** New clouds don't touch the others.
- **Duplication is the cost.** Each cloud re-declares provider, backend,
  OIDC. Acceptable for the independence.
- **No shared module surface.** When two clouds happen to need the same
  snippet, copy-paste. Extract later, when a third cloud needs it and
  the shape is clear.
- **CI workflows are per-cloud.** AWS workflows don't touch Azure
  workflows.

## Alternatives considered

- **Shared modules with cloud-specific implementations** (`modules/<name>/aws/`,
  `modules/<name>/azure/`). Rejected: leaky abstractions, harder to evolve.
- **One repo per cloud.** Rejected: more ceremony for what is, today,
  two folders. Revisit if a third cloud lands and patterns align.
- **Single shared `bootstrap/`.** Rejected: each cloud has its own account
  structure; sharing a backend couples unrelated blast radii.