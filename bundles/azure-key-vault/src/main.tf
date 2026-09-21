locals {
  name_prefix = var.md_metadata.name_prefix
  # Azure permits 3 to 24 characters in a vault name, and the name is global.
  vault_name = substr(replace(lower(local.name_prefix), "/[^a-z0-9-]/", ""), 0, 24)
  subnet_ids = [for subnet in var.network.subnets : subnet.id]
}

resource "azurerm_resource_group" "main" {
  name     = local.name_prefix
  location = var.network.region
  tags     = var.md_metadata.default_tags
}

resource "azurerm_key_vault" "main" {
  name                = local.vault_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tenant_id           = var.azure_service_principal.tenant_id
  tags                = var.md_metadata.default_tags

  sku_name = var.sku

  # An Azure role grants access, not a vault access policy. One model is easier
  # to audit than two.
  rbac_authorization_enabled = true

  purge_protection_enabled      = var.purge_protection
  soft_delete_retention_days    = var.soft_delete_days
  public_network_access_enabled = true

  # The vault answers the connected network only. Azure services such as Disk
  # Encryption reach it through the bypass.
  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = local.subnet_ids
  }
}
