# AWS Permissions Fix Guide

## Problem
Your `terraform-user` doesn't have SQS permissions. Error:
```
User: arn:aws:iam::484123688626:user/terraform-user is not authorized to perform: sqs:createqueue
```

## Solutions (Choose One)

### Option 1: Add SQS Policy to terraform-user (Recommended)

Create a custom policy for SQS and SNS access:

```bash
# First, let's check current policies
aws iam list-attached-user-policies --user-name terraform-user
aws iam list-user-policies --user-name terraform-user
```

Create a policy file for SQS/SNS permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "sqs:*",
                "sns:*"
            ],
            "Resource": "*"
        }
    ]
}
```

Save this as `sqs-sns-policy.json` and attach it:

```bash
# Create the policy
aws iam create-policy \
    --policy-name SQSSNSFullAccess \
    --policy-document file://sqs-sns-policy.json

# Attach to user
aws iam attach-user-policy \
    --user-name terraform-user \
    --policy-arn arn:aws:iam::484123688626:policy/SQSSNSFullAccess
```

### Option 2: Use AWS Managed Policies (Simpler)

```bash
# Attach AWS managed policies for SQS and SNS
aws iam attach-user-policy \
    --user-name terraform-user \
    --policy-arn arn:aws:iam::aws:policy/AmazonSQSFullAccess

aws iam attach-user-policy \
    --user-name terraform-user \
    --policy-arn arn:aws:iam::aws:policy/AmazonSNSFullAccess
```

### Option 3: Create New User with Admin Access (For Learning)

```bash
# Create a new user for this project
aws iam create-user --user-name pubsub-demo-user

# Attach admin policy (ONLY for learning environments)
aws iam attach-user-policy \
    --user-name pubsub-demo-user \
    --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Create access keys
aws iam create-access-key --user-name pubsub-demo-user
```

### Option 4: Use LocalStack (No AWS Account Needed)

If you want to avoid AWS charges and permission issues entirely:

```bash
# Install LocalStack
pip install localstack

# Start LocalStack
localstack start

# Use LocalStack endpoints
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

# Now run the same commands but they'll hit LocalStack
aws --endpoint-url=http://localhost:4566 sns create-topic --name order-events
```

## Verification Commands

After fixing permissions, test with:

```bash
# Test SQS access
aws sqs create-queue --queue-name test-queue
aws sqs delete-queue --queue-url <queue-url>

# Test SNS access  
aws sns create-topic --name test-topic
aws sns delete-topic --topic-arn <topic-arn>
```

## Recommendation

For this interview prep project, I recommend **Option 2** (AWS managed policies) as it's:
- Quick to implement
- Uses well-tested AWS policies
- Gives you the full AWS experience
- Can be easily removed after the project

## Modified Commands for LocalStack

If you choose LocalStack, update all AWS commands in the plan:

```bash
# Instead of:
aws sns create-topic --name order-events

# Use:
aws --endpoint-url=http://localhost:4566 sns create-topic --name order-events
```

## Next Steps

1. Choose your preferred option above
2. Run the commands to fix permissions
3. Test with the verification commands
4. Continue with Phase 1.2 of the project plan

Let me know which option you prefer and I'll help you implement it! 