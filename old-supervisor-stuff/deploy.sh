#!/bin/bash

echo "🚀 Starting PubSub System Deployment..."

# Parse command line arguments
FORCE_NEW_TASK_DEF=false
SKIP_BUILD=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --force-task-def)
      FORCE_NEW_TASK_DEF=true
      shift
      ;;
    --skip-build)
      SKIP_BUILD=true
      shift
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --force-task-def  Force creation of new task definition"
      echo "  --skip-build      Skip Docker build and push (use existing image)"
      echo "  --help           Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

if [ "$SKIP_BUILD" = false ]; then
  # Build multi-platform Docker image for AWS ECS (AMD64)
  echo "📦 Building Docker image for AWS ECS..."
  docker buildx build --platform linux/amd64 -t pubsub-supervisor -f Dockerfile.supervisor .

  # Tag for ECR
  echo "🏷️  Tagging for ECR..."
  docker tag pubsub-supervisor:latest 484123688626.dkr.ecr.us-east-1.amazonaws.com/pubsub-supervisor:latest

  # Push to ECR
  echo "⬆️  Pushing to ECR..."
  aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 484123688626.dkr.ecr.us-east-1.amazonaws.com
  docker push 484123688626.dkr.ecr.us-east-1.amazonaws.com/pubsub-supervisor:latest
  
  # Since we pushed a new image, we need a new task definition
  FORCE_NEW_TASK_DEF=true
else
  echo "⏭️  Skipping Docker build and push..."
fi

# Check if we need to create a new task definition
if [ "$FORCE_NEW_TASK_DEF" = true ]; then
  echo "📝 Creating new task definition..."
  cat > task-definition-final.json << 'EOF'
{
  "family": "pubsub-supervisor-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::484123688626:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::484123688626:role/ecsTaskCloudWatchRole",
  "containerDefinitions": [
    {
      "name": "pubsub-supervisor",
      "image": "484123688626.dkr.ecr.us-east-1.amazonaws.com/pubsub-supervisor:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 3000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "RAILS_ENV",
          "value": "production"
        },
        {
          "name": "AWS_REGION",
          "value": "us-east-1"
        },
        {
          "name": "AWS_SNS_TOPIC_ARN",
          "value": "arn:aws:sns:us-east-1:484123688626:order-events"
        },
        {
          "name": "AWS_ACCOUNT_ID",
          "value": "484123688626"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/pubsub-supervisor",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
EOF

  # Register new task definition
  echo "📋 Registering new task definition..."
  TASK_DEF_ARN=$(aws ecs register-task-definition --cli-input-json file://task-definition-final.json --query 'taskDefinition.taskDefinitionArn' --output text)
  echo "✅ New task definition: $TASK_DEF_ARN"
else
  echo "📋 Using existing task definition..."
  TASK_DEF_ARN="pubsub-supervisor-task"
fi

# Update ECS service (this always triggers a new deployment)
echo "🔄 Updating ECS service..."
aws ecs update-service \
  --cluster pubsub-cluster \
  --service pubsub-service \
  --task-definition "$TASK_DEF_ARN" \
  --force-new-deployment

# Wait for deployment
echo "⏳ Waiting for deployment to complete..."
aws ecs wait services-stable \
  --cluster pubsub-cluster \
  --services pubsub-service

echo "✅ Deployment complete!"
echo "🌐 Your PubSub system is available at: http://pubsub-alb-1854839058.us-east-1.elb.amazonaws.com"
echo ""
echo "💡 Quick deployment options:"
echo "   ./deploy.sh                    # Full build + deploy"
echo "   ./deploy.sh --skip-build       # Deploy existing image"
echo "   ./deploy.sh --force-task-def   # Force new task definition"
echo ""
echo "📊 Check deployment status:"
echo "aws ecs describe-services --cluster pubsub-cluster --services pubsub-service"
echo ""
echo "📋 View logs:"
echo "aws logs tail /ecs/pubsub-supervisor --follow" 