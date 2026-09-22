require 'rails_helper'

RSpec.describe ControlNodesChannel, type: :channel do
  include JsonWebToken

  describe 'checking basic' do
    let(:installation) { create(:installation, name: 'NewInstallation') }
    let(:token) do
      jwt_encode(user_id: create(:user).id, installation_id: installation.id)
    end
    let(:connection) { ActionCable::Channel::ConnectionStub.new(current_token: token) }
    let(:control_node) { create(:control_node, installation: installation) }

    before do
      ActsAsTenant.current_tenant = installation
    end

    context 'when params are correct' do
      let(:params) { { token: token, control_node_id: control_node.id } }

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
    let(:token) do
      jwt_encode(user_id: create(:user).id, installation_id: control_node.installation_id)
    end
    let(:connection) { ActionCable::Channel::ConnectionStub.new(current_token: token) }

    context 'when receive message with "refresh" key' do
      let(:params) { { token: token, control_node_id: control_node.id } }
      let(:transmited_message) do
        {
          waiting_for_response: false,
          target_value: nil,
          current_interval: control_node.communication_interval,
          accepted: nil,
          canceled: nil
        }
      end

      before do
        stub_connection
        subscribe params
        allow(subscription).to receive(:receive).and_call_original
      end

      it 'invoke #transmit_current_state method' do
        allow(subscription).to receive(:transmit_current_state)
        subscription.receive({ 'refresh' => true })

        expect(subscription).to have_received(:transmit_current_state).with(control_node)
      end

      it 'connection transmit message' do
        allow(subscription).to receive(:transmit_current_state).and_call_original

        subscription.receive({ 'refresh' => true })

        expect(transmissions).to include(transmited_message)
      end
    end
  end
end
