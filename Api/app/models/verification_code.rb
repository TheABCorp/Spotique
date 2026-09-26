class VerificationCode < ApplicationRecord
  EXPIRY_DURATION = 10.minutes
  MAX_ATTEMPTS = 5
  HOURLY_LIMIT = 3

  validates :code_digest, presence: true
  validates :expires_at, presence: true
  validate :phone_or_email_present

  scope :for_phone, ->(phone) { where(phone: phone) }
  scope :for_email, ->(email) { where(email: email) }
  scope :unexpired, -> { where("expires_at > ?", Time.current) }
  scope :unverified, -> { where(verified_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :created_within_last_hour, -> { where("created_at > ?", 1.hour.ago) }

  def self.for_medium(medium, value)
    medium == "phone" ? for_phone(value) : for_email(value)
  end

  def self.latest_active(medium, value)
    for_medium(medium, value).unexpired.unverified.recent.first
  end

  def self.hourly_count(medium, value)
    for_medium(medium, value).created_within_last_hour.count
  end

  def self.generate_code
    SecureRandom.random_number(10**6).to_s.rjust(6, "0")
  end

  def self.digest_code(code)
    BCrypt::Password.create(code)
  end

  def code_matches?(code)
    BCrypt::Password.new(code_digest).is_password?(code)
  end

  def expired?
    expires_at <= Time.current
  end

  def locked_out?
    attempts >= MAX_ATTEMPTS
  end

  def verified?
    verified_at.present?
  end

  def mark_verified!
    update!(verified_at: Time.current)
  end

  def increment_attempts!
    increment!(:attempts)
  end

  private

  def phone_or_email_present
    errors.add(:base, "Phone or email must be provided") if phone.blank? && email.blank?
  end
end
