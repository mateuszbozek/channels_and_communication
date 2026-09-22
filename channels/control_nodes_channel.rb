class ControlNodesChannel < ApplicationCable::Channel
  def subscribed
    if connection.current_token != params[:token] || params[:control_node_id].blank?
      reject
      return
    end

    control_node = ControlNode.find params[:control_node_id]

    stream_from "control_node_#{control_node.id}"
    transmit_current_state(control_node)
  rescue ActiveRecord::RecordNotFound
    reject
  end

  def receive(data)
    return unless data.is_a?(Hash) && data.key?('refresh')

    control_node = ControlNode.find_by id: params[:control_node_id]
    return if control_node.blank?

    transmit_current_state(control_node)
  end

  private

  def transmit_current_state(control_node)
    last_event = event_store.read.forward.stream("ControlNodes$#{control_node.id}").last

    message = {
      waiting_for_response: false,
      target_value: nil,
      current_interval: control_node.communication_interval,
      accepted: nil,
      canceled: nil
    }

    if last_event&.event_type == 'DeviceCommands::Events::IntervalChangeRequested'
      message[:waiting_for_response] = true
      message[:target_value] = last_event.data[:target_value]
    end
    connection.transmit identifier: identifier,
                        message: message
  end

  def event_store
    Rails.configuration.event_store
  end
end
