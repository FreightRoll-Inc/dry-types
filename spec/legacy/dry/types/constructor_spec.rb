RSpec.describe Legacy::Dry::Types::Constructor do
  subject(:type) do
    Legacy::Dry::Types::Constructor.new(Legacy::Dry::Types['string'], fn: Kernel.method(:String))
  end

  it_behaves_like Legacy::Dry::Types::Definition

  describe '.new' do
    it 'wraps primitive in a definition' do
      type = Legacy::Dry::Types::Constructor.new(String, fn: Kernel.method(:String))

      expect(type.primitive).to be(String)
    end

    it 'passes builder types as its type' do
      type = Legacy::Dry::Types::Constructor.new(Legacy::Dry::Types['strict.string'], fn: -> v { v.strip })

      expect(type.type).to be(Legacy::Dry::Types['strict.string'])
    end

    it 'allows block as the fn' do
      type = Legacy::Dry::Types::Constructor.new(String, &:strip)

      expect(type[' foo ']).to eql('foo')
    end

    it 'throws an error if no block given' do
      expect {
        Legacy::Dry::Types::Constructor.new(String)
      }.to raise_error(ArgumentError)
    end
  end

  describe '#valid?' do
    it 'returns boolean' do
      expect(type.valid?('hello')).to eql(true)
    end

    context 'fn makes invalid input valid' do
      it 'returns true' do
        expect(type.valid?(nil)).to eql(true)
      end
    end

    it 'returns boolean for invalid integer' do
      type = Legacy::Dry::Types['coercible.integer']

      expect(type.valid?('hello')).to eql(false)
    end

    context 'fn raises NoMethodError' do
      let(:type) { Legacy::Dry::Types::Constructor.new(String, &:strip) }

      it 'returns false' do
        expect(type.valid?(nil)).to eql(false)
      end
    end

    context 'fn raises TypeError' do
      let(:type) do
        array = [1, 2, 3]
        Legacy::Dry::Types::Constructor.new(String) { |x| array[x + 1].to_s }
      end

      it 'returns false' do
        expect(type.valid?('one')).to eql(false)
      end
    end

    context 'fn raises ArgumentError' do
      let(:type) do
        Legacy::Dry::Types::Constructor.new(String) { |x| Integer(x) }
      end

      it 'returns false' do
        expect(type.valid?('one')).to eql(false)
      end
    end

    context 'in case statement' do
      let(:value) do
        case 'world'
        when type then 'accepted'
          else 'invalid'
        end
      end

      it 'returns correct value' do
        expect(value).to eql('accepted')
      end
    end
  end

  describe '#call' do
    it 'uses constructor function to process input' do
      expect(type[:foo]).to eql('foo')
    end
  end

  describe '#primitive' do
    it 'delegates to its definition' do
      expect(type.primitive).to be(String)
    end
  end

  describe '#constructor' do
    it 'returns a new constructor' do
      upcaser = type.constructor(-> s { s.upcase }, id: :upcaser)

      expect(upcaser[:foo]).to eql('FOO')
      expect(upcaser.options[:id]).to be(:upcaser)
    end

    it 'accepts a block' do
      upcaser = type.constructor(id: :upcaser, &:upcase)

      expect(upcaser[:foo]).to eql('FOO')
      expect(upcaser.options[:id]).to be(:upcaser)
    end
  end

  describe '#constrained?' do
    subject(:type) { Legacy::Dry::Types['string'] }

    it 'returns true when its type is constrained' do
      expect(type.constrained(type: String).constructor(&:to_s)).to be_constrained
    end

    it 'returns true when its type is constrained' do
      expect(type.constructor(&:to_s)).to_not be_constrained
    end
  end

  context 'decoration' do
    subject(:type) { Legacy::Dry::Types['coercible.hash'] }

    it 'responds to type methods' do
      expect(type).to respond_to(:schema)
    end

    it 'returns response when it is not a type definition' do
      expect(type.constrained(type: Hash).rule).to be_kind_of(Dry::Logic::Rule)
    end

    it 'raises no-method error when it does not respond to a method' do
      expect { type.oh_noez }.to raise_error(NoMethodError)
    end
  end

  describe 'equality' do
    subject(:type) { Legacy::Dry::Types['string'] }

    it 'counts .fn' do
      to_i = :to_i.to_proc
      to_s = :to_s.to_proc

      expect(type.constructor(to_i)).to eq(type.constructor(to_i))
      expect(type.constructor(to_i)).not_to eq(type.constructor(to_s))

      expect(type.constructor(to_i)).to eql(type.constructor(to_i))
      expect(type.constructor(to_i)).not_to eql(type.constructor(to_s))
    end

    it 'counts meta' do
      to_i = :to_i.to_proc

      expect(type.constructor(to_i).meta(pos: :left)).to eql(type.constructor(to_i).meta(pos: :left))
      expect(type.constructor(to_i).meta(pos: :left)).not_to eql(type.constructor(to_i).meta(pos: :right))
    end
  end

  describe '#name' do
    subject(:type) { Legacy::Dry::Types['string'].optional.constructor(-> v { v.nil? ? nil : v.to_s }) }

    it 'works with sum types' do
      expect(type.name).to eql('NilClass | String')
    end
  end

  describe '#try' do
    subject(:type) { Legacy::Dry::Types['coercible.integer'] }

    it 'rescues ArgumentError' do
      expect(type.try('foo')).to be_failure
    end
  end
end
