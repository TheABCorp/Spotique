module Api
  module V1
    module Auth
      class SendCodeController < ApplicationController
        def create
          medium, value = extract_medium
          return render_error("Provide exactly one of phone or email", :bad_request) unless medium

          if medium == "phone"
            return render_error("Must be a valid US phone number (+1 followed by 10 digits)", :unprocessable_entity) unless valid_us_phone?(value)
          else
            return render_error("Must be a valid email address", :unprocessable_entity) unless valid_email?(value)
          end

          if VerificationCode.hourly_count(medium, value) >= VerificationCode::HOURLY_LIMIT
            return render_error("Too many requests. Please try again later.", :too_many_requests)
          end

          code = VerificationCode.generate_code
          VerificationCode.for_medium(medium, value).unexpired.unverified.update_all(expires_at: Time.current)

          VerificationCode.create!(
            medium.to_sym => value,
            code_digest: VerificationCode.digest_code(code),
            expires_at: VerificationCode::EXPIRY_DURATION.from_now
          )

          deliver_code(medium, value, code)

          render json: {
            data: {
              medium: medium,
              masked: mask_destination(medium, value),
              expires_in: VerificationCode::EXPIRY_DURATION.to_i
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

        def valid_us_phone?(phone)
          phone.match?(/\A\+1\d{10}\z/)
        end

        def valid_email?(email)
          email.match?(URI::MailTo::EMAIL_REGEXP)
        end

        def mask_destination(medium, value)
          if medium == "phone"
            "+1#{value[2..4]}***#{value[-4..]}"
          else
            local, domain = value.split("@")
            "#{local[0..1]}***@#{domain}"
          end
        end

        def deliver_code(medium, value, code)
          if medium == "phone"
            SmsService.send_verification_code(value, code)
          else
            VerificationMailer.verification_code(value, code).deliver_later
          end
        end

        def render_error(message, status)
          render json: { error: { message: message } }, status: status
        end
      end
    end
  end
end
