# iac-tfm Cleanup — Implementation Plan

Execution checklist for the findings in `ai-taste-audit.md`. Each task references the audit ID — read the audit for rationale.

**Goal:** make the repo (1) function correctly on first apply, (2) stop smelling AI-generated, (3) get consistent.

**Order is fixed:** Pass 1 → 2 → 3. Doing style first re-introduces noise when you fix bugs.

**Scope:** 45 tasks. 11 BUG, 9 STYLE, 25 POLISH. Two POLISH tasks (DS-A, R-A) are optional.

---

## Pre-flight

Before Pass 1, capture a clean baseline so verification means something:

- [ ] Run `terraform init` & `terraform validate` in every stack dir; record which fail
- [ ] Run `terraform test` in every module; record which fail
- [ ] `git status` clean, on a fresh branch `cleanup/ai-taste-pass-1`

Stack dirs: `bootstrap/`, `modules/static-site/`, `modules/contact-form/`, `modules/team-iam/`, `envs/prod/`.

---

## Pass 1 — bugs that bite on first apply

Each task is one commit. Commit message prefix `fix:`.

### P1.1 — F-1: gate IAM login profile behind count
- [ ] File: `modules/team-iam/main.tf:279-284`
- [ ] Add `var.enable_console_login` (bool, default `false`) to `modules/team-iam/variables.tf` and `envs/prod/terraform.tfvars.example`
- [ ] Wrap `aws_iam_user_login_profile` in `count = var.enable_console_login ? 1 : 0`
- [ ] Verify: `terraform validate modules/team-iam`

### P1.2 — F-2: template hardcoded policy name
- [ ] File: `modules/team-iam/main.tf:201`
- [ ] Change `read-only-iac-tfm` → `read-only-${var.project_name}`
- [ ] Verify: `terraform validate modules/team-iam`; `rg "iac-tfm" modules/team-iam/` returns no hardcoded references

### P1.3 — F-6: fix contact-form recipient coalesce
- [ ] Files: `envs/prod/sites.tf:24-26`, `envs/prod/variables.tf`
- [ ] Either flip default `enable_contact_form = false` in `envs/prod/terraform.tfvars.example`, **or** add a `validation` block on `recipient_email` rejecting `""` when contact form is enabled
- [ ] Verify: `terraform validate envs/prod`; construct a tfvars with empty recipient + enabled form, confirm plan fails clearly

### P1.4 — F-8 / D-1: delete misleading ACM output
- [ ] File: `modules/static-site/outputs.tf:16-19`
- [ ] Delete the `acm_certificate_arn` output block (it returns the un-validated ARN)
- [ ] Verify: `terraform validate modules/static-site`; `rg "acm_certificate_arn" envs/` returns nothing consuming it

### P1.5 — §3 / P-A: re-init all stacks on consistent provider version
- [ ] For each stack dir: edit `required_provider` block to `~> 5.0`, delete `.terraform.lock.hcl` and `.terraform/`, run `terraform init -backend=false`
- [ ] Confirm every committed `.terraform.lock.hcl` now shows the same `hashicorp/aws` version
- [ ] Add CI check: new workflow `.github/workflows/iac-lock-consistency.yml` running `terraform init -backend=false -input=false` in every stack, fail if any lock file is dirty afterwards
- [ ] Delete on-disk `.terraform/` dirs after re-init
- [ ] Verify: `git diff -- '*.lock.hcl'` shows 5 identical version lines

### P1.6 — S-3: remove non-existent YOUR_REPO substitution
- [ ] File: `scripts/init-from-template.sh:57`
- [ ] Either delete the `sed … s/YOUR_REPO/…` line, or introduce `YOUR_REPO` as a real token in `envs/prod/*.tf` where the repo name is referenced
- [ ] Verify: `rg "YOUR_REPO"` returns either zero hits or hits matched by real template call sites

