require 'dry/types/builder_methods'

module Dry
  module Types
    class Module < ::Module
      def initialize(registry, *args)
        @registry = registry
        check_parameters(*args)
        constants = type_constants(*args)
        define_constants(constants)
        extend(BuilderMethods)
      end

      # @api private
      def type_constants(*namespaces, default: Undefined, **aliases)
        if namespaces.empty? && aliases.empty? && Undefined.equal?(default)
          default_ns = :Nominal
        elsif Undefined.equal?(default)
          default_ns = Undefined
        else
          default_ns = Inflector.camelize(default).to_sym
        end

        tree = registry_tree

        if namespaces.empty? && aliases.empty?
          modules = tree.select { |_, v| v.is_a?(::Hash) }.map(&:first)
        else
          modules = (namespaces + aliases.keys).map { |n| Inflector.camelize(n).to_sym }
        end

        tree.each_with_object({}) do |(key, value), constants|
          if modules.include?(key)
            name = aliases.fetch(Inflector.underscore(key).to_sym, key)
            constants[name] = value
          end

          constants.update(value) if key == default_ns
        end
      end

      # @api private
      def registry_tree
        @registry_tree ||= @registry.keys.each_with_object({}) { |key, tree|
          type = @registry[key]
          *modules, const_name = key.split('.').map { |part|
            Inflector.camelize(part).to_sym
          }
          next if modules.empty?

          modules.reduce(tree) { |br, name| br[name] ||= {} }[const_name] = type
        }.freeze
      end

      private

      # @api private
      def check_parameters(*namespaces, default: Undefined, **aliases)
        referenced = namespaces.dup
        referenced << default unless false.equal?(Undefined.default(default, false))
        referenced.concat(aliases.keys)

        known = @registry.keys.map { |k|
          ns, *path = k.split('.')
          ns.to_sym unless path.empty?
        }.compact.uniq

        (referenced.uniq - known).each do |name|
          raise ArgumentError,
                "#{ name.inspect } is not a known type namespace. "\
                "Supported options are #{ known.map(&:inspect).join(', ') }"
        end
      end

      # @api private
      def define_constants(constants, mod = self)
        constants.each do |name, value|
          case value
          when ::Hash
            if mod.const_defined?(name, false)
              define_constants(value, mod.const_get(name, false))
            else
              m = ::Module.new
              mod.const_set(name, m)
              define_constants(value, m)
            end
          else
            mod.const_set(name, value)
          end
        end
      end
    end
  end
end
