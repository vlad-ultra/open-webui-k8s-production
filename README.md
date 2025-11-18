# Unified AI Platform - Kubernetes Production Deployment

A production-ready Kubernetes deployment showcasing the integration of **344+ AI models** in a single unified application, deployed on Google Kubernetes Engine (GKE) using Infrastructure as Code (IaC) principles with Terraform and Helm, fully automated through GitHub Actions CI/CD.

> **Portfolio Project**  
> This project demonstrates advanced skills in Kubernetes orchestration, Infrastructure as Code, DevOps practices, cloud-native application deployment, CI/CD automation, and AI/ML integration at scale.

> **Live Application:** https://ai.svdevops.tech/

## How to Test This Project

After the infrastructure is deployed, you can create a user account and use any of the modern AI models like ChatGPT, Gemini, Claude, and many others. I've integrated 344+ AI models that you can test.

**Popular models available:**
- GPT-4, GPT-4 Turbo, GPT-3.5 Turbo (OpenAI)
- Claude 3 Opus, Claude 3 Sonnet, Claude 3 Haiku (Anthropic)
- Gemini Pro, Gemini Ultra (Google)
- Llama 2, Llama 3 (Meta)
- Mistral Large, Mistral Medium, Mixtral (Mistral AI)
- And 330+ more models from various providers

**To get access to test these models:**
Write me an email at **svvados@gmail.com** and I'll give you access to these models so you can test them.

**DevOps Skills Demonstration:**

I can also show you how I completely destroy the entire infrastructure as if nothing ever existed, and then redeploy everything. During this process, all users are preserved and restored automatically. This demonstrates my DevOps skills as a **Middle DevOps Engineer** who can work with complex integration systems.

The demonstration includes:
- Complete infrastructure destruction (GKE cluster removal)
- Automatic data backup to Google Cloud Storage
- Complete infrastructure recreation via GitHub Actions
- Automatic data restoration from backup
- All users and their data are back exactly as before

This showcases:
- Infrastructure as Code expertise
- Automated backup and restore mechanisms
- CI/CD pipeline automation
- Disaster recovery capabilities
- Production-ready DevOps practices
- Ability to work with complex multi-component systems

**To request a live demonstration:**
Email me at **svvados@gmail.com** with subject "DevOps Skills Demonstration Request" and I'll show you the complete workflow in action.

## Integration and High Availability Capabilities

As a **Middle DevOps Engineer**, I can create integrations between any services and configure fully fault-tolerant infrastructure. This project demonstrates my ability to:

- **Service Integration** - Connect any services with each other, regardless of their technology stack or deployment model
- **API Integration** - Integrate REST APIs, GraphQL, gRPC, message queues, and other communication protocols
- **Microservices Architecture** - Design and implement microservices that can communicate seamlessly
- **Fault-Tolerant Infrastructure** - Configure high availability, load balancing, auto-scaling, and disaster recovery
- **Multi-Cloud Integration** - Connect services across different cloud providers and on-premises systems
- **Data Pipeline Integration** - Set up data flows between databases, data warehouses, message brokers, and analytics platforms
- **Third-Party Service Integration** - Integrate external services, webhooks, and APIs into existing infrastructure

This project showcases a real-world example where I've integrated:
- Kubernetes cluster with Google Cloud Storage
- Application with OpenRouter API (344+ AI models)
- Automated backup/restore mechanisms
- SSL certificate management
- CI/CD pipeline with infrastructure provisioning

I can apply these same principles to integrate any services you need - whether it's connecting your application with payment gateways, notification services, analytics platforms, databases, or any other third-party or internal services. The infrastructure is designed to be fault-tolerant with automatic failover, data replication, and disaster recovery capabilities.

## Project Overview

I've successfully integrated **344+ AI models** from multiple providers into a single unified application and deployed it to production on Kubernetes with full CI/CD automation. This project showcases a complete, production-ready deployment that includes:

- **Infrastructure provisioning** with Terraform (GKE cluster, static IP)
- **Simplified application deployment** with Helm charts (~220 lines deployment script)
- **Fully automated CI/CD** through GitHub Actions
- **Automatic database backup/restore** from Google Cloud Storage
- **Let's Encrypt SSL certificates** stored in GCS bucket
- **Zero-downtime deployments** with rolling updates
- **Integrated 344+ AI models** via OpenRouter API

## 🏗️ Architecture

### Infrastructure Layer (Terraform)
- **Google Kubernetes Engine (GKE)** cluster
- **Node Pool** with optimized configuration
- **Static IP address** - persists across cluster recreations
- **GCP APIs** enabled automatically

### Application Layer (Helm)
- **Open WebUI Application** - unified AI platform
- **NGINX Ingress Controller** - HTTP/HTTPS load balancer
- **Let's Encrypt SSL certificates** - loaded from GCS bucket
- **Persistent Volume** - application data storage (10Gi, ReadWriteMany)
- **Automatic Database Restore** - via initContainer from GCS

