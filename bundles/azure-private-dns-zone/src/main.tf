locals {
  name_prefix = var.md_metadata.name_prefix
}

resource "azurerm_resource_group" "main" {
  name     = local.name_prefix
  location = var.network.region
  tags     = var.md_metadata.default_tags
}

# A private DNS zone is global. Only the link belongs to a region.
resource "azurerm_private_dns_zone" "main" {
  name                = var.zone_name
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.md_metadata.default_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "main" {
  name                  = local.name_prefix
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.main.name
  virtual_network_id    = var.network.id
  registration_enabled  = var.registration_enabled
  tags                  = var.md_metadata.default_tags
}
