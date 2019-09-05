require 'legacy/dry/types/compiler'

RSpec.describe Legacy::Dry::Types::Compiler, '#call' do
  subject(:compiler) { Legacy::Dry::Types::Compiler.new(Legacy::Dry::Types) }

  it 'returns existing definition' do
    ast = [:definition, [Hash, {}]]
    type = compiler.(ast)

    expect(type).to be(Legacy::Dry::Types['hash'])
  end

  it 'builds a plain definition' do
    ast = [:definition, [Set, {}]]
    type = compiler.(ast)
    expected = Legacy::Dry::Types::Definition.new(Set)

    expect(type).to eql(expected)
  end

  it 'builds a definition with meta' do
    ast = [:definition, [Set, key: :value]]
    type = compiler.(ast)
    expected = Legacy::Dry::Types::Definition.new(Set, meta: { key: :value })

    expect(type).to eql(expected)
  end

  it 'builds a safe coercible hash' do
    ast = Legacy::Dry::Types['hash'].permissive(
      email: Legacy::Dry::Types['string'],
      age: Legacy::Dry::Types['params.integer'],
      admin: Legacy::Dry::Types['params.bool'],
      address: Legacy::Dry::Types['hash'].permissive(
        city: Legacy::Dry::Types['string'],
        street: Legacy::Dry::Types['string']
      )
    ).to_ast

    hash = compiler.(ast)

    expect(hash).to be_a(Legacy::Dry::Types::Hash)

    result = hash[
      email: 'jane@doe.org',
      age: '20',
      admin: '1',
      address: { city: 'NYC', street: 'Street 1/2' }
    ]

    expect(result).to eql(
      email: 'jane@doe.org', age: 20, admin: true,
      address: { city: 'NYC', street: 'Street 1/2' }
    )

    expect { hash[foo: 'jane@doe.org', age: '20', admin: '1'] }.to raise_error(
      Legacy::Dry::Types::MissingKeyError, /email/
    )
  end

  it 'builds a strict hash' do
    ast = Legacy::Dry::Types['hash'].strict(
      email: Legacy::Dry::Types['string']
    ).to_ast

    hash = compiler.(ast)

    expect(hash).to be_a(Legacy::Dry::Types::Hash)

    params = { email: 'jane@doe.org', unexpected1: 'wow', unexpected2: 'wow' }
    expect { hash[params] }
      .to raise_error(Legacy::Dry::Types::UnknownKeysError, /unexpected1, :unexpected2/)

    expect(hash[email: 'jane@doe.org']).to eql(email: 'jane@doe.org')
  end

  it 'builds a coercible hash' do
    ast = Legacy::Dry::Types['hash'].weak(
      email: Legacy::Dry::Types['string'],
      age: Legacy::Dry::Types['params.nil'] | Legacy::Dry::Types['params.integer'],
      admin: Legacy::Dry::Types['params.bool']
    ).to_ast

    hash = compiler.(ast)

    expect(hash).to be_a(Legacy::Dry::Types::Hash)

    result = hash[foo: 'bar', email: 'jane@doe.org', age: '20', admin: '1']

    expect(result).to eql(email: 'jane@doe.org', age: 20, admin: true)

    result = hash[foo: 'bar', email: 'jane@doe.org', age: '', admin: '1']

    expect(result).to eql(email: 'jane@doe.org', age: nil, admin: true)

    result = hash[foo: 'bar', email: 'jane@doe.org', admin: '1']

    expect(result).to eql(email: 'jane@doe.org', admin: true)
  end

  it 'builds a coercible hash with symbolized keys' do
    ast = Legacy::Dry::Types['hash'].symbolized(
      email: Legacy::Dry::Types['string'],
      age: Legacy::Dry::Types['params.integer'],
      admin: Legacy::Dry::Types['params.bool']
    ).to_ast

    hash = compiler.(ast)

    expect(hash).to be_a(Legacy::Dry::Types::Hash)

    expect(hash['foo' => 'bar', 'email' => 'jane@doe.org', 'age' => '20', 'admin' => '1']).to eql(
      email: 'jane@doe.org', age: 20, admin: true
    )

    expect(hash['foo' => 'bar', 'age' => '20', 'admin' => '1']).to eql(
      age: 20, admin: true
    )
  end

  it 'builds a hash with empty schema' do
    ast = Legacy::Dry::Types['hash'].schema([]).to_ast

    hash = compiler.(ast)

    expect(hash[{}]).to eql({})
  end

  it 'builds an array' do
    ast = Legacy::Dry::Types['array'].of(
      Legacy::Dry::Types['hash'].symbolized(
        email: Legacy::Dry::Types['string'],
        age: Legacy::Dry::Types['params.integer'],
        admin: Legacy::Dry::Types['params.bool']
      )
    ).to_ast

    arr = compiler.(ast)

    expect(arr).to be_a(Legacy::Dry::Types::Array)

    input = [
      'foo' => 'bar', 'email' => 'jane@doe.org', 'age' => '20', 'admin' => '1'
    ]

    expect(arr[input]).to eql([
      email: 'jane@doe.org', age: 20, admin: true
    ])

    expect(arr[['foo' => 'bar', 'age' => '20', 'admin' => '1']]).to eql([
      age: 20, admin: true
    ])
  end

  it 'builds a safe params array' do
    ast = Legacy::Dry::Types['params.array'].to_ast

    arr = compiler.(ast)

    expect(arr['oops']).to eql('oops')
    expect(arr['']).to eql([])
    expect(arr[%w(a b c)]).to eql(%w(a b c))
  end

  it 'builds a safe params array with member' do
    ast = Legacy::Dry::Types['params.array'].of(Legacy::Dry::Types['coercible.integer']).to_ast

    arr = compiler.(ast)

    expect(arr['oops']).to eql('oops')
    expect(arr[%w(1 2 3)]).to eql([1, 2, 3])
  end

  it 'builds a safe params hash' do
    ast = Legacy::Dry::Types['params.hash'].symbolized(
        email: Legacy::Dry::Types['string'],
        age: Legacy::Dry::Types['params.integer'],
        admin: Legacy::Dry::Types['params.bool'],
    ).to_ast

    hash = compiler.(ast)

    expect(hash['oops']).to eql('oops')

    expect(hash['foo' => 'bar', 'email' => 'jane@doe.org', 'age' => '20', 'admin' => '1']).to eql(
      email: 'jane@doe.org', age: 20, admin: true
    )

    expect(hash['foo' => 'bar', 'age' => '20', 'admin' => '1']).to eql(
      age: 20, admin: true
    )
  end

  it 'builds a schema-less form.hash' do
    ast = Legacy::Dry::Types['params.hash'].schema([]).to_ast

    type = compiler.(ast)

    expect(type[nil]).to eql(nil)
    expect(type[{}]).to eql({})
  end

  it 'builds a params hash from a :params_hash node' do
    ast = [:params_hash, [[], {}]]

    type = compiler.(ast)

    expect(type.fn).to be(Legacy::Dry::Types['params.hash'].fn)
  end

  it 'builds a params array from a :params_array node' do
    ast = [:params_array, [[:definition, [String, {}]], {}]]

    array = compiler.(ast)

    expect(array.type.member.primitive).to be(String)
  end

  it 'builds a json hash from a :json_hash node' do
    ast = [:json_hash, [[], {}]]

    type = compiler.(ast)
    expected_result = Legacy::Dry::Types['hash'].symbolized({}).safe

    expect(type).to eq(expected_result)
  end

  it 'builds a json array from a :json_array node' do
    ast = [:json_array, [[:definition, [String, {}]], {}]]

    array = compiler.(ast)

    expect(array.type.member.primitive).to be(String)
  end

  it 'builds a constructor' do
    fn = -> v { v.to_s }

    ast = Legacy::Dry::Types::Constructor.new(String, &fn).to_ast

    type = compiler.(ast)

    expect(type[:foo]).to eql('foo')

    expect(type.fn).to be(fn)
    expect(type.primitive).to be(String)
  end

  it 'builds a strict type' do
    ast = Legacy::Dry::Types['strict.string'].to_ast

    type = compiler.(ast)

    expect(type['hello']).to eql('hello')
    expect(type.primitive).to be(String)
  end

  it 'builds an and constrained' do
    ast = Legacy::Dry::Types['strict.string'].constrained(size: 3..12).to_ast

    type = compiler.(ast)

    expect(type['hello']).to eql('hello')
    expect(type.primitive).to be(String)
  end

  it 'build or constrained' do
    ast = [
      :constrained, [[:definition, [Integer, {}]],
      [:or,
        [
          [:predicate, [:lt?, [[:num, 5], [:input, Undefined]]]],
          [:predicate, [:gt?, [[:num, 18], [:input, Undefined]]]]
        ]
      ],{}]]

    type = compiler.(ast)

    expect(type[4]).to eql(4)
    expect(type[19]).to eql(19)
    expect(type.primitive).to be(Integer)
  end

  it 'builds a constructor with meta' do
    fn = -> v { v.to_s }

    ast = Legacy::Dry::Types::Constructor.new(String, &fn).meta(foo: :bar).to_ast

    type = compiler.(ast)

    expect(type[:foo]).to eql('foo')

    expect(type.fn).to be(fn)
    expect(type.primitive).to be(String)
    expect(type.meta).to eql(foo: :bar)
  end

  it 'builds a enum' do
    enum = Legacy::Dry::Types['strict.integer'].enum(1, 2, 3).meta(color: :red)

    ast = enum.to_ast

    type = compiler.(ast)

    expect(type).to eql(enum)
    expect(type.valid?(1)).to be(true)
    expect(type.valid?(4)).to be(false)
  end

  let(:any_ast){ [:definition, [Object, {}]] }

  it 'builds the empty map' do
    ast = Legacy::Dry::Types['hash'].map('any', 'any').to_ast
    expect(ast).to eql([:map, [any_ast, any_ast, {}]])
    type = compiler.(ast)
    expect(type).to eql(Legacy::Dry::Types::Map.new(::Hash))
  end

  it 'builds a complex map' do
    map = Legacy::Dry::Types['hash'].
            map('any', 'any').
            meta(abc: 123).
            meta(foo: 'bar').
            with(key_type: Legacy::Dry::Types['string']).
            with(value_type: Legacy::Dry::Types['integer'])

    ast = map.to_ast

    expect(ast).
      to eql([
               :map, [
                 [:definition, [String, {}]],
                 [:definition, [Integer, {}]],
                 abc: 123, foo: 'bar'
               ]
             ])

    type = compiler.(ast)

    expect(type).to eql(map)
    expect(type.meta).to eql(foo: 'bar', abc: 123)
    expect(type.valid?({ 'x' => 5 })).to eql(true)
    expect(type.valid?({ 5 => 'x' })).to eql(false)
  end
end
