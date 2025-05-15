# Requirements:
* Ensure the aws access credentials configured on your local env.
```
export AWS_ACCESS_KEY_ID=......
export AWS_SECRET_ACCESS_KEY=......
```
* Terrform version used here: 1.5.7


## To run the Terraform code
```
terraform init

terraform validate

terraform plan -var-file=../tfvars/tf-init/tf-init-dev.tfvars -state=../tfvars/tf-init/terraform-dev.tfstate

terraform apply -var-file=../tfvars/tf-init/tf-init-dev.tfvars -state=../tfvars/tf-init/terraform-dev.tfstate

```
