class Address < ApplicationRecord
  LABELS = %w[home work other].freeze

  belongs_to :user, inverse_of: :addresses

  validates :street, presence: true
  validates :city, presence: true
  validates :state, presence: true
  validates :zip, presence: true
  validates :label, inclusion: { in: LABELS }, allow_nil: true
end
