module Lantern
  module Rails
    class Railtie < ::Rails::Railtie
      initializer "lantern.request_tracker" do |app|
        # Insert middleware unconditionally — it checks config at runtime
        # and no-ops if Lantern isn't configured. This avoids the frozen
        # middleware stack issue in Rails 8.1 while ensuring the API key
        # (set in app initializers) is available when requests arrive.
        app.middleware.use Lantern::Rails::RequestTracker, Lantern::Rails.query_aggregator
      end

      config.after_initialize do
        config = Lantern::Rails.configuration

        unless config.valid?
          ::Rails.logger.info(
            "[Lantern] No API key configured. Get your free key at https://uselantern.dev " \
            "then run: rails generate lantern:install"
          )
          next
        end

        unless config.enabled
          ::Rails.logger.info("[Lantern] Disabled via configuration.")
          next
        end

        unless config.collect_in_environments.include?(::Rails.env.to_s)
          ::Rails.logger.info("[Lantern] Skipping collection in #{::Rails.env} environment.")
          next
        end

        runner = Lantern::Rails::Runner.new(config)

        at_exit { runner.stop }

        runner.start
      end
    end
  end
end
