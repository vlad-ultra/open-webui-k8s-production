# Unified AI Platform - Kubernetes Production Deployment

A production-ready Kubernetes deployment showcasing the integration of **343 AI models** in a single unified application, deployed on Google Kubernetes Engine (GKE) using Infrastructure as Code (IaC) principles with Terraform and Helm, fully automated through GitHub Actions CI/CD.

> **Portfolio Project**  
> This project demonstrates advanced skills in Kubernetes orchestration, Infrastructure as Code, DevOps practices, cloud-native application deployment, CI/CD automation, and AI/ML integration at scale.

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
- Application with OpenRouter API (343 AI models)
- Automated backup/restore mechanisms
- SSL certificate management
- CI/CD pipeline with infrastructure provisioning

I can apply these same principles to integrate any services you need - whether it's connecting your application with payment gateways, notification services, analytics platforms, databases, or any other third-party or internal services. The infrastructure is designed to be fault-tolerant with automatic failover, data replication, and disaster recovery capabilities.

## How to Test This Project

After the infrastructure is deployed, you can create a user account and use any of the modern AI models like ChatGPT, Gemini, Claude, and many others. I've integrated 343 AI models that you can test.

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

## Project Overview

I've successfully integrated **343 AI models** from multiple providers into a single unified application and deployed it to production on Kubernetes with full CI/CD automation. This project showcases a complete, production-ready deployment that includes:

- **Infrastructure provisioning** with Terraform (GKE cluster, node pools, static IP)
- **Application deployment** with Helm charts
- **Fully automated CI/CD** through GitHub Actions
- **Security best practices** (NetworkPolicy, RBAC, SecurityContext)
- **Data persistence** with automatic backup/restore from Google Cloud Storage
- **Seamless integration** with OpenRouter API for accessing 343 AI models including GPT-4, Claude, Gemini, Mistral, Llama, and many others

## Live Application

**After deployment, the application is available at:**  
**https://ai-k8s.svdevops.tech/**

You can verify the deployment by checking the domain:
- Open https://ai-k8s.svdevops.tech/ in your browser
- The application should load with SSL/TLS encryption
- Contact svvados@gmail.com for access credentials to test AI models

> **Access to AI Models**  
> To get access to the 343 AI models, please contact:  
> **Email:** svvados@gmail.com  
> **Subject:** AI Models Access Request  
> **DevOps Engineer** will provide detailed demonstration and explanation of how the project works.

## Architecture

The solution follows a cloud-native architecture with complete automation through GitHub Actions:

### Infrastructure Layer (Terraform)
- **Google Kubernetes Engine (GKE) cluster** - Managed Kubernetes service
- **Node Pool** - Cost-optimized configuration (2 nodes, e2-medium: 2 CPU, 4GB RAM)
- **Static IP address** - Persistent across cluster recreations (survives destroy/rebuild)
- **GCP APIs** - Container and Compute APIs enabled automatically

### Application Layer (Helm)
- **Open WebUI Application** - Unified AI platform deployment
- **NGINX Ingress Controller** - HTTP/HTTPS load balancer with static IP
- **cert-manager** - Automated TLS certificate management
- **Persistent Volume** - Application data storage (10Gi)
- **Automatic Database Backup/Restore** - From Google Cloud Storage bucket

### CI/CD Layer (GitHub Actions)
- **Automated Infrastructure Deployment** - Terraform apply on code changes
- **Automated Application Deployment** - Helm deployment after infrastructure
- **Error Handling** - Automatic retry logic for stuck Helm operations
- **Verification** - Pod status checks and diagnostics

### AI Integration
- **OpenRouter API** - Unified API for 343 AI models
- **OpenAI-compatible APIs** - Support for Deepseek, Groq, Together AI, etc.
- **Flexible Model Selection** - Easy switching between models

### Security & Data Persistence
- **NetworkPolicy** - Traffic isolation and restriction
- **RBAC** - Role-based access control
- **Security Contexts** - Non-root execution, read-only filesystem where possible
- **Secrets Management** - Kubernetes secrets with proper handling
- **TLS/SSL Encryption** - End-to-end encryption
- **Automatic Backup/Restore** - Database and SSL certificates in GCS
- **Static IP Persistence** - Survives cluster recreations

