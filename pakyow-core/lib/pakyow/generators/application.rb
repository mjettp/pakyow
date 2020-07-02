# frozen_string_literal: true

require "pakyow/support/inflector"

generator :application do
  required :name
  optional :path, default: "/"

  source_path File.expand_path("../../generatable/application/default", __FILE__)

  action :update_assets do
    Bundler.with_original_env do
      run "bundle exec pakyow assets:update -a #{name}", message: "Updating external assets", from: Pakyow.config.root
    end
  end

  def human_name
    Support.inflector.humanize(name)
  end
end
