require "monitor"

module Lantern
  module Rails
    class QueryAggregator
      include MonitorMixin

      def initialize
        super() # MonitorMixin requires this
        @requests = []
      end

      # Called at the end of each request with the queries captured during it.
      # request_data is a Hash:
      #   { controller_action: "orders#index", queries: { fingerprint => { count: N, sample_sql: "..." } } }
      def record_request(request_data)
        synchronize { @requests << request_data }
      end

      # Drain the buffer and return aggregated N+1 candidates.
      # Returns an Array of Hashes ready to send as query_patterns in the snapshot payload.
      def drain
        captured = synchronize do
          data = @requests
          @requests = []
          data
        end

        aggregate(captured)
      end

      private

      def aggregate(requests)
        return [] if requests.empty?

        # Group by (controller_action, fingerprint)
        grouped = Hash.new { |h, k| h[k] = { counts: [], sample_sql: nil } }

        requests.each do |req|
          action = req[:controller_action]
          next if action.nil? || action.empty?

          req[:queries]&.each do |fingerprint, data|
            key = "#{action}||#{fingerprint}"
            grouped[key][:counts] << data[:count]
            grouped[key][:sample_sql] ||= data[:sample_sql]
            grouped[key][:controller_action] = action
            grouped[key][:fingerprint] = fingerprint
          end
        end

        # Filter to N+1 candidates (avg > 2 calls per request) and build output
        grouped.filter_map do |_key, data|
          counts = data[:counts]
          avg = counts.sum.to_f / counts.size
          next if avg <= 2.0

          {
            query_fingerprint: data[:fingerprint],
            controller_action: data[:controller_action],
            calls_per_request_avg: avg.round(1),
            calls_per_request_max: counts.max,
            requests_sampled: counts.size,
            sample_sql: data[:sample_sql]&.then { |s| s.length > 2000 ? s[0, 2000] : s }
          }
        end.sort_by { |qp| -qp[:calls_per_request_avg] }
      end
    end
  end
end
