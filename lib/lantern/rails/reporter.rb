require "net/http"
require "json"
require "uri"

module Lantern
  module Rails
    class Reporter
      def initialize(config)
        @config = config
      end

      def report_snapshot(payload)
        post("/api/v1/snapshots", payload)
      end

      def report_deploy(payload)
        post("/api/v1/deploy_events", payload)
      end

      private

      def post(path, payload)
        uri  = URI("#{@config.host}#{path}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl     = uri.scheme == "https"
        http.open_timeout = 5
        http.read_timeout = 10

        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{@config.api_key}"
        request["Content-Type"]  = "application/json"
        request["Accept"]        = "application/json"
        request.body = payload.to_json

        response = http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          ::Rails.logger.warn("[Lantern] API returned #{response.code}: #{response.body}")
        end

        response
      rescue => e
        ::Rails.logger.error("[Lantern] Failed to report to #{path}: #{e.message}")
        nil
      end
    end
  end
end
