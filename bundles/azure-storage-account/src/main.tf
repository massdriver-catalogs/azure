locals {
  name_prefix = var.md_metadata.name_prefix

  # Azure permits 3 to 24 lowercase letters and digits in a storage account
  # name. The Massdriver prefix holds hyphens, so remove them and truncate.
  account_name = substr(replace(lower(local.name_prefix), "/[^a-z0-9]/", ""), 0, 24)

  subnet_ids = [for subnet in var.network.subnets : subnet.id]
  has_logs   = try(var.logs.id, null) != null
  has_key    = try(var.key_vault.id, null) != null
  has_zone   = try(var.private_dns_zone.id, null) != null

  # A private endpoint needs a subnet that no service owns.
  open_subnets    = [for subnet in var.network.subnets : subnet if try(subnet.delegation, "none") == "none"]
  endpoint_subnet = try(local.open_subnets[0].id, null)
}

resource "azurerm_resource_group" "main" {
  name     = local.name_prefix
  location = var.network.region
  tags     = var.md_metadata.default_tags
}

resource "azurerm_storage_account" "main" {
  name                = local.account_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.md_metadata.default_tags

  account_tier             = "Standard"
  account_replication_type = replace(var.redundancy, "Standard_", "")
  account_kind             = "StorageV2"
  access_tier              = var.access_tier

  # Security defaults. A developer cannot weaken these from the form.
  https_traffic_only_enabled        = true
  min_tls_version                   = "TLS1_2"
  allow_nested_items_to_be_public   = false
  public_network_access_enabled     = true
  infrastructure_encryption_enabled = true
  shared_access_key_enabled         = false
  local_user_enabled                = false
  sftp_enabled                      = false

  # A customer managed key needs a user assigned identity. Azure reads the key
  # with that identity, and a system assigned identity cannot do it, because
  # the account needs the identity before it exists.
  identity {
    type         = local.has_key ? "SystemAssigned, UserAssigned" : "SystemAssigned"
    identity_ids = local.has_key ? [azurerm_user_assigned_identity.encryption[0].id] : null
  }

  dynamic "customer_managed_key" {
    for_each = local.has_key ? [1] : []

    content {
      key_vault_key_id          = azurerm_key_vault_key.encryption[0].id
      user_assigned_identity_id = azurerm_user_assigned_identity.encryption[0].id
    }
  }

  blob_properties {
    versioning_enabled = var.versioning_enabled

    delete_retention_policy {
      days = var.retention_days
    }

    container_delete_retention_policy {
      days = var.retention_days
    }
  }

  # The account accepts traffic from the connected network only. Azure services
  # such as Monitor still reach the account through the bypass.
  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = local.subnet_ids
  }
}

resource "azurerm_storage_container" "main" {
  name                  = var.container_name
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

# Checkov CKV2_AZURE_21 asks for a record of every blob request. Connect a log
# workspace to turn it on. Without the connection the account writes no record.
resource "azurerm_monitor_diagnostic_setting" "blob" {
  count = local.has_logs ? 1 : 0

  name                       = "${local.name_prefix}-blob"
  target_resource_id         = "${azurerm_storage_account.main.id}/blobServices/default"
  log_analytics_workspace_id = var.logs.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  enabled_metric {
    category = "Transaction"
  }
}

# The key stays in the connected vault, and the account reads it with its own
# identity. The vault needs purge protection, and the service principal needs
# the Key Vault Crypto Officer role on it.
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

# A private endpoint gives the account an address inside the network. The
# connected zone answers the public name with that address.
resource "azurerm_private_endpoint" "blob" {
  count = local.has_zone ? 1 : 0

  lifecycle {
    precondition {
      condition     = local.endpoint_subnet != null
      error_message = "A private endpoint needs a subnet without a delegation. Add one to the network, then deploy again."
    }
  }

  name                = "${local.name_prefix}-blob"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  subnet_id           = local.endpoint_subnet
  tags                = var.md_metadata.default_tags

  private_service_connection {
    name                           = "${local.name_prefix}-blob"
    private_connection_resource_id = azurerm_storage_account.main.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.private_dns_zone.id]
  }
}
