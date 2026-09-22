require 'rails_helper'

class ActionCable::Channel::ConnectionStub
  def close(*)
  end
end

RSpec.describe ReadingsChannel, type: :channel do
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
      let(:params) do
        {
          token: jwt_encode(user_id: user.id, installation_id: nil)
        }
      end

      it 'reject connection' do
        stub_connection params: params

        subscribe
        expect(subscription).not_to be_confirmed
      end
    end
  end

  describe '#transmit_last_message' do
    let!(:active_device) { create(:device, device_kind: create(:device_kind, sender: true)) }
    let(:event_store) { Rails.configuration.event_store }
    let(:message) { { device_id: active_device.id, type: 'temperature', value: rand(0..300) / 10 } }
    let(:channel) do
      connection = stub_connection
      described_class.new(connection, 'identifier')
    end
    let(:event) { Readings::Events::ReadingRegistered.new data: { message: message, device_id: active_device.id } }

    before do
      active_device.update active: true
      allow(channel.connection).to receive(:transmit)
    end

    it 'broadcast messages stored in event_store' do
      event_store.publish event, stream_name: "Readings$#{active_device.id}"

      channel.transmit_last_message(active_device.installation_id, channel.connection)
      expect(channel.connection).to have_received(:transmit)
        .once
        .with({ identifier: 'identifier', message: hash_including(:reading) })
    end
  end
end
