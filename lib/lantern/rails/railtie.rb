module Lantern
  module Rails
    class Railtie < ::Rails::Railtie
      config.after_initialize do
        config = Lantern::Rails.configuration
        next unless config.valid?
        next unless config.enabled
        next unless config.collect_in_environments.include?(::Rails.env.to_s)

        runner = Lantern::Rails::Runner.new(config)

        at_exit { runner.stop }

        runner.start
      end
    end
  end
end
