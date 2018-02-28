# frozen_string_literal: true

require "pakyow/support/extension"

module Pakyow
  module Assets
    module Behavior
      module Rendering
        extend Support::Extension

        apply_extension do
          before :render do
            next unless head = @presenter.view.object.find_significant_nodes(:head)[0]

            (@connection.app.config.assets.autoloaded_packs + @presenter.view.info(:packs).to_a).uniq.each do |pack_name|
              if pack_with_name = @connection.app.state_for(:pack).find { |pack| pack.name == pack_name.to_sym }
                if pack_with_name.javascripts?
                  head.append("<script src=\"#{pack_with_name.public_path}.js\"></script>\n")
                end

                if pack_with_name.stylesheets?
                  head.append("<link rel=\"stylesheet\" type=\"text/css\" media=\"all\" href=\"#{pack_with_name.public_path}.css\">\n")
                end
              else
                @connection.logger.warn "Could not find pack `#{pack_name}'"
              end
            end
          end
        end
      end
    end
  end
end