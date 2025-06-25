# AWS Pub/Sub Microservices Project Plan

## Project Goal
Build a hands-on AWS SNS/SQS pub/sub system to gain real experience for tomorrow's interview. Create an order processing system with one publisher and multiple subscriber services.

## Architecture Overview
```
Rails Publisher App → SNS Topic "order-events" → Multiple SQS Queues
                                                ├── email-service-queue → Email Service
                                                ├── inventory-service-queue → Inventory Service  
                                                └── analytics-service-queue → Analytics Service
```

## Directory Structure
```
pubsub-system/
├── order_publisher/          # Rails API app (Phase 2)
│   ├── app/
│   │   ├── controllers/orders_controller.rb
│   │   ├── models/order.rb
│   │   └── services/order_event_publisher.rb
│   ├── config/
│   │   ├── routes.rb
│   │   └── credentials.yml.enc
│   └── db/migrate/xxx_create_orders.rb
├── email_service.rb          # Standalone microservice (Phase 3)
├── inventory_service.rb       # Standalone microservice (Phase 3)
├── analytics_service.rb       # Standalone microservice (Phase 3)
└── test_pubsub.rb            # Test script (Phase 4)
```

## Learning Objectives
- Real AWS SNS/SQS experience
- Microservices communication patterns
- Event-driven architecture
- Background job processing at scale
- Interview talking points for tomorrow

---

## Phase 1: AWS Infrastructure Setup (30-45 min)

### Step 1.1: AWS Account & Credentials
- [ ] Verify AWS account access
- [ ] Set up AWS CLI credentials (`aws configure`)
- [ ] Test with `aws sts get-caller-identity`

### Step 1.2: Create SNS Topic
```bash
aws sns create-topic --name order-events
# Note the TopicArn - will need this later
```

### Step 1.3: Create SQS Queues
```bash
# Email service queue
aws sqs create-queue --queue-name email-service-queue

# Inventory service queue  
aws sqs create-queue --queue-name inventory-service-queue

# Analytics service queue
aws sqs create-queue --queue-name analytics-service-queue
```

### Step 1.4: Subscribe SQS Queues to SNS Topic
```bash
# Get queue ARNs first
aws sqs get-queue-attributes --queue-url <email-queue-url> --attribute-names QueueArn

# Subscribe each queue to the SNS topic
aws sns subscribe --topic-arn <topic-arn> --protocol sqs --notification-endpoint <queue-arn>
```

### Step 1.5: Set SQS Permissions
**Why this step matters**: By default, SQS queues don't allow other services to write to them. We need to explicitly allow our SNS topic to send messages to each queue.

**Command template for each queue:**
```bash
aws sqs set-queue-attributes --queue-url <queue-url> --attributes '{
  "Policy": "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"sns.amazonaws.com\"},\"Action\":\"sqs:SendMessage\",\"Resource\":\"<queue-arn>\",\"Condition\":{\"ArnEquals\":{\"aws:SourceArn\":\"<topic-arn>\"}}}]}"
}'
```

**Replace these placeholders:**
- `<queue-url>` - The SQS queue URL (from Step 1.3)
- `<queue-arn>` - The queue's ARN (from Step 1.4)  
- `<topic-arn>` - The SNS topic ARN (from Step 1.2)

**Run this command for all three queues:**
- email-service-queue
- inventory-service-queue  
- analytics-service-queue

**Understanding the Policy Attributes:**
```json
{
  "Policy": {
    "Version": "2012-10-17",           // IAM policy language version
    "Statement": [{
      "Effect": "Allow",               // Grant permission (vs "Deny")
      "Principal": {
        "Service": "sns.amazonaws.com" // WHO can perform the action (SNS service)
      },
      "Action": "sqs:SendMessage",     // WHAT action is allowed (send messages)
      "Resource": "<queue-arn>",       // WHERE the action can be performed (this queue)
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "<topic-arn>" // WHEN/IF condition (only from our topic)
        }
      }
    }]
  }
}
```

