variable "basic_auth_user" {
  description = "The username for basic auth"
  type        = string
  sensitive   = true
}

variable "basic_auth_password" {
  description = "The password for basic auth"
  type        = string
  sensitive   = true
}

variable "cliniquita_app_port" {
  description = "The port the app is running on"
  type        = number
  default     = 3000
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Public Subnet CIDR values"
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "azs" {
  type        = list(string)
  description = "Availability Zones"
  default     = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
}

variable "aws_region" {
  type        = string
  description = "AWS Region"
  default     = "eu-west-2"
}

variable "ELB_account_id" {
  type        = string
  description = "ELB Account ID for the AWS region where the ELB is created"
  default     = "652711504416"
}

variable "ecs_container_cpu" {
  type        = number
  description = "The number of cpu units to reserve for the container"
  default     = 256
}

variable "ecs_container_memory" {
  type        = number
  description = "The amount (in MiB) of memory to present to the container"
  default     = 512
}

variable "ecs_container_count" {
  type        = number
  description = "The number of instances of the task definition to place and keep running"
  default     = 2
}