## Automated Deployment Process

The entire deployment is automated through GitHub Actions. Here's how it works:

### Prerequisites Setup

Before the automation can work, the following must be configured:

#### 1. GitHub Secrets Configuration

Three secrets need to be configured in GitHub repository settings:

- **`GCP_PROJECT_ID`** - Google Cloud Project ID 
- **`GCP_SA_KEY`** - Service Account JSON key with required permissions
- **`OPENROUTER_API_KEY`** (Optional) - API key for accessing 343 AI models

#### 2. GCP Service Account Setup

A Service Account must be created with the following IAM roles:
- `roles/container.admin` - Kubernetes Engine Admin
- `roles/compute.admin` - Compute Admin
- `roles/storage.admin` - Storage Admin
- `roles/iam.serviceAccountUser` - Service Account User

#### 3. GCS Bucket for Backups

A Google Cloud Storage bucket must be created for storing:
- Database backups (`open-webui-backups`)
- SSL certificates (optional, for reuse)

#### 4. DNS Configuration

DNS A record must point to the static IP address:
- Domain: `ai-k8s.svdevops.tech`
- Type: A
- Value: Static IP (assigned by Terraform)

### Deployment Workflow

The deployment happens automatically when code is pushed to the `main` branch or manually triggered. The workflow consists of two sequential jobs:

#### Job 1: Create Infrastructure

**Trigger:** Push to `main` branch with changes in:
- `terraform/**`
- `helm/**`
- `scripts/**`
- `.github/workflows/deploy.yml`

**Steps:**

1. **Checkout Code** - Retrieves the repository code
2. **Authenticate to Google Cloud** - Uses `GCP_SA_KEY` secret for authentication
3. **Set up Cloud SDK** - Installs gcloud CLI and GKE auth plugin
4. **Set up Terraform** - Installs Terraform 1.5.0
5. **Deploy Infrastructure** - Executes `scripts/deploy-infra.sh` which:
   - Initializes Terraform (if needed)
   - Checks for existing static IP in GCP
   - Imports existing IP to Terraform state (if exists but not in state)
   - Applies Terraform configuration:
     - Creates GKE cluster
     - Creates node pool with 2 e2-medium nodes
     - Creates static IP address (or reuses existing)
     - Enables required GCP APIs

**Output:** GKE cluster ready, static IP assigned

#### Job 2: Deploy Application to Kubernetes

**Trigger:** After Job 1 completes successfully (`needs: create-infrastructure`)

**Steps:**

1. **Checkout Code** - Retrieves the repository code
2. **Authenticate to Google Cloud** - Re-authenticates for kubectl access
3. **Set up Cloud SDK** - Installs gcloud CLI
4. **Set up Helm** - Installs Helm 3.12.0
5. **Set up kubectl** - Installs kubectl with GKE auth plugin
6. **Deploy Application** - Executes `scripts/deploy-to-k8s.sh` which:
   - **Step 1:** Gets cluster credentials using `gcloud container clusters get-credentials`
   - **Step 2:** Verifies cluster connectivity
   - **Step 3:** Retrieves static IP from Terraform output or GCP
   - **Step 4:** Installs NGINX Ingress Controller:
     - Adds Helm repository
     - Installs with static IP configuration
     - Handles stuck Helm operations automatically (retry logic)
   - **Step 5:** Installs cert-manager:
     - Applies cert-manager manifests
     - Waits for pods to be ready
     - Applies ClusterIssuer for Let's Encrypt
     - Creates/loads SSL certificates from GCS or generates new ones
   - **Step 6:** Creates GCP Service Account secret (for GCS access)
   - **Step 7:** Prepares Helm values:
     - Generates `WEBUI_SECRET_KEY`
     - Sets OpenRouter API key
     - Configures backup/restore settings
   - **Step 8:** Prepares namespace with Helm metadata
   - **Step 9:** Pre-creates Kubernetes secrets:
     - Creates `open-webui-secrets` with `WEBUI_SECRET_KEY`
     - Patches with `OPENAI_API_KEY` and `OPENAI__API_KEY` from OpenRouter
   - **Step 10:** Deploys Open WebUI via Helm:
     - Uses prepared values.yaml.local
     - Handles stuck Helm operations automatically
     - Creates namespace if needed
   - **Step 11:** Ensures secrets exist (fallback safety)
   - **Step 12:** Configures single replica (disables HPA)
   - **Step 13:** Checks pod status and rollout
   - **Step 14:** Verifies database restore from GCS backup
