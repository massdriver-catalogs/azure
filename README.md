# Azure Catalog

A Massdriver catalog of Azure bundles and resource types. Publish it to your
organization to get a working set of infrastructure components, then edit them
to match your standards.

Contents: 14 bundles, 13 resource types, and the Azure service principal
credential type.

This is a hard fork of the
[Massdriver catalog template](https://github.com/massdriver-cloud/massdriver-catalog),
which is the cloud-neutral starting point for any catalog. This repository
replaces the template's example bundles with Azure ones so a team can start on
Azure without writing them first. The template repository still holds the
credential types for the other clouds, the bundle scaffolds, and the
documentation on the catalog format.

## Concepts

| Term | Meaning |
|---|---|
| Resource type | A JSON Schema contract describing what one component passes to another, such as a database's connection details or a network's subnets. Massdriver validates connections against it. |
| Bundle | A versioned package of IaC (OpenTofu, Terraform, or Helm) with the schema of its inputs, the resources it produces, and its documentation. |
| Resource | The output of a deployed bundle. A Postgres bundle emits a `postgres-database` resource with the hostname, port, user, and password. |
| Project | A group of related infrastructure. Components are added at the project level. |
| Environment | A deployment context inside a project, such as `dev` or `prod`. Each environment gets one instance of every component in the project. |
| Instance | One configured, deployed copy of a bundle in one environment. |

## Bundles

Landing zone:

| Bundle | Creates |
|---|---|
| `azure-subscription-factory` | A subscription under a billing scope, placed in a management group, with a monthly budget. Emits the class that governs which bundles a project can use. |
| `azure-landing-zone-baseline` | A Log Analytics workspace, the subscription activity log, the Defender plan, and a security contact. |
| `azure-ipam-allocation` | A record of a CIDR range, registered with an external IPAM system over HTTP. |
| `azure-virtual-network` | A resource group, a VNet, delegated subnets, a network security group per subnet, and service endpoints. |
| `azure-private-dns-zone` | A private link DNS zone, linked to the network. |
| `azure-key-vault` | A key vault that uses Azure RBAC. |

Data:

| Bundle | Creates |
|---|---|
| `azure-postgres-flexible-server` | A flexible server in a delegated subnet with no public endpoint, and its private DNS zone. |
| `azure-sql-database` | A SQL server and one database, reachable from the connected network only. Takes an optional private DNS zone. |
| `azure-cosmos-account` | A Cosmos DB account and database, serverless or provisioned, behind a network filter. |
| `azure-storage-account` | A storage account and blob container with shared key access disabled. Takes an optional key vault and private DNS zone. |
| `azure-data-factory` | A factory with a system assigned identity and a managed virtual network. Takes an optional key vault. |

Compute:

| Bundle | Creates |
|---|---|
| `azure-container-app` | A Container Apps environment in a delegated subnet, and an application with a system assigned identity. |
| `azure-app-service` | A Linux web app on an App Service plan, joined to a delegated subnet, with all egress routed through the network. |
| `azure-kubernetes-service` | An AKS cluster with autoscaling, Azure CNI, the policy add-on, and Monitor integration. Takes an optional key vault for disk encryption. |

## Resource types

`cloud-account`, `data-pipeline`, `document-database`, `key-vault`,
`kubernetes-cluster`, `log-workspace`, `mssql-database`, `network-allocation`,
`object-storage`, `postgres-database`, `private-dns-zone`, `virtual-network`,
`workload`.

All of them except `cloud-account` are cloud-neutral. A catalog for another
cloud can emit the same contracts, so application bundles do not change when
the cloud does.

## Best practices

Fields that force Azure to destroy and recreate a resource carry
`$md.immutable`. That covers the network CIDR, the region, the PostgreSQL
version, the Cosmos DB API and capacity mode, the Key Vault purge protection,
and the database and container names. The form rejects the change rather than
showing it in a plan.

Azure delegates a subnet to one service. The network bundle exposes the
delegation as a field on each subnet, and each consumer selects its subnet by
delegation. A Container Apps subnet needs a `/23` or larger range.

The storage bundle sets `shared_access_key_enabled = false`, and the key vault
uses `rbac_authorization_enabled = true`. Consumers get an Azure role for their
managed identity. Bundles that produce credentials mark them `$md.sensitive`.

A producer publishes its access levels in a `policies` array. A consumer reads
that array through `$md.enum` and shows the developer a list. The application
bundles then assign the matching Azure role.

Help text on a parameter states the cost and the operational effect of each
choice, such as the price difference between access tiers or the failover time
of a high availability server.

Nine bundles carry `src/alarms.tf`, for 28 alarms bound to Azure Monitor
metrics. Each alarm needs its own `cloud_resource_id`, so the identifier is the
ARM ID followed by a pipe and the alarm name.

Connect `azure-key-vault` to the storage, Data Factory, or Kubernetes bundle to
encrypt with a customer managed key. The consumer creates its own key in the
vault, creates the identity that reads it, and assigns the
`Key Vault Crypto Service Encryption User` role. The key type follows the level
that the vault publishes, so a premium vault produces a hardware module key.
The service principal needs `Key Vault Crypto Officer` on the vault to create
the key.

Connect `azure-private-dns-zone` to the storage or SQL bundle to add a private
endpoint. The endpoint lands in the first subnet without a delegation, and the
zone answers the public name with the private address.

Massdriver runs Checkov on every deployment. Findings are either fixed in the
IaC or listed in `src/.checkov.yml` with the reason written next to each entry.
The catalog currently scans clean.

Every bundle has an `operator.md` with `templating: mustache` front matter. The
runbooks interpolate `{{resources.<name>.<field>}}`, `{{dependencies.<name>}}`,
and `{{params.<name>}}` into runnable commands, and wrap resource-sourced
sections in `{{#resources.<name>}}` guards so they render before the first
deployment.

## Publishing

Requirements: [Mass CLI](https://docs.massdriver.cloud/cli) 2.0.0 or later,
OpenTofu 1.8 or later, and an Azure service principal.

```bash
export MASSDRIVER_ORG_ID=your-org
export MASSDRIVER_API_KEY=your-key
mass whoami
```

```bash
make publish-platforms       # the azure-service-principal credential type
make publish-resource-types  # the contracts
make publish-bundles         # build, validate, and publish
```

`make publish-all` runs all three. Each target is idempotent.

Publishing a bundle updates every instance pinned to a matching release
channel. Pin production instances to an exact version to avoid that.

Then create an Azure Service Principal resource in the UI with the client ID,
tenant ID, client secret, and subscription ID, and set it as an environment
default. Each bundle reads its credential from there.

## Azure permissions

| Scope | Role | Required by |
|---|---|---|
| Subscription | `Contributor` | Every bundle |
| Subscription | `User Access Administrator` | Role assignments, used by the application and Data Factory bundles |
| Subscription | `Security Admin` | `azure-landing-zone-baseline` |
| Billing account | `Owner` | `azure-subscription-factory` |
| Management group | `Management Group Contributor` | `azure-subscription-factory` |

`azure-subscription-factory` usually runs under a separate credential with a
wider scope than the one the other bundles use.

## Layout

```
bundles/
  <name>/
    massdriver.yaml    params, dependencies, resources, UI schema
    src/               OpenTofu: main.tf, resources.tf, alarms.tf, .checkov.yml
    README.md
    operator.md        runbook
    CHANGELOG.md
    icon.svg
resource-types/        the contracts between bundles
platforms/azure/       the service principal credential type
templates/             scaffolds for `mass bundle new`
preview.yaml           preview environment configuration
Makefile               build, validate, publish
```

Do not commit `_massdriver_variables.tf`, `schema-*.json`, `.terraform/`, or
state files. `make clean` removes them, and `.gitignore` covers them.
