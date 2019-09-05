require 'spec_helper'

RSpec.describe Legacy::Dry::Types, '#to_ast' do
  let(:fn) { Kernel.method(:String) }

  let(:type_with_meta) { type.meta(key: :value) }

  context 'with a definition' do
    subject(:type) { Legacy::Dry::Types::Definition.new(String) }

    specify do
      expect(type.to_ast).
        to eql([:definition, [String, {}]])
    end

    specify 'with meta' do
      expect(type_with_meta.to_ast)
        .to eql([:definition, [String, key: :value]])
    end

    specify 'without meta' do
      expect(type_with_meta.to_ast(meta: false))
        .to eql(type.to_ast)
    end
  end

  context 'with a sum' do
    subject(:type) { Legacy::Dry::Types['string'] | Legacy::Dry::Types['integer'] }

    specify do
      expect(type.to_ast).
        to eql([:sum, [[:definition, [String, {}]], [:definition, [Integer, {}]], {}]])
    end

    specify 'with meta' do
      expect(type_with_meta.to_ast).
        to eql([:sum, [
                  [:definition, [String, {}]],
                  [:definition, [Integer, {}]],
                  key: :value
                ]])
    end

    specify 'without meta' do
      type_with_meta = (
        Legacy::Dry::Types['string'].meta(type: :str) | Legacy::Dry::Types['integer'].meta(type: :int)
      ).meta(type: :sum)

      expect(type_with_meta.to_ast(meta: false)).to eql(type.to_ast)
    end
  end

  context 'with a constrained type' do
    subject(:type) { Legacy::Dry::Types['strict.integer'] }

    specify do
      expect(type.to_ast).
        to eql([:constrained, [
                  [:definition, [Integer, {}]],
                  [:predicate, [:type?, [[:type, Integer], [:input, Undefined]]]],
                  {}
               ]])
    end

    specify 'with meta' do
      expect(type_with_meta.to_ast).
        to eql([:constrained, [
                  [:definition, [Integer, {}]],
                  [:predicate, [:type?, [[:type, Integer], [:input, Undefined]]]],
                  key: :value
                ]])
    end
  end

  context 'Hash' do
    subject(:type) { Legacy::Dry::Types['hash'] }

    specify do
      expect(type.to_ast).
        to eql([:definition, [Hash, {}]])
    end

    context 'schema' do
      subject(:type) { Legacy::Dry::Types['hash'].schema(name: Legacy::Dry::Types['string'], age: Legacy::Dry::Types['integer']) }
      let(:member_types_ast)  { type.member_types.map { |name, member| [:member, [name, member.to_ast]] } }

      specify do
        expect(type.to_ast).
          to eql([:hash_schema, [member_types_ast, {}]])
      end

      specify 'with meta' do
        expect(type_with_meta.to_ast).
          to eql([:hash_schema, [member_types_ast, key: :value]])
      end
    end
  end

  context 'lagacy Hash schemas' do
    subject(:type) { Legacy::Dry::Types['hash'] }
    let(:members) { { name: Legacy::Dry::Types['string'], age: Legacy::Dry::Types['integer'] } }

    specify do
      expect(type.to_ast).
        to eql([:definition, [Hash, {}]])
    end

    %i(schema weak permissive strict strict_with_defaults symbolized).each do |schema|
      meta = {}
      meta[:strict] = true if %i(strict strict_with_defaults).include?(schema)
      meta[:key_transform_fn] = Legacy::Dry::Types::Hash::Schema::SYMBOLIZE_KEY if schema == :symbolized

      context "#{schema.capitalize}" do
        subject(:type) do
          if schema == :schema
            Legacy::Dry::Types['hash'].schema(members, :schema )
          else
            Legacy::Dry::Types['hash'].send(schema, members)
          end
        end
        let(:member_types_ast)  { type.member_types.map { |name, member| [:member, [name, member.to_ast]] } }

        specify do
          expect(type.to_ast).
            to eql([:hash_schema, [member_types_ast, meta]])
        end

        specify 'with meta' do
          expect(type_with_meta.to_ast).
            to eql([:hash_schema, [member_types_ast, key: :value, **meta]])
        end
      end
    end
  end

  context 'Enum' do
    subject(:type) { Legacy::Dry::Types['strict.string'].enum('draft', 'published', 'archived').meta(key: :value) }

    specify do
      expect(type.to_ast).
        to eql([
                 :enum,
                 [
                   [
                     :constrained,
                     [
                       [:definition, [String, {}]],
                       [
                         :and,
                         [
                           [
                             :predicate,
                             [:type?, [[:type, String], [:input, Undefined]]]
                           ],
                           [
                             :predicate,
                             [:included_in?,
                              [[:list, ["draft", "published", "archived"]], [:input, Undefined]]]
                           ]
                         ]
                       ],
                       {}
                     ]
                   ],
                   {"draft" => "draft", "published" => "published", "archived" => "archived"},
                   key: :value
                 ]
               ])
    end
  end

  context 'Safe' do
    subject(:type) { Legacy::Dry::Types['string'].constrained(min_size: 5).safe.meta(key: :value) }

    specify do
      expect(type.to_ast).
        to eql([
                 :safe,
                 [
                   [
                     :constrained,
                     [
                       [:definition, [String, {}]],
                       [:predicate, [:min_size?, [[:num, 5], [:input, Undefined]]]],
                       key: :value
                     ]
                   ],
                   {}
                 ]
               ])
    end
  end

  context 'Constructor' do
    subject(:type) do
      Legacy::Dry::Types::Constructor.new(Legacy::Dry::Types['string'], fn: fn).meta(key: :value)
    end

    specify do
      expect(type.to_ast).
        to eql([:constructor, [[:definition, [String, {}]], "fn_#{fn.object_id}", key: :value]])
    end
  end

  context 'Array' do
    subject(:type) { Legacy::Dry::Types['array'] }

    specify do
      expect(type.to_ast).
        to eql([:definition, [Array, {}]])
    end

    specify 'with meta' do
      expect(type_with_meta.to_ast).
        to eql([:definition, [Array, key: :value]])
    end

    context 'Member' do
      subject(:type) do
        Legacy::Dry::Types['array'].of(Legacy::Dry::Types['string'])
      end

      specify do
        expect(type.to_ast).
          to eql([:array, [[:definition, [String, {}]], {}]])
      end

      specify 'with meta' do
        expect(type_with_meta.to_ast).
          to eql([:array, [[:definition, [String, {}]], key: :value]])
      end
    end

    context 'Member of structs' do
      let(:struct) do
        Test::Struct = Class.new { extend Legacy::Dry::Types::Type }
      end

      subject(:type) do
        Legacy::Dry::Types['array'].of(struct)
      end

      specify do
        expect(type.to_ast).to eql([:array, [struct, {}]])
      end
    end
  end
end
