# Input variables for the EMR Serverless stack.
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "emr-serverless"
}

variable "emr_release_label" {
  description = "EMR release label for EMR Serverless"
  type        = string
  default     = "emr-7.8.0"
}

variable "emr_serverless" {
  description = "EMR Serverless application: type, architecture, driver/executor capacity, and max capacity"
  type = object({
    application_type = string
    architecture     = string
    driver = object({
      worker_count = number
      cpu          = string
      memory       = string
      disk         = string
    })
    executor = object({
      worker_count = number
      cpu          = string
      memory       = string
      disk         = string
    })
    maximum_capacity = object({
      cpu    = string
      memory = string
      disk   = string
    })
    auto_stop_idle_minutes = number
  })
  default = {
    application_type = "Spark"
    architecture     = "X86_64"
    driver = {
      worker_count = 1
      cpu          = "1 vCPU"
      memory       = "2 GB"
      disk         = "20 GB"
    }
    executor = {
      worker_count = 2
      cpu          = "1 vCPU"
      memory       = "2 GB"
      disk         = "20 GB"
    }
    maximum_capacity = {
      cpu    = "4 vCPU"
      memory = "8 GB"
      disk   = "100 GB"
    }
    auto_stop_idle_minutes = 15
  }
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default = {
    Project   = "aws-labs"
    ManagedBy = "Terraform"
  }
}