### P1.7 — S-7 + S-9: read bucket names from env's own outputs
- [ ] File: `scripts/teardown-env.sh:64-67, 79, 87`
- [ ] Replace `resourcegroupstaggingapi` lookup (S-9) with `terraform -chdir="envs/$ENV_NAME" output -raw static_site_bucket_names` (or whatever the env exports)
- [ ] Replace `terraform -chdir=bootstrap output -raw state_bucket_arn` (S-7) with reading from `envs/$ENV_NAME/backend.tf` or a `bootstrap.auto.tfvars`
- [ ] Drop `terraform init -upgrade` (S-8) — it rewrites the lock file
- [ ] Add `state_bucket_name` output to `bootstrap/outputs.tf` (un-`sed`'d value)
- [ ] Verify: dry-run `bash -x scripts/teardown-env.sh prod` against a non-existent env; confirm it reads from the right source

### P1.8 — S-11: make contact-form verify non-side-effecting
- [ ] File: `scripts/verify-site.sh:73-77`
- [ ] Either switch the verify to GET / OPTIONS, or add `--with-contact-form` flag that gates the POST
- [ ] Verify: `bash scripts/verify-site.sh prod <site-key>` without the flag performs no writes

### P1.9 — T-A (TTL): rename or implement the lying test
- [ ] File: `modules/contact-form/contact-form.tftest.hcl:58-69`
- [ ] Decide: either (a) add `ttl { attribute_name = "timestamp" enabled = true }` to `aws_dynamodb_table.submissions` in `modules/contact-form/main.tf:11-29` and keep the test name, or (b) rename the run block to `dynamodb_table_has_range_key_timestamp` and add a separate TTL test later
- [ ] Verify: `terraform test modules/contact-form/`

### P1.10 — F-4: drop stale GitHub OIDC thumbprint
- [ ] File: `modules/team-iam/main.tf:312-317`
- [ ] Delete `thumbprint_list = […]` (AWS provider 5.83+ accepts omission)
- [ ] Verify: `terraform validate modules/team-iam`

### P1.11 — End-of-pass verification
- [ ] `terraform fmt -check -recursive` clean
- [ ] `terraform validate` passes in every stack dir
- [ ] `terraform test` passes in every module
- [ ] `terraform -chdir=envs/prod plan -refresh=false` (with placeholder tfvars) returns no errors
- [ ] Commit: `fix: pass 1 — real bugs that bite on first apply`

---

## Pass 2 — strip the AI tells

Style only. No behaviour change. Each task is one commit, prefix `style:`.

### P2.1 — B-A: delete banner blocks and `# ADAPTED:` comments
- [ ] Files: all `.tf` files listed in audit §2 (B-1 through B-8)
- [ ] Delete every `# ----…----` banner block. If a section genuinely needs a label, replace with a one-token heading (`# OIDC`, `# ACM`)
- [ ] Delete all 8 `# ADAPTED:` comments in `modules/team-iam/main.tf`
- [ ] Delete the lying output-name comment at `modules/team-iam/outputs.tf:34-35`
- [ ] Verify: `rg "^# -{5,}" **/*.tf` returns nothing; `rg "ADAPTED"` returns nothing

### P2.2 — V-A: delete redundant validation blocks
- [ ] Files: variable files listed in audit §4 (V-1 through V-8)
- [ ] Delete `validation` blocks where AWS / Terraform / CloudWatch already rejects the value (region enums, `> 0`, IAM name regexes, CloudWatch retention enum)
- [ ] Delete `terraform_data` preconditions in `modules/team-iam/main.tf:30-48`
- [ ] If any FQDN/email regex must stay, factor into one `locals.fqdn_re` in `envs/prod/variables.tf` (or a `variableslocals.tf`) and reference via `can(regex(local.fqdn_re, var.x))`
- [ ] Verify: `terraform validate` all stacks; `terraform test` all modules still pass

### P2.3 — D-A: delete unused outputs and locals
- [ ] Delete D-2 through D-10 from audit §5 (`www_redirect_function_name`, `group_arns`, `user_names`, `user_arns`, `monthly_budget_name`, `ops_dashboard_name`, `state_bucket_arn`-unused-but-keep-the-new-`state_bucket_name`-from-P1.7, `state_key_prefix` → make it a `local`, `instructions` heredoc, `next_steps` heredoc)
- [ ] Delete unused locals D-11 (`account_id`, `region`) from `envs/prod/main.tf:48-50`
- [ ] Delete the redundant `common_tags` re-merge D-12 in `modules/team-iam/main.tf:12`
- [ ] **Move** `next_steps` content (D-10) into `GETTING_STARTED.md` before deleting the output
- [ ] Verify: `terraform validate` all stacks; `rg "group_arns\|user_names\|user_arns\|monthly_budget_name\|ops_dashboard_name"` returns nothing

### P2.4 — DS-A (OPTIONAL): trim verbose descriptions
- [ ] Skip if you prefer over-documented variables. If doing it: cut each `description =` in `envs/prod/variables.tf`, `modules/team-iam/variables.tf`, `modules/team-iam/outputs.tf` to a noun-phrase; move "what to do if you forget" prose to `GETTING_STARTED.md`
- [ ] Verify: `terraform validate` all stacks

### P2.5 — T-A: shorten test names + drop redundant error_message
- [ ] File: `modules/static-site/static-site.tftest.hcl:26-50`
- [ ] Rename: `creates_one_cloudfront` → `cloudfront_count`, `creates_one_s3_bucket` → `s3_count`, `creates_one_acm_certificate` → `acm_count`
- [ ] Delete `error_message = "module must create exactly one …"` lines (assertion failures already speak)
- [ ] Add `mock_data "aws_region" { defaults = { name = "us-east-1" } }` to the `us_east_1` mock provider (audit §8b)
- [ ] Verify: `terraform test modules/static-site/`

### P2.6 — D-DOC-1 / D-DOC-2 / D-DOC-4 / D-DOC-5 / D-DOC-6: fix lying docs
- [ ] `CODE_OF_CONDUCT.md:40` — replace `[INSERT CONTACT METHOD]` with `security@<your-domain>` or replace the whole file with a 4-6 line custom CoC
- [ ] `SECURITY.md:10` — replace `security@your-domain.example` with `REPLACE_ME@example.com`; add to `init-from-template.sh` substitution list
- [ ] `GETTING_STARTED.md:91-92` — fix output names to match actual `envs/prod/outputs.tf:61-69` (unprefixed)
- [ ] `envs/prod/README.md:14` — remove "(now empty)" claim, `sites.tf` is not empty
- [ ] `envs/prod/README.md:11-12` — either uncomment the backend block in `main.tf:11-21` and document, or remove the "read main.tf for backend" claim
- [ ] Verify: read each changed doc top-to-bottom; cross-check every code reference against the actual code

### P2.7 — End-of-pass verification
- [ ] `terraform fmt -check -recursive` clean
- [ ] `terraform validate` and `terraform test` pass everywhere
- [ ] `rg "ADAPTED|INSERT CONTACT|your-domain.example"` returns nothing
- [ ] Commit: `style: pass 2 — strip AI tells`

---

## Pass 3 — consistency & polish

Each task is one commit, prefix `refactor:` or `chore:`.

### P3.1 — C-A: pick one of each
- [ ] `for_each` over `count`: replace `count = var.enable_www_redirect ? 1 : 0` in `modules/static-site/main.tf:124-125, 181-182` with `for_each` style consistent with the parent resource
- [ ] Provider-level `default_tags` only: drop per-module `locals.site_tags` merges in `modules/static-site/main.tf:8` and `modules/contact-form/main.tf:5`; drop the re-merge in `modules/team-iam/main.tf:12` (already deleted in P2.3)
- [ ] `.this` naming everywhere: rename `aws_s3_bucket.terraform_state` → `.this`, etc. in `bootstrap/main.tf` (5 resources)
- [ ] One FQDN regex: pick `^[a-z0-9]([a-z0-9.-]*[a-z0-9])+$` (C-4a), reference from one `local`
- [ ] Verify: `terraform validate` + `terraform test` all stacks; `terraform plan envs/prod -refresh=false` shows no unexpected diffs

### P3.2 — CI-A: workflow polish
- [ ] Extract `.github/actions/setup-tf-with-oidc/action.yml` composite action; call from `iac-plan.yml`, `iac-apply.yml`, `iac-test.yml`
- [ ] Drop unused `pull-requests: write` from `iac-plan.yml:15`
- [ ] Pin every action to commit SHA (not `@v4`)
- [ ] Add `concurrency: { group: ${{ github.workflow }}-${{ github.ref }}, cancel-in-progress: false }` to all workflows
- [ ] Fix `iac-teardown.yml:10-13` env dropdown — only `prod` ships, drop `stage/dev/test`
- [ ] Move `ap-southeast-2` to top-level `env:` block in all workflows
- [ ] Verify: trigger each workflow on a feature branch; confirm OIDC + setup works

### P3.3 — M-1 / M-2: repo-meta
- [ ] `.gitignore:36-43` — delete dead `# Environment` and `# Node` blocks
- [ ] `.pre-commit-config.yaml` — either run `pre-commit run --all-files` and commit regenerated README tables, or delete the `terraform_docs` hook
- [ ] Verify: `git status` clean after the change

### P3.4 — R-A (OPTIONAL): rewrite git history
- [ ] Skip if the repo already has consumers. If doing it: on a fresh branch, reset to root and rebuild with the 6 commits listed in audit §1
- [ ] Verify: `git log --oneline` shows 6 commits with real author identity

### P3.5 — S-2 / S-4 / S-5 / S-10: script polish
- [ ] `init-from-template.sh:9` — replace `example.com` idempotency grep with a unique sentinel like `__REPLACE_PRIMARY_DOMAIN__`
- [ ] `init-from-template.sh:17` — drop unused `_var_name` parameter from `prompt()`
- [ ] `replicate-env.sh:107-112` — delete empty loop with lying comment
- [ ] `prereqs.sh:24` — drop unused `_min_version` parameter
- [ ] S-1: replace `sed -i ''` with portable form (`sed -i.bak … && rm "${f}.bak"`) in `init-from-template.sh:54` and `replicate-env.sh:85, 90, 96`
- [ ] S-6: broaden `replicate-env.sh:85-92` sed scope to whole `envs/$NEW_ENV/` tree
- [ ] Verify: `shellcheck scripts/*.sh` clean; `bash scripts/init-from-template.sh --dry-run` (if it has one) or manual review

### P3.6 — D-DOC-3 / D-DOC-7 / D-TPL-1 / D-TPL-2: doc & template polish
- [ ] `README.md:4` — drop blockquote tagline (optional rename to `terraform-static-site`)
- [ ] Centralize "self-contained / S3 backend" phrasing in `ARCHITECTURE.md`, link from `bootstrap/README.md`, `envs/README.md`, `envs/prod/README.md`, `0002-…md`
- [ ] `.github/ISSUE_TEMPLATE/using-this-template.md:4` — set `title: "[question] "`
- [ ] `.github/ISSUE_TEMPLATE/bug.md:16-18` — replace empty code fence with prose prompt
- [ ] Verify: read all changed files end-to-end

### P3.7 — End-of-pass verification
- [ ] `terraform fmt -check -recursive` clean
- [ ] `terraform validate` + `terraform test` all stacks
- [ ] `terraform -chdir=envs/prod plan -refresh=false` (placeholder tfvars) clean
- [ ] `shellcheck scripts/*.sh` clean
- [ ] All workflows run green on the feature branch
- [ ] Commit: `chore: pass 3 — consistency & polish`

---

## Out of scope (deliberate)

These appear in the audit but are not in the plan:

- **F-3** (wildcard Lambda ARN), **F-5** (CORS-as-auth), **F-7** (`noreply@` SES), **F-9** (deny ordering), **F-10** (sourceIp logging) — real but require design decisions, not mechanical fixes. File as separate issues after Pass 1.
- **CI-3** (`TFVARS_SECRET`/`TFVARS_CONTENT` collapse), **CI-4** (region hardcode — folded into P3.2), **CI-6** (interpolation), **CI-7** (redundant if) — minor, fold into P3.2 ad-hoc.
- **CI-5** env dropdown — already in P3.2.

---

## Handoff

After all three passes: open one PR per pass (three PRs total) so review can sign off on bugs, then style, then polish independently. Don't combine — the BUG PR must merge before the STYLE PR is touched.
