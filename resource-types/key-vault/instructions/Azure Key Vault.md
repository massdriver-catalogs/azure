# Import an Azure Key Vault

```bash
az keyvault show --name <VAULT> \
  --query "{id:id, name:name, uri:properties.vaultUri, region:location, tenant_id:properties.tenantId, purge_protection:properties.enablePurgeProtection}"
```

| Field | Source |
|---|---|
| `id` | The `id` field of the vault. |
| `uri` | The vault URI. |
| `purge_protection` | The purge protection setting. |

## Warning

A customer managed key needs purge protection. Azure cannot turn that setting
off again, and it cannot delete the vault before the retention period ends.
