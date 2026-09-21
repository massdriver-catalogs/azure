locals {
  name_prefix = var.md_metadata.name_prefix

  # A cluster needs a subnet that no service owns. The network bundle marks such
  # a subnet with the delegation `none`.
  open_subnets = [
    for subnet in var.network.subnets : subnet
    if try(subnet.delegation, "none") == "none"
  ]

  subnet_id = try(local.open_subnets[0].id, null)
  has_key   = try(var.key_vault.id, null) != null
}

resource "azurerm_resource_group" "main" {
  name     = local.name_prefix
  location = var.network.region
  tags     = var.md_metadata.default_tags
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = local.name_prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.md_metadata.default_tags
}

resource "azurerm_kubernetes_cluster" "main" {
  lifecycle {
    precondition {
      condition     = local.subnet_id != null
      error_message = "The connected network holds no subnet without a delegation. Add one, then deploy again."
    }

    precondition {
      condition     = var.max_nodes >= var.min_nodes
      error_message = "The maximum node count is lower than the minimum. Correct one of the two values."
    }
  }

  name                = local.name_prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  dns_prefix          = local.name_prefix
  tags                = var.md_metadata.default_tags

  kubernetes_version      = var.kubernetes_version
  sku_tier                = var.service_tier
  private_cluster_enabled = var.private_cluster
  local_account_disabled  = false

  # Checkov CKV_AZURE_116 asks for the policy add-on, and CKV_AZURE_171 asks
  # for an upgrade channel. Azure then applies a patch without a deployment.
  azure_policy_enabled      = true
  automatic_upgrade_channel = "patch"

  # Every OS disk and every managed disk of the cluster uses this key.
  disk_encryption_set_id = local.has_key ? azurerm_disk_encryption_set.main[0].id : null

  default_node_pool {
    name                 = "system"
    vm_size              = var.node_size
    vnet_subnet_id       = local.subnet_id
    auto_scaling_enabled = true
    min_count            = var.min_nodes
    max_count            = var.max_nodes
    os_disk_size_gb      = 64
    max_pods             = 30
  }

  identity {
    type = "SystemAssigned"
  }

  # Checkov CKV_AZURE_4. The cluster sends its logs to this workspace.
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  # Checkov CKV_AZURE_172. The driver rotates a mounted secret on its own.
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
    service_cidr   = "172.16.0.0/16"
    dns_service_ip = "172.16.0.10"
  }
}

# A disk encryption set holds the key that encrypts the disks of the cluster.
# It reads the key with its own identity, so the set exists before the cluster.
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
}

resource "azurerm_disk_encryption_set" "main" {
  count = local.has_key ? 1 : 0

  name                = local.name_prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  key_vault_key_id    = azurerm_key_vault_key.encryption[0].id
  tags                = var.md_metadata.default_tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "encryption" {
  count = local.has_key ? 1 : 0

  scope                = var.key_vault.id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_disk_encryption_set.main[0].identity[0].principal_id
}
