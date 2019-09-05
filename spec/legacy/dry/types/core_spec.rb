RSpec.describe Legacy::Dry::Types::Definition do
  let(:string) { Legacy::Dry::Types["coercible.string"] }
  let(:hash) { Legacy::Dry::Types["coercible.hash"] }

  describe '#[]' do
    it 'returns input when type matches' do
      input = 'foo'
      expect(string[input]).to be(input)
    end

    it 'coerces input when type does not match' do
      input = :foo
      expect(string[input]).to eql('foo')
    end

    it 'raises type-error when coercion fails' do
      expect { hash['foo'] }.to raise_error(TypeError)
    end

    it 'raises type-error when non-coercible type is used and input does not match' do
      expect { Legacy::Dry::Types["strict.date"]['nopenopenope'] }
        .to raise_error(Legacy::Dry::Types::ConstraintError, /"nopenopenope" violates constraints/)
    end

    it 'is aliased as #call' do
      expect(string.call('hello')).to eql('hello')
    end
  end

  describe 'with Bool' do
    let(:bool) { Legacy::Dry::Types["strict.bool"] }

    it_behaves_like 'Legacy::Dry::Types::Definition without primitive' do
      let(:type) { bool }
    end

    it 'accepts true object' do
      expect(bool[true]).to be(true)
    end

    it 'accepts false object' do
      expect(bool[false]).to be(false)
    end

    it 'raises when input is not true or false' do
      expect { bool['false'] }.to raise_error(Legacy::Dry::Types::ConstraintError, /"false" violates constraints/)
    end
  end

  describe 'with Date' do
    let(:date) { Legacy::Dry::Types["strict.date"] }

    it_behaves_like Legacy::Dry::Types::Definition do
      let(:type) { date }
    end

    it 'accepts a date object' do
      input = Date.new

      expect(date[input]).to be(input)
    end
  end

  describe 'with DateTime' do
    let(:datetime) { Legacy::Dry::Types["strict.date_time"] }

    it_behaves_like Legacy::Dry::Types::Definition do
      let(:type) { datetime }
    end

    it 'accepts a date-time object' do
      input = DateTime.new

      expect(datetime[input]).to be(input)
    end
  end

  describe 'with Time' do
    let(:time) { Legacy::Dry::Types["strict.time"] }

    it_behaves_like Legacy::Dry::Types::Definition do
      let(:type) { time }
    end

    it 'accepts a time object' do
      input = Time.new

      expect(time[input]).to be(input)
    end
  end

  describe 'with Range' do
    let(:range) { Legacy::Dry::Types["strict.range"] }

    it_behaves_like Legacy::Dry::Types::Definition do
      let(:type) { range }
    end

    it 'accepts a range object' do
      input = 1..3

      expect(range[input]).to be(input)
    end
  end

  describe 'with built-in optional types' do
    context 'with strict string' do
      let(:string) { Legacy::Dry::Types["optional.strict.string"] }

      it_behaves_like 'Legacy::Dry::Types::Definition without primitive' do
        let(:type) { string }
      end

      it 'accepts nil' do
        expect(string[nil]).to be(nil)
      end

      it 'accepts a string' do
        expect(string['something']).to eql('something')
      end
    end

    context 'with coercible string' do
      let(:string) { Legacy::Dry::Types["optional.coercible.string"] }

      it_behaves_like 'Legacy::Dry::Types::Definition without primitive' do
        let(:type) { string }
      end

      it 'accepts nil' do
        expect(string[nil]).to be(nil)
      end

      it 'accepts a string' do
        expect(string[:something]).to eql('something')
      end
    end
  end

  describe 'defining coercible Optional String' do
    let(:optional_string) { Legacy::Dry::Types["coercible.string"].optional }

    it_behaves_like 'Legacy::Dry::Types::Definition without primitive' do
      let(:type) { optional_string }
    end

    it 'accepts nil' do
      expect(optional_string[nil]).to be(nil)
    end

    it 'accepts an object coercible to a string' do
      expect(optional_string[123]).to eql('123')
    end
  end

  describe 'defining Optional String' do
    let(:optional_string) { Legacy::Dry::Types["strict.string"].optional }

    it_behaves_like 'Legacy::Dry::Types::Definition without primitive' do
      let(:type) { optional_string }
    end

    it 'accepts nil and returns a nil' do
      value = optional_string[nil]

      expect(value).to be(nil)
    end

    it 'accepts a string and returns the string' do
      value = optional_string['SomeThing']

      expect(value).to eql('SomeThing')
    end
  end

  describe 'with Any' do
    let(:any) { Legacy::Dry::Types['any'] }
    let(:object) { Legacy::Dry::Types['object'] }
    let(:constrained) { Legacy::Dry::Types['any'].constrained(type: TrueClass) }

    it_behaves_like Legacy::Dry::Types::Definition do
      let(:type) { object }
    end

    it 'passes through any object' do
      [Object.new, true, 1, BasicObject.new].each do |o|
        expect(any[o]).to be o
      end
    end

    it 'can be constrained with a specific type' do
      expect(constrained[true]).to be true
      expect { constrained[false] }.to raise_error(Legacy::Dry::Types::ConstraintError)
    end

    context 'with BasicObject' do
      let(:basic) { BasicObject.new }

      it 'populates BasicObject' do
        expect(any[basic]).to be basic
        expect(any.valid?(basic)).to be true
      end
    end

    it 'has Object alias' do
      expect(any).to be(object)
    end

    it 'has a special name' do
      expect(any.name).to eql('Any')
    end

    it 'supports meta' do
      expect(any.meta(name: :age).meta).to eql(name: :age)
    end
  end
end
