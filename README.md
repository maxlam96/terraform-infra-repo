# terraform-infra-repo

Terraform infrastructure repository for the Jenkins + OPA + Floci lab.

## Layout

```text
.
├── Jenkinsfile
└── floci-vpc/
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
NETWORK_APPROVERS=network-team
ENV=staging
RUN_APPLY=false
```

Set `RUN_APPLY=true` only when you want Jenkins to request manual approval and then apply to Floci.

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

OPA policy is checked by Jenkins after it checks out `tf-policy-repo`.
