# frozen_string_literal: true

require "net/http"
require "json"
require "singleton"
require "forwardable"

module NotionForge
  class Client
    include Singleton

    BASE_URI = URI("https://api.notion.com/v1")
    NOTION_VERSION = "2022-06-28"
    RATE_LIMIT_DELAY = 0.5 # 500ms between requests
    MAX_RETRIES = 3
    RETRY_BACKOFF = [1, 2, 4] # exponential backoff

    class << self
      extend Forwardable
      def_delegators :instance, :get, :post, :patch, :exists?
    end

    def initialize
      @mutex = Mutex.new
      @last_request_time = 0
    end

    def get(path)
      request(path, :get)
    end

    def post(path, body:)
      request(path, :post, body: body)
    end

    def patch(path, body:)
      request(path, :patch, body: body)
    end

    def exists?(path)
      !get(path)["archived"]
    rescue
      false
    end

    private

    def request(path, method, body: nil)
      @mutex.synchronize do
        rate_limit!
        execute_with_retries(path, method, body)
      end
    end

    def execute_with_retries(path, method, body)
      MAX_RETRIES.times do |attempt|
        begin
          return execute_request(path, method, body)
        rescue APIError => e
          if e.message.include?("429") && attempt < MAX_RETRIES - 1
            # Rate limited - exponential backoff
            delay = RETRY_BACKOFF[attempt]
            NotionForge.log(:warn, "⏸️  Rate limited, retrying in #{delay}s...")
            sleep(delay)
            next
          else
            raise
          end
        end
      end
    end

    def execute_request(path, method, body)
      # Fix URI.join behavior - ensure path is properly appended to base URI
      full_path = path.start_with?('/') ? path[1..-1] : path
      uri = URI.join("#{BASE_URI}/", full_path)
      
      # Debug: Log the constructed URL
      if NotionForge.configuration.verbose
        puts "🔍 DEBUG: API Request"
        puts "   Method: #{method.upcase}"
        puts "   Path: #{path}"
        puts "   Full URL: #{uri}"
        puts "   Body: #{body ? JSON.pretty_generate(body) : 'None'}"
      end
      
      http = Net::HTTP.new(uri.host, uri.port).tap do |h|
        h.use_ssl = true
        h.open_timeout = 10  # 10 seconds to establish connection
        h.read_timeout = 30  # 30 seconds to read response
      end

      req = build_request(uri, method, body)
      
      # Debug: Log request attempt
      if NotionForge.configuration.verbose
        puts "📡 Making request..."
      end
      
      res = http.request(req)
      
      # Debug: Log response
      if NotionForge.configuration.verbose
        puts "📥 Response received:"
        puts "   Status: #{res.code} #{res.message}"
        puts "   Headers: #{res.to_hash.inspect}" if res.code != '200'
      end

      handle_response(res)
    end

    def build_request(uri, method, body)
      req_class = case method
                  when :get then Net::HTTP::Get
                  when :post then Net::HTTP::Post
                  when :patch then Net::HTTP::Patch
                  end

      req_class.new(uri).tap do |req|
        req["Authorization"] = "Bearer #{NotionForge.token}"
        req["Notion-Version"] = NOTION_VERSION
        req["Content-Type"] = "application/json"
        req["User-Agent"] = "NotionForge/#{NotionForge::VERSION}"
        req.body = body.to_json if body
      end
    end

    def handle_response(response)
      case response
      when Net::HTTPSuccess
        JSON.parse(response.body)
      when Net::HTTPTooManyRequests
        raise APIError, "HTTP 429: Rate limited - #{response.body}"
      when Net::HTTPUnauthorized
        raise APIError, "HTTP 401: Invalid token - #{response.body}"
      when Net::HTTPForbidden
        raise APIError, "HTTP 403: Forbidden - check permissions - #{response.body}"
      when Net::HTTPNotFound
        raise APIError, "HTTP 404: Resource not found - #{response.body}"
      else
        raise APIError, "HTTP #{response.code}: #{response.body}"
      end
    end

    def rate_limit!
      now = Time.now.to_f
      time_since_last = now - @last_request_time

      if time_since_last < RATE_LIMIT_DELAY
        sleep_time = RATE_LIMIT_DELAY - time_since_last
        NotionForge.log(:debug, "⏱️  Rate limiting: sleeping #{sleep_time.round(2)}s")
        sleep(sleep_time)
      end

      @last_request_time = Time.now.to_f
    end
  end
end
