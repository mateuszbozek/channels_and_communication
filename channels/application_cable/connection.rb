module ApplicationCable
  class Connection < ActionCable::Connection::Base
    include JsonWebToken
    identified_by :current_token

    def connect
      Rails.logger.info 'Trying to connect with server - ActionCable.'
      redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
                        password: ENV.fetch('REDIS_PASSWORD', nil))
      token = redis.get(request.params[:ticket]&.to_s)
      token.blank? ? reject_unauthorized_connection : self.current_token = token
    end

    def disconnect
      Rails.logger.info('Disconnected user')
    end
  end
end
