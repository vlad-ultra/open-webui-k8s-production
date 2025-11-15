# Unified AI Platform - Kubernetes Production Deployment

A production-ready Kubernetes deployment showcasing the integration of **343 AI models** in a single unified application, deployed on Google Kubernetes Engine (GKE) using Infrastructure as Code (IaC) principles with Terraform and Helm.

> **📌 Portfolio Project**  
> This project demonstrates advanced skills in Kubernetes orchestration, Infrastructure as Code, DevOps practices, cloud-native application deployment, and AI/ML integration at scale.

## 🎯 Project Overview

I've successfully integrated **343 AI models** from multiple providers into a single unified application and deployed it to production on Kubernetes. This project showcases a complete, production-ready deployment that includes infrastructure provisioning with Terraform, application deployment with Helm, security best practices, and seamless integration with OpenRouter API for accessing 343 AI models including GPT-4, Claude, Gemini, Mistral, Llama, and many others.

## 🌐 Live Application

**After deployment, the application is available at:**  
**https://ai-k8s.svdevops.tech/**

> **🔐 Access to AI Models**  
> To get access to the  AI models, please contact:  
> **Email:** svvados@gmail.com  
> **Subject:** AI Models Access Request  
> **DevOps Engineer** will provide detailed demonstration and explanation of how the project works.

## 🏗️ Architecture

The solution follows a cloud-native architecture with the following components:

- **Infrastructure Layer (Terraform)**
  - Google Kubernetes Engine (GKE) cluster with optimized node configuration
  - Static IP address for ingress (persistent across cluster recreations)
  - Cost-optimized node pool (2 nodes, e2-medium: 2 CPU, 4GB RAM)

- **Application Layer (Helm)**
  - Unified AI platform application deployment
  - NGINX Ingress Controller with TLS/SSL
  - Persistent volume for application data
  - Automatic database backup/restore from Google Cloud Storage

- **AI Integration**
  - OpenRouter API integration (343 models via unified API)
  - Support for OpenAI-compatible APIs (Deepseek, Groq, Together AI, etc.)
  - Flexible model selection and configuration

- **Security & Data Persistence**
  - NetworkPolicy for traffic restriction
  - RBAC configuration
  - Security contexts (non-root, read-only filesystem)
  - Secrets management best practices
  - TLS/SSL encryption
  - Automatic database backup/restore from GCS bucket
  - SSL certificates stored in GCS for reuse

## 🔧 Technical Stack

### Infrastructure
- **Terraform** >= 1.0 - Infrastructure as Code
- **Google Cloud Platform** - Cloud provider
- **Google Kubernetes Engine (GKE)** - Managed Kubernetes service
- **Kubernetes** - Container orchestration platform

### Application
- **Helm** v3.8+ - Package manager for Kubernetes
- **Unified AI Platform** - Single application integrating 343 AI models
- **NGINX Ingress Controller** - HTTP/HTTPS load balancer
- **cert-manager** - Automated TLS certificate management

### AI/ML
- **OpenRouter API** - Unified API for 343 AI models
- Support for: GPT-4, Claude, Gemini, Mistral, Llama, and many others

## 🚀 Quick Start

### Prerequisites

- Google Cloud Platform account with billing enabled
- `gcloud` CLI installed and authenticated
- `kubectl` installed
- `helm` v3.8+ installed
- `terraform` >= 1.0 installed

### Manual Deployment

#### Step 1: Deploy Infrastructure

Deploy the GKE cluster, node pool, and static IP address:

```bash
./scripts/deploy-infra.sh
```

This script will:
- Initialize Terraform (if needed)
- Import existing IP address (if exists in GCP)
- Create GKE cluster, node pool, and static IP

#### Step 2: Deploy Application

Deploy the application to Kubernetes:

```bash
./scripts/deploy-to-k8s.sh
```

This script will automatically:
- Get cluster credentials
- Install NGINX Ingress with static IP
- Install cert-manager for SSL
- Load SSL certificates from GCS bucket (or generate new ones)
- Deploy Open WebUI via Helm
- Restore database from GCS backup (if exists)
- Restore user accounts automatically

### Automated Deployment (GitHub Actions)

This project includes GitHub Actions workflows for automated deployment:

1. **Configure GitHub Secrets:**
   - `GCP_PROJECT_ID` - Your Google Cloud Project ID
   - `GCP_SA_KEY` - Service Account JSON key
   - (Optional) `OPENROUTER_API_KEY` - For 343 AI models

2. **Push to main branch** or **trigger workflow manually**

3. Workflow will automatically:
   - Backup database to GCS (if cluster exists)
   - Deploy infrastructure with Terraform
   - Deploy application with Helm
   - Restore database from GCS backup

## 📁 Project Structure

