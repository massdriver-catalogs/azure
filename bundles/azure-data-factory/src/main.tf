locals {
  name_prefix  = var.md_metadata.name_prefix
  factory_name = substr(replace(lower(local.name_prefix), "/[^a-z0-9-]/", ""), 0, 63)
  has_bucket   = try(var.bucket.name, null) != null
  has_key      = try(var.key_vault.id, null) != null
}

resource "azurerm_resource_group" "main" {
  name     = local.name_prefix
  location = var.network.region
  tags     = var.md_metadata.default_tags
}

resource "azurerm_data_factory" "main" {
  name                = local.factory_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.md_metadata.default_tags

  managed_virtual_network_enabled = var.managed_virtual_network
  public_network_enabled          = var.public_network_enabled

  # A customer managed key needs a user assigned identity, because the factory
  # must read the key before its own identity exists.
  identity {
    type         = local.has_key ? "SystemAssigned, UserAssigned" : "SystemAssigned"
    identity_ids = local.has_key ? [azurerm_user_assigned_identity.encryption[0].id] : null
  }

  customer_managed_key_id          = local.has_key ? azurerm_key_vault_key.encryption[0].id : null
  customer_managed_key_identity_id = local.has_key ? azurerm_user_assigned_identity.encryption[0].id : null
}

resource "azurerm_user_assigned_identity" "encryption" {
  count = local.has_key ? 1 : 0

  name                = "${local.name_prefix}-encryption"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.md_metadata.default_tags
}

resource "azurerm_role_assignment" "encryption" {
  count = local.has_key ? 1 : 0

  scope                = var.key_vault.id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_user_assigned_identity.encryption[0].principal_id
}

resource "azurerm_key_vault_key" "encryption" {
  count = local.has_key ? 1 : 0

  name         = local.name_prefix
  key_vault_id = var.key_vault.id
  key_size     = 2048

  # A hardware module key needs a premium vault. The vault publishes its level.
  key_type = try(var.key_vault.sku, "standard") == "premium" ? "RSA-HSM" : "RSA"

  key_opts = ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"]

  # Azure rotates the key and sets the next expiry. A fixed date in the code
  # would drift on every deployment.
  rotation_policy {
    expire_after         = "P1Y"
    notify_before_expiry = "P30D"

    automatic {
      time_before_expiry = "P30D"
    }
  }

  depends_on = [azurerm_role_assignment.encryption]
}

resource "azurerm_data_factory_integration_runtime_azure" "main" {
  count = var.managed_virtual_network ? 1 : 0

  name            = "default"
  data_factory_id = azurerm_data_factory.main.id
  location        = azurerm_resource_group.main.location

  virtual_network_enabled = true
  compute_type            = "General"
  core_count              = var.integration_runtime_cores
  time_to_live_min        = var.integration_runtime_ttl_minutes
}

# The factory reads and writes the connected container with its own identity.
resource "azurerm_role_assignment" "bucket" {
  count = local.has_bucket ? 1 : 0

  scope                = var.bucket.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_factory.main.identity[0].principal_id
}
