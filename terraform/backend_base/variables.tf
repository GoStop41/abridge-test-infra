variable "region" {
  type = string
}

variable "product" {
  type = string
}

variable "environment" {
  type        = string
  description = "The name of the environment, i.e. int-us, int-eu, qa-eu, prod-jp ... etc."
}

variable "eks_cluster_version" {
  type        = string
  default     = "1.32"
}

variable "eks_node_ami_name" {
  type = string
  default = "amazon-eks-node-1.32-v20250501"
}

variable "vpc_cidr" {
  type = string
  default = "10.0.0.0/16"
}

variable "assume_role_arn" {
  type = string
}

variable "devops_admin_role" {
  type = string
}

variable "devops_admin_name" {
  type = string
}

variable "node_group_max_size" {
  type = number
  default = 5
}

variable "node_group_min_size" {
  type = number
  default = 3
}

variable "node_group_desired_size" {
  type = number
  default = 3
}

variable "instance_types" {
  type = list(string)
  default = ["m6i.large", "m5.large", "m5n.large", "m5zn.large"]
}

variable "eks_ebs_node_volume" {
  type = object({
    size           = optional(string, "20Gi")
    type           = optional(string, "gp3")
    iops           = optional(number, 3000)
    throughput     = optional(number, 125)
  })
}

