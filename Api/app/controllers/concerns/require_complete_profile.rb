module RequireCompleteProfile
  extend ActiveSupport::Concern

  included do
    before_action :require_complete_profile!
  end

  private

  def require_complete_profile!
    return unless current_user
    return if current_user.profile_complete?

    render json: { error: { code: "profile_incomplete", message: "Please complete your profile before accessing this resource." } }, status: :forbidden
  end
end