### CI/CD Layer (GitHub Actions)
- **Automated Infrastructure Deployment** - Terraform apply
- **Automated Application Deployment** - simplified Helm deployment
- **Error Handling** - automatic diagnostics on failure
- **Status Verification** - pod and ingress checks

### Data & Security
- **NetworkPolicy** - traffic isolation
- **RBAC** - role-based access control
- **Secrets Management** - Kubernetes secrets with proper handling
- **TLS/SSL Encryption** - end-to-end encryption
- **Automatic Backup/Restore** - database and SSL certificates in GCS
- **Static IP Persistence** - survives cluster recreations

## 🔄 Deployment Process

The deployment consists of two sequential GitHub Actions jobs:

### Job 1: Create Infrastructure

**Steps:**
1. Authenticate to Google Cloud
2. Set up Terraform
3. Deploy infrastructure via `scripts/deploy-infra.sh`:
   - Creates GKE cluster
   - Creates node pool
   - Creates/reuses static IP
   - Enables required GCP APIs

### Job 2: Deploy Application to Kubernetes

**Steps:**
1. Authenticate to Google Cloud
2. Set up Helm and kubectl
3. Deploy application via simplified `scripts/deploy-to-k8s.sh`:
   - **Step 1:** Get cluster credentials
   - **Step 2:** Get static IP address
   - **Step 3:** Install/Upgrade NGINX Ingress
   - **Step 4:** Load SSL certificates from GCS
   - **Step 5:** Install NFS provisioner (if needed)
   - **Step 6:** Create namespace and secrets
   - **Step 7:** Prepare Helm values
   - **Step 8:** Deploy with Helm
   - **Step 9:** Wait for pods to be ready
   - **Step 10:** Verify rollout

**Key Simplifications:**
- No complex retry logic - simple and fast
- Automatic namespace metadata handling
- Streamlined certificate loading from GCS
- Fast pod startup with optimized health checks

## 📁 Project Structure

```
.
├── .github/
│   └── workflows/
│       ├── deploy.yml              # Main deployment workflow (simplified)
│       └── destroy.yml             # Infrastructure destruction workflow
│
├── terraform/                      # Infrastructure as Code
│   ├── main.tf                    # Main Terraform configuration
│   ├── variables.tf               # Variable definitions
│   ├── outputs.tf                 # Output definitions
│   └── versions.tf                # Provider versions
│
├── helm/                          # Helm charts
│   └── open-webui/
│       ├── Chart.yaml             # Chart metadata
│       ├── values.yaml            # Default values
│       ├── values.yaml.example    # Example values template
│       └── templates/             # Kubernetes manifests
│           ├── deployment.yaml    # Application deployment
│           ├── service.yaml       # Service definition
│           ├── ingress.yaml       # Ingress configuration
│           ├── pvc.yaml           # Persistent volume claim
│           └── ...                # Other resources
│
├── scripts/                       # Deployment scripts
│   ├── deploy-infra.sh            # Infrastructure deployment
│   ├── deploy-to-k8s.sh           # Simplified app deployment (~220 lines)
│   ├── destroy-infra.sh           # Infrastructure destruction
│   ├── create-self-signed-cert.sh # SSL certificate creation/loading
│   └── install-nfs-provisioner.sh # NFS provisioner installation
│
└── README.md                      # This file
```

## ⚙️ Configuration

### GitHub Secrets

Required secrets in GitHub repository settings:

- **`GCP_PROJECT_ID`** - Google Cloud Project ID
- **`GCP_SA_KEY`** - Service Account JSON key with permissions:
  - `roles/container.admin`
  - `roles/compute.admin`
  - `roles/storage.admin`
- **`OPENROUTER_API_KEY`** (optional) - API key for 344+ AI models

### Environment Variables

Default values (can be overridden in workflow):

```yaml
GCP_REGION: europe-west1
GCP_ZONE: europe-west1-b
CLUSTER_NAME: open-webui-cluster
NAMESPACE: ai
BACKUP_BUCKET: open-webui-backups
DOMAIN: ai.svdevops.tech
```

### DNS Configuration

DNS A record must point to the static IP:
- **Domain:** `ai.svdevops.tech`
- **Type:** A
- **Value:** Static IP (assigned by Terraform)

### SSL Certificates

Let's Encrypt certificates are stored in GCS bucket:
- **Path:** `gs://open-webui-backups/certs/ai.svdevops.tech.crt` and `.key`
- **Auto-loaded** on each deployment
- If certificates don't exist, self-signed certificates are generated

## 🗄️ Database Backup & Restore

### Automatic Restore

The deployment automatically restores the database via `initContainer`:

