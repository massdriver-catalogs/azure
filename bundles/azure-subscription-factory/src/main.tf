locals {
  name_prefix = var.md_metadata.name_prefix

  # A regulated zone carries the short service list that the compliance owner
  # approved. A standard zone carries the normal controls. Replace these names
  # with the policy set definitions of your own tenant.
  policy_set = var.landing_zone_class == "regulated" ? [
    "regulated-allowed-services",
    "regulated-required-controls",
    "deny-public-network-access",
    ] : [
    "standard-required-tags",
    "standard-allowed-regions",
  ]
}

# Azure creates a subscription through an alias. The service principal needs
# the Owner role on the billing scope.
resource "azurerm_subscription" "main" {
  alias             = local.name_prefix
  subscription_name = var.subscription_name
  billing_scope_id  = var.billing_scope
  workload          = var.workload_type
  tags              = var.md_metadata.default_tags
}

resource "azurerm_management_group_subscription_association" "main" {
  management_group_id = "/providers/Microsoft.Management/managementGroups/${var.management_group_id}"
  subscription_id     = "/subscriptions/${azurerm_subscription.main.subscription_id}"
}

resource "azurerm_consumption_budget_subscription" "main" {
  count = var.budget_amount > 0 ? 1 : 0

  name            = local.name_prefix
  subscription_id = "/subscriptions/${azurerm_subscription.main.subscription_id}"
  amount          = var.budget_amount
  time_grain      = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00Z", timestamp())
  }

  dynamic "notification" {
    for_each = var.budget_contact_email != "" ? [80, 100] : []

    content {
      enabled        = true
      threshold      = notification.value
      operator       = "GreaterThan"
      contact_emails = [var.budget_contact_email]
    }
  }

  lifecycle {
    ignore_changes = [time_period]
  }
}
