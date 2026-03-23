module Lantern
  module Rails
    class RequestTracker
      IGNORED_SQL = /\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE|SET|SHOW|PRAGMA)/i
      SCHEMA_SQL  = /\A\s*(CREATE|ALTER|DROP|INSERT INTO "schema_migrations")/i

      def initialize(app, aggregator)
        @app = app
        @aggregator = aggregator
      end

      def call(env)
        # No-op if Lantern isn't configured or not enabled for this environment
        return @app.call(env) unless enabled?

        # Only track actual controller requests, skip assets/healthchecks
        return @app.call(env) unless trackable_request?(env)

        request_queries = {}

        subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
          sql = payload[:sql]
          next if sql.blank?
          next if payload[:name] == "SCHEMA" || payload[:cached]
          next if IGNORED_SQL.match?(sql)
          next if SCHEMA_SQL.match?(sql)

          fingerprint = QueryFingerprinter.fingerprint(sql)
          next if fingerprint.blank?

          entry = (request_queries[fingerprint] ||= { count: 0, sample_sql: nil })
          entry[:count] += 1
          entry[:sample_sql] ||= sql.truncate(2000)
        end

        status, headers, response = @app.call(env)

        [status, headers, response]
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber

        if request_queries&.any?
          controller_action = extract_controller_action(env)
          if controller_action
            @aggregator.record_request(
              controller_action: controller_action,
              queries: request_queries
            )
          end
        end
      end

      private

      def enabled?
        return @enabled if defined?(@enabled)

        config = Lantern::Rails.configuration
        @enabled = config.valid? && config.enabled &&
                   config.collect_in_environments.include?(::Rails.env.to_s)
      end

      def trackable_request?(env)
        # Skip asset pipeline, action cable, health checks
        path = env["PATH_INFO"].to_s
        return false if path.start_with?("/assets", "/cable", "/up")
        return false if path.match?(/\.\w+\z/) # static files

        true
      end

      def extract_controller_action(env)
        params = env["action_dispatch.request.parameters"]
        return nil unless params

        controller = params["controller"]
        action = params["action"]
        return nil unless controller && action

        "#{controller}##{action}"
      end
    end
  end
end
