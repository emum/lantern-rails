module Lantern
  class InstallGenerator < ::Rails::Generators::Base
    source_root File.expand_path("templates", __dir__)

    desc "Creates a Lantern initializer with your API key."

    def copy_initializer
      template "lantern.rb.tt", "config/initializers/lantern.rb"
    end

    def print_next_steps
      say ""
      say "Lantern installed!", :green
      say ""
      say "Next steps:"
      say "  1. Add your API key to config/initializers/lantern.rb"
      say "     Get your free key at: https://uselantern.dev"
      say "  2. Deploy your app — Lantern starts collecting automatically"
      say "  3. Open https://uselantern.dev to see your dashboard"
      say ""
    end
  end
end
