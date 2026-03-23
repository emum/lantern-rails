module Lantern
  module Rails
    class Railtie < ::Rails::Railtie
      config.after_initialize do |app|
        config = Lantern::Rails.configuration
        next unless config.valid?
        next unless config.enabled
        next unless config.collect_in_environments.include?(::Rails.env.to_s)

        app.middleware.use Lantern::Rails::RequestTracker, Lantern::Rails.query_aggregator

        runner = Lantern::Rails::Runner.new(config)

        at_exit { runner.stop }

        runner.start
      end
    end
  end
end
