require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "valid with phone only" do
    user = User.new(phone: "+13475551111")
    assert user.valid?
  end

  test "valid with email only" do
    user = User.new(email: "test@example.com")
    assert user.valid?
  end

  test "invalid without phone or email" do
    user = User.new
    assert_not user.valid?
    assert_includes user.errors[:base], "Phone or email must be provided"
  end

  test "invalid with bad phone format" do
    user = User.new(phone: "555-1234")
    assert_not user.valid?
    assert user.errors[:phone].any?
  end

  test "invalid with non-US phone" do
    user = User.new(phone: "+4420712345678")
    assert_not user.valid?
  end

  test "valid US phone format" do
    user = User.new(phone: "+13475558888")
    assert user.valid?
  end

  test "invalid with bad email format" do
    user = User.new(email: "not-an-email")
    assert_not user.valid?
    assert user.errors[:email].any?
  end

  test "first_name must be 1-50 characters when present" do
    user = User.new(phone: "+13475551111", first_name: "")
    assert_not user.valid?

    user.first_name = "A" * 51
    assert_not user.valid?

    user.first_name = "Jane"
    assert user.valid?
  end

  test "last_name must be 1-50 characters when present" do
    user = User.new(phone: "+13475551111", last_name: "")
    assert_not user.valid?

    user.last_name = "A" * 51
    assert_not user.valid?

    user.last_name = "Doe"
    assert user.valid?
  end

  test "role must be host, driver, or both" do
    user = User.new(phone: "+13475551111", role: "admin")
    assert_not user.valid?
    assert user.errors[:role].any?

    %w[host driver both].each do |valid_role|
      user.role = valid_role
      assert user.valid?, "Expected role '#{valid_role}' to be valid"
    end
  end

  test "profile_complete? returns true when all fields present" do
    user = users(:complete_phone_user)
    assert user.profile_complete?
  end

  test "profile_complete? returns false when fields missing" do
    user = users(:incomplete_user)
    assert_not user.profile_complete?
  end

  test "phone uniqueness" do
    existing = users(:complete_phone_user)
    duplicate = User.new(phone: existing.phone)
    assert_not duplicate.valid?
    assert duplicate.errors[:phone].any?
  end

  test "email uniqueness" do
    existing = users(:complete_email_user)
    duplicate = User.new(email: existing.email)
    assert_not duplicate.valid?
    assert duplicate.errors[:email].any?
  end

  test "email uniqueness is case-insensitive" do
    existing = users(:complete_email_user)
    duplicate = User.new(email: existing.email.upcase)
    assert_not duplicate.valid?
    assert duplicate.errors[:email].any?
  end

  test "has_many addresses" do
    user = users(:complete_phone_user)
    assert_equal 1, user.addresses.count
    assert_equal "34-15 74th Street", user.addresses.first.street
  end

  test "destroying user cascades to addresses" do
    user = users(:complete_phone_user)
    assert_difference "Address.count", -1 do
      user.destroy
    end
  end
end
