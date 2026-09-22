class DevicesController < ApplicationController
  require 'rails_event_store'
  include DeviceStateHelper

  def index
    devices = DeviceResource.all(params)
    render jsonapi: devices
  end

  def show
    device = DeviceResource.find(params)
    render jsonapi: device
  end

  def create
    device = DeviceResource.build(params)

    if device.save
      render jsonapi: device, status: :created
    else
      render jsonapi_errors: device
    end
  end

  # update is currently supported by api/v2
  # def update
  #   device = DeviceResource.find(params)

  #   if device.update_attributes
  #     render jsonapi: device
  #   else
  #     render jsonapi_errors: device
  #   end
  # end

  def destroy
    device = DeviceResource.find(params)

    if device.destroy
      render jsonapi: { meta: {} }, status: :ok
    else
      render jsonapi_errors: device
    end
  end

  def register_command
    device = Device.command_responsive.find(params[:id])

    allow_execution? device
    message = manage_command_registration(device, cmd_params[:position])

    render json: { message: message }, status: :ok
  rescue ActiveRecord::RecordNotFound,
         ActionController::ParameterMissing,
         DeviceStateHelper::ActionPendingError,
         DeviceStateHelper::IsServiceModeError,
         DeviceCommands::Commands::ExecuteCommand::InvalidPositionValue => e
    render_rescue(e)
  end

  def switch_service_mode
    device_state = find_device_state(params[:id])
    should_be_a_bool!(params[:is_service_mode])

    current_service_mode = device_state.is_service_mode

    unless current_service_mode == params[:is_service_mode]
      command_class = DeviceStates::Commands::ChangeServiceMode
      bus.call command_class.new(device_state.device, params[:is_service_mode])
    end

    message = I18n.t('device_commands.registered')
    render json: { message: message, is_service_mode: current_service_mode }
  rescue ActiveRecord::RecordNotFound,
         DeviceStates::OnChangeServiceMode::MissingDeviceError => e
    render_rescue(e)
  rescue ArgumentError => e
    render json: { errors: [{ title: 'ArgumentError', detail: e.message }] }, status: :bad_request
  end

  private

  def cmd_params
    params.permit(:position).to_h
  end

  def bus
    Rails.configuration.command_bus
  end

  def event_store
    Rails.configuration.event_store
  end

  def manage_command_registration(device, position)
    if device.device_state.current_position == position
      I18n.t('device_commands.ignored')
    else
      request_command_execution(device, position)
      I18n.t('device_commands.registered')
    end
  end

  def request_command_execution(device, position)
    bus.call DeviceCommands::Commands::ExecuteCommand.new(device, { target_position: position })
  end

  def allow_execution?(device)
    last_event = event_store.read.stream("DeviceCommands$#{device.id}").last

    blocking_types = ['DeviceCommands::Events::DeviceCommandRegistered',
                      'DeviceCommands::Events::DeviceCommandSended',
                      'DeviceCommands::Events::DeviceCommandAccepted']

    raise DeviceStateHelper::ActionPendingError if last_event.present? && blocking_types.include?(last_event.event_type)

    raise DeviceStateHelper::IsServiceModeError if device.device_state.is_service_mode

    true
  end

  def find_device_state(device_id)
    device_state = DeviceState.find_by device_id: device_id
    return device_state if device_state.present?

    raise ActiveRecord::RecordNotFound, I18n.t('response.device.record_not_found')
  end

  def should_be_a_bool!(value)
    raise ArgumentError, I18n.t('activerecord.errors.messages.type_error') unless [true, false].include? value
  end
end
