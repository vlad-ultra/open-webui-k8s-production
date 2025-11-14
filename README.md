# Unified AI Platform - Kubernetes Production Deployment

A production-ready Kubernetes deployment showcasing the integration of **344 AI models** in a single unified application, deployed on Google Kubernetes Engine (GKE) using Infrastructure as Code (IaC) principles with Terraform and Helm.

> **📌 Portfolio Project**  
> This project demonstrates advanced skills in Kubernetes orchestration, Infrastructure as Code, DevOps practices, cloud-native application deployment, and AI/ML integration at scale.

## 🎯 Project Overview

I've successfully integrated **344 AI models** from multiple providers into a single unified application and deployed it to production on Kubernetes. This project showcases a complete, production-ready deployment that includes infrastructure provisioning with Terraform, application deployment with Helm, security best practices, and seamless integration with OpenRouter API for accessing 344+ AI models including GPT-4, Claude, Gemini, Mistral, Llama, and many others.

## 🏗️ Architecture

The solution follows a cloud-native architecture with the following components:

- **Infrastructure Layer (Terraform)**
  - Google Kubernetes Engine (GKE) cluster with optimized node configuration
  - Static IP address for ingress (persistent across cluster recreations)
  - Cost-optimized node pool (2 nodes, e2-medium: 2 CPU, 4GB RAM)

- **Application Layer (Helm)**
  - Unified AI platform application deployment
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
- **Unified AI Platform** - Single application integrating 344+ AI models
- **NGINX Ingress Controller** - HTTP/HTTPS load balancer
- **cert-manager** - Automated TLS certificate management

### AI/ML
- **OpenRouter API** - Unified API for 344+ AI models
- Support for: GPT-4, Claude, Gemini, Mistral, Llama, and many others


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

Deploy the unified AI platform to Kubernetes:

```bash
helm upgrade --install open-webui ./helm/open-webui \
  -n ai \
  -f ./helm/open-webui/values.yaml.local \
  --create-namespace
```

## 🌐 Live Demo

**View the application:** [https://ai.svdevops.tech]


## 📚 Technologies Used

- **Terraform** - Infrastructure as Code
- **Kubernetes** - Container orchestration
- **Helm** - Package manager for Kubernetes
- **Google Cloud Platform** - Cloud provider
- **Google Kubernetes Engine (GKE)** - Managed Kubernetes service
- **NGINX Ingress Controller** - HTTP/HTTPS load balancer
- **cert-manager** - Automated TLS certificate management
- **Unified AI Platform** - Single application integrating 344+ AI models
- **OpenRouter API** - Unified API for AI models

## 🎯 Key Achievements

✅ **344 AI Models Integration** - Successfully unified 344+ AI models from multiple providers in a single application  
✅ **Infrastructure as Code** - Complete infrastructure defined in Terraform  
✅ **Production Kubernetes Deployment** - Deployed to GKE with full production-grade configuration  
✅ **Cost Optimization** - Optimized node pool and resource allocation  
✅ **Security Best Practices** - Network policies, RBAC, security contexts  
✅ **Production Ready** - Health checks, resource limits, high availability  
✅ **Scalability** - HPA, PDB, flexible storage configuration  
✅ **Automated TLS** - Let's Encrypt certificates via cert-manager  
✅ **Static IP Persistence** - IP address survives cluster recreations  

## 📝 License

This project is for educational and portfolio purposes. It demonstrates production-ready Kubernetes deployment practices, Infrastructure as Code, and DevOps best practices.

## 🔗 References

- [OpenRouter Documentation](https://openrouter.ai/docs)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Helm Documentation](https://helm.sh/docs/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [NGINX Ingress Documentation](https://kubernetes.github.io/ingress-nginx/)
