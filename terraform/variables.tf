variable "aws_region" {
  type        = string
  description = "The target AWS region for all provisioned infrastructure."
  default     = ""
}

variable "environment" {
  type        = string
  description = "Deployment environment name, used to prefix and tag resources."
  default     = "production"
}

variable "container_image" {
  type        = string
  description = "The URI of the Docker container image in ECR. Left empty during bootstrapping."
  default     = ""
}
