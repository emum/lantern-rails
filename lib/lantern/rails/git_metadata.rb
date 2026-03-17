module Lantern
  module Rails
    module GitMetadata
      def self.collect
        sha     = run("git rev-parse --short HEAD")
        message = run("git log -1 --pretty=%s")
        author  = run("git log -1 --pretty=%ae")
        { sha: sha, message: message, author: author }
      rescue => e
        ::Rails.logger.debug("[Lantern] Git metadata unavailable: #{e.message}")
        { sha: nil, message: nil, author: nil }
      end

      def self.run(cmd)
        result = `#{cmd} 2>/dev/null`.strip
        result.empty? ? nil : result
      end
      private_class_method :run
    end
  end
end
