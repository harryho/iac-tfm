# envs/

One subdirectory per environment. Each is a self-contained Terraform
stack with its own state file in the shared S3 backend (key prefix
`envs/<env_name>/terraform.tfstate`).

`prod/` ships enabled by default. To add another env:

```bash
../../scripts/replicate-env.sh stage
cd stage
terraform init
terraform plan
```

To tear down an env:

```bash
../../scripts/teardown-env.sh stage
```
