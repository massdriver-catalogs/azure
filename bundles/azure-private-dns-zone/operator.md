---
templating: mustache
---

# Private DNS Zone Runbook

## Health check

{{#resources.zone}}
```bash
az network private-dns zone show \
  --resource-group {{resources.zone.resource_group}} \
  --name {{resources.zone.name}} \
  --query "{records:numberOfRecordSets, links:numberOfVirtualNetworkLinks}"
```
{{/resources.zone}}

## A client receives the public address

The network of the client does not link to this zone, or the endpoint wrote no
record.

{{#resources.zone}}
1. List the links.
   ```bash
   az network private-dns link vnet list \
     --resource-group {{resources.zone.resource_group}} \
     --zone-name {{resources.zone.name}} --output table
   ```
2. List the records.
   ```bash
   az network private-dns record-set a list \
     --resource-group {{resources.zone.resource_group}} \
     --zone-name {{resources.zone.name}} --output table
   ```
3. From a workload inside the network, resolve the name. The answer must be a
   private address.
{{/resources.zone}}

## A deployment fails with a conflicting link

One network holds one zone with registration on. A second such link fails.

Turn registration off. A zone for private endpoints does not need it.

## The zone name is wrong

Azure cannot rename a zone. Deploy a second instance with the correct name,
move each private endpoint to it, then decommission the first instance.

## Warning: a deleted zone breaks every endpoint that uses it

A client then receives the public address and fails to connect. Check the
record count before you decommission this instance.
