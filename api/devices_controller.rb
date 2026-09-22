class Api::V2::DevicesController < ApplicationController
  include DeviceHelper
  include DeviceHistoryHelper
  require 'rails_event_store'

  DEVICE_STATE_EVENT_TYPES = %w[DeviceStates::Events::DeviceActivated
                                DeviceStates::Events::DeviceDeactivated
                                DeviceStates::Events::DeviceServiceModeOn
                                DeviceStates::Events::DeviceServiceModeOff].freeze
  # DeviceStateCreated and DeviceStateUpdated are skipped

  DEVICE_READING_TYPES = %w[DeviceStates::Events::DeviceCreated
                            DeviceStates::Events::DeviceUpdated].freeze

  DEVICE_COMMAND_READING_TYPES = %w[DeviceCommands::Events::DeviceCommandRegistered
                                    DeviceCommands::Events::DeviceCommandSended
                                    DeviceCommands::Events::DeviceCommandAccepted
                                    DeviceCommands::Events::DeviceCommandRejected
                                    DeviceCommands::Events::DeviceCommandExecuted
                                    DeviceCommands::Events::DeviceCommandCanceled].freeze

  ALERT_TYPES = %w[Alerts::Operational::TurnOff
                   Alerts::Operational::RadarProbe
                   Alerts::Operational::OilProbe
                   Alerts::Operational::SludgeProbe
                   Alerts::Operational::WorkingPressureSensor
                   Alerts::Operational::PowerSensor
                   Alerts::Operational::DisposalPressureSensor
                   Alerts::Operational::BatteryLevelSensor
                   Alerts::Operational::PhotovoltaicVoltageGauge
                   Alerts::Operational::HighVoltageExternalPowerLevelSensor
                   Alerts::Operational::LowVoltageExternalPowerLevelSensor
                   Alerts::Operational::BatteryLevelSensor
                   Alerts::Operational::PhotovoltaicIntensityGauge].freeze

  def index
    devices = []

    Device.includes(:installation, :device_kind, :control_node).all.dup.each do |device|
      devices << DeviceSerializer.new(device).prepare_data_for_device_index
    end

    render json: devices
  end

  def device_edit
    device = DeviceSerializer.new(Device.find(params[:id])).prepare_data_for_device_edit
    render json: device
  rescue StandardError => e
    render_rescue(e)
  end

  def update
    valid_params_for_device_edit(params[:device])
    device = Device.find(params[:id])
    if device.update!(device_params)
      meta = { message: "#{I18n.t('activerecord.models.device.one')} #{I18n.t('response.success.edit')}" }
      render json: { id: device.id, meta: meta }
    else
      render json: device
    end
  rescue StandardError => e
    render_rescue(e)
  end

  def activate
    device = Device.find params[:id]

    update_active(device, will_be_active: true) unless device.active

    render json: { id: device.id, active: true }, status: :ok
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid => e
    render_rescue(e)
  end

  def deactivate
    device = Device.find params[:id]

    update_active(device, will_be_active: false) if device.active

    render json: { id: device.id, active: false }, status: :ok
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid => e
    render_rescue(e)
  end

  def read_device_history
    device = Device.find_by(id: params[:id])

    if device.blank?
      render json: { message: I18n.t('response.device.record_not_found') }, status: :not_found
      return
    end
    streams = %w[device_ DeviceStates$ DeviceCommands$ AlertDevice$].map { |prefix| "#{prefix}#{params[:id]}" }
    types = [*DEVICE_STATE_EVENT_TYPES, *DEVICE_READING_TYPES, *DEVICE_COMMAND_READING_TYPES, *ALERT_TYPES]

    all_events = event_store.read.stream(streams).of_type(types).backward.limit(50).to_a

    translated_events = prepare_device_history(all_events)
    render json: translated_events
  end

  private

  def device_params
    params.require(:device).permit(:serial_number, :name, :address, :remarks, :installation_date, :latitude,
                                   :longitude, :control_node_id)
  end

  def update_active(device, will_be_active:)
    attrs = { active: will_be_active }
    event_class = DeviceStates::Events::DeviceDeactivated

    if will_be_active
      attrs.merge! activation_date: Time.now.utc
      event_class = DeviceStates::Events::DeviceActivated
    end

    device.transaction do
      device.update! attrs
      event_store.publish event_class.new(data: { device_id: device.id, attributes: attrs }),
                          stream_name: "DeviceStates$#{device.id}"
    end
  end

  def event_store
    Rails.configuration.event_store
  end
end
