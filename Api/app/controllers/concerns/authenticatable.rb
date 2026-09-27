module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end

  private

  def authenticate_user!
    token = extract_token
    return render_unauthorized("Missing authorization token") unless token

    payload = JwtService.decode(token)
    return render_unauthorized("Invalid or expired token") unless payload

    @current_user = User.find_by(id: payload["sub"])
    return render_unauthorized("User not found") unless @current_user
  end

  def current_user
    @current_user
  end

  def extract_token
    header = request.headers["Authorization"]
    header&.split(" ")&.last
  end

  def render_unauthorized(message)
    render json: { error: { message: message } }, status: :unauthorized
  end
end
