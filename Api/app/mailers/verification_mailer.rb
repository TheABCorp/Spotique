class VerificationMailer < ApplicationMailer
  def verification_code(email, code)
    @code = code
    mail(to: email, subject: "Your Spotique verification code")
  end
end
