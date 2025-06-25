#!/bin/bash

set -e

echo "🚀 Complete PubSub System Build & Deploy"
echo "======================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="us-east-1"
CLUSTER_NAME="pubsub-cluster"

# Get AWS Account ID
echo -e "${BLUE}🔍 Getting AWS Account ID...${NC}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "Account ID: ${GREEN}$ACCOUNT_ID${NC}"

# ECR Base URL
ECR_BASE_URL="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

# Service definitions
declare -A SERVICES
SERVICES[order-publisher]="order_publisher"
SERVICES[email-service]="services/email-service"
SERVICES[inventory-service]="services/inventory-service"
SERVICES[analytics-service]="services/analytics-service"

echo ""
echo -e "${YELLOW}📦 Step 1: Setting up ECR Repositories...${NC}"

# Create ECR repositories
for service in "${!SERVICES[@]}"; do
    echo -e "Creating repository: ${BLUE}$service${NC}"
    aws ecr describe-repositories --repository-names $service --region $AWS_REGION >/dev/null 2>&1 || \
    aws ecr create-repository --repository-name $service --region $AWS_REGION
done

echo ""
echo -e "${YELLOW}🔐 Step 2: Login to ECR...${NC}"
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_BASE_URL

echo ""
echo -e "${YELLOW}🏗️ Step 3: Building and Pushing Docker Images...${NC}"

# Build and push each service
for service in "${!SERVICES[@]}"; do
    service_dir="${SERVICES[$service]}"
    image_url="$ECR_BASE_URL/$service:latest"
    
    echo -e "${BLUE}Building $service from $service_dir...${NC}"
    
    # Check if directory exists
    if [ ! -d "$service_dir" ]; then
        echo -e "${RED}❌ Directory $service_dir not found!${NC}"
        continue
    fi
    
    # Build image
    docker build -t $service $service_dir/
    
    # Tag for ECR
    docker tag $service:latest $image_url
    
    # Push to ECR
    echo -e "${BLUE}Pushing $service to ECR...${NC}"
    docker push $image_url
    
    echo -e "${GREEN}✅ $service pushed successfully${NC}"
done

echo ""
echo -e "${YELLOW}📝 Step 4: Updating Kubernetes Manifests...${NC}"

# Update k8s YAML files with correct image URLs
for service in "${!SERVICES[@]}"; do
    k8s_file="k8s/$service.yaml"
    if [ -f "$k8s_file" ]; then
        echo -e "Updating $k8s_file with account ID ${GREEN}$ACCOUNT_ID${NC}"
        # Replace hardcoded account ID with actual account ID
        sed -i.bak "s/484123688626\.dkr\.ecr\.us-east-1\.amazonaws\.com/$ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/g" "$k8s_file"
        rm "$k8s_file.bak" 2>/dev/null || true
    fi
done

echo ""
echo -e "${YELLOW}☸️ Step 5: Deploying to Kubernetes...${NC}"

# Check if cluster is accessible
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo -e "${RED}❌ Kubernetes cluster not accessible. Run ./deploy-k8s.sh first!${NC}"
    exit 1
fi

# Apply all Kubernetes manifests
echo -e "${BLUE}Applying Kubernetes manifests...${NC}"
kubectl apply -f k8s/

echo ""
echo -e "${YELLOW}⏳ Step 6: Waiting for Deployments...${NC}"

# Wait for deployments to be ready
for service in "${!SERVICES[@]}"; do
    echo -e "Waiting for ${BLUE}$service${NC} deployment..."
    kubectl wait --for=condition=available --timeout=300s deployment/$service || true
done

echo ""
echo -e "${GREEN}✅ Deployment Complete!${NC}"
echo "========================"

# Show status
echo -e "${BLUE}📊 Deployment Status:${NC}"
kubectl get pods
echo ""

echo -e "${BLUE}🌐 Services:${NC}"
kubectl get svc

echo ""
echo -e "${BLUE}📋 Next Steps:${NC}"
echo "1. Check pod logs: kubectl logs -f deployment/<service-name>"
echo "2. Get external IP: kubectl get svc order-publisher-service"
echo "3. Access application: http://<EXTERNAL-IP>/"
echo "4. Create test order to trigger PubSub flow"

echo ""
echo -e "${GREEN}🎉 Your PubSub system is now running on Kubernetes!${NC}" 