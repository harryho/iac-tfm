# bootstrap

S3 bucket + DynamoDB lock table for Terraform state. Run **once per AWS
account** before any env.

## Usage

```bash
terraform init
terraform apply
```

Outputs:
- `backend_config` — values for the `backend "s3"` block in envs/<env>/
- `state_bucket_name` — for teardown scripts
