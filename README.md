These Terraform scripts are free to use, and intended to demonstrate the generation of "ethically walled", secure work environments that isolate customer networks in a multi-tenant environment, using Azure Virtual Desktops with access centrally controlled using Entra ID.

These configuration files use the technique of [for_each](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each) where an input variable is declared using an [object](https://developer.hashicorp.com/terraform/language/expressions/type-constraints#object) map to define attributes that are specific to each customer silo.

See the [variables.tf](https://github.com/JamieLaing/EthicalWalledAvd/blob/main/variables.tf) file for more info.

Also note that the local machine password is stored in an environment variable, check out [this article](https://support.hashicorp.com/hc/en-us/articles/4547786359571-Reading-and-using-environment-variables-in-Terraform-runs).  To apply the value in linux, and assuming you are using VS code for IDE, use "export TF_VAR_password=+EnterValueHere+" to set the variable.
