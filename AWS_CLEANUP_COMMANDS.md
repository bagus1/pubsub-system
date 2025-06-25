# AWS Cleanup Commands

## Delete SNS Subscriptions First
```bash
# List all subscriptions to get their ARNs
aws sns list-subscriptions

# Delete each subscription (use the actual SubscriptionArn from the list command)
aws sns unsubscribe --subscription-arn arn:aws:sns:us-east-1:484123688626:order-events:6378a17c-3e0f-45b0-8287-bcbb8397d6ea
aws sns unsubscribe --subscription-arn arn:aws:sns:us-east-1:484123688626:order-events:20c136c2-57f2-4d19-b96e-9fe8e3323c63
aws sns unsubscribe --subscription-arn arn:aws:sns:us-east-1:484123688626:order-events:6e87c0fb-5e59-4d64-993b-b68036e0bdc0
```

## Delete SNS Topic
```bash
aws sns delete-topic --topic-arn arn:aws:sns:us-east-1:484123688626:order-events
```

## Delete SQS Queues
```bash
aws sqs delete-queue --queue-url https://sqs.us-east-1.amazonaws.com/484123688626/email-service-queue
aws sqs delete-queue --queue-url https://sqs.us-east-1.amazonaws.com/484123688626/inventory-service-queue
aws sqs delete-queue --queue-url https://sqs.us-east-1.amazonaws.com/484123688626/analytics-service-queue
```

## Verify Cleanup
```bash
# Should return empty results
aws sns list-topics
aws sqs list-queues
aws sns list-subscriptions
```

## Remove IAM Policies (Optional)
If you want to remove the SQS/SNS permissions we added to terraform-user:

```bash
# List attached policies
aws iam list-attached-user-policies --user-name terraform-user

# Detach the policies we added
aws iam detach-user-policy --user-name terraform-user --policy-arn arn:aws:iam::aws:policy/AmazonSQSFullAccess
aws iam detach-user-policy --user-name terraform-user --policy-arn arn:aws:iam::aws:policy/AmazonSNSFullAccess
```

## One-Liner Cleanup Script
```bash
# Delete subscriptions (you'll need to get the actual ARNs first)
aws sns list-subscriptions --query 'Subscriptions[?TopicArn==`arn:aws:sns:us-east-1:484123688626:order-events`].SubscriptionArn' --output text | xargs -I {} aws sns unsubscribe --subscription-arn {}

# Delete topic
aws sns delete-topic --topic-arn arn:aws:sns:us-east-1:484123688626:order-events

# Delete queues
aws sqs list-queues --queue-name-prefix email-service --query 'QueueUrls[0]' --output text | xargs -I {} aws sqs delete-queue --queue-url {}
aws sqs list-queues --queue-name-prefix inventory-service --query 'QueueUrls[0]' --output text | xargs -I {} aws sqs delete-queue --queue-url {}
aws sqs list-queues --queue-name-prefix analytics-service --query 'QueueUrls[0]' --output text | xargs -I {} aws sqs delete-queue --queue-url {}
```

## Cost Check
After cleanup, verify no charges:
```bash
# These should all return empty
aws sns list-topics
aws sqs list-queues
```

**Note**: SNS and SQS have very minimal costs, but it's good practice to clean up resources you're not using! 