# ADR 0002: Directory-based multi-environment

## Status

Accepted.

## Context

Real deployments need multiple environments (dev, stage, prod). The
template has to support adding new envs without rewriting the stack.

Common approaches:

1. **Terraform workspaces.** Single config, multiple state files via
   `terraform workspace new <env>`. Simple but state co-mingles and
   per-env tfvars need `-var-file=` discipline.
2. **Directory-based.** Each env is `envs/<env>/` with its own state
   file in a per-env S3 key prefix. Self-contained; easy to reason
   about; easy to tear down.
3. **Terragrunt.** More powerful but adds a heavy dependency. Out of
   scope for v1.

## Decision

Directory-based. Each env is a self-contained `envs/<env>/` folder
with its own `.tf` files and its own state file at
`envs/<env>/terraform.tfstate` in the shared S3 backend. Bootstrap
runs once per AWS account and is independent of envs.

`scripts/replicate-env.sh` copies `envs/prod/` to a new
`envs/<env_name>/` and rewrites `environment_name` and
`role_name_prefix` so per-env OIDC roles don't collide.

## Consequences

- Easy to teach — each env is a folder a new team member can read
  end-to-end.
- Easy to compare — `diff envs/prod/ envs/stage/` shows exactly what
  differs.
- Easy to tear down — `scripts/teardown-env.sh <env>` empties S3,
  runs `terraform destroy`, and cleans up state.
- One env's failure cannot corrupt another's state.
- Slight duplication: each env repeats provider/backend config. This
  is acceptable for the explicitness it buys.

## Alternatives considered

- **Workspaces.** Rejected: state co-mingling, harder to gate per
  env in CI, harder to teach.
- **Terragrunt.** Rejected: heavier dependency; out of v1 scope.
- **Single env with `for_each` over a map.** Rejected: doesn't match
  the per-env CI/CD story (GitHub Environments, OIDC roles, state
  isolation).
