RSpec.describe "logging in the data layer" do
  before do
    Pakyow.config.data.connections.sql[:default] = "sqlite::memory"
    Pakyow.config.data.logging = logging_enabled
  end

  include_context "testable app"

  context "logging is enabled" do
    let :logging_enabled do
      true
    end

    it "configures the logger" do
      expect(Pakyow.data_connections[:sql][:default].adapter.connection.loggers[0]).to eq(Pakyow.logger)
    end
  end

  context "logging is disabled" do
    let :logging_enabled do
      false
    end

    it "configures the logger" do
      expect(Pakyow.data_connections[:sql][:default].adapter.connection.loggers[0]).to be(nil)
    end
  end
end
