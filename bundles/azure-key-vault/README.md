# Azure Key Vault

This bundle creates a vault for keys, secrets, and certificates.

## Access

The vault uses Azure roles, not vault access policies. One model is easier to
audit than two. Give an identity the role that matches its need:

| Need | Role |
|---|---|
| Read a secret | `Key Vault Secrets User` |
| Manage secrets | `Key Vault Secrets Officer` |
| Use a key to encrypt | `Key Vault Crypto Service Encryption User` |
| Manage keys | `Key Vault Crypto Officer` |

## Network

The vault denies every source outside the connected network. Azure services
such as Disk Encryption reach it through the bypass.

## Immutable fields

- **Purge protection.** Azure cannot turn it off. A vault with the setting on
  stays until the retention period ends, and its name stays reserved.
- **Soft delete retention.** Azure cannot shorten the period later.

A customer managed key needs purge protection, so turn it on before you point
another bundle at this vault.
