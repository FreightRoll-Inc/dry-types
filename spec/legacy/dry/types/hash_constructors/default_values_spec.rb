RSpec.describe Legacy::Dry::Types::Hash, 'with default values' do
  subject(:hash) do
    Legacy::Dry::Types['hash'].schema(
      {
        name: 'string',
        email: email,
        password: password,
        created_at: created_at
      },
      :schema
    )
  end

  let(:email) { Legacy::Dry::Types['optional.strict.string'] }
  let(:password) { Legacy::Dry::Types['strict.string'].default('changeme') }
  let(:created_at) { Legacy::Dry::Types['strict.time'].default { Time.now } }

  describe '#[]' do
    it 'fills in default values' do
      result = hash[name: 'Jane', email: 'foo@bar.com']

      expect(result).to include(
        name: 'Jane', email: 'foo@bar.com', password: 'changeme'
      )

      expect(result[:created_at]).to be_instance_of(Time)
    end

    it 'sets nil as a default value for optional types' do
      result = hash[name: 'Jane']

      expect(result[:email]).to be_nil
    end
  end
end
