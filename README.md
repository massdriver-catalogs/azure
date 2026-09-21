# Azure Catalog

A production-shaped Massdriver catalog for Azure. It gives a platform team a
working set of resource types and bundles on day one, so you start from real
infrastructure instead of a blank canvas.

Clone it, publish it to your organization, then change what doesn't fit. Every
bundle here is meant to be edited — the value is in the shape, not in the
specific numbers.

---

## How a Massdriver catalog works

If you're new to the platform, five ideas carry most of the weight.

| Concept | What it is |
|---|---|
| **Resource type** | A JSON Schema contract that describes what one component hands to another — a database's connection details, a network's subnets. Type safety for infrastructure: you can't wire a Postgres output into a bucket input. |
| **Bundle** | A versioned package of IaC (OpenTofu, Terraform, Helm) plus the schema of its inputs, the resources it produces, and its operational docs. Bundles are what your developers pick from. |
| **Resource** | The live output of a deployed bundle. A Postgres bundle emits a `postgres-database` resource holding the real hostname and password. |
| **Project & environment** | A project groups related infrastructure; each environment (`dev`, `staging`, `prod`) is a canvas inside it. Add a component once to the project, and every environment gets an instance. |
| **Instance** | One configured, deployed copy of a bundle in one environment. |

The point of a catalog is that the platform team writes the guardrails once —
in schemas, defaults and policies — and developers self-serve inside them.

---

## What's in here

### Bundles

**Landing zone** — owned by the platform team.

| Bundle | Creates |
|---|---|
| `azure-subscription-factory` | A subscription under a billing scope, placed in a management group, with a budget. Emits the landing-zone class that governs which bundles a project may use. |
| `azure-landing-zone-baseline` | Log Analytics, subscription activity logs, the Defender plan, a security contact. |
| `azure-ipam-allocation` | Records a CIDR and registers it with your external IPAM (Infoblox, Strata, whatever you run). |
| `azure-virtual-network` | Resource group, VNet, delegated subnets, an NSG per subnet, service endpoints. |
| `azure-private-dns-zone` | A private link zone, linked to the network. |
| `azure-key-vault` | A vault using Azure RBAC rather than access policies. |

**Data**

| Bundle | Creates |
|---|---|
| `azure-postgres-flexible-server` | A flexible server injected into a delegated subnet, with no public endpoint, plus its private DNS zone. |
| `azure-sql-database` | A SQL server and database reachable only from the connected network. |
| `azure-cosmos-account` | A Cosmos DB account, serverless or provisioned, behind a network filter. |
| `azure-storage-account` | A storage account with shared-key auth disabled — consumers use Azure roles. |
| `azure-data-factory` | A factory with a managed identity and a managed VNet. |

**Compute**

| Bundle | Creates |
|---|---|
| `azure-container-app` | A Container Apps environment in a delegated subnet, with a managed identity and its database password held as a secret. |
| `azure-app-service` | A Linux web app on an App Service plan, VNet-integrated, with all egress routed through the network. |
| `azure-kubernetes-service` | An AKS cluster with autoscaling, Azure CNI, the policy add-on and Monitor integration. |

### Resource types

`cloud-account`, `data-pipeline`, `document-database`, `key-vault`,
`kubernetes-cluster`, `log-workspace`, `mssql-database`, `network-allocation`,
`object-storage`, `postgres-database`, `private-dns-zone`, `virtual-network`,
`workload`.

These are deliberately **cloud-neutral**. A `postgres-database` contract fits
Azure Flexible Server and Cloud SQL alike, so the GCP catalog can emit the same
type and your app bundles don't care which cloud they land on. Only
`cloud-account` carries cloud-specific fields.

---

## The patterns worth copying

This is the part to read before you write your own bundles.

**Immutability over apology.** Any field where a change forces Azure to destroy
and recreate is marked `$md.immutable`: network CIDR, region, database version,
Cosmos consistency mode, Key Vault purge protection. The form blocks the change
instead of surfacing it in a plan.

**One PaaS service per subnet.** Azure delegates a subnet to exactly one
service. The network bundle makes the delegation a first-class field, and every
consumer picks its subnet by delegation rather than by position.

**Identity, not keys.** Storage disables shared-key auth entirely; consumers
receive an Azure role and use a managed identity. Key Vault uses RBAC, not
access policies. No connection string leaves a bundle that doesn't need one.

