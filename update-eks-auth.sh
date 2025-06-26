#!/bin/bash

# Script to add github-actions-user to EKS cluster access
# This script should be run by someone with admin access to the EKS cluster

set -e

CLUSTER_NAME="pubsub-cluster"
REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Adding github-actions-user to EKS cluster access..."
echo "Cluster: $CLUSTER_NAME"
echo "Region: $REGION"
echo "Account ID: $ACCOUNT_ID"

# Get current aws-auth ConfigMap
kubectl get configmap aws-auth -n kube-system -o yaml > /tmp/aws-auth-patch.yaml

# Create the patch for aws-auth ConfigMap
cat << EOF > /tmp/aws-auth-users.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::$ACCOUNT_ID:role/pubsub-eks-node-group-role
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
  mapUsers: |
    - userarn: arn:aws:iam::$ACCOUNT_ID:user/github-actions-user
      username: github-actions-user
      groups:
        - system:masters
EOF

echo "Applying aws-auth ConfigMap update..."
kubectl apply -f /tmp/aws-auth-users.yaml

echo "Verifying the update..."
kubectl get configmap aws-auth -n kube-system -o yaml

echo "✅ Successfully added github-actions-user to EKS cluster access!"
echo "The GitHub Actions workflow should now be able to deploy to the cluster."

# Cleanup
rm -f /tmp/aws-auth-patch.yaml /tmp/aws-auth-users.yaml 