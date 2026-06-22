# iac-tfm — AI-Trace Analysis & Human-Cleanup Plan

**Audit date:** 2026-06-22
**Repo:** `harryho/iac-tfm` (single squash commit `b4c82e3`, author `iac-tfm-bot@local`, 68 files / 4186 LOC)
**Scope:** full repo — Terraform modules & envs, bootstrap, scripts, GitHub workflows, docs, repo-meta

---

## TL;DR

This repo was generated in one AI pass and never refactored by a human. The AI-trace profile is internally consistent: decorative banner comments above every resource, defensive validation that duplicates AWS / type-system guarantees, dead outputs and locals, mixed `count` / `for_each` styles, three different copies of the same FQDN regex, a single squash commit from a bot identity, and several docs that contradict the code.

The strongest **non-style** signal is provider-version drift across the five committed `.terraform.lock.hcl` files: `modules/team-iam` is locked to AWS provider **6.51.0** while everything else is **5.100.0** with a `~> 5.0` constraint. No human who has ever run `terraform init` end-to-end leaves a repo in that state.

**Cleanup strategy:** do it in three passes — **(1) fix the real bugs**, **(2) remove AI-prose / banner / comment noise**, **(3) finish with style & consistency**. Don't try to do all three at once; you'll re-introduce the prose noise trying to fix bugs.

Findings are grouped into **Trace Categories** (what the AI did that gave it away) and **Cleanup Tasks** (what to do). A consolidated task list with severity is at the bottom.

---

## 1. Repository-level signals (git, history, structure)

These are the most reliable AI tells because they require intent to fabricate.

| ID | Finding | File / Evidence |
|---|---|---|
| R-1 | **Single squash commit** by a bot identity (`iac-tfm-bot@local`, `@local` is non-resolvable). 68 files / 4186 LOC, no prior history. | `git log` shows only `b4c82e3 chore: initial public release` |
| R-2 | **Conventional-Commits-form commit message** but no `Co-authored-by`, no PR ref, no `Signed-off-by`, no detailed body. | Same commit |
| R-3 | **Stray `.terraform/` directories on disk** in every module / env (gitignored correctly, but the working tree was left dirty after init). | `bootstrap/.terraform/`, `modules/*/.terraform/`, `envs/prod/.terraform/` |
| R-4 | **Five committed `.terraform.lock.hcl` files with conflicting provider versions.** | See §3 below |
| R-5 | **No `CHANGELOG.md`** — AI scaffolds usually emit one; absence is mildly human, but combined with R-1 it's "first-pass template". | Repo root |

**Task R-A (optional, controversial).** Rewriting public history is a judgement call, not a defect — many teams prefer one clean squash commit. If you do want a more human-flavoured history, rewrite the initial commit as a small, ordered series on a feature branch, then merge:

1. `chore: scaffold repo layout and docs`
2. `feat(bootstrap): S3 + DynamoDB backend with OIDC role`
3. `feat(modules): static-site, contact-form, team-iam`
4. `feat(envs/prod): wire modules for prod with per-site files`
5. `ci: add OIDC workflows (plan, apply, test, teardown, deploy-content)`
6. `chore: lock providers at consistent versions`

Use a real-looking identity (yours, not `bot@local`). Skip this task if the repo is already public with consumers — the disruption isn't worth the smell reduction.

---

## 2. Decorative comments & banner blocks

The single most pervasive AI trace in this repo. Pattern: `# ----` banner line, one-line header, then the resource whose name already says what the header said.

| ID | File | Lines | Banner text |
|---|---|---|---|
| B-1 | `bootstrap/main.tf` | 32-34, 90-92 | "S3 bucket for Terraform state", "DynamoDB table for state locking" |
| B-2 | `envs/prod/main.tf` | 23-25, 39-41, 45-47 | "Providers", "Data sources", "Locals" |
| B-3 | `envs/prod/infra.tf` | 1-3, 12-14 | "SES domain identity", "SNS alerts topic" |
| B-4 | `envs/prod/sites.tf` | 1-3, 19-21 | "Static sites — one module call per entry in var.sites" |
| B-5 | `envs/prod/team-iam.tf` | 1-3 | "Team IAM — groups, users, OIDC roles" |
| B-6 | `modules/static-site/main.tf` | 11-13, 62-64, 73, 96-98, 121-123, 149-151 | 6 banners, e.g. "S3 Origin Bucket (private — served only via CloudFront OAC)" |
| B-7 | `modules/contact-form/main.tf` | 8-10, 31-33, 41-43, 115-117, 151-153, 172-174 | 6 banners |
| B-8 | `modules/team-iam/main.tf` | 24-26, 28-29, 50-52, 68-70, 106-108, 197-199, 264-266, 293-295, 307-311 | 8 banners, some 4-5 lines for one resource |

