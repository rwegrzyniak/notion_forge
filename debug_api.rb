#!/usr/bin/env ruby

require 'json'
require 'openssl'
require 'base64'
require 'digest'
require_relative 'lib/notion_forge'

# Load configuration
config_path = File.expand_path("~/.notion_forge/secrets")
if File.exist?(config_path)
  encrypted_config = JSON.parse(File.read(config_path))
  
  # Decrypt
  cipher = OpenSSL::Cipher.new('AES-256-GCM')
  cipher.decrypt
  machine_id = `uname -n`.strip rescue "unknown"
  user_id = ENV['USER'] || ENV['USERNAME'] || "unknown"
  key = Digest::SHA256.digest("#{machine_id}:#{user_id}:notion_forge")
  cipher.key = key
  cipher.iv = Base64.strict_decode64(encrypted_config['iv'])
  cipher.auth_tag = Base64.strict_decode64(encrypted_config['auth_tag'])
  
  decrypted_data = cipher.update(Base64.strict_decode64(encrypted_config['data'])) + cipher.final
  config = JSON.parse(decrypted_data)
  
  puts "🧪 Testing direct API call"
  puts "Token: secret_***#{config['token'][-8..]}"
  puts "Page ID: #{config['parent_page_id']}"
  
  # Make direct HTTP call
  require 'net/http'
  require 'uri'
  
  uri = URI("https://api.notion.com/v1/pages/#{config['parent_page_id']}")
  puts "URL: #{uri}"
  
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.open_timeout = 5
  http.read_timeout = 10
  
  request = Net::HTTP::Get.new(uri)
  request['Authorization'] = "Bearer #{config['token']}"
  request['Notion-Version'] = '2022-06-28'
  
  puts "Making request..."
  
  begin
    response = http.request(request)
    puts "Response: #{response.code} #{response.message}"
    puts "Body: #{response.body[0..200]}..."
  rescue => e
    puts "Error: #{e.message}"
    puts "Class: #{e.class}"
  end
else
  puts "❌ Config not found"
end