1. **Checks existing database** - if users exist, skips restore
2. **Downloads from GCS** - `gs://open-webui-backups/latest.db`
3. **Restores to PVC** - `/app/backend/data/webui.db`
4. **Verifies restore** - checks for users after restoration (shows user count if successful)

Database backup/restore scripts are available in the `backup/` directory for manual operations.

## 🚀 Features

### Infrastructure as Code
- Complete Terraform configuration
- Version-controlled infrastructure
- Reproducible deployments
- Static IP persistence

### Simplified CI/CD
- Fast deployment script (~220 lines)
- Streamlined GitHub Actions workflow
- Automatic error diagnostics
- Status verification

### Data Persistence
- Automatic database restore on deployment
- SSL certificates stored in GCS
- User accounts preserved across deployments
- ReadWriteMany storage for zero-downtime

### Security
- Network policies for traffic isolation
- RBAC configuration
- Secrets management
- TLS/SSL encryption
- Let's Encrypt certificates

### Application
- **344+ AI Models** via OpenRouter API
- OpenAI-compatible API
- Health checks (startup, readiness, liveness)
- Optimized resource allocation
- Fast startup with optimized initContainer

## 🔧 Technical Stack

### Infrastructure
- **Terraform** >= 1.0
- **Google Cloud Platform**
- **Google Kubernetes Engine (GKE)**
- **Kubernetes**

### CI/CD
- **GitHub Actions**
- **GitHub Secrets**

### Application Deployment
- **Helm** v3.12.0
- **NGINX Ingress Controller**
- **Let's Encrypt** (certificates from GCS)

### Application
- **Open WebUI** - LLM chatting UI
- **OpenRouter API** - unified API for 344+ AI models
- **SQLite** - database with automatic backup/restore

## 📊 Deployment Flow

```
GitHub Push to main branch
    ↓
GitHub Actions Workflow Starts
    ↓
Job 1: Create Infrastructure
    ├─→ Authenticate to GCP
    ├─→ Terraform Apply
    │   ├─→ Create GKE Cluster
    │   ├─→ Create Node Pool
    │   └─→ Create/Reuse Static IP
    └─→ Infrastructure Ready
    ↓
Job 2: Deploy Application
    ├─→ Authenticate to GCP
    ├─→ Get Cluster Credentials
    ├─→ Install NGINX Ingress
    ├─→ Load SSL Certificates from GCS
    ├─→ Install NFS Provisioner (if needed)
    ├─→ Create Namespace & Secrets
    ├─→ Prepare Helm Values
    ├─→ Deploy with Helm
    │   ├─→ InitContainer Restores Database
    │   ├─→ Application Pod Starts
    │   └─→ Health Checks Pass
    └─→ Application Ready
    ↓
Application Available at:
https://ai.svdevops.tech/
```

## 🎯 Key Achievements

- **Simplified Deployment** - reduced from 730+ to ~220 lines
- **Faster Startup** - optimized initContainer and health checks
- **Zero-Downtime** - rolling updates with ReadWriteMany storage
- **Automatic Backup/Restore** - database and SSL certificates
- **Let's Encrypt Integration** - certificates from GCS bucket
- **Production Ready** - health checks, resource limits, security policies

## 🔍 Troubleshooting

### Deployment fails with namespace error
- Namespace metadata is automatically added by deployment script
- The deployment script handles namespace metadata automatically

### Pods not starting
- InitContainer logs show database restore status
- Verify GCS bucket access for backups and certificates

### SSL certificate issues
- Certificates are automatically loaded from GCS bucket
- Verify domain DNS points to static IP address
- Certificates are stored at `gs://open-webui-backups/certs/`

### Database not restoring
- InitContainer automatically restores database from GCS
- Backup location: `gs://open-webui-backups/latest.db`
- Database restore is verified after completion (checks for users)

## 📚 References

- [OpenRouter Documentation](https://openrouter.ai/docs)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Helm Documentation](https://helm.sh/docs/)
- [NGINX Ingress Documentation](https://kubernetes.github.io/ingress-nginx/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

## 📧 Accessing the Application

After deployment, the application is available at:
- **URL:** https://ai.svdevops.tech/
- **Protocol:** HTTPS (SSL/TLS encrypted)

You can verify the deployment by:
1. Opening the URL in your browser
2. Checking that the page loads with SSL encryption
3. Verifying the domain resolves correctly
4. Contact svvados@gmail.com for access credentials to test AI models

### Getting Access to AI Models

To access the 344+ AI models integrated in this platform:

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
   - Overview of the 344+ integrated AI models
   - Technical explanation of the Kubernetes deployment
   - Q&A session about the implementation

---

**Contact for AI Models Access:** svvados@gmail.com  
**Live Application:** https://ai.svdevops.tech/  
**Portfolio Project** - Demonstrates DevOps expertise with Kubernetes, Infrastructure as Code, and CI/CD automation
