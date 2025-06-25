# email_service.rb (standalone script)
require 'aws-sdk-sqs'
require 'json'

class EmailService
  def self.start
    queue_url = "https://sqs.#{ENV['AWS_REGION'] || 'us-east-1'}.amazonaws.com/#{ENV['AWS_ACCOUNT_ID'] || '484123688626'}/email-service-queue"
    
    sqs = Aws::SQS::Client.new
    puts "Email Service starting... listening to #{queue_url}"

    loop do
      begin
        response = sqs.receive_message({
          queue_url: queue_url,
          max_number_of_messages: 10,
          wait_time_seconds: 20 # Long polling
        })

        response.messages.each do |message|
          process_message(JSON.parse(message.body), sqs, message.receipt_handle, queue_url)
        end
      rescue => e
        puts "Error in email service: #{e.message}"
        sleep 5
      end
    end
  end

  private

  def self.process_message(sns_message, sqs, receipt_handle, queue_url)
    order_data = JSON.parse(sns_message['Message'])
    
    case order_data['event_type']
    when 'order.created'
      send_order_confirmation(order_data)
    when 'order.updated'
      send_status_update(order_data)
    end

    # Delete message after processing
    sqs.delete_message({
      queue_url: queue_url,
      receipt_handle: receipt_handle
    })
  end

  def self.send_order_confirmation(order_data)
    puts "📧 Sending order confirmation email for order #{order_data['order_id']}"
    puts "   User: #{order_data['user_id']}, Total: $#{order_data['total']}"
    # In real app: EmailMailer.order_confirmation(order_data).deliver_now
  end

  def self.send_status_update(order_data)
    puts "📧 Sending status update email for order #{order_data['order_id']}"
    puts "   New status: #{order_data['status']}"
    # In real app: EmailMailer.status_update(order_data).deliver_now
  end
end

# Start the service
EmailService.start if __FILE__ == $0