# frozen_string_literal: true

require "erb"
require "fileutils"
require "pathname"

require "pakyow/support/cli/runner"
require "pakyow/support/class_state"
require "pakyow/support/extension"
require "pakyow/support/hookable"

require "pakyow/support/pipeline"
require "pakyow/support/pipeline/object"

module Pakyow
  # Base class for generators.
  #
  class Generator
    module Common
      def dot
        "."
      end
    end

    include Common

    include Support::Hookable
    events :generate

    include Support::Pipeline

    attr_reader :files

    def initialize(source_path)
      @files = Dir.glob(::File.join(source_path, "**/*")).reject { |path|
        ::File.directory?(path)
      }.map { |path|
        File.new(path, source_path, context: self)
      }
    end

    def generate(destination_path, **options)
      call(destination_path, **options)
    end

    def run(command, message:)
      Support::CLI::Runner.new(message: message).run(
        "cd #{@destination_path} && #{command}"
      )
    end

    private def call(destination_path, **options)
      @destination_path = Pathname.new(destination_path)

      performing :generate do
        FileUtils.mkdir_p(@destination_path)

        @files.each do |file|
          file.generate(@destination_path, **options)
        end
      end
    end

    def run(command, message:)
      Support::CLI::Runner.new(message: message).run(
        "cd #{@destination_path} && #{command}"
      )
    end

    class File
      include Common

      include Support::Pipeline::Object

      attr_accessor :path, :logical_path, :content, :context

      def initialize(path, source_path, context: self)
        @path, @context = path, context

        @logical_path = Pathname.new(path).relative_path_from(
          Pathname.new(source_path)
        ).to_s

        @content = ::File.read(@path)
      end

      def generate(destination_path, options)
        options.each do |key, value|
          @context.instance_variable_set(:"@#{key}", value)
        end

        # Process the file.
        #
        Processor.new.call(self)

        # Build the generated file path.
        #
        destination_path_for_file = ::File.join(destination_path, @logical_path)

        # Make sure the directory exists.
        #
        FileUtils.mkdir_p(::File.dirname(destination_path_for_file))

        # Skip keep files.
        #
        unless ::File.basename(@logical_path) == "keep"
          # Write the file.
          #
          ::File.open(destination_path_for_file, "w+") do |file|
            file.write(@content)
          end
        end
      end
    end

    class Processor
      include Support::Pipeline

      action :process_erb
      action :populate_path

      def process_erb(file)
        if ::File.extname(file.logical_path) == ".erb"
          file.logical_path = ::File.join(
            ::File.dirname(file.logical_path),
            ::File.basename(file.logical_path, ".erb")
          )

          erb = if RUBY_VERSION.start_with?("2.5")
            ERB.new(file.content, nil, "%<>-")
          else
            ERB.new(file.content, trim_mode: "%-")
          end

          file.content = erb.result(
            file.context.instance_eval { binding }
          )
        end
      end

      PATH_VAR_REGEX = /%([^}]*)%/

      def populate_path(file)
        file.logical_path.scan(PATH_VAR_REGEX).each do |match|
          file.logical_path.gsub!("%#{match[0]}%", file.context.send(match[0].to_sym))
        end
      end
    end
  end
end
