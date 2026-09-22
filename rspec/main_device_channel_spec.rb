require 'rails_helper'

RSpec.describe MainDeviceChannel, type: :channel do
  include JsonWebToken

  describe 'checking basic' do
    let(:installation) { create(:installation, name: 'NewInstallation') }
    let(:device) { create(:device, installation: installation, is_main_device: true) }
    let(:token) do
      jwt_encode(user_id: create(:user).id, installation_id: installation.id)
    end
    let(:connection) { ActionCable::Channel::ConnectionStub.new(current_token: token) }

    let(:params) { { token: token } }

    before do
      ActsAsTenant.current_tenant = installation
      device
    end

    it 'confirm subscription' do
      stub_connection

      subscribe params
      expect(subscription).to be_confirmed
    end

    context 'when installation has not main device' do
      before do
        ActsAsTenant.current_tenant = installation
        device.update(is_main_device: false)
      end

      let(:params) { { token: token } }

      it 'reject subscription' do
        stub_connection

        subscribe params
        expect(subscription).not_to be_confirmed
      end
    end
  end
end
