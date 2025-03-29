provider "azurerm" {
  features {}
subscription_id = "955faad9-ebe9-4a85-9974-acae429ae877" 
}

resource "azurerm_resource_group" "rg" {
  name     = "kong-aks-rg"
  location = "East US"
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "kong-aks-cluster"
  resource_group_name = "kong-aks-rg"
  location            = "eastus"

  dns_prefix = "kongaks"  # Ensure this is added

default_node_pool {
  name                         = "default"
  node_count                   = 2
  vm_size = "Standard_B2s"
  temporary_name_for_rotation  = "tempnp1"  # Fixed name
}

  identity {
    type = "SystemAssigned"
  }
}

output "kube_config" {
  value     = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive = true
}
