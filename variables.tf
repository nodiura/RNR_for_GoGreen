variable "desired_web_instances" {
  default = 2
}
variable "desired_app_instances" {
  default = 2
}
variable "desired_DB_instances" {
  default = 2
}
variable "prefix" {
  description = "Prefix for resource names"
  default     = "GoGreen"
}
# Variable Declarations
variable "environment" {
  description = "The environment of the deployment (e.g., dev, stage, prod)"
  type        = string
  default     = "dev"
}
