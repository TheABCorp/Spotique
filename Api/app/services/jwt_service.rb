class JwtService
  ALGORITHM = "HS256"

  def self.encode(user_id)
    payload = {
      sub: user_id,
      iat: Time.current.to_i
    }
    JWT.encode(payload, secret_key, ALGORITHM)
  end

  def self.decode(token)
    decoded = JWT.decode(token, secret_key, true, algorithm: ALGORITHM)
    decoded.first
  rescue JWT::DecodeError
    nil
  end

  def self.secret_key
    Rails.application.credentials.secret_key_base || Rails.application.secret_key_base
  end
end
