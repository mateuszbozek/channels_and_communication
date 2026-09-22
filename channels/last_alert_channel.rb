class LastAlertChannel < ApplicationCable::Channel
  require 'rails_event_store'
  include JsonWebToken
  include ConvertReadingBeforeBroadcastHelper
  include ConvertAlertEventHelper

  def subscribed
    if connection.current_token == params[:token]
      installation_id = jwt_decode(connection.current_token)[:installation_id]
      stream_from "last_alert_#{installation_id}"
      alert = Alert.active&.last
      transmit_last_alert(alert) if alert.present?
    else
      reject
    end
  end

  private

  def transmit_last_alert(alert)
    event = Rails.configuration.event_store.read.stream("Alerts$#{alert.id}").last
    return if event.blank?

    connection.transmit(identifier: identifier,
                        message: translate_event_for_widget(alert, event))
  end
end
