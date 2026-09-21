locals {
  name_prefix = var.md_metadata.name_prefix
  server_name = substr(replace(lower(local.name_prefix), "/[^a-z0-9-]/", ""), 0, 63)
  subnets     = { for subnet in var.network.subnets : subnet.name => subnet.id }
  has_zone    = try(var.private_dns_zone.id, null) != null

  # A private endpoint needs a subnet that no service owns.
  open_subnets    = [for subnet in var.network.subnets : subnet if try(subnet.delegation, "none") == "none"]
  endpoint_subnet = try(local.open_subnets[0].id, null)
}

resource "random_password" "admin" {
  length           = 32
  special          = true
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  override_special = "!#%*()-_=+[]{}<>:?"
}

resource "azurerm_resource_group" "main" {
  name     = local.name_prefix
  location = var.network.region
  tags     = var.md_metadata.default_tags
}

resource "azurerm_mssql_server" "main" {
  name                = local.server_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.md_metadata.default_tags

  version                       = "12.0"
  administrator_login           = var.username
  administrator_login_password  = random_password.admin.result
  minimum_tls_version           = "1.2"
  public_network_access_enabled = true
}

# The server answers the connected network only. No firewall rule opens it to
# the internet.
resource "azurerm_mssql_virtual_network_rule" "main" {
  for_each = local.subnets

  name      = each.key
  server_id = azurerm_mssql_server.main.id
  subnet_id = each.value
}

resource "azurerm_mssql_database" "main" {
  name      = var.database_name
  server_id = azurerm_mssql_server.main.id
  tags      = var.md_metadata.default_tags

  sku_name       = var.sku
  max_size_gb    = var.max_size_gb
  zone_redundant = var.zone_redundant

  storage_account_type = var.backup_redundancy

  lifecycle {
    precondition {
      condition     = var.sku != "Basic" || var.max_size_gb <= 2
      error_message = "The Basic level holds 2 GiB at most. Lower the size, or pick a larger level."
    }
  }
}

resource "azurerm_mssql_server_extended_auditing_policy" "main" {
  server_id              = azurerm_mssql_server.main.id
  log_monitoring_enabled = true
  retention_in_days      = 90
}

# A private endpoint gives the server an address inside the network. The
# connected zone answers the public name with that address.
resource "azurerm_private_endpoint" "sql" {
  count = local.has_zone ? 1 : 0

  lifecycle {
    precondition {
      condition     = local.endpoint_subnet != null
      error_message = "A private endpoint needs a subnet without a delegation. Add one to the network, then deploy again."
    }
  }

  name                = local.name_prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  subnet_id           = local.endpoint_subnet
  tags                = var.md_metadata.default_tags

  private_service_connection {
    name                           = local.name_prefix
    private_connection_resource_id = azurerm_mssql_server.main.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.private_dns_zone.id]
  }
}
