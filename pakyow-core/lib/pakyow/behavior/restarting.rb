# frozen_string_literal: true

require "pakyow/support/cli/runner"
require "pakyow/support/deprecatable"
require "pakyow/support/extension"

module Pakyow
  module Behavior
    module Restarting
      extend Support::Extension

      apply_extension do
        on "run" do
          # Automatically bundle.
          #
          watch File.join(config.root, "Gemfile") do
            if CLI.system("bundle install", logger_key: "bndl").success?
              restart
            end
          end

          # Watch all files for changes.
          #
          watch File.join(config.root, "**", "*")

          # Ignore the bootsnap cache.
          #
          ignore File.join(config.root, "tmp/cache/**/*")

          # Restart when any file changes.
          #
          changed snapshot: true do |diff|
            unless diff.include?(File.join(config.root, "Gemfile")) || diff.include?(File.join(config.root, "Gemfile.lock"))
              restart
            end
          end
        end
      end

      class_methods do
        def respawn(env: Pakyow.env)
          restart(env: env)
        end

        extend Support::Deprecatable
        deprecate :respawn, solution: "prefer `Pakyow.restart'"
      end
    end
  end
end
