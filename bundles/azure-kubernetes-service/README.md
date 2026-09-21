# Azure Kubernetes Service

This bundle creates a cluster in the connected network. A chart bundle deploys
onto it.

## Network

The cluster uses the first subnet without a delegation. The Azure network plugin
gives every pod an address from that subnet, so the subnet needs free space.

Each node takes about 30 addresses. A `/24` subnet holds about 8 nodes.

## Outputs

A `kubernetes-cluster` resource. It carries the API server address and the
client certificate. Massdriver masks those fields, and it records every
download.

## Disk encryption

Connect a key vault to encrypt every disk of the cluster with a customer
managed key. The bundle creates the key, a disk encryption set, and the role
assignment that lets the set read the key.

Azure sets the disk encryption set at creation. A cluster that already exists
cannot take one later.

## Cost

| Item | Cost |
|---|---|
| Free tier control plane | No charge, and no uptime promise. |
| Standard tier control plane | About 73 dollars per month. |
| Nodes | The price of each virtual machine, per hour. |

## Immutable fields

The private API server. Azure sets it at creation.
