#!/bin/bash
set -e

echo "Initializing Terraform..."
cd ../terraform
terraform init

echo "Deploying infrastructure..."
terraform apply -auto-approve

echo "Configuring AKS credentials..."
az aks get-credentials --resource-group kong-openai-rg --name kong-aks

echo "Installing Helm and Kong..."
helm repo add kong https://charts.konghq.com
helm repo update

# Uninstall existing Kong release if it exists
if helm list -n kong | grep -q "kong"; then
  echo "Uninstalling existing Kong release..."
  helm uninstall kong -n kong
fi

helm install kong kong/kong --namespace kong --create-namespace \
  --set ingressController.enabled=true \
  --set admin.enabled=true \
  --set admin.http.enabled=true \
  --set proxy.enabled=true \
  --set proxy.type=LoadBalancer

echo "Waiting for Kong proxy to be ready..."
MAX_ATTEMPTS=30
ATTEMPT=1
until kubectl get svc -n kong kong-kong-proxy >/dev/null 2>&1; do
  if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
    echo "Error: kong-kong-proxy service not found after $MAX_ATTEMPTS attempts."
    exit 1
  fi
  echo "Attempt $ATTEMPT/$MAX_ATTEMPTS: Waiting for kong-kong-proxy service to be created..."
  sleep 10
  ATTEMPT=$((ATTEMPT + 1))
done
until KONG_IP=$(kubectl get svc -n kong kong-kong-proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null) && [ -n "$KONG_IP" ]; do
  if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
    echo "Error: Kong proxy IP not available after $MAX_ATTEMPTS attempts."
    exit 1
  fi
  echo "Attempt $ATTEMPT/$MAX_ATTEMPTS: Waiting for kong-kong-proxy IP..."
  sleep 10
  ATTEMPT=$((ATTEMPT + 1))
done
echo "Kong Proxy IP: $KONG_IP"

echo "Applying Kong configuration..."
OPENAI_NAME=$(terraform output -raw openai_name)
sed -i "s/REPLACE_WITH_OPENAI_NAME/$OPENAI_NAME/g" ../kong_config/kong_config.yaml
kubectl apply -f ../kong_config/kong_config.yaml

echo "Installing Prometheus..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/prometheus --namespace kong

echo "Configuring Azure Log Analytics..."
WORKSPACE_ID=$(az resource show -g kong-openai-rg -n kong-openai-logs --resource-type Microsoft.OperationalInsights/workspaces --query id -o tsv)
AKS_ID=$(az aks show -g kong-openai-rg -n kong-aks --query id -o tsv)
az monitor diagnostic-settings create \
  --resource $AKS_ID \
  --workspace $WORKSPACE_ID \
  --name "kong-diagnostics" \
  --logs '[{"category": "kube-apiserver", "enabled": true}]'

echo "Deployment complete! Kong IP: $KONG_IP"
