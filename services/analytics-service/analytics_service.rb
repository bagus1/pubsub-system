# analytics_service.rb
require 'aws-sdk-sqs'
require 'json'

class AnalyticsService
  def self.start
    queue_url = "https://sqs.#{ENV['AWS_REGION'] || 'us-east-1'}.amazonaws.com/#{ENV['AWS_ACCOUNT_ID'] || '484123688626'}/analytics-service-queue"
    
    sqs = Aws::SQS::Client.new
    puts "Analytics Service starting... listening to #{queue_url}"

    loop do
      begin
        response = sqs.receive_message({
          queue_url: queue_url,
          max_number_of_messages: 10,
          wait_time_seconds: 20
        })

        response.messages.each do |message|
          process_message(JSON.parse(message.body), sqs, message.receipt_handle, queue_url)
        end
      rescue => e
        puts "Error in analytics service: #{e.message}"
        sleep 5
      end
    end
  end

  private

  def self.process_message(sns_message, sqs, receipt_handle, queue_url)
    order_data = JSON.parse(sns_message['Message'])
    
    track_event(order_data)

    sqs.delete_message({
      queue_url: queue_url,
      receipt_handle: receipt_handle
    })
  end

  def self.track_event(order_data)
    puts "📊 Tracking analytics event: #{order_data['event_type']}"
    puts "   Order: #{order_data['order_id']}, User: #{order_data['user_id']}"
    puts "   Total: $#{order_data['total']}, Status: #{order_data['status']}"
    
    # In real app: 
    # AnalyticsTracker.track(order_data['event_type'], {
    #   order_id: order_data['order_id'],
    #   user_id: order_data['user_id'],
    #   revenue: order_data['total']
    # })
  end
end

AnalyticsService.start if __FILE__ == $0