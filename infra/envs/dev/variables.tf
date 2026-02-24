variable "region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
    description = "Name of the project to be used in resource naming"
    type        = string
    default     = "my-project"
}