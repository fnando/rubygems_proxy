# Idea from: http://speakmy.name/2011/05/29/simple-configuration-for-ruby-apps/
# Configuration parameters go here.

Proxy.config do
  # Proxy server
  # If rubygems_proxy itself is behind a proxy server, add its configuration here.
  # http_proxy_url "http://127.0.0.1:3128
  # http_proxy_user "user"
  # http_proxy_pass "password"
  
  # Time until the download specs expire. Default is 24 hours
  spec_expiry_time 84600
end
