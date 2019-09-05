RSpec.describe Legacy::Dry::Types::Map do
  context 'shared examples' do
    let(:type) { Legacy::Dry::Types::Map.new(::Hash) }

    it_behaves_like 'Legacy::Dry::Types::Definition#meta'

    it_behaves_like Legacy::Dry::Types::Definition
  end

  context 'options' do
    let(:empty_map) { Legacy::Dry::Types::Map.new(::Hash) }
    let(:keyed_map) { Legacy::Dry::Types::Map.new(::Hash, key_type: Legacy::Dry::Types['strict.integer']) }
    let(:value_map) { Legacy::Dry::Types::Map.new(::Hash, value_type: Legacy::Dry::Types['strict.string']) }

    let(:complex_map) do
      Legacy::Dry::Types::Map.new(
        ::Hash,
        key_type:   Legacy::Dry::Types['strict.integer'],
        value_type: Legacy::Dry::Types['strict.string'],
        meta:   { a: 1, b: 2, c: 3 }
      )
    end

    describe '#key_type' do
      it 'can be read' do
        expect(empty_map.key_type).to eql Legacy::Dry::Types['any']
        expect(value_map.key_type).to eql Legacy::Dry::Types['any']
        expect(keyed_map.key_type).to eql Legacy::Dry::Types['strict.integer']
        expect(complex_map.key_type).to eql Legacy::Dry::Types['strict.integer']
      end

      it 'must be a Type' do
        expect {
          Legacy::Dry::Types::Map.new(::Hash, key_type: "seven")
        }.to raise_error(Legacy::Dry::Types::MapError, /must be a Legacy::Dry::Types::Type/)
      end
    end

    describe '#value_type' do
      it 'can be read' do
        expect(empty_map.value_type).to eql Legacy::Dry::Types['any']
        expect(keyed_map.value_type).to eql Legacy::Dry::Types['any']
        expect(value_map.value_type).to eql Legacy::Dry::Types['strict.string']
        expect(complex_map.value_type).to eql Legacy::Dry::Types['strict.string']
      end

      it 'must be a Type' do
        expect {
          Legacy::Dry::Types::Map.new(::Hash, value_type: "seven")
        }.to raise_error(Legacy::Dry::Types::MapError, /must be a Legacy::Dry::Types::Type/)
      end
    end

    describe '#name' do
      it 'is Map' do
        expect(empty_map.name).to eql 'Map'
        expect(keyed_map.name).to eql 'Map'
        expect(value_map.name).to eql 'Map'
        expect(complex_map.name).to eql 'Map'
      end
    end

    describe '#primitive' do
      it 'is Hash' do
        expect(empty_map.primitive).to eql ::Hash
        expect(keyed_map.primitive).to eql ::Hash
        expect(value_map.primitive).to eql ::Hash
        expect(complex_map.primitive).to eql ::Hash
      end
    end

    describe '#with' do
      it "creates a new Map with different options" do
        expect(empty_map.with(key_type: Legacy::Dry::Types['strict.integer'])).to eql keyed_map
        expect(empty_map.with(value_type: Legacy::Dry::Types['strict.string'])).to eql value_map
        partial = value_map.with(key_type: Legacy::Dry::Types['strict.integer'])
        expect(partial).not_to eql complex_map
        expect(partial.with(meta: {a:1, b:2, c:3})).to eql complex_map
      end
    end

    describe '#to_ast' do
      let(:any_ast) { Legacy::Dry::Types::Any.to_ast }
      it 'decomposes the map into an ast array' do
        expect(empty_map.to_ast).to eql [:map, [any_ast, any_ast, {}]]
        expect(complex_map.to_ast).
          to eql(
               [:map, [
                  [:constrained, [
                     [:definition, [Integer, {}]],
                     [:predicate, [:type?, [[:type, Integer], [:input, Legacy::Dry::Types::Undefined]]]],
                     {}
                   ]],
                  [:constrained, [
                     [:definition, [String, {}]],
                     [:predicate, [:type?, [[:type, String], [:input, Legacy::Dry::Types::Undefined]]]],
                     {}
                   ]],
                  { a:1, b:2, c:3 }
                ]
               ]
             )
      end
    end
  end

  context 'with a sample map' do
    let(:cleaned_string) do
      Legacy::Dry::Types['strict.string'].constructor do |x|
        x.is_a?(String) ? x.gsub(/\s+/, ' ').strip.downcase : x
      end
    end

    let(:map) do
      Legacy::Dry::Types::Map.new(
        ::Hash,
        key_type:   cleaned_string.constrained(format: /\Aopt_/),
        value_type: Legacy::Dry::Types['strict.bool']
      )
    end

    context 'with a valid input' do
      let(:input) do
        { "opt_one" => false, "  opt_two  " => true, "OPT_THrEe" => true }
      end
      let(:output) do
        { "opt_one" => false, "opt_two" => true, "opt_three" => true }
      end

      describe '#valid?' do
        it "is true" do
          expect(map.valid?(input)).to eql true
        end
      end

      describe '#try' do
        it "returns Result::Success" do
          result = map.try(input)
          expect(result).to be_a Legacy::Dry::Types::Result::Success
          expect(result.input).to eql output
        end

        it "does not yield" do
          expect { |b| map.try(input, &b) }.not_to yield_control
        end
      end

      describe '#call' do
        it 'returns the coerced input' do
          expect(map.call(input)).to eql output
        end
      end
    end

    context 'with an invalid input' do
      let(:input) { { opt_sym: false, ' opt_foo ' => 'bar', "other" => true } }

      let(:failures) {[
        "input key :opt_sym is invalid: type?(String, :opt_sym)",
        "input value \"bar\" for key \" opt_foo \" is invalid: type?(FalseClass, \"bar\")",
        "input key \"other\" is invalid: format?(/\\Aopt_/, \"other\")"
      ]}

      describe '#valid?' do
        it "is false" do
          expect(map.valid?(input)).to eql false
        end
      end

      describe '#try' do
        it "returns Result::Failure" do
          result = map.try(input)
          expect(result).to be_a Legacy::Dry::Types::Result::Failure
          expect(result.error).to eql failures
        end

        it "yields Result::Failure" do
          expect do |b|
            map.try(input, &b)
          end.to yield_with_args(Legacy::Dry::Types::Result::Failure)
        end
      end

      describe '#call' do
        it "raises MapError" do
          expect{ map.call(input) }.to raise_error(
            Legacy::Dry::Types::MapError, failures.join("\n"))
        end
      end
    end
  end
end
