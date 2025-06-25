class ApplicationController < ActionController::Base
  # Disable CSRF protection for API testing
  # protect_from_forgery with: :exception
end
