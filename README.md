# Open WebUI - Kubernetes Production Deployment

Production-ready Kubernetes deployment of Open WebUI with 344+ AI models, deployed on Google Kubernetes Engine (GKE) using Infrastructure as Code (IaC) with Terraform and Helm, fully automated through GitHub Actions CI/CD.

> **Live Application:** https://ai.svdevops.tech/

## 🚀 Quick Start

The entire deployment is automated through GitHub Actions. Simply push to `main` branch and the infrastructure + application will be deployed automatically.

**Prerequisites:**
- GitHub Secrets configured: `GCP_PROJECT_ID`, `GCP_SA_KEY`, `OPENROUTER_API_KEY`
- GCS bucket for backups: `open-webui-backups`
- DNS A record pointing to static IP

## 📋 Project Overview

This project demonstrates a complete, production-ready Kubernetes deployment with:

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
│   ├── create-self-signed-cert.sh # SSL certificate creation
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
4. **Verifies restore** - checks for users after restoration

### Manual Backup

To manually backup the database:

```bash
kubectl exec -n ai <pod-name> -- sqlite3 /app/backend/data/webui.db ".backup /tmp/webui.db"
kubectl cp ai/<pod-name>:/tmp/webui.db ./webui_backup.db
gsutil cp ./webui_backup.db gs://open-webui-backups/latest.db
```

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
- Check if namespace exists: `kubectl get namespace ai`

### Pods not starting
- Check pod logs: `kubectl logs -n ai -l app.kubernetes.io/name=open-webui`
- Check initContainer logs for database restore issues
- Verify GCS bucket access for backups

### SSL certificate issues
- Verify certificates exist in GCS: `gsutil ls gs://open-webui-backups/certs/`
- Check Ingress status: `kubectl get ingress -n ai`
- Verify domain DNS points to static IP

### Database not restoring
- Check initContainer logs for restore errors
- Verify backup exists: `gsutil ls gs://open-webui-backups/latest.db`
- Check GCS bucket permissions

## 📚 References

- [OpenRouter Documentation](https://openrouter.ai/docs)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Helm Documentation](https://helm.sh/docs/)
- [NGINX Ingress Documentation](https://kubernetes.github.io/ingress-nginx/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

## 📧 Contact

For questions or access to AI models:
- **Email:** svvados@gmail.com
- **Live Application:** https://ai.svdevops.tech/

---

**License:** This project is for educational and portfolio purposes.
