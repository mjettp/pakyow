# frozen_string_literal: true

require "pakyow/support/deep_dup"
require "pakyow/support/inflector"

module Pakyow
  module Support
    module Definable
      # Contains defined state. Intended to be used through {Pakyow::Support::Definable}.
      #
      class Registry
        using DeepDup

        # The name of the defined state.
        #
        attr_reader :name

        # The state being defined.
        #
        attr_reader :object

        # @api private
        attr_reader :builder, :parent, :definitions

        # @api private
        PRIORITIES = { default: 0, high: 1, low: -1 }.freeze

        def initialize(name, object, parent:, namespace: [], builder: nil, lookup: nil, abstract: true)
          @name = name
          @object = object
          @parent = parent
          @namespace = namespace
          @builder = builder
          @lookup = lookup
          @abstract = abstract
          @definitions = []
          @priorities ={}
          @state = {}
        end

        def initialize_copy(_)
          super

          @definitions = @definitions.deep_dup
          @priorities = @priorities.deep_dup
        end

        # Define an object.
        #
        def define(name = nil, *args, priority: :default, **opts, &block)
          if @object.name.nil?
            opts[:set_const] = false
          end

          name, *args = build_final_args(name, *args, **opts)

          if found = find(name)
            found.class_eval(&block); found
          else
            defined = @object.make(*object_type_namespace, name, *args, &block)
            register(name, defined, priority: priority)
          end
        end

        # Find a defined object by name.
        #
        def find(*namespace, object_name)
          @definitions.find { |definition|
            definition.object_name && definition.object_name.name == object_name && (definition.object_name.namespace.parts - object_type_namespace) == namespace
          }
        end

        # Iterate over defined objects.
        #
        def each
          return enum_for(:each) unless block_given?

          @definitions.each do |definition|
            yield definition
          end
        end

        # @api private
        def <<(definition)
          @definitions << definition
        end

        # @api private
        def method_missing(name, *args, **kwargs, &block)
          if definition = @state[name]
            if @lookup
              @lookup.call(@parent, definition, *args, **kwargs, &block)
            else
              definition
            end
          else
            super
          end
        end

        # @api private
        def respond_to_missing?(name, *)
          @state.key?(name) || super
        end

        # @api private
        def rebase(object)
          @object = object
          @object_type_namespace = nil
          @object_namespace = nil

          self
        end

        # @api private
        def reparent(parent)
          @parent = parent

          self
        end

        private def register(name, object, priority: :default)
          unless name.nil?
            @state[name.to_sym] = object
          end

          unless priority.is_a?(Integer)
            priority = PRIORITIES.fetch(priority) {
              raise ArgumentError, "unknown priority `#{priority}'"
            }
          end

          unless object.is_a?(Module)
            enforce_registration!(object)
          end

          unless @definitions.include?(object)
            @definitions << object
          end

          @priorities[object] = priority
          reprioritize!
          object
        end

        private def enforce_registration!(object)
          ancestors = if object.respond_to?(:new)
            object.ancestors
          else
            object.class.ancestors
          end

          unless ancestors.include?(@object)
            raise ArgumentError, "expected an ancestor of `#{@object}'"
          end
        end

        private def reprioritize!
          @definitions.sort! { |a, b|
            (@priorities[b] || 0) <=> (@priorities[a] || 0)
          }
        end

        private def build_final_args(object_name, *args, **opts)
          if @builder
            @builder.call(object_name, *args, **opts)
          else
            return object_name, *args, **opts
          end
        end

        private def object_type_namespace
          @object_type_namespace ||= object_namespace.dup.concat(@namespace)
        end

        private def object_namespace
          @object_namespace ||= build_object_namespace
        end

        private def build_object_namespace
          parts = Support.inflector.underscore(@object.name.to_s).split("/")

          if @abstract
            parts[0..-2].map(&:to_sym)
          else
            parts.map(&:to_sym)
          end
        end
      end
    end
  end
end