# Kong AI Gateway with Azure OpenAI

## Overview
Deploys Kong Gateway on AKS to route LLM traffic to Azure OpenAI, with authentication, rate limiting, and monitoring.

## Prerequisites
- Azure subscription
- Tools: Terraform, Azure CLI, Helm, kubectl

## Deployment
1. Authenticate: `az login`
2. Run: `cd scripts && ./deploy.sh`
3. Note the Kong Proxy IP from output.

## Milestones
- Kong Gateway on AKS
- JWT auth with Azure Key Vault
- Rate limiting (100/min), caching (300s)
- Prometheus and Azure Log Analytics

## Troubleshooting
- Check AKS status: `kubectl get pods -n kong`
- Verify OpenAI endpoint: `terraform output openai_endpoint`
