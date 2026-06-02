# terraform-infra-repo

Terraform infrastructure repository for the Jenkins + OPA + Floci lab.

## Layout

```text
.
├── Jenkinsfile
├── modules/
│   ├── vpc/
│   └── eks/
├── floci-vpc/
│   ├── main.tf
│   ├── providers.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   └── envs/
└── floci-eks/
    ├── main.tf
    ├── providers.tf
    ├── variables.tf
    ├── outputs.tf
    ├── versions.tf
    └── envs/
```

## Jenkins Parameters

```text
FLOCI_ENDPOINT=http://192.168.251.1:4566
POLICY_REPO_URL=https://github.com/maxlam96/tf-policy-repo.git
POLICY_REPO_BRANCH=main
POLICY_REPO_CREDENTIALS_ID=maxlam96
NETWORK_APPROVERS=network-team
TF_DIR=floci-vpc
ENV=staging
RUN_APPLY=false
```

Use `TF_DIR=floci-vpc` for the VPC stack and `TF_DIR=floci-eks` for the EKS stack.

Set `RUN_APPLY=true` only when you want Jenkins to request manual approval and then apply to Floci. Floci currently supports the VPC lab path, but it does not emulate the EKS control plane APIs, so Jenkins skips Floci apply for `TF_DIR=floci-eks`.

VPC creation requires approval in Jenkins from `NETWORK_APPROVERS`. After the approval step passes, Jenkins injects `change_request.submitted_by_team=network` into OPA data. Without that approval, OPA blocks `aws_vpc` creation.

Set `NETWORK_APPROVERS` to the Jenkins user or group that represents the Network team, for example `network-team` or `alice,bob`.

## Local Check

```bash
cd floci-vpc
terraform init -input=false
terraform validate
terraform plan -refresh=false -out=tfplan -var-file=envs/staging.tfvars -var='floci_endpoint=http://192.168.251.1:4566'
terraform show -json tfplan > plan.json
```

For EKS policy validation:

```bash
cd floci-eks
terraform init -input=false
terraform validate
terraform plan -refresh=false -out=tfplan -var-file=envs/staging.tfvars -var='floci_endpoint=http://192.168.251.1:4566'
terraform show -json tfplan > plan.json
```

OPA policy is checked by Jenkins after it checks out `tf-policy-repo`.
