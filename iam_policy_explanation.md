# AWS IAM Policy JSON Structure Explained

## What's happening in Step 1.5

The `--attributes` parameter takes a JSON string that contains an IAM policy. This policy gets attached to the SQS queue to control who can access it.

## JSON Structure Breakdown

```json
{
  "Policy": "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [
      {
        \"Effect\": \"Allow\",
        \"Principal\": {
          \"Service\": \"sns.amazonaws.com\"
        },
        \"Action\": \"sqs:SendMessage\",
        \"Resource\": \"<queue-arn>\",
        \"Condition\": {
          \"ArnEquals\": {
            \"aws:SourceArn\": \"<topic-arn>\"
          }
        }
      }
    ]
  }"
}
```

## Each JSON Field Explained

### Top Level
- **`Policy`**: The entire IAM policy document (as a JSON string)

### Policy Document Fields
- **`Version`**: IAM policy language version
  - Always use `"2012-10-17"` (current version)
  - This is the date the policy language was last updated

### Statement Array
- **`Statement`**: Array of permission statements (can have multiple)
- Each statement is a complete permission rule

### Statement Fields
- **`Effect`**: 
  - `"Allow"` = Grant the permission
  - `"Deny"` = Explicitly deny (overrides any Allow)

- **`Principal`**: WHO is allowed to perform the action
  - `{"Service": "sns.amazonaws.com"}` = The SNS service
  - Could also be `{"AWS": "arn:aws:iam::123456789012:user/username"}` for users
  - Or `{"AWS": "*"}` for anyone (dangerous!)

- **`Action`**: WHAT actions are allowed
  - `"sqs:SendMessage"` = Can send messages to the queue
  - Could be `"sqs:*"` for all SQS actions
  - Or `["sqs:SendMessage", "sqs:ReceiveMessage"]` for multiple actions

- **`Resource`**: WHERE the action can be performed
  - `"<queue-arn>"` = This specific queue
  - Could be `"*"` for all resources (dangerous!)
  - Or `"arn:aws:sqs:us-east-1:123456789012:*"` for all queues in account

- **`Condition`**: WHEN/IF the action is allowed (optional)
  - `{"ArnEquals": {"aws:SourceArn": "<topic-arn>"}}` = Only if message comes from our topic
  - Many condition types: `StringEquals`, `IpAddress`, `DateGreaterThan`, etc.

## Why the Escaped Quotes?

The command line requires the Policy value to be a JSON string, so:
```bash
--attributes '{"Policy": "JSON_STRING_HERE"}'
```

Inside that JSON string, quotes must be escaped with backslashes:
```json
"Policy": "{\"Version\":\"2012-10-17\", ...}"
```

## Alternative: Policy Files

Instead of inline JSON, you could create a file:

**queue-policy.json:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "sns.amazonaws.com"
      },
      "Action": "sqs:SendMessage",
      "Resource": "arn:aws:sqs:us-east-1:484123688626:email-service-queue",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "arn:aws:sns:us-east-1:484123688626:order-events"
        }
      }
    }
  ]
}
```

Then use:
```bash
aws sqs set-queue-attributes --queue-url <url> --attributes Policy=file://queue-policy.json
```

## Official AWS Documentation

### IAM Policy Reference
- **Main Policy Docs**: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies.html
- **Policy Elements**: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements.html
- **Condition Reference**: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_condition-keys.html

### SQS Specific
- **SQS Access Policy**: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-access-policy-language-overview.html
- **SQS Actions**: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_Operations.html

### SNS Specific  
- **SNS Access Control**: https://docs.aws.amazon.com/sns/latest/dg/sns-access-policy-language-overview.html

### CLI Reference
- **SQS set-queue-attributes**: https://docs.aws.amazon.com/cli/latest/reference/sqs/set-queue-attributes.html

## Real-World Examples

### More Restrictive (IP-based)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"Service": "sns.amazonaws.com"},
      "Action": "sqs:SendMessage",
      "Resource": "*",
      "Condition": {
        "IpAddress": {
          "aws:SourceIp": "203.0.113.0/24"
        }
      }
    }
  ]
}
```

### Time-based Access
```json
{
  "Version": "2012-10-17", 
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"Service": "sns.amazonaws.com"},
      "Action": "sqs:SendMessage",
      "Resource": "*",
      "Condition": {
        "DateGreaterThan": {
          "aws:CurrentTime": "2024-01-01T00:00:00Z"
        }
      }
    }
  ]
}
```

## Interview Talking Points

- "IAM policies use a JSON structure with Effect, Principal, Action, Resource, and optional Conditions"
- "The principle of least privilege - only grant the minimum permissions needed"
- "Resource-based policies (like SQS queue policies) vs identity-based policies (attached to users/roles)"
- "Conditions allow fine-grained control based on time, IP, source ARN, etc." 