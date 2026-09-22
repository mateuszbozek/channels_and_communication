class DevicesChannel < ApplicationCable::Channel
  require 'rails_event_store'
  include JsonWebToken
  include ConvertReadingBeforeBroadcastHelper

  def subscribed
    if connection.current_token == params[:token]
      if params[:device_id].present?
        installation_id = jwt_decode(connection.current_token)[:installation_id]
        stream_from "installation_#{installation_id}_device_#{params[:device_id]}"
        transmit_device_details(params[:device_id])
      else
        reject
      end
    else
      reject
    end
  end

  def receive(data)
    return unless data.is_a?(Hash) && data.key?('refresh')

    transmit_device_details(params['device_id'])
  end

  private

  def transmit_device_details(device_id)
    device = Device.find(device_id)
    event = Rails.configuration.event_store.read.stream("Readings$#{device.id}").last
    return if event.blank?

    connection.transmit(identifier: identifier,
                        message: prepare_message_for_device(event.data))
  rescue ActiveRecord::RecordNotFound
    reject
  end
end
