# Terraform Infrastructure Setup

This repository provides a Terraform infrastructure setup that includes components such as VPC, KMS, S3 backend, EKS, IRSA, and CI/CD roles, structured into reusable modules and organized environments.

## Directory Structure Overview

terraform/<br>
├── backend_additional/ # Optional or extended backend config<br>
├── backend_base/ # Main infrastructure components (EKS, VPC, KMS, IRSA)<br>
├── data/ # External data dependencies or files<br>
├── modules/ # Reusable infrastructure modules<br>
│ ├── m-irsa<br>
│ ├── m-kms-key<br>
│ ├── m-tfstate<br>
│ └── m-vpc<br>
├── tf-init/ # Terraform state bucket and IAM bootstrap<br>
├── tfvars/ # Variable files per environment<br>

## Prerequisites

Make sure the following are installed:

- [Terraform 1.5.7]
- [AWS CLI]
- AWS admin credentials configured via environment variables or profile (`~/.aws/credentials`)


## Setup Instructions

### 1. Clone the repository

```bash
git clone https://github.com/GoStop41/abridge-test-infra.git>
cd abridge-test-infra/terraform
```

### 2. Initialize Terraform State Storage (One-Time Setup)
```
cd tf-init
terraform plan -var-file=../tfvars/tf-init/tf-init-dev.tfvars -state=../tfvars/tf-init/terraform-dev.tfstate

terraform apply -var-file=../tfvars/tf-init/tf-init-dev.tfvars -state=../tfvars/tf-init/terraform-dev.tfstate
```

This step sets up the remote state backend (S3) and state locking (DynamoDB).

### 3. Bootstrap Base Infrastructure
Navigate to backend_base, which provisions VPC, EKS, KMS, and IRSA roles:
```
cd ../backend_base
terraform init
terraform plan -var-file=../tfvars/backend_base/base-dev.tfvars
terraform apply -var-file=../tfvars/backend_base/base-dev.tfvars
```

Ensure the backend_base uses the remote backend created in the previous step.

### 4. (Optional) Apply Additional Backends
If using backend_additional:
```
cd ../backend_additional
terraform init
terraform apply -var-file=../tfvars/backend_additional/<your-env>.tfvars
```

Module Details<br>
Each module in https://github.com/GoStop41/abridge-test-modules/ is designed for reuse

Module  Purpose from https://github.com/GoStop41/abridge-test-modules/<br>
m-vpc   Creates a custom VPC<br>
m-kms-key   Provisions KMS keys<br>
m-tfstate   Sets up S3 & DynamoDB for tfstate<br>
m-irsa  Configures IAM Roles for Service Accounts<br>
m-eks   (if exists) Deploys EKS cluster<br>


Notes
```
Each environment (e.g., dev/staging/prod) should have its own *.tfvars in the tfvars/ directory.

Always run terraform plan before applying changes.
```

Cleanup
To destroy resources (be cautious):
```
terraform destroy -var-file=../tfvars/<file>.tfvars
```
