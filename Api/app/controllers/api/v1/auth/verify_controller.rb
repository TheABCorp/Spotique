module Api
  module V1
    module Auth
      class VerifyController < ApplicationController
        def create
          medium, value = extract_medium
          return render_error("Provide exactly one of phone or email", :bad_request) unless medium

          code_record = VerificationCode.latest_active(medium, value)
          return render_error("No active verification code found. Request a new one.", :unauthorized) unless code_record

          if code_record.locked_out?
            return render_error("Too many attempts. Request a new code.", :too_many_requests)
          end

          unless code_record.code_matches?(params[:code].to_s)
            code_record.increment_attempts!

            if code_record.locked_out?
              return render_error("Too many attempts. Request a new code.", :too_many_requests)
            end

            return render_error("Invalid code. Please try again.", :unauthorized)
          end

          code_record.mark_verified!

          user = User.find_by(medium.to_sym => value)
          is_new = user.nil?

          if is_new
            user = User.create!(medium.to_sym => value)
          end

          token = JwtService.encode(user.id)

          render json: {
            data: {
              is_new: is_new,
              token: token,
              user: is_new ? nil : UserSerializer.call(user)
            }
          }
        end

        private

        def extract_medium
          phone = params[:phone]
          email = params[:email]

          if phone.present? && email.blank?
            [ "phone", phone ]
          elsif email.present? && phone.blank?
            [ "email", email ]
          end
        end

        def render_error(message, status)
          render json: { error: { message: message } }, status: status
        end
      end
    end
  end
end
