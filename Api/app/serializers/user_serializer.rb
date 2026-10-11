class UserSerializer
  def self.call(user)
    {
      id: user.id,
      phone: user.phone,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      role: user.role,
      addresses: user.addresses.map { |address| address_json(address) },
      created_at: user.created_at.iso8601,
      updated_at: user.updated_at.iso8601
    }
  end

  def self.address_json(address)
    {
      id: address.id,
      label: address.label,
      street: address.street,
      city: address.city,
      state: address.state,
      zip: address.zip,
      latitude: address.latitude&.to_f,
      longitude: address.longitude&.to_f
    }
  end
  private_class_method :address_json
end
