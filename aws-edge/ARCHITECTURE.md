# Architecture (aws-edge)

Cross-cutting conventions live one level up at
[`/ARCHITECTURE.md`](../ARCHITECTURE.md). This file lists what each
component in `aws-edge/` does.

## Components

### `bootstrap/`
- S3 bucket for Terraform state (versioned, encrypted, lifecycle rules)
- DynamoDB table for state locking
- Outputs: backend config block + state bucket name

### `modules/static-site/`
- S3 bucket (private, OAC-only access)
- CloudFront distribution with OAC
- ACM certificate in `us-east-1` (required for CloudFront)
- Optional www → apex redirect via CloudFront Function
- Custom 404 page

### `modules/contact-form/`
- Lambda function (Node.js 20, SES + DynamoDB)
- Function URL (public, CORS locked to site domain)
- DynamoDB table for submission log
- CloudWatch log group + error alarm
- Optional Cloudflare Turnstile

### `modules/team-iam/`
- IAM groups (admin / developer / tester)
- IAM users from `team_members` variable
- Password policy + MFA enforcement
- OIDC roles for GitHub Actions (per-env via `role_name_prefix`)

### `envs/<env>/`
- Wires the modules together for one environment
- Declares the SES domain identity (one per env)
- SNS alerts topic + email subscription
- CloudWatch dashboard
- AWS Budget