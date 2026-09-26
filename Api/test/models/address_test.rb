require "test_helper"

class AddressTest < ActiveSupport::TestCase
  test "valid with all required fields" do
    address = Address.new(
      user: users(:incomplete_user),
      street: "34-15 74th Street",
      city: "Jackson Heights",
      state: "NY",
      zip: "11372"
    )
    assert address.valid?
  end

  test "invalid without street" do
    address = Address.new(
      user: users(:incomplete_user),
      city: "Jackson Heights",
      state: "NY",
      zip: "11372"
    )
    assert_not address.valid?
    assert address.errors[:street].any?
  end

  test "invalid without city" do
    address = Address.new(
      user: users(:incomplete_user),
      street: "34-15 74th Street",
      state: "NY",
      zip: "11372"
    )
    assert_not address.valid?
    assert address.errors[:city].any?
  end

  test "invalid without state" do
    address = Address.new(
      user: users(:incomplete_user),
      street: "34-15 74th Street",
      city: "Jackson Heights",
      zip: "11372"
    )
    assert_not address.valid?
    assert address.errors[:state].any?
  end

  test "invalid without zip" do
    address = Address.new(
      user: users(:incomplete_user),
      street: "34-15 74th Street",
      city: "Jackson Heights",
      state: "NY"
    )
    assert_not address.valid?
    assert address.errors[:zip].any?
  end

  test "label must be home, work, or other when present" do
    address = Address.new(
      user: users(:incomplete_user),
      street: "34-15 74th Street",
      city: "Jackson Heights",
      state: "NY",
      zip: "11372",
      label: "invalid"
    )
    assert_not address.valid?
    assert address.errors[:label].any?

    %w[home work other].each do |valid_label|
      address.label = valid_label
      assert address.valid?, "Expected label '#{valid_label}' to be valid"
    end
  end

  test "label is optional" do
    address = Address.new(
      user: users(:incomplete_user),
      street: "34-15 74th Street",
      city: "Jackson Heights",
      state: "NY",
      zip: "11372"
    )
    assert address.valid?
  end

  test "belongs to user" do
    address = addresses(:jane_home)
    assert_equal users(:complete_phone_user), address.user
  end
end