7. **Verify Deployment** - Checks pod and ingress status
8. **Diagnose Issues** - If pod not ready, provides detailed diagnostics

**Output:** Application running, accessible via HTTPS

### Component Interaction Flow

Here's how all components interact during deployment:

```
GitHub Push/Manual Trigger
    ↓
GitHub Actions Workflow Starts
    ↓
┌─────────────────────────────────────┐
│ Job 1: Create Infrastructure        │
├─────────────────────────────────────┤
│ 1. Authenticate to GCP              │
│    (uses GCP_SA_KEY secret)         │
│    ↓                                │
│ 2. Run deploy-infra.sh              │
│    ↓                                │
│ 3. Terraform Apply                  │
│    ├─→ Enables GCP APIs             │
│    ├─→ Creates GKE Cluster          │
│    ├─→ Creates Node Pool            │
│    └─→ Creates/Reuses Static IP     │
│    ↓                                │
│ 4. Infrastructure Ready             │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ Job 2: Deploy Application           │
├─────────────────────────────────────┤
│ 1. Authenticate to GCP              │
│    ↓                                │
│ 2. Get Cluster Credentials          │
│    (gcloud get-credentials)         │
│    ↓                                │
│ 3. Install NGINX Ingress            │
│    (Helm chart + static IP)         │
│    ↓                                │
│ 4. Install cert-manager             │
│    (TLS certificate management)     │
│    ↓                                │
│ 5. Load/Create SSL Certificates     │
│    (from GCS or generate new)       │
│    ↓                                │
│ 6. Prepare Helm Values              │
│    (secrets, configs, backup)       │
│    ↓                                │
│ 7. Pre-create Kubernetes Secrets    │
│    (WEBUI_SECRET_KEY, API keys)     │
│    ↓                                │
│ 8. Deploy Open WebUI                │
│    (Helm chart deployment)          │
│    ├─→ Creates Namespace            │
│    ├─→ Creates PVC (PersistentVolume)│
│    ├─→ Creates Deployment           │
│    ├─→ Creates Service              │
│    ├─→ Creates Ingress              │
│    └─→ Creates NetworkPolicy        │
│    ↓                                │
│ 9. InitContainer Restores Database  │
│    (from GCS bucket)                │
│    ↓                                │
│ 10. Application Pod Starts          │
│     (with restored database)        │
│     ↓                               │
│ 11. Application Ready               │
│     (accessible via HTTPS)          │
└─────────────────────────────────────┘
    ↓
Application Available at:
https://ai-k8s.svdevops.tech/
```

### Detailed Component Interactions

#### Terraform → GCP
- **Terraform Provider** authenticates using Service Account
- **Creates Resources:**
  - GKE Cluster (with deletion protection disabled)
  - Node Pool (2 nodes, e2-medium)
  - Static IP (with lifecycle prevent_destroy)
  - Enables required APIs

#### GitHub Actions → Terraform
- **Triggers:** Code changes in terraform/, scripts/, or workflow files
- **Executes:** `scripts/deploy-infra.sh`
- **Passes:** Environment variables (GCP_PROJECT_ID, region, zone, cluster name)
- **Outputs:** Cluster endpoint, static IP address

#### GitHub Actions → Kubernetes
- **Authentication:** Uses Service Account key via `gcloud get-credentials`
- **Tools:** kubectl, helm
- **Operations:**
  - Install NGINX Ingress (Helm chart)
  - Install cert-manager (kubectl apply)
  - Create secrets (kubectl create/patch)
  - Deploy application (Helm upgrade --install)

