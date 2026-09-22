module ApplicationCable
  class Channel < ActionCable::Channel::Base
    def unsubscribed
      connection.transmit identifier: identifier,
                          type: 'see_you_later_alligator'
      super
    end
  end
end