**Secondary form — `# ADAPTED:` comments** narrating decisions as if the model just made them. Eight occurrences in `modules/team-iam/main.tf`. Two of these lie outright:

- `modules/team-iam/outputs.tf:34-35` says the output names "include role_name_prefix to disambiguate multi-env outputs at the root level" — they don't. The output names are `github_content_role_arn` and `github_infra_role_arn`. The comment is left over from a different design.
- `modules/team-iam/main.tf:201` names an IAM policy `read-only-iac-tfm` — hardcoding `iac-tfm` in a place that should use `var.project_name`. The `# ADAPTED:` narrative around this file didn't catch the substitution.

**Task B-A.** Delete every banner block. If a section needs a label, use a one-token heading (`# OIDC`, `# ACM`). Delete every `# ADAPTED:` comment — most are restating what the code already says. Delete the lying output-name comment.

---

## 3. Provider / lockfile inconsistencies (real bug, not style)

| File | AWS provider version | Constraint |
|---|---|---|
| `bootstrap/.terraform.lock.hcl` | 5.100.0 | `~> 5.0` |
| `modules/static-site/.terraform.lock.hcl` | 5.100.0 | `~> 5.0` |
| `modules/contact-form/.terraform.lock.hcl` | 5.100.0 | `~> 5.0` |
| `modules/team-iam/.terraform.lock.hcl` | **6.51.0** | **none** |
| `envs/prod/.terraform.lock.hcl` | 5.100.0 | `~> 5.0` |

AWS provider 6.x is **not** API-compatible with 5.x in several places (`aws_s3_bucket_versioning`/`aws_s3_bucket_server_side_encryption_configuration` were deprecated in v6 in favor of `aws_s3_bucket_versioning_configuration`). Composing `envs/prod` (which uses `team-iam` and `static-site`) will pull two major versions into one run and either fail or silently drift.

**Task P-A.** Pick one major. For a "static-site / contact-form" template that started in v5, stay on 5.x. Re-init every stack against `~> 5.0` and commit a single consistent set of lock files. Then add a CI check: `terraform init -backend=false -input=false` per stack, fail if any lock file diverges.

**Task P-B.** Delete the on-disk `.terraform/` directories from the working tree after re-init, even though they're gitignored. They're a smell to anyone inspecting the repo.

---

## 4. Over-defensive / cargo-culted validation

There are **16 `validation` blocks** across the variable files. Most re-implement checks the type system or the AWS provider already enforces.

| ID | File:Line | Validation | Why it's cargo-culted |
|---|---|---|---|
| V-1 | `bootstrap/variables.tf:6-9` | `contains([us-east-1, us-west-2, ap-southeast-2], aws_region)` | Hardcoded 3-region allow-list — the user will delete it the first time they need a different region |
| V-2 | `bootstrap/variables.tf:17-20` | `^[a-z0-9-]+$` for `project_name` | AWS provider validates bucket / IAM names at apply time with clearer errors |
| V-3 | `envs/prod/variables.tf` (7 blocks, lines 6, 17, 28, 39, 56, 73, 84) | Region allow-list, three regex copies, `monthly_budget_limit_usd > 0` | Same regex copy-pasted in 3 files; `> 0` is the type system |
| V-4 | `modules/static-site/variables.tf:15-19` | FQDN regex (more restrictive form) | Different regex from the env-level one — see C-3 |
| V-5 | `modules/contact-form/variables.tf:18-22, 28-32, 38-42` | FQDN regex + email regex twice | SES will reject bad addresses at first send |
| V-6 | `modules/contact-form/variables.tf:67-73` | `log_retention_days` must be in 22-element enum | CloudWatch rejects invalid values with a clearer error |
| V-7 | `modules/team-iam/variables.tf:6-9, 16-19` | Same regex, third copy | Triple-duplicated |
| V-8 | `modules/team-iam/main.tf:30-48` | `terraform_data` with two `lifecycle.precondition` blocks checking for `YOUR_ORG`/`YOUR_REPO` placeholders | Variable description already says "Replace YOUR_ORG placeholder before applying"; default is `""`; precondition is third layer of paranoia |

**Task V-A.** Delete `validation` blocks where AWS / Terraform / CloudWatch will reject the value. Keep at most **one** region allow-list, one FQDN regex, one email regex — and put them in `envs/prod/variables.tf`. Delete the `terraform_data` preconditions in `team-iam/main.tf`. If you keep a regex, factor it into a single `locals.fqdn_re = "..."` and reference it from `validation { condition = can(regex(local.fqdn_re, var.x)) }`.

---

## 5. Dead variables, dead outputs, dead locals

