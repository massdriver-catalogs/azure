resource "massdriver_resource" "zone" {
  field = "zone"
  name  = "Private DNS Zone ${var.zone_name}"

  resource = jsonencode({
    id              = azurerm_private_dns_zone.main.id
    name            = azurerm_private_dns_zone.main.name
    resource_group  = azurerm_resource_group.main.name
    linked_networks = [azurerm_private_dns_zone_virtual_network_link.main.virtual_network_id]
  })
}
