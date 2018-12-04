start_simplecov do
  lib_path = File.expand_path("../../lib", __FILE__)

  add_filter do |file|
    !file.filename.start_with?(lib_path)
  end

  track_files File.join(lib_path, "**/*.rb")
end

require "pakyow/data"

require_relative "../../spec/helpers/app_helpers"
require_relative "../../spec/helpers/mock_handler"

RSpec.configure do |config|
  config.include AppHelpers

  config.after do
    Pakyow.data_connections[:sql].to_h.values.reject { |connection|
      connection.adapter.connection.nil?
    }.each do |connection|
      connection.adapter.connection.tables.each do |table|
        case connection.opts[:adapter]
        when "sqlite"
          connection.adapter.connection.run "PRAGMA foreign_keys = off"
          connection.adapter.connection.run "DROP TABLE #{table}"
        when "mysql2"
          connection.adapter.connection.run "SET FOREIGN_KEY_CHECKS = 0"
          connection.adapter.connection.run "DROP TABLE #{table}"
        else
          connection.adapter.connection.run "DROP TABLE #{table} CASCADE"
        end
      end
    end

    Pakyow.data_connections.values.flat_map(&:values).each(&:disconnect)
  end
end

require_relative "../../spec/context/testable_app_context"
require_relative "./context/migration_context"
require_relative "./context/task_context"

$data_app_boilerplate = Proc.new do
end
