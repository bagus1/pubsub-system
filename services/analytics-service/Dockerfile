# Use official Ruby image
FROM ruby:3.2-alpine

# Set working directory
WORKDIR /app

# Install AWS SDK gems
RUN gem install aws-sdk-sqs aws-sdk-sns

# Copy service file
COPY analytics_service.rb ./

# Run the analytics service
CMD ["ruby", "analytics_service.rb"] 