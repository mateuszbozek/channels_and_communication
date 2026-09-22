require 'rails_helper'

RSpec.describe ApplicationCable::Connection, type: :channel do
  include JsonWebToken

  describe 'checking basic' do
    before do
      Redis.new.setex('Ticket', 600, 'token')
    end

    let(:params) do
      {
        ticket: 'Ticket'
      }
    end

    it 'successfully connects' do
      expect { connect '/ws', params: params }.not_to raise_error
    end
  end
end
