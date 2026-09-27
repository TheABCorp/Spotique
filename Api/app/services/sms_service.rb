class SmsService
  def self.send_verification_code(phone, code)
    return Rails.logger.info("[SMS] Code #{code} to #{phone}") unless twilio_configured?

    client = Twilio::REST::Client.new(
      Rails.application.credentials.dig(:twilio, :account_sid),
      Rails.application.credentials.dig(:twilio, :auth_token)
    )

    client.messages.create(
      from: Rails.application.credentials.dig(:twilio, :phone_number),
      to: phone,
      body: "Your Spotique verification code is: #{code}. It expires in 10 minutes."
    )
  end

  def self.twilio_configured?
    Rails.application.credentials.dig(:twilio, :account_sid).present?
  end
end
