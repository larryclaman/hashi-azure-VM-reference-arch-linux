data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                = "${var.name}-kv"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id

  sku_name = "standard"


  purge_protection_enabled = false
  /*  // for now, let's make it public
   public_network_access_enabled = false  
  
  network_acls {
    virtual_network_subnet_ids = [var.subnetids]
    default_action             = "Deny"
  }

*/

}

resource "azurerm_key_vault_access_policy" "kvpolicy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get", "Set", "List", "Delete"
  ]
}