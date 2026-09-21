# Azure Monitor metrics for a vault.

resource "massdriver_instance_alarm" "availability" {
  display_name        = "Availability below 99.9 percent"
  cloud_resource_id   = "${azurerm_key_vault.main.id}|availability"
  threshold           = 99.9
  period              = 300
  comparison_operator = "LessThanThreshold"

  metric {
    name      = "Availability"
    namespace = "Microsoft.KeyVault/vaults"
    statistic = "Average"
    region    = azurerm_resource_group.main.location
  }
}

resource "massdriver_instance_alarm" "saturation" {
  display_name        = "Request rate above 75 percent of the limit"
  cloud_resource_id   = "${azurerm_key_vault.main.id}|saturation"
  threshold           = 75
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "SaturationShoebox"
    namespace = "Microsoft.KeyVault/vaults"
    statistic = "Average"
    region    = azurerm_resource_group.main.location
  }
}

resource "massdriver_instance_alarm" "latency" {
  display_name        = "Request latency above one second"
  cloud_resource_id   = "${azurerm_key_vault.main.id}|latency"
  threshold           = 1000
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "ServiceApiLatency"
    namespace = "Microsoft.KeyVault/vaults"
    statistic = "Average"
    region    = azurerm_resource_group.main.location
  }
}
