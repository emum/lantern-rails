module Lantern
  module Rails
    class Configuration
      attr_accessor :api_key, :host, :interval, :environment, :enabled, :collect_in_environments

      def initialize
        @host                     = "https://uselantern.dev"
        @interval                 = 300  # 5 minutes
        @environment              = detect_environment
        @enabled                  = true
        @collect_in_environments  = %w[production staging]
      end

      def valid?
        api_key.present?
      end

      private

      def detect_environment
        defined?(::Rails) ? ::Rails.env.to_s : "production"
      end
    end
  end
end
