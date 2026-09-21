# Azure Subscription Factory

This bundle vends a subscription. The platform team owns it. No application
team deploys it.

## Resources created

- A subscription under the billing scope that you give.
- An association to a management group, which carries the policy set.
- A monthly budget with an alert at 80 percent and at 100 percent.

## Outputs

A `cloud-account` resource. It carries the class of the landing zone, and that
class decides which bundles the projects in the subscription can use.

## Permissions

The service principal needs the `Owner` role on the billing scope, and the
`Management Group Contributor` role on the parent group. A credential that
holds one subscription cannot run this bundle.

## Immutable fields

The name, the class, the management group, the billing scope, and the workload
type. Azure sets all of them at creation.