#### Helm Chart → Kubernetes Resources
- **Deployment:** Application pods with initContainer
- **Service:** ClusterIP service exposing port 8080
- **Ingress:** Routes traffic from domain to service
- **PVC:** Persistent volume for database storage
- **NetworkPolicy:** Restricts network traffic
- **ServiceAccount:** RBAC configuration
- **Secret:** Application secrets (API keys, etc.)

#### InitContainer → GCS Bucket
- **Purpose:** Restore database before application starts
- **Process:**
  1. Checks if database exists
  2. If not, downloads from `gs://open-webui-backups/latest.db`
  3. Restores to `/app/backend/data/webui.db`
  4. Sets proper permissions
  5. Application starts with restored data

#### NGINX Ingress → Static IP
- **Configuration:** LoadBalancer service with static IP annotation
- **Result:** External IP assigned from Terraform-created static IP
- **DNS:** Domain points to this IP

#### cert-manager → Let's Encrypt
- **ClusterIssuer:** Configured for Let's Encrypt production
- **Certificate:** Automatically issues TLS certificate for domain
- **Storage:** Certificate stored in Kubernetes secret

## Project Structure

```
.
├── .github/
│   └── workflows/
│       ├── deploy.yml              # Main deployment workflow (2 jobs)
│       ├── destroy.yml             # Infrastructure destruction workflow
│       └── manual-deploy.yml       # Manual deployment workflow
│
├── terraform/                      # Infrastructure as Code
│   ├── main.tf                    # Main Terraform configuration
│   ├── variables.tf               # Variable definitions
│   ├── outputs.tf                 # Output definitions (IP, cluster info)
│   ├── versions.tf                # Provider versions
│   └── apply.sh                   # Helper script for IP import
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
│           ├── secret.yaml        # Secrets template
│           ├── networkpolicy.yaml # Network policies
│           ├── serviceaccount.yaml# Service account
│           ├── hpa.yaml           # Horizontal Pod Autoscaler
│           ├── pdb.yaml           # Pod Disruption Budget
│           └── servicemonitor.yaml# Prometheus monitoring
│
├── scripts/                       # Deployment automation scripts
│   ├── deploy-infra.sh            # Infrastructure deployment
│   ├── deploy-to-k8s.sh           # Application deployment
│   ├── destroy-infra.sh           # Infrastructure destruction
│   ├── create-self-signed-cert.sh # SSL certificate creation
│   ├── setup-gcs-backup.sh        # GCS bucket setup
│   └── create-sa-for-project.sh   # Service account creation
│
├── backup/                        # Backup/restore scripts
│   ├── backup-database.sh         # Manual database backup
│   └── restore-database.sh        # Manual database restore
│
├── bootstrap/                     # Bootstrap configurations
│   ├── cluster-issuer.yaml        # Let's Encrypt ClusterIssuer
│   └── nginx-ingress.yaml         # NGINX Ingress config (reference)
│
└── monitoring/                    # Monitoring configurations
    └── grafana-dashboards/
        └── open-webui-dashboard.json  # Grafana dashboard
```

## Key Features

### Infrastructure as Code (IaC)
- **Complete Terraform Configuration** - All infrastructure defined in code
- **Version Control** - Infrastructure changes tracked in Git
- **Reproducible Deployments** - Same infrastructure every time
- **Static IP Persistence** - IP survives cluster recreations
- **Cost Optimization** - Optimized node configuration (e2-medium)

### CI/CD Automation
- **GitHub Actions Workflows** - Fully automated deployment
- **Two-Stage Deployment** - Infrastructure → Application
- **Error Handling** - Automatic retry for stuck operations
- **Verification** - Automatic health checks and diagnostics
- **Manual Triggers** - Can be triggered manually if needed

### Data Persistence
- **Automatic Database Backup** - To Google Cloud Storage
- **Automatic Database Restore** - On every deployment via initContainer
- **SSL Certificate Storage** - Certificates stored in GCS for reuse
- **User Accounts Preserved** - Data survives deployments
- **PVC Configuration** - Persistent volume for application data

