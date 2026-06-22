# Contributing

Thanks for your interest in improving `iac-tfm`!

## Issues

- **Bug reports** → use the `.github/ISSUE_TEMPLATE/bug.md` template
- **Feature requests** → use `.github/ISSUE_TEMPLATE/feature.md`
- **"I'm using this template and..."** → use
  `.github/ISSUE_TEMPLATE/using-this-template.md`

## Pull requests

Open a PR against `main`. The template is small enough that we don't
require an issue first, but for non-trivial changes, please open an
issue to discuss.

CI checks:
- `terraform fmt -check -recursive`
- `terraform validate` (every config)
- `terraform test` (every module)

All checks must pass.

## Style

- Conventional commits: `type(scope): description`
- Terraform: `terraform fmt`
- Shell: `shellcheck`
- Markdown: keep lines under 100 chars where possible

## License

By contributing, you agree your contributions will be licensed under
the MIT License.

## Code of conduct

A code of conduct, if desired, can be added from
[Contributor Covenant](https://www.contributor-covenant.org/).