class AuthenticationController < ApplicationController
  skip_before_action :authenticate_request_with_installation, except: %i[generate_ticket token_active]
  skip_before_action :find_current_tenant
  include JsonWebToken

  def sign_in
    user = User.find_by(email: params[:email])
    if user&.authenticate(params[:password])
      render json: authenticated_response(user), status: :ok
    else
      render json: { error: I18n.t('authorization.wrong_email_or_password') }, status: :unauthorized
    end
  end

  def sign_in_to_installation
    user = User.find_by(email: params[:email])
    if user&.authenticate(params[:password])
      installation = find_installation(params)
      render json: authenticated_response(user, installation: installation), status: :ok
    else
      render json: { error: I18n.t('authorization.wrong_email_or_password') }, status: :unauthorized
    end
  rescue StandardError => e
    render_rescue(e)
  end

  def sign_out
    JwtDenyList.create!(jwt_token: extract_token)

    render json: { meta: { message: I18n.t('authorization.sign_out') } }, status: :ok
  rescue StandardError => e
    render_rescue(e)
  end

  def generate_ticket
    ticket = SecureRandom.hex(50)
    token = clean_auth_header
    redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
                      password: ENV.fetch('REDIS_PASSWORD', nil))
    redis.setex(ticket, 600, token)
    render json: { meta: { ticket: ticket } }, status: :ok
  end

  def token_active
    render json: { data: 'Knock' }, status: :ok
  end

  private

  def find_installation(params)
    raise AuthenticationErrors::InvalidAttributes if params[:installation_id].blank?

    Installation.find(params[:installation_id])
  rescue ActiveRecord::RecordNotFound
    raise AuthenticationErrors::InvalidAttributes
  end

  def authenticated_response(user, installation: nil)
    user_has_installation = user.installation.present?

    if installation.present? # no matter is user assigned to any installation
      return { token: jwt_encode(user_id: user.id, installation_id: installation.id),
               meta: authenticated_meta(user_has_installation, installation) }
    end

    if user_has_installation
      return { token: jwt_encode(user_id: user.id, installation_id: user.installation.id),
               meta: authenticated_meta(user_has_installation, user.installation) }
    end

    { token: jwt_encode(user_id: user.id),
      meta: authenticated_meta(user_has_installation) }
  end

  def authenticated_meta(user_has_installation, installation = nil)
    { message: I18n.t("authorization.#{installation.present? ? 'sign_in_to_installation' : 'sign_in'}"),
      has_installation: user_has_installation,
      installation_name: installation&.name }
  end
end
