# Contributing

## Issues

Use the issue templates in `aws-edge/.github/ISSUE_TEMPLATE/`
(also `az-swa/.github/ISSUE_TEMPLATE/` and
`gcp-edge/.github/ISSUE_TEMPLATE/` — each cloud folder ships its own;
add yours there when you add a new cloud).

## Pull requests

Open against `main`. CI runs:

- `terraform fmt -check -recursive`
- `terraform validate` per stack
- `terraform test` per module
- `shellcheck` on shell scripts (advisory)

All checks must pass.