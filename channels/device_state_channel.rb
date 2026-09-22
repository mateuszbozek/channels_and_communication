class DeviceStateChannel < ApplicationCable::Channel
  include DeviceStateHelper

  def subscribed
    if connection.current_token == params[:token] && params[:device_id].present?
      device_state = DeviceState.find_by(device_id: params[:device_id])
      if device_state.present?
        stream_from "device_state_#{device_state.id}"
        transmit_current_state(device_state)

        return
      end
    end
    reject
  end

  def receive(data)
    return unless data.is_a?(Hash) && data.key?('refresh')

    device_state = DeviceState.find_by(device_id: params[:device_id])
    return if device_state.blank?

    transmit_current_state(device_state)
  end

  private

  def transmit_current_state(device_state)
    connection.transmit identifier: identifier,
                        message: ws_message(device_state)
  end
end
