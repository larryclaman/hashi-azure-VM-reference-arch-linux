output "Net-vm-ref-arch" {
  value = azurerm_virtual_network.vm-ref-arch
}

output "subnet-appgtw" {
  value = azurerm_subnet.app_gateway_sub.id
}

output "subnet-mgmt" {
  value = azurerm_subnet.mgmt_sub.id
}

output "subnet-web" {
  value = azurerm_subnet.web_tier_sub.id
}


output "subnet-api" {
  value = azurerm_subnet.biz_tier_sub.id
}



output "api-subnet" {
  value = azurerm_subnet.biz_tier_sub.id
}

output "subnet-data" {
  value = azurerm_subnet.data_tier_sub.id
}

output "appgw-nsg" {
  value = azurerm_network_security_group.appgw
}

output "mgmt-nsg" {
  value = azurerm_network_security_group.mgmt
}

output "web-nsg" {
  value = azurerm_network_security_group.web
}

output "api-nsg" {
  value = azurerm_network_security_group.api
}

output "data-nsg" {
  value = azurerm_network_security_group.data
}

output "app-gtw-ip" {
  value = azurerm_public_ip.app-gateway.id
}

output "app-gtw-domainname" {
  value = azurerm_public_ip.app-gateway.domain_name_label
}

# output "private_dns_zone" {
#   value = azurerm_private_dns_zone.default.id
# }

# output "private_dns_zone_link" {
#   value = azurerm_private_dns_zone_virtual_network_link.default
# }
