# frozen_string_literal: true

command :assets, :update do
  describe "Update external assets"
  required :app

  argument :asset, "The asset to update"

  action do
    unless @app.class.includes_framework?(:assets)
      fail "#{@app.class} does not include the assets framework and cannot be updated"
    end
  end

  action do
    require_relative "../../assets/errors"
    require_relative "../../assets/external"

    if @asset
      @asset = @asset.to_sym

      script = @app.config.assets.externals.scripts.find { |script|
        script.name == asset
      } || raise(Pakyow::Assets::UnknownExternalAsset.new_with_message(asset: asset))

      fetch!(script)
    else
      @app.config.assets.externals.scripts.each do |script|
        fetch!(script)
      end

      @app.plugs.each do |plug|
        plug.config.assets.externals.scripts.each do |script|
          fetch!(script)
        end
      end
    end
  end

  private def fetch!(script)
    require "pakyow/support/cli/runner"

    Pakyow::Support::CLI::Runner.new(message: "Fetching #{script.name}").run do |runner|
      script.fetch!

      runner.succeeded
    rescue StandardError => error
      runner.failed(error.message)
    end
  end
end
