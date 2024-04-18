#Create a single resource group for all resources
resource "azurerm_resource_group" "sh" {
  name     = "EthicallyWalledGarden"
  location = var.resource_group_location
}

data "azurerm_role_definition" "roleDVU" { # access an existing built-in role
  name = "Desktop Virtualization User"
}

data "azurerm_role_definition" "roleVMUL" { # access an existing built-in role
  name = "Virtual Machine User Login"
}

data "azurerm_role_definition" "roleDVA" { # access an existing built-in role
  name = "Virtual Machine Administrator Login"
}

data "azuread_user" "aad_admins_list" {
  for_each            = toset(var.avd_admins)
  user_principal_name = format("%s", each.key)
}

#Create virtual desktop administrators group
resource "azuread_group" "aad_group_admin" {
  display_name     = "demo-avd-admins"
  security_enabled = true
}

#assign the AVD role to the administrators group
resource "azurerm_role_assignment" "role_admin" {
  scope              = azurerm_resource_group.sh.id
  role_definition_id = data.azurerm_role_definition.roleDVA.id
  principal_id       = azuread_group.aad_group_admin.id
}

#Add users to the admin group by email address
resource "azuread_group_member" "aad_avd_admins" {
  for_each         = data.azuread_user.aad_admins_list
  group_object_id  = azuread_group.aad_group_admin.id
  member_object_id = each.value["id"]
}

#create one azuread group per customer
resource "azuread_group" "aad_group" {
  for_each         = var.customers
  display_name     = "demo-${each.value.short_name}-AVD-Group"
  security_enabled = true
}

#assign the AVD role to each group
resource "azurerm_role_assignment" "role" {
  for_each           = var.customers
  scope              = azurerm_virtual_desktop_application_group.dag[each.key].id
  role_definition_id = data.azurerm_role_definition.roleDVU.id
  principal_id       = azuread_group.aad_group[each.key].id
}

#assign the VMUL role to each group
resource "azurerm_role_assignment" "role_VMUL" {
  for_each           = var.customers
  scope              = azurerm_resource_group.sh.id
  role_definition_id = data.azurerm_role_definition.roleVMUL.id
  principal_id       = azuread_group.aad_group[each.key].id
}

# Create a virtual network for all VMs
resource "azurerm_virtual_network" "vnet" {
  address_space       = ["13.250.0.0/16"]
  location            = "centralus"
  name                = "Walled-Garden-VNet"
  resource_group_name = azurerm_resource_group.sh.name
  depends_on = [
    azurerm_resource_group.sh
  ]
}

# Create a subnet for all VMs
resource "azurerm_subnet" "subnet" {
  address_prefixes     = ["13.250.0.0/24"]
  name                 = "default"
  resource_group_name  = azurerm_resource_group.sh.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  depends_on = [
    azurerm_virtual_network.vnet
  ]
}

# Create an AVD host pool for each customer
resource "azurerm_virtual_desktop_host_pool" "hostpool" {
  for_each                 = var.customers
  name                     = "${each.value.short_name}-HostPool"
  friendly_name            = each.value.long_name
  resource_group_name      = azurerm_resource_group.sh.name
  location                 = azurerm_resource_group.sh.location
  custom_rdp_properties    = "drivestoredirect:s:*;audiomode:i:0;videoplaybackmode:i:1;redirectclipboard:i:1;redirectprinters:i:1;devicestoredirect:s:*;redirectcomports:i:1;redirectsmartcards:i:1;usbdevicestoredirect:s:*;enablecredsspsupport:i:0;redirectwebauthn:i:1;use multimon:i:1;enablerdsaadauth:i:1;"
  description              = "${each.value.long_name} Host Pool created by Terraform"
  type                     = "Pooled"
  load_balancer_type       = "DepthFirst"
  maximum_sessions_allowed = 5
  #TODO: is this variable causing an issue?
  start_vm_on_connect      = true
  tags                     = each.value.tags
}

# Create AVD host pool registration info for each host pool
resource "azurerm_virtual_desktop_host_pool_registration_info" "hostpool-info" {
  for_each        = var.customers
  hostpool_id     = azurerm_virtual_desktop_host_pool.hostpool[each.key].id
  expiration_date = timeadd(timestamp(), "24h")
}

# Create AVD Desktop Application Group for each customer
resource "azurerm_virtual_desktop_application_group" "dag" {
  for_each                     = var.customers
  name                         = "${each.value.short_name}-DAG"
  friendly_name                = "${each.value.long_name} Desktop"
  resource_group_name          = azurerm_resource_group.sh.name
  default_desktop_display_name = "${each.value.long_name} Win11"
  host_pool_id                 = azurerm_virtual_desktop_host_pool.hostpool[each.key].id
  location                     = azurerm_resource_group.sh.location
  type                         = "Desktop"
  description                  = "Desktop Application Group created by Terraform for ${each.value.long_name}"
  tags = {
    cm-resource-parent = azurerm_virtual_desktop_host_pool.hostpool[each.key].id
  }
  depends_on = [
    azurerm_virtual_desktop_host_pool.hostpool
  ]
}

