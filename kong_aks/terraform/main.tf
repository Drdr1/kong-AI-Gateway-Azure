provider "azurerm" {
  features {}
subscription_id = "955faad9-ebe9-4a85-9974-acae429ae877"
}

resource "azurerm_resource_group" "rg" {
  name     = "kong-openai-rg"
  location = "East US"
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "kong-aks"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "kongaks"

  default_node_pool {
    name       = "default"
    node_count = 2
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_cognitive_account" "openai" {
  name                = "myopenai-${random_string.suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "OpenAI"
  sku_name            = "S0"
}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "azurerm_cognitive_deployment" "openai_deployment" {
  name                 = "gpt-35-turbo"
  cognitive_account_id = azurerm_cognitive_account.openai.id
  model {
    format  = "OpenAI"
    name    = "gpt-35-turbo"
    version = "0125"
  }
  sku {
    name     = "Standard"
    capacity = 10
  }
}

resource "azurerm_key_vault" "kv" {
  name                        = "kong-openai-kv"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = false
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault_access_policy" "aks_access" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_kubernetes_cluster.aks.identity[0].principal_id
  secret_permissions  = ["Get", "List"]
}

resource "azurerm_key_vault_secret" "jwt_secret" {
  name         = "jwt-secret"
  value        = "my-super-secret-jwt-key"
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_log_analytics_workspace" "logs" {
  name                = "kong-openai-logs"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
}
