# AWS Deployment Strategies for Pub/Sub System

## Overview
This document outlines three different approaches to deploy our order processing pub/sub system to AWS, each demonstrating different architectural patterns and AWS services.

## Current System Architecture
```
Rails Publisher App (Dockerized) → SNS Topic → SQS Queues → 3 Service Scripts
├── order_publisher/ (Rails API - containerized)
├── email_service.rb (Ruby script)
├── inventory_service.rb (Ruby script)
└── analytics_service.rb (Ruby script)
```

## Infrastructure Already Deployed
- ✅ SNS Topic: `order-events`
- ✅ SQS Queues: `email-service-queue`, `inventory-service-queue`, `analytics-service-queue`
- ✅ IAM Permissions: SQS/SNS policies configured

---

## Phase 1: Full Container Approach (ECS)

### Architecture
```
Internet → ALB → ECS Cluster
                 ├── order-publisher service (Rails)
                 ├── email-service container
                 ├── inventory-service container
                 └── analytics-service container
                 
All containers pull from ECR registry
```

### Benefits
- ✅ Consistent deployment model
- ✅ Easy to scale individual services
- ✅ Full control over runtime environment
- ✅ Great for stateful applications

### Steps

#### 1.1: Create ECR Repository
```bash
# Create repository for Rails app
aws ecr create-repository --repository-name order-publisher

# Create repositories for services
aws ecr create-repository --repository-name email-service
aws ecr create-repository --repository-name inventory-service  
aws ecr create-repository --repository-name analytics-service
```

#### 1.2: Containerize Service Scripts
Create `services/Dockerfile`:
```dockerfile
FROM ruby:3.2-alpine

WORKDIR /app

# Install AWS SDK gems
RUN gem install aws-sdk-sqs aws-sdk-sns

# Copy service files
COPY *.rb ./

# Default command (override in ECS task definition)
CMD ["ruby", "email_service.rb"]
```

#### 1.3: Build and Push Images
```bash
# Get ECR login
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Build and push Rails app
docker build -t order-publisher .
docker tag order-publisher:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/order-publisher:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/order-publisher:latest

# Build and push services
cd ../services
docker build -t email-service .
docker tag email-service:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/email-service:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/email-service:latest

# Repeat for inventory and analytics services
```

#### 1.4: Create ECS Cluster
```bash
aws ecs create-cluster --cluster-name pubsub-cluster
```

#### 1.5: Create Task Definitions

**What is a Task Definition?**
A task definition is like a "blueprint" that tells ECS how to run your container. It specifies the Docker image, resource requirements, and configuration needed to run your application.

**Key Components Explained:**

**1. CPU/Memory Allocations**
- **Why needed**: Containers need dedicated compute resources
- **Fargate options**: Pre-defined combinations (e.g., 256 CPU + 512 MB RAM)
- **Cost impact**: Higher allocations = higher cost per hour
- **Recommendation**: 
  - Rails app: 512 CPU (0.5 vCPU) + 1024 MB RAM
  - Service scripts: 256 CPU (0.25 vCPU) + 512 MB RAM

**2. Environment Variables for AWS Credentials**
- **Why needed**: Containers need AWS permissions to access SNS/SQS
- **Security**: Use IAM roles instead of hardcoded keys
- **Required variables**:
  ```
  AWS_REGION=us-east-1
  AWS_DEFAULT_REGION=us-east-1
  ```
- **Note**: IAM execution role handles credentials automatically

**3. Network Configuration**
- **Mode**: `awsvpc` (required for Fargate)
- **What it means**: Each container gets its own network interface
- **Benefits**: Better isolation, security groups per container
- **Subnets**: Must specify which VPC subnets to use

**4. Log Groups**
- **Purpose**: Capture container stdout/stderr logs
- **CloudWatch**: Logs go to CloudWatch Logs for monitoring
- **Cost**: Pay per GB of logs stored
- **Retention**: Set retention period (e.g., 7 days for dev)

**Example Task Definition Structure:**
```json
{
  "family": "email-service-td",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::ACCOUNT:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "email-service",
      "image": "ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/email-service:latest",
      "environment": [
        {"name": "AWS_REGION", "value": "us-east-1"}
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/email-service",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

**Prerequisites Before Creating Task Definitions:**
1. **IAM Execution Role**: Allows ECS to pull images from ECR
2. **CloudWatch Log Groups**: Must exist before task runs
3. **VPC/Subnets**: Default VPC is fine for learning

**Creating the Required IAM Role:**
```bash
# Create execution role for ECS tasks
aws iam create-role --role-name ecsTaskExecutionRole --assume-role-policy-document '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"Service": "ecs-tasks.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }
  ]
}'