# Create AVD workspace for each customer
resource "azurerm_virtual_desktop_workspace" "workspace" {
  for_each            = var.customers
  name                = "${each.value.short_name}-Workspace"
  resource_group_name = azurerm_resource_group.sh.name
  location            = azurerm_resource_group.sh.location
  friendly_name       = "${each.value.long_name} Workspace"
  description         = "Workspace used for ${each.value.long_name}"
  tags                = each.value.tags
  depends_on = [
    azurerm_resource_group.sh
  ]
}

# Associate Workspaces and DAGs
resource "azurerm_virtual_desktop_workspace_application_group_association" "ws-dag" {
  for_each             = var.customers
  application_group_id = azurerm_virtual_desktop_application_group.dag[each.key].id
  workspace_id         = azurerm_virtual_desktop_workspace.workspace[each.key].id
  depends_on = [
    azurerm_virtual_desktop_application_group.dag,
    azurerm_virtual_desktop_workspace.workspace
  ]
}

#Create a virtual machine for each customer
resource "azurerm_windows_virtual_machine" "vm" {
  for_each            = var.customers
  name                = "${each.value.short_name}-VM"
  resource_group_name = azurerm_resource_group.sh.name
  location            = azurerm_resource_group.sh.location
  license_type        = "Windows_Client"
  size                = "Standard_D2s_v3"
  admin_username      = "LocalAdmin"
  admin_password      = var.password
  network_interface_ids = [
    azurerm_network_interface.nic[each.key].id
  ]
  provision_vm_agent = true
  tags = {
    cm-resource-parent = azurerm_virtual_desktop_host_pool.hostpool[each.key].id
  }
  identity {
    type = "SystemAssigned"
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }
  source_image_reference {
    offer     = "windows-10"
    publisher = "microsoftwindowsdesktop"
    sku       = "win10-22h2-avd-g2"
    version   = "latest"
  }
  depends_on = [
    azurerm_subnet.subnet
  ]
}

# Create a network interface for each VM
resource "azurerm_network_interface" "nic" {
  for_each            = var.customers
  name                = "${each.value.short_name}-NIC"
  location            = azurerm_resource_group.sh.location
  resource_group_name = azurerm_resource_group.sh.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = {
    cm-resource-parent = azurerm_virtual_desktop_host_pool.hostpool[each.key].id
  }
  depends_on = [
    azurerm_subnet.subnet
  ]
}

#Enable AAD Login for each VM
resource "azurerm_virtual_machine_extension" "vmext_aadlogin" {
  for_each             = var.customers
  auto_upgrade_minor_version = true
  name                 = "AADLoginForWindows"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm[each.key].id
  publisher            = "Microsoft.Azure.ActiveDirectory"
  type                 = "AADLoginForWindows"
  type_handler_version = "2.0"
  depends_on = [ azurerm_windows_virtual_machine.vm ]
}

#Enable DSC for each VM
resource "azurerm_virtual_machine_extension" "vmext_dsc" {
  for_each                   = var.customers
  auto_upgrade_minor_version = true
  name                       = "Microsoft.PowerShell.DSC"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm[each.key].id
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.73"
  settings                   = <<-SETTINGS
    {
      "configurationFunction": "Configuration.ps1\\AddSessionHost",
      "modulesUrl": "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1.0.02507.246.zip",
      "properties": {
        "UseAgentDownloadEndpoint":true,
        "aadJoin":true,
        "aadJoinPreview":false,
        "HostPoolName":"${azurerm_virtual_desktop_host_pool.hostpool[each.key].name}"
      }
    }
  SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
    {
      "properties": {
        "registrationInfoToken": "${azurerm_virtual_desktop_host_pool_registration_info.hostpool-info[each.key].token}"
      }
    }
  PROTECTED_SETTINGS

  depends_on = [
    azurerm_windows_virtual_machine.vm
  ]
}

#enable Azure Defender for each VM
resource "azurerm_virtual_machine_extension" "vmext_defender" {
  for_each                   = var.customers
  auto_upgrade_minor_version = true
  name                       = "MDE.Windows"
  publisher                  = "Microsoft.Azure.AzureDefenderForServers"
  type                       = "MDE.Windows"
  type_handler_version       = "1.0"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm[each.key].id
  depends_on = [azurerm_windows_virtual_machine.vm]
}

resource "azurerm_virtual_machine_extension" "APFW" {
  for_each                   = var.customers
  auto_upgrade_minor_version = true
  name                       = "AzurePolicyforWindows"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm[each.key].id
  publisher                  = "Microsoft.GuestConfiguration"
  type                       = "ConfigurationForWindows"
  type_handler_version       = "1.1"
  #add depends on for the virtual machine
  depends_on = [azurerm_windows_virtual_machine.vm]
}