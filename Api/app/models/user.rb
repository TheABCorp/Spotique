class User < ApplicationRecord
  ROLES = %w[host driver both].freeze

  has_many :addresses, dependent: :destroy, inverse_of: :user

  validates :phone, uniqueness: true, allow_nil: true
  validates :phone, format: { with: /\A\+1\d{10}\z/, message: "must be a valid US phone number" }, allow_nil: true
  validates :email, uniqueness: { case_sensitive: false }, allow_nil: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }, allow_nil: true
  validate :phone_or_email_present

  validates :first_name, length: { in: 1..50 }, allow_nil: true
  validates :last_name, length: { in: 1..50 }, allow_nil: true
  validates :role, inclusion: { in: ROLES }, allow_nil: true

  def profile_complete?
    first_name.present? && last_name.present? && addresses.any? && role.present?
  end

  private

  def phone_or_email_present
    errors.add(:base, "Phone or email must be provided") if phone.blank? && email.blank?
  end
end
