require 'rails_helper'

RSpec.describe LastAlertChannel, type: :channel do
  include JsonWebToken

  describe 'checking basic' do
    let(:installation) { create(:installation, name: 'NewInstallation') }
    let(:token) do
      jwt_encode(user_id: create(:user).id, installation_id: installation.id)
    end
    let(:connection) { ActionCable::Channel::ConnectionStub.new(current_token: token) }

    let(:params) { { token: token } }

    before do
      ActsAsTenant.current_tenant = installation
    end

    it 'confirm subscription' do
      stub_connection

      subscribe params
      expect(subscription).to be_confirmed
    end
  end
end