**Security Benefits:**
- Only SNS service can send messages (not users or other services)
- Only messages from our specific topic are allowed
- Prevents unauthorized access to queues

---

## Phase 2: Rails Publisher App (45-60 min)

### Step 2.1: Create Rails App
```bash
cd ruby-practice
rails new order_publisher --api
cd order_publisher
```

### Step 2.2: Add AWS Gems
```ruby
# Gemfile
gem 'aws-sdk-sns'
gem 'aws-sdk-sqs'
```

### Step 2.3: AWS Configuration
```ruby
# config/application.rb
Aws.config.update({
  region: 'us-east-1', # or your preferred region
  credentials: Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY'])
})
```

### Step 2.4: Create Order Model
```ruby
# app/models/order.rb
class Order < ApplicationRecord
  after_create :publish_order_created
  after_update :publish_order_updated, if: :saved_change_to_status?

  private

  def publish_order_created
    OrderEventPublisher.publish('order.created', self)
  end

  def publish_order_updated
    OrderEventPublisher.publish('order.updated', self)
  end
end
```

### Step 2.5: Create Event Publisher Service
```ruby
# app/services/order_event_publisher.rb
class OrderEventPublisher
  SNS_TOPIC_ARN = 'arn:aws:sns:us-east-1:YOUR_ACCOUNT:order-events'

  def self.publish(event_type, order)
    sns = Aws::SNS::Client.new
    
    message = {
      event_type: event_type,
      order_id: order.id,
      user_id: order.user_id,
      total: order.total,
      status: order.status,
      timestamp: Time.current.iso8601
    }

    sns.publish({
      topic_arn: SNS_TOPIC_ARN,
      message: message.to_json,
      subject: "Order Event: #{event_type}"
    })

    Rails.logger.info "Published #{event_type} for order #{order.id}"
  rescue => e
    Rails.logger.error "Failed to publish order event: #{e.message}"
  end
end
```

### Step 2.6: Create Orders Controller
```ruby
# app/controllers/orders_controller.rb
class OrdersController < ApplicationController
  def create
    @order = Order.new(order_params)
    
    if @order.save
      render json: @order, status: :created
    else
      render json: @order.errors, status: :unprocessable_entity
    end
  end

  def update
    @order = Order.find(params[:id])
    
    if @order.update(order_params)
      render json: @order
    else
      render json: @order.errors, status: :unprocessable_entity
    end
  end

  private

  def order_params
    params.require(:order).permit(:user_id, :total, :status)
  end
end
```

### Step 2.7: Database Migration
```ruby
# db/migrate/xxx_create_orders.rb
class CreateOrders < ActiveRecord::Migration[7.0]
  def change
    create_table :orders do |t|
      t.integer :user_id, null: false
      t.decimal :total, precision: 10, scale: 2
      t.string :status, default: 'pending'
      t.timestamps
    end

    add_index :orders, :user_id
    add_index :orders, :status
  end
end
```

---

## Phase 3: Subscriber Services (60-90 min)

### Step 3.1: Email Service
```ruby
# email_service.rb (standalone script)
require 'aws-sdk-sqs'
require 'json'

class EmailService
  QUEUE_URL = 'https://sqs.us-east-1.amazonaws.com/YOUR_ACCOUNT/email-service-queue'

  def self.start
    sqs = Aws::SQS::Client.new
    puts "Email Service starting... listening to #{QUEUE_URL}"

    loop do
      begin
        response = sqs.receive_message({
          queue_url: QUEUE_URL,
          max_number_of_messages: 10,
          wait_time_seconds: 20 # Long polling
        })

        response.messages.each do |message|
          process_message(JSON.parse(message.body), sqs, message.receipt_handle)
        end
      rescue => e
        puts "Error in email service: #{e.message}"
        sleep 5
      end
    end
  end

  private

  def self.process_message(sns_message, sqs, receipt_handle)
    order_data = JSON.parse(sns_message['Message'])
    
    case order_data['event_type']
    when 'order.created'
      send_order_confirmation(order_data)
    when 'order.updated'
      send_status_update(order_data)
    end

    # Delete message after processing
    sqs.delete_message({
      queue_url: QUEUE_URL,
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
```

