# Azure Private DNS Zone

This bundle creates a private DNS zone and links it to the connected network.

## Purpose

A private endpoint gives a service an address inside your network. A client
still asks for the public name, such as `myaccount.blob.core.windows.net`. The
private link zone answers that question with the private address.

Without the zone and the link, a client receives the public address and then
fails to connect.

## Zone names

| Service | Zone |
|---|---|
| Blob storage | `privatelink.blob.core.windows.net` |
| PostgreSQL | `privatelink.postgres.database.azure.com` |
| SQL Server | `privatelink.database.windows.net` |
| Key Vault | `privatelink.vaultcore.azure.net` |
| Cosmos DB (NoSQL) | `privatelink.documents.azure.com` |

Deploy one instance per zone name.

## Immutable fields

The zone name. Azure cannot rename a zone.
