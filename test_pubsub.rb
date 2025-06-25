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