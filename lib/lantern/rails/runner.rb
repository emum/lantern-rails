module Lantern
  module Rails
    class Runner
      def initialize(config)
        @config   = config
        @thread   = nil
        @stopping = false
      end

      def start
        return unless @config.valid? && @config.enabled

        @thread = Thread.new do
          ::Rails.logger.info("[Lantern] Collector started (interval: #{@config.interval}s)")
          loop do
            break if @stopping
            collect_and_report
            sleep @config.interval
            break if @stopping
          end
        end

        @thread.abort_on_exception = false
        @thread.name = "lantern-collector"
      end

      def stop
        @stopping = true
        @thread&.join(5)
      end

      private

      def collect_and_report
        payload = Collector.new.collect
        return unless payload

        Reporter.new(@config).report_snapshot(payload)
      rescue => e
        ::Rails.logger.error("[Lantern] Runner error: #{e.message}")
      end
    end
  end
end
