SecureHeaders::Configuration.default do |config|
  # Content Security Policy (CSP) - OWASP A03:2021 Injection Prevention
  config.csp = {
    default_src: %w('self'),
    script_src: %w('self' 'unsafe-inline' cdn.jsdelivr.net cdnjs.cloudflare.com),
    style_src: %w('self' 'unsafe-inline' cdn.jsdelivr.net cdnjs.cloudflare.com),
    img_src: %w('self' data: https:),
    font_src: %w('self' cdnjs.cloudflare.com),
    connect_src: %w('self'),
    frame_ancestors: %w('none'),
    base_uri: %w('self'),
    form_action: %w('self')
  }
  
  # HTTP Strict Transport Security (HSTS) - OWASP A02:2021 Cryptographic Failures
  config.hsts = "max-age=#{1.year.to_i}; includeSubDomains; preload"
  
  # X-Frame-Options - OWASP A03:2021 Injection (Clickjacking)
  config.x_frame_options = 'DENY'
  
  # X-Content-Type-Options - OWASP A06:2021 Vulnerable Components
  config.x_content_type_options = 'nosniff'
  
  # X-XSS-Protection - OWASP A03:2021 Injection (XSS)
  config.x_xss_protection = '1; mode=block'
  
  # Referrer Policy - OWASP A01:2021 Broken Access Control
  config.referrer_policy = 'strict-origin-when-cross-origin'
  
  # Permissions Policy (Feature Policy) - Not supported in this version of secure_headers
  # config.permissions_policy = {
  #   camera: %w(),
  #   microphone: %w(),
  #   geolocation: %w(),
  #   payment: %w()
  # }
end 