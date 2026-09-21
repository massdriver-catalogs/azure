resource "massdriver_resource" "vault" {
  field = "vault"
  name  = "Key Vault ${var.md_metadata.name_prefix}"

  resource = jsonencode({
    id               = azurerm_key_vault.main.id
    name             = azurerm_key_vault.main.name
    uri              = azurerm_key_vault.main.vault_uri
    region           = azurerm_resource_group.main.location
    tenant_id        = var.azure_service_principal.tenant_id
    purge_protection = var.purge_protection
  })
}
