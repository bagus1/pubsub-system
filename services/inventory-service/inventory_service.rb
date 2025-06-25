# inventory_service.rb
require 'aws-sdk-sqs'
require 'json'

class InventoryService
  def self.start
    queue_url = "https://sqs.#{ENV['AWS_REGION'] || 'us-east-1'}.amazonaws.com/#{ENV['AWS_ACCOUNT_ID'] || '484123688626'}/inventory-service-queue"
    
    sqs = Aws::SQS::Client.new
    puts "Inventory Service starting... listening to #{queue_url}"

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
        puts "Error in inventory service: #{e.message}"
        sleep 5
      end
    end
  end

  private

  def self.process_message(sns_message, sqs, receipt_handle, queue_url)
    order_data = JSON.parse(sns_message['Message'])
    
    case order_data['event_type']
    when 'order.created'
      reserve_inventory(order_data)
    when 'order.updated'
      handle_status_change(order_data)
    end

    sqs.delete_message({
      queue_url: queue_url,
      receipt_handle: receipt_handle
    })
  end

  def self.reserve_inventory(order_data)
    puts "📦 Reserving inventory for order #{order_data['order_id']}"
    puts "   Processing $#{order_data['total']} worth of items"
    # In real app: InventoryManager.reserve_items(order_data)
  end

  def self.handle_status_change(order_data)
    puts "📦 Handling status change for order #{order_data['order_id']}"
    puts "   Status: #{order_data['status']}"
    
    case order_data['status']
    when 'cancelled'
      puts "   Releasing reserved inventory"
    when 'shipped'
      puts "   Removing items from inventory"
    end
  end
end

InventoryService.start if __FILE__ == $0