variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "cluster_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "dhakacart-k8s"
}

variable "bastion_instance_type" {
  description = "EC2 instance type for bastion"
  type        = string
  default     = "t3.medium"
}

variable "master_instance_type" {
  description = "EC2 instance type for master nodes"
  type        = string
  default     = "t3.medium"
}

variable "worker_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "master_count" {
  description = "Number of master nodes"
  type        = number
  default     = 2
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 3
}

