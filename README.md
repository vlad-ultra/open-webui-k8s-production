# Open WebUI on Kubernetes - Production Deployment

A production-ready deployment of [Open WebUI](https://github.com/open-webui/open-webui) on Google Kubernetes Engine (GKE) using Infrastructure as Code (IaC) principles with Terraform and Helm.

> **📌 Portfolio Project**  
> This project is part of my portfolio and demonstrates skills in Kubernetes, Infrastructure as Code, DevOps practices, and cloud-native application deployment.

## 🎯 Project Overview

This project demonstrates a complete, production-ready Kubernetes deployment of Open WebUI - an extensible, feature-rich, and user-friendly LLM (Large Language Model) chatting UI. The deployment includes infrastructure provisioning with Terraform, application deployment with Helm, security best practices, and integration with OpenRouter API for accessing 344+ AI models.

## 🏗️ Architecture

The solution follows a cloud-native architecture with the following components:

- **Infrastructure Layer (Terraform)**
  - Google Kubernetes Engine (GKE) cluster with optimized node configuration
  - Static IP address for ingress (persistent across cluster recreations)
  - Cost-optimized node pool (2 nodes, e2-medium: 2 CPU, 4GB RAM)

- **Application Layer (Helm)**
  - Open WebUI application deployment
  - NGINX Ingress Controller with TLS/SSL (Let's Encrypt via cert-manager)
  - Persistent volume for application data
  - Resource limits optimized based on real-world usage metrics

- **AI Integration**
  - OpenRouter API integration (344+ models via unified API)
  - Support for OpenAI-compatible APIs (Deepseek, Groq, Together AI, etc.)
  - Flexible model selection and configuration

- **Security**
  - NetworkPolicy for traffic restriction
  - RBAC configuration
  - Security contexts (non-root, read-only filesystem)
  - Secrets management best practices
  - TLS/SSL encryption

## 🔧 Technical Stack

### Infrastructure
- **Terraform** >= 1.0 - Infrastructure as Code
- **Google Cloud Platform** - Cloud provider
- **Google Kubernetes Engine (GKE)** - Managed Kubernetes service
- **Kubernetes** - Container orchestration platform

### Application
- **Helm** v3.8+ - Package manager for Kubernetes
- **Open WebUI** - LLM chatting UI
- **NGINX Ingress Controller** - HTTP/HTTPS load balancer
- **cert-manager** - Automated TLS certificate management

### AI/ML
- **OpenRouter API** - Unified API for 344+ AI models
- Support for: GPT-4, Claude, Gemini, Mistral, Llama, and many others

## 📋 Project Configuration

- **GCP Project ID**: Configure in `terraform/terraform.tfvars` (example: `your-project-id`)
- **Cluster Name**: `open-webui-cluster` (configurable)
- **Domain**: Configure in `helm/open-webui/values.yaml` (example: `ai.svdevops.tech`)
- **Namespace**: `ai` (configurable)
- **Node Pool**: 2 nodes, `e2-medium` (2 CPU, 4GB RAM per node)
- **Storage**: 20GB disk per node, standard persistent disk
- **AI Provider**: OpenRouter API (344+ models)

## 🚀 Key Features

### Infrastructure as Code (IaC)
- Complete infrastructure defined in Terraform
- Version-controlled infrastructure configuration
- Reproducible deployments
- Static IP persistence across cluster recreations

### Cost Optimization
- Optimized node pool configuration (e2-medium: 2 CPU, 4GB RAM)
- Resource limits based on real-world usage metrics
- Efficient resource allocation
- Removed unnecessary components (Ollama local deployment)

### Security Best Practices
- Network policies for traffic isolation
- RBAC for access control
- Security contexts (non-root execution)
- Secrets management (values.yaml.local in .gitignore)
- TLS/SSL encryption with Let's Encrypt

### Scalability
- Horizontal Pod Autoscaler (HPA) ready
- Pod Disruption Budget (PDB) for high availability
- Flexible storage configuration (RWO/RWX support)

### AI Integration
- OpenRouter API integration (344+ models)
- Support for multiple AI providers
- Flexible model selection
- Cost-effective API usage

## 📁 Project Structure

```
.
├── terraform/                    # Infrastructure as Code
│   ├── main.tf                  # Main Terraform configuration
│   ├── variables.tf             # Variable definitions
│   ├── outputs.tf               # Output definitions
│   ├── versions.tf              # Provider versions
│   ├── terraform.tfvars.example # Example variables file
│   └── .gitignore               # Terraform gitignore
│
├── helm/                         # Helm charts
│   └── open-webui/              # Open WebUI Helm chart
│       ├── Chart.yaml           # Chart metadata
│       ├── values.yaml          # Default values
│       ├── values.yaml.example  # Example values file
│       └── templates/           # Kubernetes manifests
│           ├── _helpers.tpl     # Template helpers
│           ├── namespace.yaml   # Namespace
│           ├── secret.yaml      # Secrets
│           ├── configmap.yaml   # ConfigMap
│           ├── serviceaccount.yaml  # ServiceAccount
│           ├── pvc.yaml         # PersistentVolumeClaim
│           ├── deployment.yaml  # Deployment
│           ├── service.yaml     # Service
│           ├── ingress.yaml     # Ingress
│           ├── networkpolicy.yaml   # NetworkPolicy
│           ├── hpa.yaml         # HorizontalPodAutoscaler
│           └── pdb.yaml         # PodDisruptionBudget
│
├── bootstrap/                    # Bootstrap configurations
│   ├── cert-manager.yaml        # cert-manager installation
│   ├── cluster-issuer.yaml      # Let's Encrypt ClusterIssuer
│   └── nginx-ingress.yaml       # NGINX Ingress installation
│
└── README.md                     # This file
```

## 🚀 Quick Start

### Prerequisites

- Google Cloud Platform account with billing enabled
- `gcloud` CLI installed and configured
- `terraform` >= 1.0 installed
- `kubectl` installed
- `helm` v3.8+ installed
- Domain name (configure DNS records after deployment)
- DNS access for configuring records
- OpenRouter API key (or other OpenAI-compatible API key)

### Step 1: Set Up GKE Cluster with Terraform

```bash
# Navigate to terraform directory
cd terraform

# Configure variables (edit terraform.tfvars)
# Copy terraform.tfvars.example to terraform.tfvars and update values

# Authenticate with Google Cloud
gcloud auth login
gcloud auth application-default login

# Set your project (replace with your actual project ID from terraform.tfvars)
gcloud config set project $(cd terraform && grep project_id terraform.tfvars | cut -d'"' -f2)

# Initialize Terraform
terraform init

# Review changes
terraform plan

# Create cluster (2 nodes, e2-medium: 2 CPU, 4GB RAM)
terraform apply

# Get cluster credentials
terraform output -raw kubectl_command | bash

# Verify cluster
kubectl get nodes
```

### Step 2: Install NGINX Ingress Controller

```bash
# Get the static IP address from Terraform
export INGRESS_IP=$(cd terraform && terraform output -raw ingress_ip)
echo "Static IP: $INGRESS_IP"

# Add Helm repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install NGINX Ingress with static IP
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.service.annotations."cloud\.google\.com/load-balancer-type"="External" \
  --set controller.service.loadBalancerIP="$INGRESS_IP"

# Wait for LoadBalancer to get the static IP
kubectl get svc -n ingress-nginx ingress-nginx-controller -w
```

### Step 3: Configure DNS

```bash
# Get the static IP address
export INGRESS_IP=$(cd terraform && terraform output -raw ingress_ip)
echo "Static IP: $INGRESS_IP"

# Update your DNS records to point to the static IP
# Create an A record for your domain:
# Name: <subdomain> (e.g., "ai" for ai.example.com)
# Type: A
# Value: $INGRESS_IP
# TTL: 300

# Verify DNS resolution (replace with your domain)
# dig your-domain.com +short
```

### Step 4: Install cert-manager

```bash
# Install cert-manager CRDs
# Check latest version at: https://github.com/cert-manager/cert-manager/releases
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for cert-manager to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s

# Create ClusterIssuer for Let's Encrypt
kubectl apply -f bootstrap/cluster-issuer.yaml

# Verify ClusterIssuer
kubectl get clusterissuer letsencrypt-prod
```

### Step 5: Configure Secrets

```bash
# Copy example values file
cp helm/open-webui/values.yaml.example helm/open-webui/values.yaml.local

# Edit values.yaml.local and add your OpenRouter API key
# OpenRouter API key: https://openrouter.ai/keys
# API Base URL: https://openrouter.ai/api/v1
```

**Important**: Never commit `values.yaml.local` to Git. It's in `.gitignore` for security.

### Step 6: Deploy Open WebUI

```bash
# Install Open WebUI
helm upgrade --install open-webui ./helm/open-webui \
  -n ai \
  -f ./helm/open-webui/values.yaml.local \
  --create-namespace

# Check deployment status
kubectl get pods -n ai
kubectl get ingress -n ai
```

### Step 7: Verify Deployment

```bash
# Check pods
kubectl get pods -n ai

# Check services
kubectl get svc -n ai

# Check ingress
kubectl get ingress -n ai

# Check TLS certificate
kubectl get certificate -n ai

# Access the application (replace with your domain)
curl -I https://your-domain.com
```

## 🔒 Security

### Secrets Management

**⚠️ CRITICAL**: Never commit secrets to Git!

This project uses secure secret management practices:

1. **Local Secrets**: Use `values.yaml.local` (in `.gitignore`)
2. **GitHub Secrets**: For CI/CD via GitHub Actions
3. **External Secrets Operator**: For production with GCP Secret Manager
4. **Kubernetes Secrets**: Created manually or via operators

All API keys and sensitive information must be stored in `values.yaml.local` which is excluded from version control.

### Network Security

- NetworkPolicy enabled for traffic isolation
- Ingress traffic restricted to HTTPS only
- Egress traffic controlled for security

### Application Security

- Non-root user execution (UID 1000)
- Read-only root filesystem (except data directory)
- Dropped capabilities
- No privilege escalation
- RBAC configured

## 🔧 Configuration

### Resource Limits

Optimized resource limits based on real-world usage:

- **Requests**: 256Mi memory, 100m CPU
- **Limits**: 1Gi memory, 500m CPU
- **Real Usage**: ~618Mi memory, ~6m CPU

### Node Configuration

- **Machine Type**: `e2-medium` (2 CPU, 4GB RAM)
- **Node Count**: 2 nodes
- **Disk Size**: 20GB per node
- **Disk Type**: `pd-standard`

### AI Provider Configuration

- **Default**: OpenRouter API (344+ models)
- **API Base URL**: `https://openrouter.ai/api/v1`
- **Alternative**: Any OpenAI-compatible API (Deepseek, Groq, Together AI, etc.)

## 🐛 Troubleshooting

### Pods Not Starting

```bash
# Check pod logs
kubectl logs -n ai -l app.kubernetes.io/name=open-webui

# Check pod events
kubectl describe pod -n ai -l app.kubernetes.io/name=open-webui

# Check resource usage
kubectl top pods -n ai
```

### Ingress Not Working

```bash
# Check ingress status
kubectl describe ingress -n ai open-webui

# Check NGINX ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# Verify DNS (replace with your domain)
dig your-domain.com +short
```

### TLS Certificate Issues

```bash
# Check certificate status
kubectl get certificate -n ai
kubectl describe certificate -n ai open-webui-tls

# Check cert-manager logs
kubectl logs -n cert-manager -l app.kubernetes.io/instance=cert-manager

# Check ClusterIssuer
kubectl get clusterissuer letsencrypt-prod
kubectl describe clusterissuer letsencrypt-prod
```

### Resource Issues

```bash
# Check resource usage
kubectl top nodes
kubectl top pods -n ai

# Check resource quotas
kubectl get resourcequota -n ai
kubectl describe resourcequota -n ai
```

## 🗑️ Cleanup

### Delete Cluster (Terraform)

```bash
# Navigate to terraform directory
cd terraform

# Delete all resources created by Terraform
terraform destroy

# Or with auto-approve
terraform destroy -auto-approve
```

**Note**: The static IP address is protected from deletion (`lifecycle.prevent_destroy = true`) and will persist even after cluster deletion.

### Delete Cluster (gcloud)

```bash
# Delete cluster (replace with your actual project ID and zone)
gcloud container clusters delete open-webui-cluster \
  --project=$(cd terraform && grep project_id terraform.tfvars | cut -d'"' -f2) \
  --zone=$(cd terraform && grep zone terraform.tfvars | cut -d'"' -f2) \
  --quiet
```

### Delete Application

```bash
# Delete Helm release
helm uninstall open-webui -n ai

# Delete namespace
kubectl delete namespace ai

# Delete secrets
kubectl delete secret -n ai open-webui-secrets

# Delete PVC (optional)
kubectl delete pvc -n ai open-webui-pvc
```

## 📚 Technologies Used

- **Terraform** - Infrastructure as Code
- **Kubernetes** - Container orchestration
- **Helm** - Package manager for Kubernetes
- **Google Cloud Platform** - Cloud provider
- **Google Kubernetes Engine (GKE)** - Managed Kubernetes service
- **NGINX Ingress Controller** - HTTP/HTTPS load balancer
- **cert-manager** - Automated TLS certificate management
- **Open WebUI** - LLM chatting UI
- **OpenRouter API** - Unified API for AI models

## 🎯 Key Achievements

✅ **Infrastructure as Code** - Complete infrastructure defined in Terraform  
✅ **Cost Optimization** - Optimized node pool and resource allocation  
✅ **Security Best Practices** - Network policies, RBAC, security contexts  
✅ **Production Ready** - Health checks, resource limits, high availability  
✅ **Scalability** - HPA, PDB, flexible storage configuration  
✅ **AI Integration** - OpenRouter API with 344+ models  
✅ **Automated TLS** - Let's Encrypt certificates via cert-manager  
✅ **Static IP Persistence** - IP address survives cluster recreations  

## 📝 License

This project is for educational and portfolio purposes. It demonstrates production-ready Kubernetes deployment practices, Infrastructure as Code, and DevOps best practices.

## 🔗 References

- [Open WebUI Documentation](https://github.com/open-webui/open-webui)
- [OpenRouter Documentation](https://openrouter.ai/docs)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Helm Documentation](https://helm.sh/docs/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [NGINX Ingress Documentation](https://kubernetes.github.io/ingress-nginx/)
