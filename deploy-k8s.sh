#!/bin/bash

set -e

echo "🚀 PubSub System - Terraform + Kubernetes Deployment"
echo "====================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="us-east-1"
CLUSTER_NAME="pubsub-cluster"

# Step 1: Initialize and Apply Terraform
echo -e "${YELLOW}📋 Step 1: Deploying Infrastructure with Terraform...${NC}"
cd terraform

if [ ! -f ".terraform/terraform.tfstate" ]; then
    echo "🔧 Initializing Terraform..."
    terraform init
fi

echo "🏗️ Planning infrastructure..."
terraform plan

echo "🚀 Applying infrastructure..."
terraform apply -auto-approve

echo "📤 Getting outputs..."
CLUSTER_NAME=$(terraform output -raw cluster_name)
SNS_TOPIC_ARN=$(terraform output -raw sns_topic_arn)

cd ..

# Step 2: Configure kubectl
echo -e "${YELLOW}⚙️ Step 2: Configuring kubectl...${NC}"
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Step 3: Wait for cluster to be ready
echo -e "${YELLOW}⏳ Step 3: Waiting for cluster nodes to be ready...${NC}"
echo "Waiting for nodes..."
kubectl wait --for=condition=Ready node --all --timeout=300s

echo ""
echo -e "${GREEN}✅ Terraform + Kubernetes Infrastructure Ready!${NC}"
echo "=============================================="
echo -e "📊 Cluster Name: ${GREEN}$CLUSTER_NAME${NC}"
echo -e "📈 SNS Topic: ${GREEN}$SNS_TOPIC_ARN${NC}"
echo ""
echo "🔧 Next steps:"
echo "  1. Build and push your Docker images to ECR"
echo "  2. Update k8s/*.yaml files with correct image URLs"
echo "  3. Deploy with: kubectl apply -f k8s/" 