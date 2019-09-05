if RUBY_ENGINE == 'ruby' && ENV['COVERAGE'] == 'true'
  require 'yaml'
  rubies = YAML.load(File.read(File.join(__dir__, '..', '.travis.yml')))['rvm']
  latest_mri = rubies.select { |v| v =~ /\A\d+\.\d+.\d+\z/ }.max

  if RUBY_VERSION == latest_mri
    require 'simplecov'
    SimpleCov.start do
      add_filter '/spec/'
    end
  end
end

require 'pathname'

SPEC_ROOT = Pathname(__FILE__).dirname

require 'legacy'
require 'dry-types'

begin
  require 'pry-byebug'
  require 'mutant'

  module Mutant
    class Selector
      class Expression < self
        def call(_subject)
          integration.all_tests
        end
      end # Expression
    end # Selector
  end # Mutant
rescue LoadError; end

Dir[Pathname(__dir__).join('shared/*.rb')].each(&method(:require))
require 'legacy/dry/types/spec/types'

Undefined = Dry::Core::Constants::Undefined

require 'dry/core/deprecations'
Dry::Core::Deprecations.set_logger!(SPEC_ROOT.join('../log/deprecations.log'))

RSpec.configure do |config|
  config.before(:example, :maybe) do
    Legacy::Dry::Types.load_extensions(:maybe)
  end

  config.filter_run_when_matching :focus
  config.disable_monkey_patching!

  config.warnings = true

  config.before do
    @types = Legacy::Dry::Types.container._container.keys

    module Test
      def self.remove_constants
        constants.each { |const| remove_const(const) }
        self
      end
    end
  end

  config.after do
    container = Legacy::Dry::Types.container._container
    (container.keys - @types).each { |key| container.delete(key) }
    Legacy::Dry::Types.instance_variable_set('@type_map', Concurrent::Map.new)

    Object.send(:remove_const, Test.remove_constants.name)
  end

  config.order = 'random'
end

srand RSpec.configuration.seed
