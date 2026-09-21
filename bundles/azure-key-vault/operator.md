---
templating: mustache
---

# Key Vault Runbook

## Health check

{{#resources.vault}}
```bash
az keyvault show --name {{resources.vault.name}} \
  --query "{state:properties.provisioningState, rbac:properties.enableRbacAuthorization}"
```
{{/resources.vault}}

## An application gets `Forbidden`

The identity holds no role on the vault. This vault uses Azure roles, so a vault
access policy has no effect here.

{{#resources.vault}}
1. Assign the role.
   ```bash
   az role assignment create \
     --assignee <PRINCIPAL_ID> \
     --role "Key Vault Secrets User" \
     --scope {{resources.vault.id}}
   ```
2. Wait up to five minutes. Azure needs that time to apply a new role.
3. Verify.
   ```bash
   az role assignment list --assignee <PRINCIPAL_ID> --scope {{resources.vault.id}} --output table
   ```
{{/resources.vault}}

## A client outside the network gets a timeout

The vault denies every source outside the connected network.

{{#resources.vault}}
```bash
az keyvault show --name {{resources.vault.name}} \
  --query "{action:properties.networkAcls.defaultAction, subnets:properties.networkAcls.virtualNetworkRules[].id}"
```
{{/resources.vault}}

## A deployment fails with `VaultAlreadyExists`

The vault name is global to Azure. A soft deleted vault keeps its name until the
retention period ends.

```bash
az keyvault list-deleted --query "[].{name:name, purgeDate:properties.scheduledPurgeDate}" --output table
```

Rename the instance, or recover the deleted vault.

```bash
az keyvault recover --name <VAULT>
```

## Recover a deleted secret

```bash
az keyvault secret recover --vault-name <VAULT> --name <SECRET>
```

## Warning: purge protection cannot be turned off

A vault with purge protection stays for the whole retention period, and nobody
can remove it early. Turn the setting on only when a customer managed key needs
it.
