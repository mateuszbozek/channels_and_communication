class MainDeviceChannel < ApplicationCable::Channel
  require 'rails_event_store'
  include JsonWebToken
  include ConvertReadingBeforeBroadcastHelper

  def subscribed
    if connection.current_token == params[:token]
      installation_id = jwt_decode(connection.current_token)[:installation_id]
      device_id = Device.find_by(installation_id: installation_id, is_main_device: true)&.id
      reject if device_id.blank?
      stream_from "installation_#{installation_id}_device_#{device_id}"
      transmit_device_details(device_id)
    else
      reject
    end
  end

  private

  def transmit_device_details(device_id)
    event = Rails.configuration.event_store.read.stream("Readings$#{device_id}").last
    return if event.blank?

    connection.transmit(identifier: identifier,
                        message: prepare_message_for_device(event.data))
  end
end
