$LOAD_PATH.unshift('lib')

require 'bundler/setup'
require 'dry-types'

module SchemaBench
  def self.hash_schema(type)
    Legacy::Dry::Types['hash'].public_send(type,
      email:   Legacy::Dry::Types['string'],
      age:     Legacy::Dry::Types['params.integer'],
      admin:   Legacy::Dry::Types['params.bool'],
      address: Legacy::Dry::Types['hash'].public_send(type,
        city: Legacy::Dry::Types['string'],
        street: Legacy::Dry::Types['string']
      )
    )
  end

  private_class_method(:hash_schema)

  SCHEMAS =
    Legacy::Dry::Types::Hash
      .public_instance_methods(false)
      .map { |schema_type| [schema_type, hash_schema(schema_type)] }
      .to_h

  INPUT = {
    email: 'jane@doe.org',
    age: '20',
    admin: '1',
    address: { city: 'NYC', street: 'Street 1/2' }
  }
end

require 'benchmark/ips'

Benchmark.ips do |x|
  SchemaBench::SCHEMAS.each do |schema_type, schema|
    x.report("#{schema_type}#call") do
      schema.call(SchemaBench::INPUT)
    end
  end

  SchemaBench::SCHEMAS.each do |schema_type, schema|
    x.report("#{schema_type}#try") do
      schema.try(SchemaBench::INPUT)
    end
  end

  x.compare!
end
