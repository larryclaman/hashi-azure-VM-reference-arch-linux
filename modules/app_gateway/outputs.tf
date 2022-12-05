output "app_gateway" {
  value = azurerm_application_gateway.network
}
# output "app_gateway_backendpool" {
#   value = azurerm_application_gateway.backend_address_pool[*].id
# }