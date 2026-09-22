require 'rails_helper'

RSpec.describe DeviceStateChannel, type: :channel do
  include JsonWebToken

  describe 'checking basic' do
    let(:installation) { create(:installation, name: 'NewInstallation') }
    let(:device_state) do
      create(:device_state, device: create(:device, installation: installation), installation: installation)
    end
    let(:token) do
      jwt_encode(user_id: create(:user).id, installation_id: installation.id)
    end
    let(:connection) { ActionCable::Channel::ConnectionStub.new(current_token: token) }

    before do
      ActsAsTenant.current_tenant = installation
    end

    context 'when params are correct' do
      let(:params) { { token: token, device_id: device_state.device_id } }

      it 'confirm subscription' do
        stub_connection

        subscribe params
        expect(subscription).to be_confirmed
      end
    end

    context 'when device not passed' do
      let(:params) { { token: token } }

      it 'reject subscription' do
        stub_connection

        subscribe params
        expect(subscription).not_to be_confirmed
      end
    end
  end

  describe '#receive' do
    let(:control_node) { create(:control_node, installation: create(:installation, name: 'NewInstallation')) }
    let(:device) { create(:device, installation: control_node.installation, control_node: control_node) }
    let(:token) do
      jwt_encode(user_id: create(:user).id, installation_id: device.installation.id)
    end
    let(:connection) { ActionCable::Channel::ConnectionStub.new(current_token: token) }

    context 'when receive message with "refresh" key' do
      let(:params) { { token: token, device_id: device.id } }

      before do
        create(:device_state, device: device, installation: device.installation)
        stub_connection
        subscribe params
        allow(subscription).to receive(:receive).and_call_original
        allow(subscription).to receive(:transmit_current_state)
      end

      it 'invoke #transmit_current_state method' do
        message = { 'refresh' => true }
        subscription.receive(message)

        expect(subscription).to have_received(:transmit_current_state).with(device.device_state)
      end

      it 'return correct message' do
        transmission_keys = %w[is_service_mode current_position execution_pending service_mode_change_canceled
                               service_mode_change_pending service_mode_change_rejected
                               target_position start_position executed waiting_for_response].sort
        subscription.receive({ 'refresh' => true })

        expect(transmissions.first.keys.sort).to eq transmission_keys
      end
    end
  end
end
