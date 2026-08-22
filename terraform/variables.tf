variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS deployment region"
}

variable "db_username" {
  type        = string
  default     = "nimbususer"
  description = "Database master username"
}

variable "db_password" {
  type        = string
  default     = "NimbusPass123!"
  sensitive   = true
  description = "Database master password"
}

variable "key_name" {
  type        = string
  default     = "Testing"
  description = "Name of an existing AWS SSH KeyPair (optional)"
}

variable "api_docker_image" {
  type        = string
  default     = "python:3.10-slim" # Replace with your ECR or Docker Hub API image URI
  description = "Docker image for the App Tier API"
}