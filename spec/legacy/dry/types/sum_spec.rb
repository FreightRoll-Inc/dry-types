RSpec.describe Legacy::Dry::Types::Sum do
  describe 'common definition behavior' do
    subject(:type) { Legacy::Dry::Types['bool'] }

    it_behaves_like 'Legacy::Dry::Types::Definition#meta'

    it_behaves_like 'Legacy::Dry::Types::Definition without primitive'

    it 'is frozen' do
      expect(type).to be_frozen
    end
  end

  describe '#optional?' do
    it 'return true if left side is nil' do
      type = Legacy::Dry::Types['strict.nil'] | Legacy::Dry::Types['string']

      expect(type).to be_optional
    end

    it 'return false if left is not nil' do
      type = Legacy::Dry::Types['string'] | Legacy::Dry::Types['nil']

      expect(type).to_not be_optional
    end

    it 'works when left is a Sum type' do
      type = Legacy::Dry::Types['strict.integer'] | Legacy::Dry::Types['strict.date'] | Legacy::Dry::Types['strict.string']

      expect(type).to_not be_optional
    end
  end

  describe '#[]' do
    it 'works with two pass-through types' do
      type = Legacy::Dry::Types['integer'] | Legacy::Dry::Types['string']

      expect(type[312]).to be(312)
      expect(type['312']).to eql('312')
      expect(type[nil]).to be(nil)
    end

    it 'works with two strict types' do
      type = Legacy::Dry::Types['strict.integer'] | Legacy::Dry::Types['strict.string']

      expect(type[312]).to be(312)
      expect(type['312']).to eql('312')

      expect { type[{}] }.to raise_error(TypeError)
    end

    it 'works with nil and strict types' do
      type = Legacy::Dry::Types['strict.nil'] | Legacy::Dry::Types['strict.string']

      expect(type[nil]).to be(nil)
      expect(type['312']).to eql('312')

      expect { type[{}] }.to raise_error(TypeError)
    end

    it 'is aliased as #call' do
      type = Legacy::Dry::Types['integer'] | Legacy::Dry::Types['string']
      expect(type.call(312)).to be(312)
      expect(type.call('312')).to eql('312')
    end

    it 'works with two constructor & constrained types' do
      left = Legacy::Dry::Types['strict.array<strict.string>']
      right = Legacy::Dry::Types['strict.array<strict.hash>']

      type = left | right

      expect(type[%w(foo bar)]).to eql(%w(foo bar))

      expect(type[[{ name: 'foo' }, { name: 'bar' }]]).to eql([
        { name: 'foo' }, { name: 'bar' }
      ])
    end

    it 'works with two complex types with constraints' do
      pair = Legacy::Dry::Types['strict.array']
        .of(Legacy::Dry::Types['coercible.string'])
        .constrained(size: 2)

      string_list = Legacy::Dry::Types['strict.array']
        .of(Legacy::Dry::Types['strict.string'])
        .constrained(min_size: 1)

      string_pairs = Legacy::Dry::Types['strict.array']
        .of(pair)
        .constrained(min_size: 1)

      type = string_list | string_pairs

      expect(type.(%w(foo))).to eql(%w(foo))
      expect(type.(%w(foo bar))).to eql(%w(foo bar))

      expect(type.([[1, 'foo'], [2, 'bar']])).to eql([['1', 'foo'], ['2', 'bar']])

      expect { type[:oops] }.to raise_error(Legacy::Dry::Types::ConstraintError, /:oops/)

      expect { type[[]] }.to raise_error(Legacy::Dry::Types::ConstraintError, /\[\]/)

      expect { type.([%i[foo]]) }.to raise_error(Legacy::Dry::Types::ConstraintError, /\[:foo\]/)

      expect { type.([[1], [2]]) }.to raise_error(Legacy::Dry::Types::ConstraintError, %r[[1]])
      expect { type.([[1], [2]]) }.to raise_error(Legacy::Dry::Types::ConstraintError, %r[[2]])
    end
  end

  describe '#try' do
    subject(:type) { Legacy::Dry::Types['strict.bool'] }

    it 'returns success when value passed' do
      expect(type.try(true)).to be_success
    end

    it 'returns failure when value did not pass' do
      expect(type.try('true')).to be_failure
    end
  end

  describe '#success' do
    subject(:type) { Legacy::Dry::Types['strict.bool'] }

    it 'returns success when value passed' do
      expect(type.success(true)).to be_success
    end

    it 'raises ArgumentError when non of the types have a valid input' do
      expect{
        type.success('true')
      }.to raise_error(ArgumentError, /Invalid success value 'true'/)
    end
  end

  describe '#failure' do
    subject(:type) { Legacy::Dry::Types['integer'] | Legacy::Dry::Types['string'] }

    it 'returns failure when invalid value is passed' do
      expect(type.failure(true)).to be_failure
    end
  end

  describe '#===' do
    subject(:type) { Legacy::Dry::Types['integer'] | Legacy::Dry::Types['string']  }

    it 'returns boolean' do
      expect(type.===('hello')).to eql(true)
      expect(type.===(nil)).to eql(false)
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

  describe '#default' do
    it 'returns a default value sum type' do
      type = (Legacy::Dry::Types['nil'] | Legacy::Dry::Types['string']).default('foo')

      expect(type.call).to eql('foo')
    end

    it 'supports a sum type which includes a constructor type' do
      type = (Legacy::Dry::Types['params.nil'] | Legacy::Dry::Types['params.integer']).default(3)

      expect(type['']).to be(3)
    end

    it 'supports a sum type which includes a constrained constructor type' do
      type = (Legacy::Dry::Types['strict.nil'] | Legacy::Dry::Types['coercible.integer']).default(3)

      expect(type[]).to be(3)
      expect(type['3']).to be(3)
      expect(type['7']).to be(7)
    end
  end

  describe '#constructor' do
    let(:type) {  (Legacy::Dry::Types['string'] |  Legacy::Dry::Types['nil']).constructor { |input| input ? input.to_s + ' world' : input } }

    it 'returns the correct value' do
      expect(type.call('hello')).to eql('hello world')
      expect(type.call(nil)).to eql(nil)
      expect(type.call(10)).to eql('10 world')
    end

    it 'returns if value is valid' do
      expect(type.valid?('hello')).to eql(true)
      expect(type.valid?(nil)).to eql(true)
      expect(type.valid?(10)).to eql(true)
    end
  end

  describe '#rule' do
    let(:two_addends) { Legacy::Dry::Types['strict.nil'] | Legacy::Dry::Types['strict.string'] }

    shared_examples_for 'a disjunction of constraints' do
      it 'returns a rule' do
        rule = type.rule

        expect(rule.(nil)).to be_success
        expect(rule.('1')).to be_success
        expect(rule.(1)).to be_failure
      end
    end

    it_behaves_like 'a disjunction of constraints' do
      subject(:type) { two_addends }
    end

    it_behaves_like 'a disjunction of constraints' do
      subject(:type) { Legacy::Dry::Types['strict.true'] | two_addends  }

      it 'accepts true' do
        rule = type.rule

        expect(rule.(true)).to be_success
        expect(rule.(false)).to be_failure
      end
    end

    it_behaves_like 'a disjunction of constraints' do
      subject(:type) { two_addends | Legacy::Dry::Types['strict.true'] }

      it 'accepts true' do
        rule = type.rule

        expect(rule.(true)).to be_success
        expect(rule.(false)).to be_failure
      end
    end
  end
end