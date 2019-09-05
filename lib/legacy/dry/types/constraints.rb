require 'dry/logic/rule_compiler'
require 'dry/logic/predicates'
require 'dry/logic/rule/predicate'

module Legacy::Dry
  module Types
    # @param [Hash] options
    # @return [Dry::Logic::Rule]
    def self.Rule(options)
      rule_compiler.(
        options.map { |key, val| ::Dry::Logic::Rule::Predicate.new(::Dry::Logic::Predicates[:"#{key}?"]).curry(val).to_ast }
      ).reduce(:and)
    end

    # @return [Dry::Logic::RuleCompiler]
    def self.rule_compiler
      @rule_compiler ||= ::Dry::Logic::RuleCompiler.new(::Dry::Logic::Predicates)
    end
  end
end