# Attach the managed policy for ECR access
aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
```

**Creating CloudWatch Log Groups:**
```bash
# Create log groups for each service
aws logs create-log-group --log-group-name /ecs/order-publisher
aws logs create-log-group --log-group-name /ecs/email-service  
aws logs create-log-group --log-group-name /ecs/analytics-service
aws logs create-log-group --log-group-name /ecs/inventory-service
```

**Register Task Definitions:**
```bash
# Register each task definition
aws ecs register-task-definition --cli-input-json file://order-publisher-td.json
aws ecs register-task-definition --cli-input-json file://email-service-td.json
aws ecs register-task-definition --cli-input-json file://analytics-service-td.json
aws ecs register-task-definition --cli-input-json file://inventory-service-td.json
```

#### 1.6: Deploy Services

**Get Default Subnets and Security Group:**
```bash
# Get default VPC subnets
aws ec2 describe-subnets --filters "Name=default-for-az,Values=true" --query "Subnets[*].SubnetId" --output text

# Get default security group
aws ec2 describe-security-groups --filters "Name=group-name,Values=default" --query "SecurityGroups[*].GroupId" --output text
```

**Create Services with Network Configuration:**
```bash
# Replace SUBNET-ID and SG-ID with values from above commands

# Rails API service (needs public IP for HTTP access)
aws ecs create-service \
  --cluster pubsub-cluster \
  --service-name order-publisher \
  --task-definition order-publisher-td \
  --desired-count 1 \
  --network-configuration "awsvpcConfiguration={subnets=[SUBNET-ID],securityGroups=[SG-ID],assignPublicIp=ENABLED}"

# Service scripts (no public IP needed, just SQS access)  
aws ecs create-service \
  --cluster pubsub-cluster \
  --service-name email-service \
  --task-definition email-service-td \
  --desired-count 1 \
  --network-configuration "awsvpcConfiguration={subnets=[SUBNET-ID],securityGroups=[SG-ID],assignPublicIp=ENABLED}"

aws ecs create-service \
  --cluster pubsub-cluster \
  --service-name inventory-service \
  --task-definition inventory-service-td \
  --desired-count 1 \
  --network-configuration "awsvpcConfiguration={subnets=[SUBNET-ID],securityGroups=[SG-ID],assignPublicIp=ENABLED}"

aws ecs create-service \
  --cluster pubsub-cluster \
  --service-name analytics-service \
  --task-definition analytics-service-td \
  --desired-count 1 \
  --network-configuration "awsvpcConfiguration={subnets=[SUBNET-ID],securityGroups=[SG-ID],assignPublicIp=ENABLED}"
```

**Note**: All services need `assignPublicIp=ENABLED` to pull images from ECR and access AWS services unless you have NAT Gateway configured.

### Interview Talking Points
- "Deployed microservices using ECS with Fargate"
- "Used ECR for private container registry"
- "Each service scales independently based on demand"
- "Consistent deployment and monitoring across all services"

---

## Phase 2: Hybrid Approach (ECS + Lambda)

### Architecture
```
Internet → ALB → ECS (Rails App)
                 
SNS Topic → SQS Queues → Lambda Functions
            ├── email-lambda
            ├── inventory-lambda
            └── analytics-lambda
```

### Benefits
- ✅ Rails app benefits from container consistency
- ✅ Event processors benefit from serverless scaling
- ✅ Cost optimization (pay per invocation for processors)
- ✅ Automatic scaling for message processing

### Steps

#### 2.1: Keep Rails App in ECS
- Reuse existing ECS deployment from Phase 1
- Rails app continues to publish to SNS

#### 2.2: Convert Services to Lambda
Create Lambda deployment packages:

**email-lambda/index.js** (or Ruby runtime):
```ruby
require 'aws-sdk-sqs'
require 'json'

def lambda_handler(event:, context:)
  event['Records'].each do |record|
    # Parse SQS message
    body = JSON.parse(record['body'])
    message = JSON.parse(body['Message'])
    
    # Process email logic
    send_order_email(message)
  end
  
  { statusCode: 200 }
end

def send_order_email(order_data)
  puts "📧 Sending email for order #{order_data['order_id']}"
  # Email logic here
end
```

#### 2.3: Configure SQS Triggers
```bash
# Add SQS as trigger for each Lambda
aws lambda create-event-source-mapping \
  --function-name email-lambda \
  --event-source-arn arn:aws:sqs:us-east-1:<account>:email-service-queue
```

#### 2.4: Deploy Lambda Functions
```bash
zip -r email-lambda.zip index.rb
aws lambda create-function \
  --function-name email-lambda \
  --runtime ruby3.2 \
  --handler index.lambda_handler \
  --zip-file fileb://email-lambda.zip
