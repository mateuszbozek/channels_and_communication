class ReadingsChannel < ApplicationCable::Channel
  require 'rails_event_store'
  include JsonWebToken
  include ConvertReadingBeforeBroadcastHelper

  def subscribed
    if connection.current_token == params[:token]
      installation_id = jwt_decode(connection.current_token)[:installation_id]
      stream_from "installation_#{installation_id}_readings"
      transmit_last_message(installation_id, connection)
    else
      reject
    end
  rescue StandardError => e
    Rails.logger.error "Error in ReadingsChannel: #{e}"
    reject
  end

  def unsubscribed
    Rails.logger.info '_____________UNSUB__________________'
    super
  end

  def transmit_last_message(installation_id, connection)
    stream_names = Device.where(installation_id: installation_id).ids.map { |id| "\'Readings$#{id}\'" }.join(', ')
    return if stream_names.empty?

    sql = <<~SQL.squish
      SELECT encode(ese.data, 'escape')
      FROM public.event_store_events ese
      JOIN event_store_events_in_streams eseis ON ese.event_id = eseis.event_id
      WHERE eseis.stream IN (#{stream_names})
      ORDER BY ese.created_at DESC
      LIMIT 1
    SQL

    data = ActiveRecord::Base.connection.execute sql
    return unless data.any?

    message = RubyEventStore::Serializers::YAML.load data[0]['encode']
    connection.transmit(identifier: identifier, message: prepare_message(message, all: false))
  end
end
