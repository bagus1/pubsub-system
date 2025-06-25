# app/services/order_event_publisher.rb
require 'net/http'
require 'json'

class OrderEventPublisher
  def self.sns_topic_arn
    Rails.application.credentials.dig(:aws, :sns_topic_arn) || ENV['AWS_SNS_TOPIC_ARN']
  end

  def self.fetch_instance_credentials
    begin
      # Get role name
      role_uri = URI('http://169.254.169.254/latest/meta-data/iam/security-credentials/')
      role_name = Net::HTTP.get(role_uri).strip
      
      # Get credentials
      creds_uri = URI("http://169.254.169.254/latest/meta-data/iam/security-credentials/#{role_name}")
      creds_response = Net::HTTP.get(creds_uri)
      creds = JSON.parse(creds_response)
      
      {
        access_key_id: creds['AccessKeyId'],
        secret_access_key: creds['SecretAccessKey'],
        session_token: creds['Token']
      }
    rescue => e
      Rails.logger.error "Failed to fetch instance credentials: #{e.message}"
      nil
    end
  end

  def self.publish(event_type, order)
    Rails.logger.info "Attempting to publish order event for order #{order.id}"
    
    # Try to get credentials from instance metadata
    instance_creds = fetch_instance_credentials
    
    if instance_creds
      Rails.logger.info "Using instance credentials"
      credentials = Aws::Credentials.new(
        instance_creds[:access_key_id],
        instance_creds[:secret_access_key],
        instance_creds[:session_token]
      )
    else
      Rails.logger.info "Falling back to default credential chain"
      credentials = nil
    end

    sns = if credentials
      Aws::SNS::Client.new(
        credentials: credentials,
        region: ENV['AWS_REGION'] || 'us-east-1'
      )
    else
      Aws::SNS::Client.new(
        region: ENV['AWS_REGION'] || 'us-east-1'
      )
    end

    message = {
      event_type: event_type,
      order_id: order.id,
      user_id: order.user_id,
      total: order.total,
      status: order.status,
      timestamp: Time.current.iso8601
    }

    Rails.logger.info "Publishing to SNS: #{message.to_json}"
    
    response = sns.publish({
      topic_arn: sns_topic_arn,
      message: message.to_json,
      subject: "Order Event: #{event_type}"
    })

    Rails.logger.info "SUCCESS: Published #{event_type} for order #{order.id} - Message ID: #{response.message_id}"
  rescue => e
    Rails.logger.error "FAILED to publish order event: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    # Don't re-raise so order creation doesn't fail
    Rails.logger.error "Order creation will continue without event publishing..."
  end
end