```

### Interview Talking Points
- "Chose ECS for Rails app (stateful, HTTP traffic) and Lambda for event processing (stateless, event-driven)"
- "Optimized costs by using serverless for variable workloads"
- "Demonstrates architectural decision-making based on service characteristics"

---

## Phase 3: Full Serverless (All Lambda)

### Architecture
```
API Gateway → Lambda (Rails API)
              ↓
          SNS Topic → SQS Queues → Lambda Functions
                      ├── email-lambda
                      ├── inventory-lambda
                      └── analytics-lambda
```

### Benefits
- ✅ Fully serverless - no infrastructure management
- ✅ Pay per request pricing
- ✅ Automatic scaling to zero
- ✅ Maximum cost efficiency for variable loads

### Steps

#### 3.1: Convert Rails to Lambda
Use AWS Lambda Web Adapter or Rails Lambda:

**Dockerfile for Rails Lambda**:
```dockerfile
FROM public.ecr.aws/lambda/ruby:3.2

# Copy Rails app
COPY . ${LAMBDA_TASK_ROOT}

# Install dependencies
RUN bundle install

# Lambda handler
CMD ["lambda_function.lambda_handler"]
```

**lambda_function.rb**:
```ruby
require_relative 'config/environment'

def lambda_handler(event:, context:)
  # Convert API Gateway event to Rack env
  rack_env = convert_event_to_rack(event)
  
  # Process through Rails
  status, headers, body = Rails.application.call(rack_env)
  
  # Convert back to API Gateway response
  {
    statusCode: status,
    headers: headers,
    body: body.join
  }
end
```

#### 3.2: API Gateway Integration
```bash
aws apigatewayv2 create-api --name pubsub-api --protocol-type HTTP
aws apigatewayv2 create-integration --api-id <api-id> --integration-type AWS_PROXY --integration-uri <lambda-arn>
```

#### 3.3: Deploy All Lambda Functions
- Rails API as Lambda function
- Email service as Lambda function  
- Inventory service as Lambda function
- Analytics service as Lambda function

### Interview Talking Points
- "Achieved fully serverless architecture with zero infrastructure management"
- "Optimized for cost and automatic scaling"
- "Used API Gateway for HTTP traffic and SQS triggers for event processing"

---

## Comparison Matrix

| Aspect | ECS Containers | Hybrid ECS+Lambda | Full Serverless |
|--------|----------------|-------------------|-----------------|
| **Complexity** | Medium | Medium | High |
| **Cost** | Fixed | Optimized | Variable |
| **Scaling** | Manual/Auto | Mixed | Automatic |
| **Cold Starts** | None | Lambda only | All services |
| **Control** | Full | Mixed | Limited |
| **Best For** | Consistent load | Mixed workloads | Variable load |

---

## Implementation Timeline

### Day 1: Phase 1 (ECS) - 2-3 hours
- [ ] Create ECR repositories
- [ ] Containerize all services
- [ ] Push images to ECR
- [ ] Create ECS cluster and services
- [ ] Test end-to-end flow

### Day 2: Phase 2 (Hybrid) - 1-2 hours  
- [ ] Convert service scripts to Lambda
- [ ] Configure SQS triggers
- [ ] Deploy and test
- [ ] Compare performance/costs

### Day 3: Phase 3 (Serverless) - 2-3 hours
- [ ] Convert Rails to Lambda
- [ ] Set up API Gateway
- [ ] Deploy full serverless stack
- [ ] Performance comparison

---

## Interview Preparation Talking Points

### Technical Depth
- "I've deployed the same system three different ways to understand trade-offs"
- "Can speak to when containers vs serverless makes sense"
- "Understand cost implications of different architectures"

### Real-World Experience
- "Used ECR for container registry management"
- "Configured ECS services with proper scaling policies"
- "Implemented Lambda with SQS triggers for event processing"
- "Set up API Gateway for serverless HTTP traffic"

### Architecture Decision Making
- "Chose containers for stateful Rails app with consistent traffic"
- "Used Lambda for event-driven processing with variable load"
- "Optimized costs by matching service characteristics to deployment model"

---

## Cleanup Commands

### ECS Cleanup
```bash
aws ecs delete-service --cluster pubsub-cluster --service order-publisher --force
aws ecs delete-cluster --cluster pubsub-cluster
```

### Lambda Cleanup  
```bash
aws lambda delete-function --function-name email-lambda
aws lambda delete-function --function-name inventory-lambda
aws lambda delete-function --function-name analytics-lambda
```

### ECR Cleanup
```bash
aws ecr delete-repository --repository-name order-publisher --force
aws ecr delete-repository --repository-name email-service --force
```

This progressive approach gives you experience with multiple AWS deployment patterns - perfect for tomorrow's interview! 🚀 