# frozen_string_literal: true

require "pakyow/data/migrator"
require "pakyow/data/migrators/mysql"
require "pakyow/data/migrators/postgres"
require "pakyow/data/migrators/sqlite"

namespace :db do
  desc "Finalize a database"
  option :adapter, "The adapter to migrate"
  option :connection, "The connection to migrate"
  task :finalize, [:adapter, :connection] do |_, args|
    Pakyow.boot

    migrator = Pakyow::Data::Migrator.establish(
      adapter: args[:adapter],
      connection: args[:connection],
      connection_overrides: {
        path: -> (connection_path) {
          "#{connection_path}-migrator"
        }
      }
    )

    # Create the migrator database unless it exists.
    #
    migrator.create!

    # Run the existing migrations on it.
    #
    migrator.migrate!

    # Create migrations for unmigrated schema.
    #
    migrator.finalize!

    # Cleanup.
    #
    migrator.disconnect! do
      migrator.drop!
    end
  end
end
