require 'rails_helper'

RSpec.describe WeatherChannel, type: :channel do
  include JsonWebToken

  describe 'checking basic' do
    let(:user) { create(:user) }
    let(:installation) { create(:installation, name: 'NewInstallation') }
    let(:token) do
      jwt_encode(user_id: user.id, installation_id: installation.id)
    end

    let(:connection) { ActionCable::Channel::ConnectionStub.new(current_token: token) }

    let(:params) do
      {
        token: token
      }
    end

    it 'confirm subscription' do
      stub_connection

      subscribe params
      expect(subscription).to be_confirmed
    end

    context 'when installation not exist' do
      it 'reject connection' do
        stub_connection

        subscribe params: nil
        expect(subscription).not_to be_confirmed
      end
    end
  end
end
