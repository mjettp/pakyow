module Pakyow
  module Support
    module DeepFreeze
      def self.extended(subclass)
        subclass.instance_variable_set(:@unfreezable_variables, [])

        super
      end

      def inherited(subclass)
        subclass.instance_variable_set(:@unfreezable_variables, @unfreezable_variables)

        super
      end

      def unfreezable(*ivars)
        @unfreezable_variables.concat(ivars.map { |ivar| :"@#{ivar}" })
        @unfreezable_variables.uniq!
      end

      refine Object do
        def deep_freeze
          return self if frozen? || !respond_to?(:freeze)

          self.freeze

          freezable_variables.each do |name|
            instance_variable_get(name).deep_freeze
          end

          self
        end

        private

        def freezable_variables
          object = self.is_a?(Class) ? self : self.class

          if object.instance_variable_defined?(:@unfreezable_variables)
            instance_variables - object.instance_variable_get(:@unfreezable_variables)
          else
            instance_variables
          end
        end
      end

      refine Array do
        def deep_freeze
          return self if frozen?

          self.freeze

          each(&:deep_freeze)

          self
        end
      end

      refine Hash do
        def deep_freeze
          return self if frozen?

          frozen_hash = {}

          each_pair do |key, value|
            frozen_hash[key.deep_freeze] = value.deep_freeze
          end

          self.replace(frozen_hash)

          self.freeze
        end
      end
    end
  end
end
