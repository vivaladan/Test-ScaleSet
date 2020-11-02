terraform {
}

provider "azurerm" {
  version = "~> 2.34.0"
  features {}
}

resource "azurerm_resource_group" "app" {
  name     = "Test-ScaleSet"
  location = "North Europe"
}

resource "azurerm_virtual_network" "app" {
  name                = "Test-ScaleSet-vnet"
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "app" {
  name                 = "public"
  resource_group_name  = azurerm_resource_group.app.name
  virtual_network_name = azurerm_virtual_network.app.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "app" {
  name                    = "Test-ScaleSet-public-ip"
  resource_group_name     = azurerm_resource_group.app.name
  location                = azurerm_resource_group.app.location
  allocation_method       = "Dynamic"
  idle_timeout_in_minutes = 30
}

resource "azurerm_lb" "app" {
  name                = "Test-ScaleSet-lb"
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.app.id
  }
}

resource "azurerm_lb_backend_address_pool" "app" {
  name                = "BackEndAddressPool"
  resource_group_name = azurerm_resource_group.app.name
  loadbalancer_id     = azurerm_lb.app.id
}

resource "azurerm_lb_probe" "app" {
  name                = "httpProbe"
  resource_group_name = azurerm_resource_group.app.name
  loadbalancer_id     = azurerm_lb.app.id
  port                = 80

  depends_on = [azurerm_lb.app]
}

resource "azurerm_lb_rule" "app" {
  name                           = "http"
  resource_group_name            = azurerm_resource_group.app.name
  loadbalancer_id                = azurerm_lb.app.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  backend_address_pool_id        = azurerm_lb_backend_address_pool.app.id
  frontend_ip_configuration_name = "PublicIPAddress"
  probe_id                       = azurerm_lb_probe.app.id
}

resource "azurerm_linux_virtual_machine_scale_set" "app" {
  name                            = "Test-ScaleSet-vmss"
  resource_group_name             = azurerm_resource_group.app.name
  location                        = azurerm_resource_group.app.location
  sku                             = "Standard_B1s"
  instances                       = 1
  admin_username                  = "azureuser"
  admin_password                  = "12letmeiN!"
  disable_password_authentication = false
  health_probe_id                 = azurerm_lb_probe.app.id
  upgrade_mode                    = "Automatic"

  automatic_os_upgrade_policy {
    disable_automatic_rollback  = false
    enable_automatic_os_upgrade = true
  }

  rolling_upgrade_policy {
    max_batch_instance_percent              = 30
    max_unhealthy_instance_percent          = 30
    max_unhealthy_upgraded_instance_percent = 30
    pause_time_between_batches              = "PT30S"
  }

  //  admin_ssh_key {
  //    username   = "azureuser"
  //    public_key = file("~/.ssh/id_rsa.pub")
  //  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "nic"
    primary = true

    ip_configuration {
      name                                   = "public"
      primary                                = true
      subnet_id                              = azurerm_subnet.app.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.app.id]
    }
  }

  depends_on = [azurerm_lb_probe.app, azurerm_lb.app]
}

# resource "azurerm_virtual_machine_scale_set_extension" "example" {
#   name                         = basename(var.deploy_script)
#   virtual_machine_scale_set_id = azurerm_linux_virtual_machine_scale_set.app.id
#   publisher                    = "Microsoft.Azure.Extensions"
#   type                         = "CustomScript"
#   type_handler_version         = "2.0"
#   settings = jsonencode({
#     "fileUris" : [
#       var.deploy_script,
#       var.deploy_package
#     ],
#     "commandToExecute" : "./${basename(var.deploy_script)}"
#   })
# }

locals {
  version = timestamp()
}

resource "azurerm_virtual_machine_scale_set_extension" "app" {
  name                         = "Test-ScaleSet-Extension1"
  virtual_machine_scale_set_id = azurerm_linux_virtual_machine_scale_set.app.id
  publisher                    = "Microsoft.Azure.Extensions"
  type                         = "CustomScript"
  type_handler_version         = "2.0"
  force_update_tag             = local.version
  settings = jsonencode({
    "fileUris" : [
      "https://raw.githubusercontent.com/vivaladan/Test-ScaleSet/main/automate_nginx.sh"
    ],
    "commandToExecute" : "bash automate_nginx.sh ${local.version}"
  })
}

output "ip_address" {
  value = azurerm_public_ip.app.ip_address
}

output "timestamp" {
  value = local.version
}