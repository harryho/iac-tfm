# Contributing

## Issues

Use the issue templates in `aws-edge/.github/ISSUE_TEMPLATE/` (other
clouds add their own under `<cloud>/.github/ISSUE_TEMPLATE/`).

## Pull requests

Open against `main`. CI runs:

- `terraform fmt -check -recursive`
- `terraform validate` per stack
- `terraform test` per module
- `shellcheck` on shell scripts (advisory)

All checks must pass.