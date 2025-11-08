resource "azurerm_logic_app_workflow" "example" {
  name                = "example-logicapp"
  location            = data.azurerm_resource_group.identity_lab.location
  resource_group_name = data.azurerm_resource_group.identity_lab.name
  parameters          = {}
}

resource "azurerm_monitor_action_group" "logicapp_action" {
  name                = "logicapp-action-group"
  resource_group_name = data.azurerm_resource_group.identity_lab.name
  short_name          = "logicapp"

  logic_app_receiver {
    name         = "logicapp-webhook"
    resource_id  = azurerm_logic_app_workflow.example.id
    callback_url = azurerm_logic_app_workflow.example.access_endpoint
  }
}
