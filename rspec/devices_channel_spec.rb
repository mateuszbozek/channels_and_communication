require 'rails_helper'

RSpec.describe DevicesChannel, type: :channel do
  include JsonWebToken

  describe 'checking basic' do
    let(:installation) { create(:installation, name: 'NewInstallation') }
    let(:device) { create(:device, installation: installation) }
    let(:token) do
      jwt_encode(user_id: create(:user).id, installation_id: installation.id)
    end
    let(:connection) { ActionCable::Channel::ConnectionStub.new(current_token: token) }

    let(:params) do
      {
        token: token,
        device_id: device.id
      }
    end

    it 'confirm subscription' do
      stub_connection

      subscribe params
      expect(subscription).to be_confirmed
    end

    context 'when device not passed' do
      let(:params) do
        {
          token: token
        }
      end

      it 'reject subscription' do
        stub_connection

        subscribe params
        expect(subscription).not_to be_confirmed
      end
    end
  end

  describe '#receive' do
    let(:device) { create(:device, installation: create(:installation, name: 'NewInstallation')) }
    let(:token) do
      jwt_encode(user_id: create(:user).id, installation_id: device.installation.id)
    end
    let(:connection) { ActionCable::Channel::ConnectionStub.new(current_token: token) }

    let(:params) { { token: token, device_id: device.id } }

    context 'when receive message with "refresh" key' do
      let(:message) { { 'refresh' => true } }

      before do
        stub_connection
        subscribe params
      end

      it 'invoke #transmit_device_details method' do
        allow(subscription).to receive(:receive).and_call_original
        allow(subscription).to receive(:transmit_device_details)

        subscription.receive(message)

        expect(subscription).to have_received(:transmit_device_details).with(device.id)
      end
    end
  end
end
