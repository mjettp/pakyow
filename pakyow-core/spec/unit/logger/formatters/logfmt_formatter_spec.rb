require 'spec_helper'
require 'unit/logger/formatters/shared'
require 'pakyow/core/logger/formatters/logfmt_formatter'

describe Pakyow::Logger::LogfmtFormatter do
  include_examples :log_formatter

  let :formatter do
    Pakyow::Logger::LogfmtFormatter.new
  end

  it 'formats the prologue' do
    expect(formatter.call(severity, datetime, progname, prologue)).to eq("severity=DEBUG timestamp=\"#{datetime}\" id=123 type=http elapsed=10.00ms message=foo method=GET path=/ ip=0.0.0.0\n")
  end

  it 'formats the epilogue' do
    expect(formatter.call(severity, datetime, progname, epilogue)).to eq("severity=DEBUG timestamp=\"#{datetime}\" id=123 type=http elapsed=10.00ms message=foo status=200\n")
  end

  it 'formats an error' do
    expect(formatter.call(severity, datetime, progname, error)).to eq("severity=DEBUG timestamp=\"#{datetime}\" id=123 type=http elapsed=10.00ms message=foo exception=ArgumentError backtrace=one,two\n")
  end

  it 'formats a message' do
    expect(formatter.call(severity, datetime, progname, message)).to eq("severity=DEBUG timestamp=\"#{datetime}\" id=123 type=http elapsed=10.00ms message=foo\n")
  end
end