**Policies chosen, not written.** A producer publishes its access levels
(`Read`, `Read and write`, `Full control`); a consumer picks one from a
dropdown via `$md.enum`. The developer never sees an IAM document.

**Costs and consequences in the UI.** Help text states what a choice costs and
what it breaks: *"Cool cuts storage price roughly in half and raises the price
of every read."* *"Doubles the cost of the server. Failover takes about 60
seconds."*

**Alarms ship with the bundle.** 28 alarms across 9 bundles, wired to Azure
Monitor metrics. Nobody has to remember to add monitoring afterwards.

**Compliance decisions are written down.** Every Checkov finding is either
fixed in code or skipped in `src/.checkov.yml` with the reason beside it. The
catalog scans clean, and nothing is hidden — the skip files are the audit
trail.

**Runbooks that interpolate.** Each bundle carries an `operator.md` rendered
with live values, organised as symptom → diagnosis → fix with runnable
commands.

---

## Quick start

### 1. Prerequisites

- [Mass CLI](https://docs.massdriver.cloud/cli) ≥ `2.0.0`
- OpenTofu ≥ 1.8
- An Azure service principal

### 2. Authenticate

```bash
export MASSDRIVER_ORG_ID=your-org
export MASSDRIVER_API_KEY=your-key
mass whoami
```

### 3. Publish

```bash
make publish-platforms       # the azure-service-principal credential type
make publish-resource-types  # the contracts
make publish-bundles         # build, validate, publish
```

`make publish-all` does all three. Every target is idempotent.

> **Note:** publishing a bundle updates every instance pinned to a matching
> release channel. Pin production instances to an exact version if you don't
> want that.

### 4. Add the credential

In the Massdriver UI, create an **Azure Service Principal** resource with your
client ID, tenant ID, client secret and subscription ID, then set it as an
environment default. Every bundle reads its credential from there.

### 5. Build a project

Create a project, add components, wire them together, deploy. A sensible first
shape:

```
platform-landing-zones     network, baseline, DNS zones, key vault
  └── consumed by ──►  application-platform    app + database + storage
                       data-platform           cluster, pipelines, warehouse
```

Application projects reach the network by remote reference or environment
default, so the platform team owns it and app teams merely consume it.

---

## Azure permissions

The service principal needs:

| Scope | Role | Needed for |
|---|---|---|
| Subscription | `Contributor` | Almost everything |
| Subscription | `Security Admin` | The Defender plan in the baseline bundle |
| Subscription | `User Access Administrator` | Role assignments (storage access for app identities) |
| Billing account | `Owner` | The subscription factory only |
| Management group | `Management Group Contributor` | The subscription factory only |

Most of the catalog runs with `Contributor` plus `User Access Administrator`.
The subscription factory is the outlier and usually belongs to a separate,
more privileged credential.

---

## Layout

```
bundles/           one directory per bundle
  <name>/
    massdriver.yaml    params, connections, resources, UI
    src/               OpenTofu: main.tf, resources.tf, alarms.tf, .checkov.yml
    README.md          what it builds and why
    operator.md        runbook, rendered with live values
    CHANGELOG.md
    icon.svg
resource-types/    the contracts between bundles
platforms/         cloud credential types (azure)
templates/         scaffolds for `mass bundle new`
preview.yaml       preview-environment config for PR-based workflows
Makefile           build, validate, publish
```

---

## Known gaps

Honest list, in rough priority order:

- **Customer-managed keys aren't wired up.** The Key Vault bundle exists, but
  storage, Cosmos, Data Factory and AKS don't yet accept a key connection.
  Five Checkov skips point at this.
- **Private endpoints aren't wired up.** The DNS zone bundle exists; no bundle
  creates an endpoint against it yet. Three skips point at this.
- **Missing bundles** that most Azure estates eventually want: Functions,
  Container Registry, Redis, Service Bus, Application Gateway or Front Door,
  MySQL.
- **Versions are all `0.0.0`.** Adopt semver before anyone depends on this.

---

## Conventions

- **Resource types are cloud-neutral; bundles carry the cloud name.** Keeps app
  bundles portable across clouds.
- **Bundle names are `azure-<service>`.** Bundle and resource-type repositories
  share one namespace, so names can't collide.
- **Never commit** `_massdriver_variables.tf`, `schema-*.json`, `.terraform/`
  or state. `make clean` removes them.