| ID | File:Line | Dead code | Notes |
|---|---|---|---|
| D-1 | `modules/static-site/outputs.tf:16-19` | `acm_certificate_arn` | **Unused.** Also returns `aws_acm_certificate.this.arn` while the distribution attaches `aws_acm_certificate_validation.this.certificate_arn` — wrong value. |
| D-2 | `modules/static-site/outputs.tf:33-35` | `www_redirect_function_name` | Unused |
| D-3 | `modules/team-iam/outputs.tf:10-17` | `group_arns` | Unused |
| D-4 | `modules/team-iam/outputs.tf:19-22` | `user_names` | Unused |
| D-5 | `modules/team-iam/outputs.tf:24-32` | `user_arns` | Unused |
| D-6 | `envs/prod/outputs.tf:46-54` | `monthly_budget_name`, `ops_dashboard_name` | Unused; empty-string "no-op" outputs |
| D-7 | `bootstrap/outputs.tf:11-19` | `lock_table_arn` | Unused; `state_bucket_arn` is also unused — `scripts/teardown-env.sh:87` tries to consume it but extracts the bucket name with a `sed 's/.*:://'` kludge because no plain `state_bucket_name` output exists |
| D-8 | `bootstrap/outputs.tf:21-24` | `state_key_prefix` | Hardcoded `"envs"` — should be a `local`, not an output |
| D-9 | `bootstrap/outputs.tf:26-39` | `instructions` | Multi-line heredoc duplicating `backend_config` output one block above |
| D-10 | `envs/prod/outputs.tf:71-81` | `next_steps` | Multi-line heredoc telling the user to do six manual things — belongs in the README, not a Terraform output |
| D-11 | `envs/prod/main.tf:48-50` | `account_id`, `region` locals | Defined but never referenced in `infra.tf`, `sites.tf`, `outputs.tf`, `team-iam.tf` |
| D-12 | `modules/team-iam/main.tf:12` | `local.common_tags` re-merge | `ManagedBy = "terraform"` is already set by provider-level `default_tags` in `envs/prod/main.tf:56`; the merge inside the module is a third copy |

