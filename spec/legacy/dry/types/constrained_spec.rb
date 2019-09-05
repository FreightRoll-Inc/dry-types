RSpec.describe Legacy::Dry::Types::Constrained do
  describe 'common definition behavior' do
    subject(:type) { Legacy::Dry::Types['strict.string'].constrained(size: 3..12) }

    it_behaves_like Legacy::Dry::Types::Definition
    it_behaves_like 'Legacy::Dry::Types::Definition#meta'
  end

  describe '#[]' do
    subject(:type) do
      Legacy::Dry::Types['strict.string'].constrained(size: 3..12)
    end

    it 'passes when constraints are not violated' do
      expect(type['hello']).to eql('hello')
    end

    it 'raises when a given constraint is violated' do
      expect { type['he'] }.to raise_error(
        Legacy::Dry::Types::ConstraintError,
        '"he" violates constraints (size?(3..12, "he") failed)'
      )
    end

    it 'is aliased as #call' do
      expect(type.call('hello')).to eql('hello')
    end
  end

  describe '#===' do
    subject(:type) do
      Legacy::Dry::Types['strict.string'].constrained(size: 3..12)
    end

    it 'return boolean' do
      expect(type.===('hello')).to eql(true)
      expect(type.===('no')).to eql(false)
    end

    context 'in case statement' do
      let(:value) do
        case 'awesome'
          when type then 'accepted'
          else 'invalid'
        end
      end

      it 'returns correct value' do
        expect(value).to eql('accepted')
      end
    end
  end

  context 'with a constructor type' do
    subject(:type) do
      Legacy::Dry::Types['coercible.hash'].constrained(size: 1)
    end

    it_behaves_like Legacy::Dry::Types::Definition

    it 'passes when constraints are not violated by the coerced value' do
      expect(type[a: 1]).to eql(a: 1)
    end

    it 'fails when constraints are violated by coerced value' do
      expect { type[{}] }.to raise_error(
        Legacy::Dry::Types::ConstraintError,
        '{} violates constraints (size?(1, {}) failed)'
      )
    end

    it 'fails when coercion fails' do
      expect { type['foo'] }.to raise_error(Legacy::Dry::Types::ConstraintError, /foo/)
    end

    context 'constructor fn changes validity' do
      context 'from invalid to valid' do
        subject(:type) do
          Legacy::Dry::Types['strict.integer'].constrained(gt: 1).constructor { |x| x + 1 }
        end

        it 'passes' do
          expect(type.valid?(1)).to eql(true)
        end
      end

      context 'from valid to invalid' do
        subject(:type) do
          Legacy::Dry::Types['strict.integer'].constrained(gt: 1).constructor { |x| x - 1 }
        end

        it 'fails' do
          expect(type.valid?(2)).to eql(false)
        end
      end
    end
  end

  context 'with an optional sum type' do
    subject(:type) do
      Legacy::Dry::Types['string'].constrained(size: 4).optional
    end

    it_behaves_like 'Legacy::Dry::Types::Definition without primitive'

    it 'passes when constraints are not violated' do
      expect(type[nil]).to be(nil)
      expect(type['hell']).to eql('hell')
    end

    it 'raises when a given constraint is violated' do
      expect { type['hel'] }.to raise_error(Legacy::Dry::Types::ConstraintError, /hel/)
    end
  end

  context 'with another constrained type' do
    subject(:type) do
      Legacy::Dry::Types['strict.string'].constrained(size: 4)
    end

    it_behaves_like Legacy::Dry::Types::Definition

    it 'passes when constraints are not violated' do
      expect(type['hell']).to eql('hell')
    end

    it 'raises when a given constraint is violated' do
      expect { type[nil] }.to raise_error(Legacy::Dry::Types::ConstraintError, /nil/)
      expect { type['hel'] }.to raise_error(Legacy::Dry::Types::ConstraintError, /hel/)
    end
  end

  context 'with another complex and constrained type' do
    subject(:type) do
      Legacy::Dry::Types['strict.array']
        .constrained(size: 3)
        .of(Legacy::Dry::Types['coercible.string'])
    end

    it_behaves_like Legacy::Dry::Types::Definition

    it 'passes when constraints are not violated' do
      expect(type[[:foo, :bar, :baz]]).to eql(%w(foo bar baz))
    end

    it 'raises when a given constraint is violated' do
      expect { type[%w(foo bar)] }.to raise_error(Legacy::Dry::Types::ConstraintError)
    end
  end

  context 'with an array on a constrained type' do
    subject(:type) do
      Legacy::Dry::Types['strict.array']
        .of(Legacy::Dry::Types['coercible.string'].constrained(min_size: 3))
    end

    it_behaves_like Legacy::Dry::Types::Definition

    it 'raises when a given constraint is violated' do
      expect { type[%w(a b)] }.to raise_error(Legacy::Dry::Types::ConstraintError)
    end

    it 'coerces values' do
      expect(type.try(%i(foo aa)).input).to eql(%w(foo aa))
    end
  end

  context 'defined on optional' do
    subject(:type) do
      Legacy::Dry::Types['strict.string'].optional.constrained(min_size: 3)
    end

    it 'gets applied to the underlying type' do
      expect(type['foo']).to eql('foo')
      expect { type['fo'] }.to raise_error(Legacy::Dry::Types::ConstraintError)
      expect(type[nil]).to be_nil
    end
  end
end
