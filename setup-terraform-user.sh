#!/bin/bash

# setup-terraform-user.sh
# Script to create and configure the terraform-user with all necessary permissions

set -e

USER_NAME="terraform-user"

echo "🔐 Setting up Terraform User with EKS permissions..."

# Check if user exists
if aws iam get-user --user-name $USER_NAME >/dev/null 2>&1; then
    echo "✅ User $USER_NAME already exists"
else
    echo "👤 Creating user: $USER_NAME"
    aws iam create-user --user-name $USER_NAME
fi

# Required AWS Managed Policies for EKS + Terraform
POLICIES=(
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    "arn:aws:iam::aws:policy/AmazonVPCFullAccess" 
    "arn:aws:iam::aws:policy/IAMFullAccess"
    "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
    "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
    "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
    "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
)

echo "📋 Attaching required policies..."
for policy in "${POLICIES[@]}"; do
    policy_name=$(basename $policy)
    echo "  - Attaching: $policy_name"
    aws iam attach-user-policy --user-name $USER_NAME --policy-arn $policy
done

# Create ECS Task Role Pass Policy (custom policy needed for ECS)
CUSTOM_POLICY_NAME="ECSTaskRolePassPolicy"
echo "📝 Creating custom policy: $CUSTOM_POLICY_NAME"

POLICY_DOC='{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "iam:PassRole",
                "iam:GetRole",
                "iam:CreateRole",
                "iam:AttachRolePolicy",
                "iam:DetachRolePolicy",
                "iam:ListAttachedRolePolicies"
            ],
            "Resource": "*"
        }
    ]
}'

# Check if custom policy exists
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CUSTOM_POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${CUSTOM_POLICY_NAME}"

if aws iam get-policy --policy-arn $CUSTOM_POLICY_ARN >/dev/null 2>&1; then
    echo "✅ Custom policy already exists"
else
    echo "  Creating custom policy..."
    aws iam create-policy \
        --policy-name $CUSTOM_POLICY_NAME \
        --policy-document "$POLICY_DOC"
fi

echo "  Attaching custom policy..."
aws iam attach-user-policy --user-name $USER_NAME --policy-arn $CUSTOM_POLICY_ARN

# Check if access keys exist
echo "🔑 Checking access keys..."
EXISTING_KEYS=$(aws iam list-access-keys --user-name $USER_NAME --query 'AccessKeyMetadata' --output text)

if [ -z "$EXISTING_KEYS" ]; then
    echo "  Creating access keys..."
    aws iam create-access-key --user-name $USER_NAME > terraform-user-credentials.json
    echo "🚨 IMPORTANT: Your credentials are saved in terraform-user-credentials.json"
    echo "🚨 Configure these in your AWS CLI or environment variables"
else
    echo "✅ Access keys already exist"
fi

echo ""
echo "✅ Terraform user setup complete!"
echo ""
echo "📋 Summary of attached policies:"
aws iam list-attached-user-policies --user-name $USER_NAME --query 'AttachedPolicies[].PolicyName' --output table

echo ""
echo "🚀 You can now run: ./deploy-k8s.sh" 