**Task D-A.** Delete D-1 through D-10 and D-11. For D-7, add a `state_bucket_name` output (the un-`sed`'d value) and use it from `teardown-env.sh`. Move D-10's content into `GETTING_STARTED.md`. Delete the module-level `common_tags` re-merge in `team-iam`.

---

## 6. Verbose `description =` blocks (style preference, not a defect)

100% of variables and outputs have a `description =`. This is **better than the alternative** (no descriptions) and the prose is accurate. The observation below is about taste, not correctness — treat the whole section as optional.

| ID | Example | Observation |
|---|---|---|
| DS-1 | `envs/prod/variables.tf:35` — `"Prefix for OIDC role names. Must be unique per env in the same AWS account (e.g. 'iac-prod', 'iac-stage')."` | Could be a noun-phrase ("OIDC role name prefix"); the uniqueness note is useful but lives better in ADR or GETTING_STARTED |
| DS-2 | `envs/prod/variables.tf:24` — `"Short env identifier (e.g. prod, stage, dev). Used in state path and the Env tag."` | Implementation detail in description |
| DS-3 | `envs/prod/variables.tf:46` — `"GitHub Environment name to constrain the OIDC trust policy to. Defaults to environment_name."` | The default is self-evident from the variable declaration |
| DS-4 | `envs/prod/variables.tf:139` — `"GitHub org/user for OIDC trust. Replace YOUR_ORG placeholder before applying."` | Failure-mode prose belongs in a docs file, not in `description =` |
| DS-5 | `modules/team-iam/variables.tf:23` — `"GitHub Environment name to constrain the OIDC trust policy to (e.g. 'production', 'staging'). Workflows must run in this environment to assume the role."` | Same shape as DS-3 — copy-paste between env and module |
| DS-6 | `modules/team-iam/outputs.tf:37` — `"GitHub Actions content deploy role ARN (empty if OIDC not configured)"` | The "empty if OIDC not configured" is an implementation detail |

**Task DS-A (optional).** If you trim, target one short noun-phrase per `description =` and move "what to do if you forget" prose to `GETTING_STARTED.md` / ADRs. No fixed word count — stop when the description still makes sense standing alone. Skip entirely if you'd rather have over-documented than under-documented variables.

---

## 7. Style inconsistencies across modules

These are the kind of things that don't appear in a single AI pass and that no human merges without noticing.

### 7a. `for_each` vs `count`, and inline map-rebuilding

| ID | Location | Smell |
|---|---|---|
| C-1 | `envs/prod/sites.tf:6` — `for_each = var.sites` | |
| C-1 | `envs/prod/sites.tf:24-26` — `for_each = { for k, v in var.sites : k => v if try(v.enable_contact_form, true) }` | Manual rebuild of the same map |
| C-1 | `modules/team-iam/main.tf:267, 279, 286` — `for_each = { for m in var.team_members : m.name => m }` | Same rebuild pattern, three times in one file |
| C-1 | `modules/static-site/main.tf:124-125, 181-182` — `count = var.enable_www_redirect ? 1 : 0` | `count` for one resource, `for_each` for the parent |

### 7b. Tags — three different mechanisms in one repo

| ID | Location | Mechanism |
|---|---|---|
| C-2a | `bootstrap/main.tf:15-21`, `envs/prod/main.tf:29-32` | Provider-level `default_tags` |
| C-2b | `modules/static-site/main.tf:8`, `modules/contact-form/main.tf:5` | Module-level `locals.{site_tags} = merge(var.common_tags, { Site = var.domain })` |
| C-2c | `modules/team-iam/main.tf:12` | Module-level re-merge of `common_tags` with `ManagedBy = "terraform"` |

### 7c. Resource naming — two conventions

| ID | Location | Convention |
|---|---|---|
| C-3a | `bootstrap/main.tf` | `aws_s3_bucket.terraform_state`, `aws_s3_bucket_versioning.terraform_state`, etc. — five resources all named `.terraform_state` |
| C-3b | `modules/static-site/main.tf` | `aws_cloudfront_distribution.this`, `aws_s3_bucket.this` — singular `this` |

### 7d. FQDN regex — three different versions

| ID | File | Regex |
|---|---|---|
| C-4a | `envs/prod/variables.tf:57` | `^[a-z0-9]([a-z0-9.-]*[a-z0-9])+$` |
| C-4b | `modules/static-site/variables.tf:16` | `^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$` (escaped backslash) |
| C-4c | `modules/contact-form/variables.tf:19` | `^[a-z0-9]([a-z0-9.-]*[a-z0-9])+$` (matches envs) |

**Task C-A.** Pick one of each. Either `count` or `for_each` everywhere — pick `for_each`. Pick provider-level `default_tags` everywhere and drop the per-module merges. Pick `.this` per resource family. Pick **one** FQDN regex (use C-4a — it's the most permissive and matches existing call sites) and reference it from a single `local`.

---

## 8. Test files

### 8a. `contact-form.tftest.hcl:58-69` — `dynamodb_table_has_ttl_attribute`

```
run "dynamodb_table_has_ttl_attribute"
```

The test name says **TTL** but the code has no `ttl { ... }` block on `aws_dynamodb_table.submissions` (`modules/contact-form/main.tf:11-29`). The test asserts the `timestamp` *attribute* (which is the range key, declared at `main.tf:16`) — that's a different thing from a TTL attribute. The error message correctly says "(used as range key)", so the test is mis-named.

This is a **real bug**: submissions are stored forever, with no expiry. Either add the `ttl { attribute_name = "timestamp" enabled = true }` block and rename the test to match, or rename the test to `dynamodb_table_has_range_key_timestamp` and add a separate test (with the TTL block in code) for TTL.

### 8b. `static-site.tftest.hcl:22-24`

```
mock_provider "aws" { alias = "us_east_1" }
```

This will work for the CloudFront distribution test but fail the moment you add an assertion that reads a derived attribute from the us-east-1 ACM cert. Add `mock_data "aws_region" { defaults = { name = "us-east-1" } }` to give the mock provider something to return.

### 8c. Verbose test names + matching `error_message`

`modules/static-site/static-site.tftest.hcl` lines 26-50:
- `run "creates_one_cloudfront"` — `error_message = "module must create exactly one CloudFront distribution"`
- `run "creates_one_s3_bucket"` — `error_message = "module must create exactly one S3 bucket"`
- `run "creates_one_acm_certificate"` — `error_message = "module must create exactly one ACM certificate"`

The "module must create exactly one …" phrasing is AI-style narrative about its own code. A human writes `cfn_count = 1` and lets the assertion failure speak for itself.

**Task T-A.** Fix the lying TTL test. Either implement TTL or rename the test. Add `mock_data "aws_region"` to the us_east_1 mock. Shorten the test names and delete the redundant `error_message =` lines.

---

## 9. Scripts (`scripts/*.sh`)

Overall the scripts are terse and consistent — **the strongest human signal in the repo**. The findings below are mostly bugs and one AI tell.

| ID | File:Line | Finding |
|---|---|---|
| S-1 | `init-from-template.sh:54`, `replicate-env.sh:85, 90, 96` | `sed -i ''` is **macOS-only**; breaks silently on Linux. Use `sed -i.bak … && rm "${f}.bak"` or branch on `sed --version`. |
| S-2 | `init-from-template.sh:9` | Idempotency check greps for `example.com` — a user whose actual domain is `example.com` will get a false "Already initialized?" error on the second run. Use a unique sentinel like `__REPLACE_PRIMARY_DOMAIN__`. |
| S-3 | `init-from-template.sh:57` | `sed … s/YOUR_REPO/$PROJECT_NAME/g` — **substitutes a token that does not exist anywhere in the repo.** No human ran this script end-to-end. (Other tokens — `YOUR_ORG`, `YOUR_ACCOUNT_ID`, `example.com`, `ap-southeast-2` — do exist.) |
| S-4 | `init-from-template.sh:17-30` | `prompt()` accepts `_var_name="$1"` but never reads `_var_name`. Drop the parameter. |
| S-5 | `replicate-env.sh:107-112` | Dead `for f in "envs/$NEW_ENV"/sites/_*.tf; do [ -f "$f" ] || continue; done` — empty loop with a lying comment. |
| S-6 | `replicate-env.sh:85-92` | sed-based rewrite hardcoded to `variables.tf` + `terraform.tfvars.example`. Misses any other file in `envs/$NEW_ENV/` that mentions `iac-prod`. Rewrite over the whole `envs/$NEW_ENV/` tree. |
| S-7 | `teardown-env.sh:87` | `terraform -chdir=bootstrap output -raw state_bucket_arn` may fail (different role); `2>/dev/null \|\| echo ""` swallows the error and silently skips state cleanup. Read the bucket from `envs/$ENV_NAME/backend.tf` or a `bootstrap.auto.tfvars` instead. |
| S-8 | `teardown-env.sh:79` | `terraform init -upgrade` rewrites the lock file. Drop `-upgrade`. |
| S-9 | `teardown-env.sh:64-67` | `resourcegroupstaggingapi get-resources` requires `tag:GetResources` which the destroying env's role may not have. Read bucket names from `terraform output` of the env being destroyed (its `static_site[*].bucket_name` outputs). |
| S-10 | `prereqs.sh:24` | `_min_version` parameter is taken but never compared to `ver`. Drop it. |
| S-11 | `verify-site.sh:73-77` | Contact-form verify is a real `POST` — sends SES email and writes to DynamoDB. Make it a GET / OPTIONS, or gate behind `--with-contact-form`. |

**Task S-A.** Fix S-1, S-3, S-7, S-8, S-11 — the ones that are real bugs or that signal an unrun script. Fix S-2 to use a unique sentinel. Delete S-4, S-5, S-10 dead code. Broaden S-6.

---

## 10. CI / workflows

| ID | File:Line | Finding |
|---|---|---|
| CI-1 | `iac-plan.yml:15` | Requests `pull-requests: write` but never comments on the PR. Drop the permission. |
| CI-2 | `iac-plan.yml`, `iac-apply.yml`, `iac-test.yml` | Identical 18-line `setup-terraform` + OIDC blocks. Extract to `.github/actions/setup-tf-with-oidc/action.yml`. |
| CI-3 | `iac-plan.yml:62-67` | `TFVARS_SECRET` and `TFVARS_CONTENT` are both set to the same secret; `TFVARS_SECRET` is checked but never used. Collapse. |
| CI-4 | All workflows | Region `ap-southeast-2` hardcoded in 4 workflows. Move to top-level `env:` block. |
| CI-5 | `iac-teardown.yml:10-13` | Dropdown lists `stage / dev / test` — only `prod` is shipped; user clicks `dev` → OIDC failure. |
| CI-6 | `iac-teardown.yml:33-37` | `${{ inputs.environment }}` interpolated directly in shell. Use `env:` block. |
| CI-7 | `deploy-content.yml:39` | `if: needs.detect.outputs.matrix != '[]'` is redundant with the `paths:` filter. Drop it. |
| CI-8 | All workflows | Action versions are tags, not SHAs (`aws-actions/configure-aws-credentials@v4` etc.). Pin to SHAs if the security stance is "OIDC only". |
| CI-9 | All workflows | No `concurrency:` block. A double-push to `main` spawns two applies. |

**Task CI-A.** Extract composite action (CI-2), drop unused permission (CI-1), pin SHAs (CI-8), add `concurrency:` (CI-9). Fix the broken env list (CI-5). The rest is polish.

---

## 11. Documentation

Top-level docs (`README.md`, `ARCHITECTURE.md`, `GETTING_STARTED.md`, `CONTRIBUTING.md`, `SECURITY.md`, the two ADRs, all module READMEs) read as **human-written** — terse, table-driven, no "Welcome to…", no marketing adjectives. Strongest human signal in the repo.

Findings below are mostly small.

| ID | File:Line | Finding |
|---|---|---|
| D-DOC-1 | `CODE_OF_CONDUCT.md:40` | Ships with literal `[INSERT CONTACT METHOD]` placeholder. Fill in (e.g. `security@<your-domain>`) or replace with a 4-6 line custom CoC. |
| D-DOC-2 | `SECURITY.md:10` | `security@your-domain.example` — fully-formatted fake that looks live. Replace with `<REPLACE_ME>@example.com` and add to `init-from-template.sh` substitution list. |
| D-DOC-3 | `README.md:4` | Blockquote tagline + "IaC Repo based on Terraform" is mildly AI-coded. Optional: drop blockquote, rename to `terraform-static-site` or similar. |
| D-DOC-4 | `GETTING_STARTED.md:91-92` | Docs claim outputs are `github_infra_role_arn_prod` / `github_content_role_arn_prod` (env-suffixed). Actual outputs in `envs/prod/outputs.tf:61-69` are unprefixed. **Docs lie** — fix the doc or rename the outputs. |
| D-DOC-5 | `envs/prod/README.md:14` | Says `sites.tf (now empty — per-site files in sites/)`. `sites.tf` is **not** empty. |
| D-DOC-6 | `envs/prod/README.md:11-12` | Tells the user to read `main.tf` for the backend block — but `main.tf:11-21` has it commented out. Either un-comment (and document) or remove the claim. |
| D-DOC-7 | "self-contained" / "S3 backend" phrasing | Repeated near-verbatim in 4 files (`bootstrap/README.md:3-4`, `envs/README.md:3-5`, `envs/prod/README.md:29-30`, `0002-…md:26-28`, `ARCHITECTURE.md:11-12, 50-51`). Centralize in `ARCHITECTURE.md`, link from siblings. |

**Issue / PR templates** are customised (the strongest human signal in `.github/`) — short, no GitHub defaults. Three small findings:

| ID | File:Line | Finding |
|---|---|---|
| D-TPL-1 | `.github/ISSUE_TEMPLATE/using-this-template.md:4` | `title: ""` (empty string) is an AI tell. Set `title: "[question] "` to match the other templates. |
| D-TPL-2 | `.github/ISSUE_TEMPLATE/bug.md:16-18` | Empty fenced code block with `# Commands you ran` inside. Replace with prose. |

---

## 12. Repo-meta

| ID | File:Line | Finding |
|---|---|---|
| M-1 | `.gitignore:36-43` | `# Environment` (`.env`, `.env.*`, `!.env.example`) and `# Node` (`node_modules/`, `package-lock.json`) blocks are **dead config** — no `.env.example` or `package.json` exists. Delete. |
| M-2 | `.pre-commit-config.yaml` | `terraform_docs` hook has **never been run.** If it had, module README tables would be the 4-5 column format it emits; current tables are 2-column `Output / Description`. Either run `pre-commit run --all-files` and commit regenerated tables, or delete the hook. |
| M-3 | `.editorconfig` | Clean. No finding. |

---

## 13. Functional / security issues that overlap with AI traces

These look like AI oversights (the model didn't think them through) and would be caught by a human reviewer:

| ID | File:Line | Issue |
|---|---|---|
| F-1 | `modules/team-iam/main.tf:279-284` | `aws_iam_user_login_profile` is **unconditional** for every team member. Each apply auto-generates a console password and stores it in state. Gate behind `count`, or drop the resource entirely and use `aws_iam_user_login_profile` only when explicitly requested. |
| F-2 | `modules/team-iam/main.tf:201` | Policy name `read-only-iac-tfm` hardcodes `iac-tfm` — should be `read-only-${var.project_name}`. The AI copied the `default = "iac-tfm"` into the resource name and forgot to template it. |
| F-3 | `modules/team-iam/main.tf:257` | `Resource = ["arn:aws:lambda:*:*:function:contact-*"]` — wildcard across all accounts and regions. Narrow to the env's account and region. |
| F-4 | `modules/team-iam/main.tf:312-317` | `thumbprint_list = ["1b58db2c8c81e5d343c31695c1c0e1f2a31379e5"]` is a stale GitHub OIDC thumbprint. AWS provider 5.83+ accepts omission of `thumbprint_list`; delete the hardcoded value. |
| F-5 | `modules/contact-form/src/index.mjs:17` | Origin header check as auth — CORS is browser-enforced, so any non-browser client can hit the URL with the right `Origin` header. Not strictly an AI tell but it reads as "AI shipped the CORS example". |
| F-6 | `envs/prod/sites.tf:24-26` | `coalesce(each.value.recipient_email, var.alert_email)` — when both are `""` (defaults), the contact form is silently enabled with an empty recipient, which then **fails the email regex** at `modules/contact-form/variables.tf:28-32` (`""` doesn't match `[^@\s]+@[^@\s]+\.[^@\s]+`). Default `enable_contact_form = true` plus empty recipient = broken out-of-the-box. |
| F-7 | `envs/prod/sites.tf:29` | `sender_email = "noreply@${var.primary_domain}"` — SES will reject unless `noreply` is also a verified email identity (domain identity alone isn't enough). |
| F-8 | `modules/static-site/outputs.tf:16-19` | `acm_certificate_arn` returns `aws_acm_certificate.this.arn` (un-validated) while the distribution attaches `aws_acm_certificate_validation.this.certificate_arn`. Anyone consuming this output would attach an un-validated cert. See D-1. |
| F-9 | `modules/team-iam/main.tf:175-177` | The deny-by-resource ordering relies on explicit statement order; the developer allow above (`s3:*` on `Resource = "*"`) is correct but the policy could be tightened to per-site ARNs. |
| F-10 | `modules/contact-form/src/index.mjs:68` | Logs raw `sourceIp` into DynamoDB — fine, but no TTL on the table (see §8a) means the table grows unboundedly. |

**Task F-A.** Fix F-1, F-2, F-3, F-6, F-8 — these are bugs that affect anyone who runs the template as-shipped. Fix F-4 and F-7 before you cut a release. The rest can wait.

---

## 14. Suggested cleanup sequence

### Pass 1 — bugs that bite on first apply (do this first)
1. **F-1** — gate `aws_iam_user_login_profile` behind `count` or delete
2. **F-2** — template the policy name with `var.project_name`
3. **F-6** — fix `coalesce` / `recipient_email` interaction (default `enable_contact_form = false`, or fail loudly when both recipient and alert email are empty)
4. **F-8** — delete the lying `acm_certificate_arn` output (D-1)
5. **§3 / P-A** — re-init every stack against `~> 5.0`, commit consistent lock files, add CI check
6. **§9 / S-3** — make `init-from-template.sh` substitute a token that actually exists (or remove `YOUR_REPO`)
7. **§9 / S-7, S-9** — make `teardown-env.sh` read bucket names from `terraform output` of the env being destroyed

### Pass 2 — strip the AI tells
8. **§2 / B-A** — delete every banner block and every `# ADAPTED:` comment
9. **§4 / V-A** — delete validation blocks; factor one FQDN regex and one email regex if any must stay
10. **§5 / D-A** — delete unused outputs and locals
11. **§6 / DS-A** *(optional)* — cut every `description =` to a noun-phrase
12. **§8 / T-A** — rename the lying TTL test (or implement TTL); shorten `error_message =` lines; add `mock_data "aws_region"`
13. **§11 / D-DOC-1, D-DOC-2, D-DOC-4, D-DOC-5** — fix the lying doc references

### Pass 3 — consistency & polish
14. **§7 / C-A** — pick `for_each` (drop `count`), pick provider-level `default_tags` (drop per-module merges), pick `.this` per resource, pick one FQDN regex
15. **§10 / CI-A** — extract composite action, drop unused permission, pin SHAs, add `concurrency:`
16. **§12 / M-1, M-2** — delete dead `.gitignore` blocks; either run pre-commit or delete the hook
17. **§1 / R-A** *(optional)* — rewrite the single squash commit as a small ordered series
18. **§9 / S-2, S-4, S-5, S-10** — clean up scripts: unique sentinel, drop dead params/loops

---

## 15. Consolidated task list

Severity legend: **BUG** = real functional bug, **STYLE** = pure AI-tell, **POLISH** = nice-to-have.

| # | ID | File | Severity | Task |
|---|---|---|---|---|
| 1 | F-1 | `modules/team-iam/main.tf:279-284` | **BUG** | Gate `aws_iam_user_login_profile` behind `count` |
| 2 | F-2 | `modules/team-iam/main.tf:201` | **BUG** | Use `var.project_name` in policy name, not hardcoded `iac-tfm` |
| 3 | F-6 | `envs/prod/sites.tf:24-26` | **BUG** | Fix `coalesce(recipient_email, alert_email)` default interaction |
| 4 | F-8 / D-1 | `modules/static-site/outputs.tf:16-19` | **BUG** | Delete misleading `acm_certificate_arn` output |
| 5 | §3 / P-A | `modules/team-iam/.terraform.lock.hcl` | **BUG** | Re-init all stacks against `~> 5.0`; commit consistent locks |
| 6 | S-3 | `scripts/init-from-template.sh:57` | **BUG** | Remove `YOUR_REPO` substitution (token doesn't exist) |
| 7 | S-7 | `scripts/teardown-env.sh:87` | **BUG** | Read bucket from env's own `terraform output`, not bootstrap |
| 8 | S-8 | `scripts/teardown-env.sh:79` | **BUG** | Drop `terraform init -upgrade` |
| 9 | S-11 | `scripts/verify-site.sh:73-77` | **BUG** | Make contact-form verify non-side-effecting |
| 10 | T-A (TTL) | `modules/contact-form/tftest:58-69` | **BUG** | Rename lying TTL test or implement TTL |
| 11 | F-4 | `modules/team-iam/main.tf:312-317` | **BUG** | Remove stale OIDC thumbprint |
| 12 | B-A | banner blocks across all `.tf` | **STYLE** | Delete every `# ----` banner |
| 13 | B-A | `# ADAPTED:` comments | **STYLE** | Delete all 8 occurrences in `team-iam/main.tf` |
| 14 | B-A | `modules/team-iam/outputs.tf:34-35` | **STYLE** | Delete lying "output names include role_name_prefix" comment |
| 15 | V-A | `validation` blocks across modules | **STYLE** | Delete redundant ones; factor one FQDN / email regex if any |
| 16 | V-A | `modules/team-iam/main.tf:30-48` | **STYLE** | Delete `terraform_data` preconditions |
| 17 | D-A | unused outputs (D-2 … D-10) | **STYLE** | Delete |
| 18 | D-A | `envs/prod/main.tf:48-50` unused locals | **STYLE** | Delete `account_id`, `region` |
| 19 | D-A | `modules/team-iam/main.tf:12` `common_tags` | **STYLE** | Delete redundant `ManagedBy` re-merge |
| 20 | DS-A | every `description =` | **STYLE** *(optional)* | Cut to one short noun-phrase — skip if you prefer over-documented variables |
| 21 | C-A | mixed `count` / `for_each` | **POLISH** | Pick `for_each` |
| 22 | C-A | three tag mechanisms | **POLISH** | Pick provider-level `default_tags` only |
| 23 | C-A | `.terraform_state` vs `.this` | **POLISH** | Pick `.this` everywhere |
| 24 | C-A | three FQDN regexes | **POLISH** | Pick one |
| 25 | CI-1 | `iac-plan.yml:15` | **POLISH** | Drop unused `pull-requests: write` |
| 26 | CI-2 | workflows | **POLISH** | Extract composite action for setup-tf + OIDC |
| 27 | CI-8 | workflows | **POLISH** | Pin actions to SHAs |
| 28 | CI-9 | workflows | **POLISH** | Add `concurrency:` block |
| 29 | S-1 | `init-from-template.sh:54`, `replicate-env.sh:85,90,96` | **POLISH** | Replace `sed -i ''` with portable form |
| 30 | S-2 | `init-from-template.sh:9` | **POLISH** | Use unique sentinel, not `example.com` |
| 31 | S-4 | `init-from-template.sh:17` | **POLISH** | Drop unused `_var_name` parameter |
| 32 | S-5 | `replicate-env.sh:107-112` | **POLISH** | Delete empty loop with lying comment |
| 33 | S-6 | `replicate-env.sh:85-92` | **POLISH** | Broaden sed scope to whole env tree |
| 34 | S-10 | `prereqs.sh:24` | **POLISH** | Drop unused `_min_version` param |
| 35 | D-DOC-1 | `CODE_OF_CONDUCT.md:40` | **POLISH** | Replace `[INSERT CONTACT METHOD]` |
| 36 | D-DOC-2 | `SECURITY.md:10` | **POLISH** | Replace fake email with `REPLACE_ME@example.com` |
| 37 | D-DOC-4 | `GETTING_STARTED.md:91-92` | **POLISH** | Fix output names referenced in docs |
| 38 | D-DOC-5 | `envs/prod/README.md:14` | **POLISH** | Remove "(now empty)" claim |
| 39 | D-DOC-6 | `envs/prod/README.md:11-12` | **POLISH** | Either enable the commented backend or remove the claim |
| 40 | D-DOC-7 | "self-contained" phrasing | **POLISH** | Centralize in `ARCHITECTURE.md` |
| 41 | D-TPL-1 | `using-this-template.md:4` | **POLISH** | Set `title: "[question] "` |
| 42 | D-TPL-2 | `bug.md:16-18` | **POLISH** | Replace empty code fence with prose |
| 43 | M-1 | `.gitignore:36-43` | **POLISH** | Delete dead `.env*` and `node_modules` blocks |
| 44 | M-2 | `.pre-commit-config.yaml` | **POLISH** | Either run pre-commit or delete the `terraform_docs` hook |
| 45 | R-A | git history | **POLISH** *(optional)* | Rewrite single squash as 6 ordered commits — skip if repo already has consumers |

---

## 16. Closing note

The single most diagnostic feature of this repo is **the provider-version drift in `.terraform.lock.hcl`**. Everything else is recoverable with cosmetic passes; that one means the template was never exercised end-to-end by a person who would have hit `terraform init` in `envs/prod` and seen two different `hashicorp/aws` majors resolve.

Once Pass 1 (the seven real bugs) is done, the repo will function correctly for the first time. Passes 2 and 3 are what makes it stop *smelling* like an AI generated it — but they don't fix bugs, they remove the tells that suggest someone should look harder for bugs.