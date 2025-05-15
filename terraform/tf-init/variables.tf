variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "terraform_parent_role" {
  type = string
}

variable "cicd_devops_role_name" {
  type        = string
  description = "cicd devops role name"
}

variable "additional_admin_roles" {
  type        = list(string)
  description = "Additional role ARNs to allow to assume the CICD Devops role"
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to created resources."
}