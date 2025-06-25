# PubSub System - Terraform + Kubernetes

A modern microservices architecture demonstrating PubSub patterns using **Terraform** for infrastructure management and **Kubernetes** for container orchestration.

## 🏗️ Architecture

This system showcases the **correct** way to deploy microservices:

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  Terraform      │    │   Kubernetes     │    │   AWS Services  │
│                 │    │                  │    │                 │
│ • EKS Cluster   │───▶│ • 4 Deployments  │───▶│ • SNS Topic     │
│ • VPC + Subnets │    │ • Load Balancer  │    │ • 3 SQS Queues  │
│ • IAM Roles     │    │ • Auto-scaling   │    │ • ECR Registry  │
│ • Networking    │    │ • Health Checks  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### Services

1. **Order Publisher** - Rails app (2 replicas, LoadBalancer)
2. **Email Service** - Ruby microservice (1 replica)  
3. **Inventory Service** - Ruby microservice (1 replica)
4. **Analytics Service** - Ruby microservice (1 replica)

### PubSub Flow

```
Order Created → SNS Topic → 3 SQS Queues → Microservices
```

## 🚀 Quick Start

### Prerequisites

- **AWS CLI configured** with credentials
- **Terraform >= 1.0** installed
- **kubectl** installed  
- **Docker** installed and running
- **curl** for testing
- **bash** shell (macOS/Linux)

### ⚠️ First Time Setup

**IMPORTANT:** Before deployment, set up IAM permissions:

```bash
# Run this ONCE to create terraform-user with proper permissions
./setup-terraform-user.sh
```

This script creates a `terraform-user` with the following policies:
- `AmazonEKSClusterPolicy` - EKS cluster management
- `AmazonVPCFullAccess` - VPC and networking
- `IAMFullAccess` - IAM role management
- `AmazonSNSFullAccess` - SNS topic management
- `AmazonSQSFullAccess` - SQS queue management
- `AmazonEC2ContainerRegistryFullAccess` - ECR access
- `AmazonECS_FullAccess` - ECS legacy support
- `SecretsManagerReadWrite` - Secrets management
- Custom `ECSTaskRolePassPolicy` - IAM role passing

### Deploy Everything

#### Option A: Full Automated Deployment
```bash
# 1. Create infrastructure (one-time)
./deploy-k8s.sh

# 2. Build images and deploy apps (run after any code changes)
./build-and-deploy.sh
```

#### Option B: Step-by-Step Deployment
```bash
# 1. Create infrastructure
./deploy-k8s.sh

# 2. Build and deploy manually (see steps below)
```

**What `./deploy-k8s.sh` does:**
1. 🏗️ Create EKS cluster, VPC, SNS/SQS with Terraform
2. ⚙️ Configure kubectl  
3. ⏳ Wait for cluster readiness
4. 📤 Output cluster info and next steps

**What `./build-and-deploy.sh` does:**
1. 📦 Create ECR repositories
2. 🔐 Login to ECR
3. 🏗️ Build Docker images for all 4 services
4. ⬆️ Push images to ECR
5. 📝 Update Kubernetes manifests with your account ID
6. ☸️ Deploy to Kubernetes
7. ⏳ Wait for deployments to be ready

### Manual Deployment Steps

If you prefer step-by-step:

#### 1. Deploy Infrastructure
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

#### 2. Configure Kubernetes
```bash
aws eks update-kubeconfig --region us-east-1 --name pubsub-cluster
```

#### 3. Build & Push Images
```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 484123688626.dkr.ecr.us-east-1.amazonaws.com

# Create repositories
for repo in order-publisher email-service inventory-service analytics-service; do
    aws ecr create-repository --repository-name $repo --region us-east-1
done

# Build and push each service
cd order_publisher
docker build -t order-publisher .
docker tag order-publisher:latest 484123688626.dkr.ecr.us-east-1.amazonaws.com/order-publisher:latest
docker push 484123688626.dkr.ecr.us-east-1.amazonaws.com/order-publisher:latest
# ... repeat for other services
```

#### 4. Deploy to Kubernetes
```bash
# Update k8s/*.yaml files with correct ECR image URLs
kubectl apply -f k8s/
```

## 📁 Project Structure

