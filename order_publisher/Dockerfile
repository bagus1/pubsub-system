# Use official Ruby image
FROM ruby:3.4.2

# Set working directory
WORKDIR /app

# Install dependencies
RUN apt-get update -qq && \
    apt-get install -y nodejs postgresql-client && \
    rm -rf /var/lib/apt/lists/*

# Copy Gemfile and install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy application code
COPY . .

# Expose port
EXPOSE 3000

# Create startup script
RUN echo '#!/bin/bash\nset -e\n\n# Run database migrations\nrails db:migrate\n\n# Start the Rails server\nexec rails server -b 0.0.0.0' > /app/startup.sh && \
    chmod +x /app/startup.sh

# Start command
CMD ["/app/startup.sh"]