### Security Best Practices
- **Network Policies** - Traffic isolation and restriction
- **RBAC** - Role-based access control
- **Security Contexts** - Non-root execution, minimal privileges
- **Secrets Management** - Kubernetes secrets with proper handling
- **TLS/SSL Encryption** - End-to-end encryption
- **Service Account** - Least privilege access

### Application Features
- **343 AI Models** - Unified access through OpenRouter API
- **OpenAI-Compatible** - Works with any OpenAI-compatible API
- **Flexible Configuration** - Easy model switching
- **Health Checks** - Liveness, readiness, and startup probes
- **Resource Limits** - Optimized based on real-world usage

## Technical Stack

### Infrastructure
- **Terraform** >= 1.0 - Infrastructure as Code
- **Google Cloud Platform** - Cloud provider
- **Google Kubernetes Engine (GKE)** - Managed Kubernetes service
- **Kubernetes** - Container orchestration platform

### CI/CD
- **GitHub Actions** - CI/CD automation platform
- **GitHub Secrets** - Secure credential storage

### Application Deployment
- **Helm** v3.12.0 - Package manager for Kubernetes
- **NGINX Ingress Controller** - HTTP/HTTPS load balancer
- **cert-manager** - Automated TLS certificate management

### Application
- **Open WebUI** - User-friendly LLM chatting UI
- **OpenRouter API** - Unified API for 343 AI models
- **SQLite** - Database (with automatic backup/restore)

### Monitoring & Observability
- **ServiceMonitor** - Prometheus metrics (ready for Prometheus Operator)
- **Grafana Dashboard** - Pre-configured dashboard template

## Key Achievements

- **343 AI Models Integration** - Successfully unified 343 AI models from multiple providers in a single application  
- **Infrastructure as Code** - Complete infrastructure defined in Terraform  
- **Fully Automated CI/CD** - GitHub Actions workflows for complete automation  
- **Production Kubernetes Deployment** - Deployed to GKE with full production-grade configuration  
- **Cost Optimization** - Optimized node pool and resource allocation  
- **Security Best Practices** - Network policies, RBAC, security contexts  
- **Production Ready** - Health checks, resource limits, high availability  
- **Automated Backup/Restore** - Database and SSL certificates stored in GCS  
- **Static IP Persistence** - IP address survives cluster recreations  
- **Error Handling** - Automatic retry logic for stuck operations  
- **Zero-Downtime Deployments** - Proper rollout strategies  

## Accessing the Application

After deployment, the application is available at:
- **URL:** https://ai-k8s.svdevops.tech/
- **Protocol:** HTTPS (SSL/TLS encrypted)

You can verify the deployment by:
1. Opening the URL in your browser
2. Checking that the page loads with SSL encryption
3. Verifying the domain resolves correctly

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

## Backup and Restore

The deployment automatically handles backup and restore:

- **Database Backups** - Stored in Google Cloud Storage bucket (`open-webui-backups`)
- **SSL Certificates** - Stored in GCS for reuse across deployments
- **Automatic Restore** - On every deployment via initContainer
- **User Accounts Preserved** - All data survives deployments
- **Manual Backup/Restore** - Scripts available in `backup/` directory

## Technologies Used

- **Terraform** - Infrastructure as Code
- **Kubernetes** - Container orchestration
- **Helm** - Package manager for Kubernetes
- **Google Cloud Platform** - Cloud provider
- **Google Kubernetes Engine (GKE)** - Managed Kubernetes service
- **GitHub Actions** - CI/CD automation
- **NGINX Ingress Controller** - HTTP/HTTPS load balancer
- **cert-manager** - Automated TLS certificate management
- **OpenRouter API** - Unified API for 343 AI models

## License

This project is for educational and portfolio purposes. It demonstrates production-ready Kubernetes deployment practices, Infrastructure as Code, CI/CD automation, and DevOps best practices.

## References

- [OpenRouter Documentation](https://openrouter.ai/docs)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Helm Documentation](https://helm.sh/docs/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [NGINX Ingress Documentation](https://kubernetes.github.io/ingress-nginx/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

---

**Contact for AI Models Access:** svvados@gmail.com  
**Live Application:** https://ai-k8s.svdevops.tech/