```
pubsub-system/
├── terraform/           # Infrastructure as Code
│   ├── main.tf         # EKS, VPC, SNS, SQS
│   ├── variables.tf    # Input variables
│   └── outputs.tf      # Important outputs
├── k8s/                # Kubernetes manifests
│   ├── order-publisher.yaml
│   ├── email-service.yaml
│   ├── inventory-service.yaml
│   └── analytics-service.yaml
├── order_publisher/    # Rails app
│   ├── Dockerfile
│   └── app/...
├── services/           # Microservices
│   ├── email-service/
│   ├── inventory-service/
│   └── analytics-service/
├── deploy-k8s.sh      # Deployment script
└── old-supervisor-stuff/ # Archived files
```

## 🔧 Development Commands

### Kubernetes Operations
```bash
# View all pods
kubectl get pods

# View services  
kubectl get svc

# View logs
kubectl logs -f deployment/order-publisher
kubectl logs -f deployment/email-service

# Scale services
kubectl scale deployment email-service --replicas=3

# Port forward for local access
kubectl port-forward svc/order-publisher-service 8080:80
```

### Terraform Operations
```bash
cd terraform

# Plan changes
terraform plan

# Apply changes
terraform apply

# Destroy infrastructure
terraform destroy
```

### 🧹 Complete Teardown & Rebuild

To completely clean up and recreate the system:

```bash
# 1. Destroy all infrastructure
cd terraform && terraform destroy -auto-approve

# 2. Optional: Remove terraform-user (if starting fresh)
aws iam list-attached-user-policies --user-name terraform-user --query 'AttachedPolicies[].PolicyArn' --output text | xargs -I {} aws iam detach-user-policy --user-name terraform-user --policy-arn {}
aws iam delete-user --user-name terraform-user

# 3. Recreate IAM permissions
./setup-terraform-user.sh

# 4. Deploy everything again
./deploy-k8s.sh
```

## 🎯 Why This Approach?

### ✅ **What We Fixed:**
- **No more supervisor complexity** - Kubernetes handles process management
- **Proper microservices** - Each service in its own container
- **Infrastructure as Code** - Terraform manages all AWS resources
- **Service Discovery** - Kubernetes built-in networking
- **Auto-scaling** - Kubernetes handles scaling automatically
- **Health Checks** - Kubernetes restarts failed containers
- **Load Balancing** - AWS Load Balancer integration

### ❌ **What We Avoided:**
- Single supervisor container managing multiple processes
- Manual AWS resource creation
- Complex log aggregation setup
- Manual service discovery
- No auto-scaling capabilities

## 🔍 Testing the System

### 1. Access the Application
```bash
# Get external IP
kubectl get svc order-publisher-service

# Visit the application
curl http://<EXTERNAL-IP>/orders
```

### 2. Create an Order
Navigate to the web interface and create an order. The PubSub flow will:
1. Rails app publishes to SNS
2. SNS fans out to 3 SQS queues
3. Each microservice processes its queue
4. Check logs with `kubectl logs -f deployment/email-service`

### 3. Monitor Services
```bash
# View all running pods
kubectl get pods

# Check service status
kubectl get deployments

# View events
kubectl get events --sort-by=.metadata.creationTimestamp
```

## 🧹 Cleanup

```bash
# Delete Kubernetes resources
kubectl delete -f k8s/

# Destroy AWS infrastructure
cd terraform
terraform destroy
```

## 📚 Learning Outcomes

This project demonstrates:
- **Container Orchestration** with Kubernetes
- **Infrastructure as Code** with Terraform  
- **Microservices Architecture** patterns
- **PubSub Messaging** with SNS/SQS
- **DevOps Best Practices**
- **Cloud-Native Development**

---

## 🔄 Comparison: Old vs New

| Aspect | Old (Supervisor) | New (Kubernetes) |
|--------|------------------|------------------|
| **Architecture** | Monolithic container | True microservices |
| **Scaling** | Manual | Automatic |
| **Health Checks** | Basic | Advanced |
| **Deployment** | Docker + ECS | Terraform + K8s |
| **Service Discovery** | Manual | Built-in |
| **Logs** | Centralized complexity | Per-service simplicity |
| **Development** | Complex debugging | Independent services |

The Kubernetes approach is the **industry standard** for modern microservices deployment. 