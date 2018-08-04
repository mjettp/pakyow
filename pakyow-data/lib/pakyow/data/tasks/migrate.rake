# frozen_string_literal: true

require "pakyow/data/migrator"
require "pakyow/data/migrators/mysql"
require "pakyow/data/migrators/postgres"
require "pakyow/data/migrators/sqlite"

namespace :db do
  desc "Migrate a database"
  option :adapter, "The adapter to migrate"
  option :connection, "The connection to migrate"
  task :migrate, [:adapter, :connection] do |_, args|
    if Pakyow.config.data.auto_migrate
      # FIXME: make this a nice error
      raise "Can't migrate with auto migrate enabled"
    else
      migrator = Pakyow::Data::Migrator.establish(
        adapter: args[:adapter],
        connection: args[:connection]
      )

      migrator.migrate!
      migrator.disconnect!
    end
  end
end