### Step 3.2: Inventory Service
```ruby
# inventory_service.rb
require 'aws-sdk-sqs'
require 'json'

class InventoryService
  QUEUE_URL = 'https://sqs.us-east-1.amazonaws.com/YOUR_ACCOUNT/inventory-service-queue'

  def self.start
    sqs = Aws::SQS::Client.new
    puts "Inventory Service starting... listening to #{QUEUE_URL}"

    loop do
      begin
        response = sqs.receive_message({
          queue_url: QUEUE_URL,
          max_number_of_messages: 10,
          wait_time_seconds: 20
        })

        response.messages.each do |message|
          process_message(JSON.parse(message.body), sqs, message.receipt_handle)
        end
      rescue => e
        puts "Error in inventory service: #{e.message}"
        sleep 5
      end
    end
  end

  private

  def self.process_message(sns_message, sqs, receipt_handle)
    order_data = JSON.parse(sns_message['Message'])
    
    case order_data['event_type']
    when 'order.created'
      reserve_inventory(order_data)
    when 'order.updated'
      handle_status_change(order_data)
    end

    sqs.delete_message({
      queue_url: QUEUE_URL,
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
```

### Step 3.3: Analytics Service
```ruby
# analytics_service.rb
require 'aws-sdk-sqs'
require 'json'

class AnalyticsService
  QUEUE_URL = 'https://sqs.us-east-1.amazonaws.com/YOUR_ACCOUNT/analytics-service-queue'

  def self.start
    sqs = Aws::SQS::Client.new
    puts "Analytics Service starting... listening to #{QUEUE_URL}"

    loop do
      begin
        response = sqs.receive_message({
          queue_url: QUEUE_URL,
          max_number_of_messages: 10,
          wait_time_seconds: 20
        })

        response.messages.each do |message|
          process_message(JSON.parse(message.body), sqs, message.receipt_handle)
        end
      rescue => e
        puts "Error in analytics service: #{e.message}"
        sleep 5
      end
    end
  end

  private

  def self.process_message(sns_message, sqs, receipt_handle)
    order_data = JSON.parse(sns_message['Message'])
    
    track_event(order_data)

    sqs.delete_message({
      queue_url: QUEUE_URL,
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
```

---

## Phase 4: Testing & Demo (30 min)

### Step 4.1: Test Script
```ruby
# test_pubsub.rb
require 'net/http'
require 'json'

# Create test orders
orders = [
  { user_id: 1, total: 29.99, status: 'pending' },
  { user_id: 2, total: 149.50, status: 'pending' },
  { user_id: 1, total: 75.00, status: 'pending' }
]

orders.each_with_index do |order_data, index|
  puts "Creating order #{index + 1}..."
  
  uri = URI('http://localhost:3000/orders')
  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Post.new(uri)
  request['Content-Type'] = 'application/json'
  request.body = { order: order_data }.to_json
  
  response = http.request(request)
  order = JSON.parse(response.body)
  
  puts "Created order #{order['id']}"
  
  # Update status after a moment
  sleep 2
  
  update_uri = URI("http://localhost:3000/orders/#{order['id']}")
  update_request = Net::HTTP::Patch.new(update_uri)
  update_request['Content-Type'] = 'application/json'
  update_request.body = { order: { status: 'confirmed' } }.to_json
  
  http.request(update_request)
  puts "Updated order #{order['id']} to confirmed"
  
  sleep 1
end
```

### Step 4.2: Running the Demo
```bash
# Terminal 1: Start Rails app
cd order_publisher
rails server

# Terminal 2: Start Email Service
ruby email_service.rb

# Terminal 3: Start Inventory Service  
ruby inventory_service.rb

# Terminal 4: Start Analytics Service
ruby analytics_service.rb

# Terminal 5: Run test script
ruby test_pubsub.rb
```

---

## Phase 5: Interview Preparation (15 min)

