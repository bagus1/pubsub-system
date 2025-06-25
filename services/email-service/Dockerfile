# Use official Ruby image
FROM ruby:3.2-alpine

# Set working directory
WORKDIR /app

# Install AWS SDK gems
RUN gem install aws-sdk-sqs aws-sdk-sns

# Copy service file
COPY email_service.rb ./

# Run the email service
CMD ["ruby", "email_service.rb"] 