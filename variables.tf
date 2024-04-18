variable "customers" {
  type = map(object({
    short_name = string,
    long_name  = string,
    tags       = map(string)
  }))
  default = {
    c1 = {
      short_name = "Cust1"
      long_name  = "Customer One"
      tags = {
        "costcenter"             = "12345"
        "environment"            = "dev"
        "inconsistent-tag-count" = "just-fine"
      },
    },
    # c2 = {
    #   short_name = "Cust2"
    #   long_name  = "Customer Two"
    #   tags = {
    #     "costcenter"  = "67890"
    #     "environment" = "prod"
    #   },
    # },
    # c3 = {
    #   short_name = "Cust3"
    #   long_name  = "Customer Three"
    #   tags = {
    #     "costcenter"  = "13579"
    #     "environment" = "dev"
    #   },
    # },
  }
}

variable "password" {
  type        = string
  description = "Password value taken from local machine env variable"
}

variable "resource_group_location" {
  default     = "centralus"
  description = "Location of the resource group."
}

#Upfront machine admins
variable "avd_admins" {
  description = "Azure Virtual Desktop Admins"
  default = [
    "jlaing_admin@upfronthealthcare.com",
    "adminthanasi@upfronthealthcare.com",
    "adminjpatel@upfronthealthcare.com"
  ]
}