```
.
├── terraform/                    # Infrastructure as Code
│   ├── main.tf                  # Main Terraform configuration
│   ├── variables.tf             # Variable definitions
│   ├── outputs.tf               # Output definitions
│   └── versions.tf              # Provider versions
│
├── helm/                         # Helm charts
│   └── open-webui/              # Open WebUI Helm chart
│       ├── Chart.yaml           # Chart metadata
│       ├── values.yaml.example  # Example values file
│       └── templates/           # Kubernetes manifests
│
├── scripts/                      # Deployment scripts
│   ├── deploy-infra.sh          # Deploy infrastructure
│   ├── deploy-to-k8s.sh         # Deploy application
│   ├── destroy-infra.sh         # Destroy infrastructure
│   └── create-self-signed-cert.sh # SSL certificate management
│
├── backup/                       # Backup scripts
│   ├── backup-database.sh       # Backup database
│   └── restore-database.sh      # Restore database
│
└── bootstrap/                    # Bootstrap configurations
    ├── cluster-issuer.yaml      # Let's Encrypt ClusterIssuer
    └── nginx-ingress.yaml       # NGINX Ingress installation
```

## 🔑 Key Features

### Infrastructure as Code (IaC)
- Complete infrastructure defined in Terraform
- Version-controlled infrastructure configuration
- Reproducible deployments
- Static IP persistence across cluster recreations

### Data Persistence
- Automatic database backup to Google Cloud Storage (GCS)
- Automatic database restore on deployment
- SSL certificates stored in GCS for reuse
- User accounts preserved across deployments

### Security Best Practices
- Network policies for traffic isolation
- RBAC for access control
- Security contexts (non-root execution)
- Secrets management
- TLS/SSL encryption

### Cost Optimization
- Optimized node pool configuration (e2-medium: 2 CPU, 4GB RAM)
- Resource limits based on real-world usage metrics
- Efficient resource allocation

### AI Integration
- OpenRouter API integration (343 models)
- Support for multiple AI providers
- Flexible model selection
- Cost-effective API usage

## 🎯 Key Achievements

✅ **343 AI Models Integration** - Successfully unified 343 AI models from multiple providers in a single application  
✅ **Infrastructure as Code** - Complete infrastructure defined in Terraform  
✅ **Production Kubernetes Deployment** - Deployed to GKE with full production-grade configuration  
✅ **Cost Optimization** - Optimized node pool and resource allocation  
✅ **Security Best Practices** - Network policies, RBAC, security contexts  
✅ **Production Ready** - Health checks, resource limits, high availability  
✅ **Automated Backup/Restore** - Database and SSL certificates stored in GCS  
✅ **Static IP Persistence** - IP address survives cluster recreations  

## 📝 For Testers

### Accessing the Application

After deployment, the application is available at:
- **URL:** https://ai-k8s.svdevops.tech/
- **Protocol:** HTTPS (SSL/TLS encrypted)

### Getting Access to AI Models

To access the 343 AI models integrated in this platform:

1. **Contact the DevOps Engineer:**
   - **Email:** svvados@gmail.com
   - **Subject:** AI Models Access Request

2. **What you'll get:**
   - Access credentials to the platform
   - Detailed demonstration of how the project works
   - Explanation of the architecture and features
   - Technical walkthrough of the deployment process

3. **What to expect:**
   - Live demonstration of the unified AI platform
   - Overview of the 343 integrated AI models
   - Technical explanation of the Kubernetes deployment
   - Q&A session about the implementation

### Testing the Deployment

If you want to test the deployment process:

1. **Deploy Infrastructure:**
   ```bash
   ./scripts/deploy-infra.sh
   ```

2. **Deploy Application:**
   ```bash
   ./scripts/deploy-to-k8s.sh
   ```

3. **Verify Deployment:**
   ```bash
   kubectl get pods -n ai
   kubectl get ingress -n ai
   ```

4. **Access Application:**
   - Open https://ai-k8s.svdevops.tech/ in your browser
   - Contact svvados@gmail.com for access credentials

## 🔄 Backup and Restore

The deployment automatically handles backup and restore:
- **Database backups** are stored in Google Cloud Storage (GCS)
- **SSL certificates** are stored in GCS for reuse
- **Automatic restore** on deployment from GCS bucket
- User accounts and data are preserved across deployments

## 📚 Technologies Used

- **Terraform** - Infrastructure as Code
- **Kubernetes** - Container orchestration
- **Helm** - Package manager for Kubernetes
- **Google Cloud Platform** - Cloud provider
- **Google Kubernetes Engine (GKE)** - Managed Kubernetes service
- **NGINX Ingress Controller** - HTTP/HTTPS load balancer
- **cert-manager** - Automated TLS certificate management
- **OpenRouter API** - Unified API for 343 AI models

## 📝 License

This project is for educational and portfolio purposes. It demonstrates production-ready Kubernetes deployment practices, Infrastructure as Code, and DevOps best practices.

## 🔗 References

- [OpenRouter Documentation](https://openrouter.ai/docs)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Helm Documentation](https://helm.sh/docs/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [NGINX Ingress Documentation](https://kubernetes.github.io/ingress-nginx/)

---

**Contact for AI Models Access:** svvados@gmail.com  
**Live Application:** https://ai-k8s.svdevops.tech/
