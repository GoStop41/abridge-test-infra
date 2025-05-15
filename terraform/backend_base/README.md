# Requirements:
* terraform version: 1.5.7
* Ensure the aws access credentials configured on your local env.
```
export AWS_ACCESS_KEY_ID=......
export AWS_SECRET_ACCESS_KEY=......
export AWS_SESSION_TOKEN=......
```


## Terraform apply:
```
terraform init -backend-config=../tfvars/backend_base/backend-dev.tfvars

terraform validate

terraform plan -var-file=../tfvars/backend_base/base-dev.tfvars

terraform apply -var-file=../tfvars/backend_base/base-dev.tfvars
```

### A note on networking.

This Terraform configuration provisions a highly customizable AWS VPC, allowing control over the number and structure of public, private, and isolated subnets. It supports flexible CIDR allocation using bitwise operations.

## Features

- Modular VPC configuration
- Subnet tiering with public, private, and isolated types
- Deterministic subnet CIDRs via `newbits` and `netnum_shift_map`
- Equal subnet distribution across availability zones

---

## 📦 Inputs

The default VPC CIDR is 10.0.0.0/16 and can be changed by vpc_cidr variable

## `newbits`

Determines the number of additional bits to "borrow" from the base CIDR block to define subnets for each tier.

Example:
```
newbits = {
  public   = "5"
  private  = "4"
  isolated = "5"
}
```
The subnet mask for each tier will be calculated as follows: public-/21, private-/20, isolated-/21.

## `subnet_map`

Specifies how many subnets of each type should be created.

Example:
```
subnet_map = {
  public   = "3"
  private  = "3"
  isolated = "3"
}
```

## `netnum_shift_map`
Used to calculate the starting point (netnum) for subnet CIDR derivation. Helps prevent overlapping CIDRs between subnet tiers.

Example:
```
netnum_shift_map = {
  public   = "0"
  private  = "6"
  isolated = "18"
}
```
The starting point for each subnet tier will be calculated as follows: public-10.0.0.0/21(followed by 10.0.8.0/21 and 10.0.16.0/21), private-10.0.96.0/20(followed by 10.0.128.0/20 and 10.0.112.0/20), isolated-10.0.144.0/21(followed by 10.0.152.0/21 and 10.0.160.0/21)







