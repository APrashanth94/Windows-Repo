resource "azurerm_resource_group" "CUR_Win_resourcegroup" {
  count    = length(local.csv_data)
  name     = local.format_csv_data[count.index].resourcegroup
  location = local.csv_data[count.index].location

   /*provisioner "local-exec" {
    command = "echo Resource Group: ${local.format_csv_data[count.index].resourcegroup} Location: ${local.csv_data[count.index].location}"
  }*/
}

resource "azurerm_network_security_group" "CUR_Win_NSG" {
  for_each            = local.format_csv_data_map
  name                = each.value.nsgName
  location            = each.value.location
  resource_group_name = azurerm_resource_group.CUR_Win_resourcegroup[each.key].name

    
  dynamic "security_rule" {
     for_each = each.value.nsg_rules
     
    content {
      name                       = security_rule.value.rdpRuleName
      priority                   = security_rule.value.priority
      direction                  = "Inbound"
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.sourcePortRange
      destination_port_range     = security_rule.value.destinationPortRange
      source_address_prefix      = security_rule.value.sourceAddressPrefix
      destination_address_prefix = security_rule.value.destinationAddressPrefix
    }
  } 
}

resource "azurerm_virtual_network" "CUR_Win_Vnetwork" {
  count            = length(local.csv_data)
  name             = local.csv_data[count.index].virtualNetworkName
  location         = azurerm_resource_group.CUR_Win_resourcegroup[count.index].location
  resource_group_name = azurerm_resource_group.CUR_Win_resourcegroup[count.index].name
  address_space    = [local.csv_data[count.index].vnetAddressPrefixes]
}

resource "azurerm_subnet" "CUR_Win_Subnet" {
  count              = length(local.csv_data)
  name               = local.csv_data[count.index].subnetName
  resource_group_name = azurerm_resource_group.CUR_Win_resourcegroup[count.index].name
  virtual_network_name = azurerm_virtual_network.CUR_Win_Vnetwork[count.index].name
  address_prefixes   = [local.csv_data[count.index].snetAddressPrefixes]
}


resource "azurerm_network_interface" "CUR_Win_Network_Interface" {
  count             = length(local.csv_data)
  name              = local.csv_data[count.index].nicName
  location          = azurerm_resource_group.CUR_Win_resourcegroup[count.index].location
  resource_group_name = azurerm_resource_group.CUR_Win_resourcegroup[count.index].name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.CUR_Win_Subnet[count.index].id
    private_ip_address_allocation = local.csv_data[count.index].privateIPAllocationMethod
    private_ip_address            = local.csv_data[count.index].privateIPv4Address
  }

}

resource "random_id" "storage_account_id" {
  count      = length(local.csv_data)
  byte_length = 8
  prefix     = "diag"
  
}

resource "azurerm_storage_account" "storage_account" {
  count                     = length(local.csv_data)
  name                      = "${random_id.storage_account_id[count.index].hex}"
  resource_group_name       = azurerm_resource_group.CUR_Win_resourcegroup[count.index].name
  location                  = local.csv_data[count.index].location
  account_tier              = "Standard"
  account_replication_type  = "LRS"
}

 
resource "azurerm_virtual_machine" "CUR_Win_VM" {
  count                = length(local.csv_data)
  name                 = local.csv_data[count.index].virtualMachineName
  location             = local.csv_data[count.index].location
  resource_group_name  = azurerm_resource_group.CUR_Win_resourcegroup[count.index].name
  network_interface_ids = [azurerm_network_interface.CUR_Win_Network_Interface[count.index].id]
  vm_size              = local.csv_data[count.index].virtualMachineSize
   
 
    delete_os_disk_on_termination = true
    os_profile {
    computer_name  = local.csv_data[count.index].virtualMachineName
    admin_username = local.csv_data[count.index].adminUsername
    admin_password = local.csv_data[count.index].adminPassword

  }

  os_profile_windows_config {
    provision_vm_agent = true
  }

   storage_image_reference {
    publisher = local.csv_data[count.index].osImagePublisher
    offer     = local.csv_data[count.index].osOffer
    sku       = local.csv_data[count.index].osSKU
    version   = local.csv_data[count.index].oSVersion
  }

  storage_os_disk {
    name              = local.csv_data[count.index].osDiskName
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = local.csv_data[count.index].osDiskType
  }
}

output "resource_group_names" {
  value = [for rg in azurerm_resource_group.CUR_Win_resourcegroup : rg.name]
}

output "nsg_names" {
  value = [for nsg in azurerm_network_security_group.CUR_Win_NSG : nsg.name]
}