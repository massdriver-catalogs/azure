# Azure Storage Account

This bundle creates a storage account and one blob container.

## Outputs

An `object-storage` resource. It carries the endpoint, the container name, and
three access policies.

## Access

The bundle turns off the shared access key, so no secret leaves it. An
application selects a policy, then assigns the matching Azure role to its own
managed identity.

| Policy | Azure role |
|---|---|
| Read | `Storage Blob Data Reader` |
| Read and write | `Storage Blob Data Contributor` |
| Full control | `Storage Blob Data Owner` |

## Encryption

Connect a key vault to encrypt the account with a customer managed key. The
bundle creates the key in that vault, creates a user assigned identity, and
gives the identity the `Key Vault Crypto Service Encryption User` role. The
vault needs purge protection, and the service principal needs
`Key Vault Crypto Officer` on it.

Without a vault, Azure encrypts with its own key. Infrastructure encryption
stays on either way.

## Private endpoint

Connect a private DNS zone named `privatelink.blob.core.windows.net` to give
the account an address inside the network. The endpoint lands in the first
subnet without a delegation.

## Network

The account denies all traffic, except traffic from the subnets of the
connected network. The subnets need the `Microsoft.Storage` service endpoint.
The `azure-virtual-network` bundle sets that endpoint on every subnet.

## Immutable fields

- **Container name.** Azure cannot rename a container.
