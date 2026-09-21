# Azure Data Factory

This bundle creates a Data Factory with a managed identity and a managed virtual
network.

## Outputs

A `data-pipeline` resource. It carries the studio address and the principal of
the identity.

## Access

The factory holds a system assigned identity. When you connect a storage
container, the bundle assigns `Storage Blob Data Contributor` on it.

For any other source, give the principal a role by hand. A pipeline fails at run
time when a role is missing, not at deployment time.

## Encryption

Connect a key vault to encrypt the factory with a customer managed key. The
bundle creates the key and the identity that reads it. The service principal
needs `Key Vault Crypto Officer` on the vault.

## Cost

Azure charges per core hour while a data flow runs. The idle time keeps the
cluster warm after a flow ends. A value of 0 stops the cluster at once, and the
next flow then waits about four minutes.

## Immutable fields

The managed virtual network. Azure sets it at creation.
