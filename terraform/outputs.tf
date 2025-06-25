output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = aws_eks_cluster.main.name
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for order events"
  value       = aws_sns_topic.order_events.arn
}

output "sqs_queues" {
  description = "URLs of the SQS queues"
  value = {
    email_service     = aws_sqs_queue.email_service.url
    inventory_service = aws_sqs_queue.inventory_service.url
    analytics_service = aws_sqs_queue.analytics_service.url
  }
} 