### Key Talking Points
- [ ] **Event-driven architecture**: How pub/sub decouples services
- [ ] **Scalability**: Each service can scale independently
- [ ] **Reliability**: SQS provides message durability and retry logic
- [ ] **Microservices communication**: Async vs sync patterns
- [ ] **AWS services integration**: SNS, SQS, Rails ecosystem

### Demo Script for Interview
1. Show the architecture diagram
2. Demonstrate creating an order → watch all services react
3. Explain how this scales vs traditional monolith
4. Discuss error handling and retry strategies
5. Talk about monitoring and observability needs

### Questions You Can Answer
- "How do you handle communication between microservices?"
- "What's your experience with AWS messaging services?"
- "How do you ensure message delivery reliability?"
- "What patterns do you use for event-driven architecture?"

---

## Cleanup Checklist
- [ ] Delete SNS topic
- [ ] Delete SQS queues  
- [ ] Remove AWS resources to avoid charges
- [ ] Save code examples for portfolio

## AWS Cleanup Commands

### Step 1: Delete SNS Subscriptions First
```bash
# List all subscriptions to get their ARNs
aws sns list-subscriptions

# Delete each subscription (replace with actual SubscriptionArn from list command)
aws sns unsubscribe --subscription-arn <subscription-arn-1>
aws sns unsubscribe --subscription-arn <subscription-arn-2>
aws sns unsubscribe --subscription-arn <subscription-arn-3>
```

### Step 2: Delete SNS Topic
```bash
aws sns delete-topic --topic-arn <topic-arn>
```

### Step 3: Delete SQS Queues
```bash
aws sqs delete-queue --queue-url <email-queue-url>
aws sqs delete-queue --queue-url <inventory-queue-url>
aws sqs delete-queue --queue-url <analytics-queue-url>
```

### Step 4: Verify Cleanup
```bash
# Should return empty results
aws sns list-topics
aws sqs list-queues
aws sns list-subscriptions
```

### Step 5: Remove IAM Policies (Optional)
If you want to remove the SQS/SNS permissions added to your user:

```bash
# List attached policies
aws iam list-attached-user-policies --user-name <your-username>

# Detach the policies we added
aws iam detach-user-policy --user-name <your-username> --policy-arn arn:aws:iam::aws:policy/AmazonSQSFullAccess
aws iam detach-user-policy --user-name <your-username> --policy-arn arn:aws:iam::aws:policy/AmazonSNSFullAccess
```

### One-Liner Cleanup Script
```bash
# Delete subscriptions for specific topic
aws sns list-subscriptions --query 'Subscriptions[?TopicArn==`<topic-arn>`].SubscriptionArn' --output text | xargs -I {} aws sns unsubscribe --subscription-arn {}

# Delete topic
aws sns delete-topic --topic-arn <topic-arn>

# Delete queues by name prefix
aws sqs list-queues --queue-name-prefix email-service --query 'QueueUrls[0]' --output text | xargs -I {} aws sqs delete-queue --queue-url {}
aws sqs list-queues --queue-name-prefix inventory-service --query 'QueueUrls[0]' --output text | xargs -I {} aws sqs delete-queue --queue-url {}
aws sqs list-queues --queue-name-prefix analytics-service --query 'QueueUrls[0]' --output text | xargs -I {} aws sqs delete-queue --queue-url {}
```

---

## Time Estimates
- **Phase 1 (AWS Setup)**: 30-45 min
- **Phase 2 (Rails Publisher)**: 45-60 min  
- **Phase 3 (Subscribers)**: 60-90 min
- **Phase 4 (Testing)**: 30 min
- **Phase 5 (Interview Prep)**: 15 min
- **Total**: 3-4 hours

---

## Success Criteria
✅ SNS topic publishing messages  
✅ Multiple SQS queues receiving messages  
✅ Rails app publishing order events  
✅ All subscriber services processing events  
✅ End-to-end demo working  
✅ Confident talking points for interview  

## Next Steps After Interview
- Add error handling and dead letter queues
- Implement proper logging and monitoring
- Add authentication and authorization
- Scale testing with more load
- Explore ECS/EKS deployment options 