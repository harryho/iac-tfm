# envs/prod

Production environment stack. Source of truth for the
`iac-tfm-template-design` example.

## Layout

```
prod/
├── main.tf                terraform + provider (backend config commented)
├── variables.tf           env_name, primary_domain, sites, etc.
├── outputs.tf             per-site outputs
├── infra.tf               SES, SNS, budget, dashboard
├── sites.tf               static_site + contact_form module calls
├── team-iam.tf            per-env OIDC roles
├── terraform.tfvars.example
├── sites/
│   ├── _example-com.tf
│   ├── _blogs-example-com.tf
│   └── _app-example-com.tf
└── content/
    ├── example-com/dist/
    ├── blogs-example-com/dist/
    └── app-example-com/dist/
```

## State

`s3://<bootstrap-bucket>/envs/prod/terraform.tfstate`, locked by the
shared DynamoDB table.

## CI/CD

GitHub Environment: `production`. Secrets:
- `AWS_ROLE_ARN_PLAN_PROD`
- `AWS_ROLE_ARN_APPLY_PROD`
