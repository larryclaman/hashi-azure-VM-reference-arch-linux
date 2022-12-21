# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used



terraform {
  cloud {
    organization = "larryclaman"
    workspaces {
      # This will choose all workspaces with this tag.  
      # You will need to subsequently select the workspace for the run, eg 'terraform workspace select prod'
      # or you will need to set the TF_WORKSPACE env variable
      tags = ["azure-vm-ref-arch"]
    }
  }



  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.26.0"
    }
    # random = {
    #   source  = "hashicorp/random"
    #   version = "~>3.0"
    # }
  }
}


provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = false
    }
  }
}

data "azurerm_client_config" "current" {}


resource "random_pet" "name" {
  prefix = var.resource_group_name_prefix
  length = 1
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "dbpassword" {
  length  = 16
  special = false
  # override_special = "!#$%&*()-_=+[]{}<>:?"
}

######################################
# Create Resource Group.
######################################

resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = var.resource_group_name
}

######################################
# Create networks
######################################

module "networks" {
  source                  = "./modules/networks"
  name                    = random_pet.name.id
  resource_group_location = var.resource_group_location
  resource_group_name     = azurerm_resource_group.rg.name
  remote_vnet             = module.bastion-host.bastion-vnet
  remote_vnet_name        = module.bastion-host.bastion-vnet-name
}

######################################
# Create Bastion Host
######################################

module "bastion-host" {
  source                  = "./modules/management_tools"
  name                    = random_pet.name.id
  resource_group_location = var.resource_group_location
  resource_group_name     = azurerm_resource_group.rg.name
}

######################################
# Create app_gateway
######################################

module "app-gateway" {
  source                  = "./modules/app_gateway"
  name                    = random_pet.name.id
  resource_group_location = var.resource_group_location
  resource_group_name     = azurerm_resource_group.rg.name
  app_gtw_sub             = module.networks.subnet-appgtw
  app_gtw_ip              = module.networks.app-gtw-ip
}

######################################
# Create private load_balancer
######################################

module "load_balancer" {
  source                  = "./modules/load_balancer"
  name                    = random_pet.name.id
  resource_group_location = var.resource_group_location
  resource_group_name     = azurerm_resource_group.rg.name
  lb_sub                  = module.networks.subnet-web
}

######################################
# Create web scale set
######################################

module "web-vmss" {
  source                   = "./modules/vmss"
  name                     = "${random_pet.name.id}-web"
  location                 = var.resource_group_location
  resource_group_name      = azurerm_resource_group.rg.name
  scale_set_sub            = module.networks.subnet-web
  type                     = "web"
  app_gty_backend_pool_ids = module.app-gateway.app_gateway.backend_address_pool[*].id
  admin_user               = var.admin_user
  admin_password           = random_password.password.bcrypt_hash
  # app provisioning
  custom_data = base64encode(templatefile("app/webinit.tmpl", {
    api_private_ip = module.load_balancer.mid_tier_lb.private_ip_address,
    web_image      = var.web_image
    }
  ))
}

######################################
# Create biz scale set
######################################
module "api-vmss" {
  source              = "./modules/vmss"
  name                = "${random_pet.name.id}-api"
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.rg.name
  scale_set_sub       = module.networks.subnet-api
  type                = "api"
  lb_backend_pool_ids = module.load_balancer.lb_pool_ids
  admin_user          = var.admin_user
  admin_password      = random_password.password.bcrypt_hash
  # app provisioning
  custom_data = base64encode(templatefile("app/apiinit.tmpl", {
    api_image       = var.api_image,
    sql_server_fqdn = module.db_SQLSERVER.sqlserver-fqdn,
    sql_username    = var.sqladmin,
    sql_password    = random_password.dbpassword.result
    }
  ))
}

######################################
# Create Database.
######################################
# module "db_MySQL" {
#   source                  = "./modules/COSMOSDB"
#   name                    = random_pet.name.id
#   resource_group_location = var.resource_group_location
#   resource_group_name     = azurerm_resource_group.rg.name
#   throughput              = 400
#   data_tier_sub_id        = module.networks.subnet-data
#   ip_range_filter         = "0.0.0.0"
# }
module "db_SQLSERVER" {
  source              = "./modules/SQLSERVER"
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.rg.name
  servername          = random_pet.name.id
  dbname              = var.dbname
  adminlogin          = var.sqladmin
  adminpwd            = random_password.dbpassword.result
  apisubnetid         = module.networks.api-subnet
}

##### 
# Create Keyvault and store secrets in it
#####
# module "kv" {
#   source              = "./modules/keyvault"
#   name                = random_pet.name.id
#   location            = var.resource_group_location
#   resource_group_name = azurerm_resource_group.rg.name
#   // tenant_id           = data.azurerm_client_config.current.tenant_id
# }

resource "azurerm_key_vault" "kv" {
  name                     = "${random_pet.name.id}-kv"
  location                 = var.resource_group_location
  resource_group_name      = var.resource_group_name
  tenant_id                = data.azurerm_client_config.current.tenant_id
  sku_name                 = "standard"
  purge_protection_enabled = false
}

resource "azurerm_key_vault_access_policy" "kvpolicy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get", "Set", "List", "Delete", "Purge", "Recover"
  ]
  lifecycle {
    ignore_changes = [
      secret_permissions
    ]
  }
}
resource "azurerm_key_vault_secret" "vmcred" {
  name         = "vmcred"
  value        = random_password.password.bcrypt_hash
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [
    resource.azurerm_key_vault_access_policy.kvpolicy
  ]
}
resource "azurerm_key_vault_secret" "dbcred" {
  name         = "dbcred"
  value        = random_password.dbpassword.result
  key_vault_id = azurerm_key_vault.kv.id
  depends_on = [
    azurerm_key_vault_access_policy.kvpolicy
  ]
}