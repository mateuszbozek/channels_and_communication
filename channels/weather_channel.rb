class WeatherChannel < ApplicationCable::Channel
  include JsonWebToken

  def subscribed
    if connection.current_token == params[:token]
      installation_id = jwt_decode(connection.current_token)[:installation_id]
      stream_from "installation_#{installation_id}_weather"
      load_last_weather(installation_id)
    else
      reject
    end
  rescue StandardError => e
    Rails.logger.error "Error in WeatherChannel: #{e}"
    reject
  end

  private

  def load_last_weather(installation_id)
    last_weather = Ext::Weather.where(installation_id: installation_id).order(calc_at: :desc).first
    connection.transmit identifier: identifier, message: last_weather.as_message if last_weather.present?
  end
end
