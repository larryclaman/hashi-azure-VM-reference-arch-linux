######################################
# Create scale_set tier scale set
######################################

# Accept terms
resource "azurerm_marketplace_agreement" "flatcar" {
  publisher = "kinvolk"
  offer     = "flatcar-container-linux-free"
  plan      = "stable-gen2"
}


resource "azurerm_linux_virtual_machine_scale_set" "scale_set" {
  name                            = "${var.name}-vmss"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  sku                             = "Standard_D2a_v4"
  instances                       = 3
  admin_username                  = var.admin_user
  admin_password                  = var.admin_password
  disable_password_authentication = false
  custom_data                     = var.custom_data

  boot_diagnostics {
    storage_account_uri = ""
  }

  source_image_reference {
    publisher = "kinvolk"
    offer     = "flatcar-container-linux-free"
    sku       = "stable-gen2"
    version   = "latest"
  }

  plan {
    name      = "stable-gen2"
    product   = "flatcar-container-linux-free"
    publisher = "kinvolk"
  }

  network_interface {
    name    = "${var.name}-network-int"
    primary = true

    dynamic "ip_configuration" {
     for_each = (var.type == "web") ? [1] : []
      content {
        name                                         = "internal-appgw"
        primary                                      = true
        subnet_id                                    = var.scale_set_sub
      application_gateway_backend_address_pool_ids = var.app_gty_backend_pool_ids
      }
    }

    dynamic "ip_configuration" {
      for_each = (var.type == "api") ? [1] : []
      content {
        name                                   = "internal-lb"
        primary                                = true
        subnet_id                              = var.scale_set_sub
        load_balancer_backend_address_pool_ids = [var.lb_backend_pool_ids]
      }
    }


  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  # Since these can change via auto-scaling outside of Terraform,
  # let's ignore any changes to the number of instances
  lifecycle {
    ignore_changes = [instances]
  }
}

resource "azurerm_monitor_autoscale_setting" "web_scale_set_mon" {
  name                = "${var.name}-autoscale-config"
  resource_group_name = var.resource_group_name
  location            = var.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.scale_set.id

  profile {
    name = "WebAutoScale"

    capacity {
      default = 1
      minimum = 1
      maximum = 5
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.scale_set.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.scale_set.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }
}