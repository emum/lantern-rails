require "lantern/rails/version"
require "lantern/rails/configuration"
require "lantern/rails/git_metadata"
require "lantern/rails/collector"
require "lantern/rails/reporter"
require "lantern/rails/runner"
require "lantern/rails/railtie" if defined?(::Rails)

module Lantern
  module Rails
    class << self
      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield configuration
      end

      # Manually report a deploy event. Call this from your CI/CD pipeline
      # or a deploy hook in your Rails app.
      #
      # Example (in a Rake task or initializer after deploy):
      #   Lantern::Rails.report_deploy
      def report_deploy(git_sha: nil, git_message: nil, git_author: nil, deployer: nil)
        return unless configuration.valid?

        git = GitMetadata.collect

        payload = {
          git_sha:     git_sha     || git[:sha],
          git_message: git_message || git[:message],
          git_author:  git_author  || git[:author],
          deployer:    deployer,
          environment: configuration.environment,
          deployed_at: Time.current.iso8601
        }

        Reporter.new(configuration).report_deploy(payload)
      end
    end
  end
end
