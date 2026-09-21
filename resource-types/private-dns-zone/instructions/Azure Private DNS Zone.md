# Import an Azure Private DNS Zone

```bash
az network private-dns zone show \
  --resource-group <GROUP> --name <ZONE> \
  --query "{id:id, name:name, resource_group:resourceGroup}"
```

```bash
az network private-dns link vnet list \
  --resource-group <GROUP> --zone-name <ZONE> \
  --query "[].virtualNetwork.id"
```

| Field | Source |
|---|---|
| `id` | The `id` field of the zone. |
| `name` | The zone name, such as `privatelink.blob.core.windows.net`. |
| `linked_networks` | One entry per linked network. |

## Warning

A private endpoint resolves only from a network that links to the zone. A client
in an unlinked network receives the public address and then fails to connect.
