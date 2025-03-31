output "openai_endpoint" {
  value = azurerm_cognitive_account.openai.endpoint
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "openai_name" {
  value = azurerm_cognitive_account.openai.name
}
