require "test_helper"

class VerificationCodeTest < ActiveSupport::TestCase
  test "valid with phone" do
    vc = VerificationCode.new(
      phone: "+13475551234",
      code_digest: BCrypt::Password.create("123456"),
      expires_at: 10.minutes.from_now
    )
    assert vc.valid?
  end

  test "valid with email" do
    vc = VerificationCode.new(
      email: "test@example.com",
      code_digest: BCrypt::Password.create("123456"),
      expires_at: 10.minutes.from_now
    )
    assert vc.valid?
  end

  test "invalid without phone or email" do
    vc = VerificationCode.new(
      code_digest: BCrypt::Password.create("123456"),
      expires_at: 10.minutes.from_now
    )
    assert_not vc.valid?
  end

  test "invalid without code_digest" do
    vc = VerificationCode.new(phone: "+13475551234", expires_at: 10.minutes.from_now)
    assert_not vc.valid?
  end

  test "code_matches? returns true for correct code" do
    code = verification_codes(:active_phone_code)
    assert code.code_matches?("123456")
  end

  test "code_matches? returns false for wrong code" do
    code = verification_codes(:active_phone_code)
    assert_not code.code_matches?("000000")
  end

  test "expired? returns true when past expiry" do
    code = verification_codes(:expired_code)
    assert code.expired?
  end

  test "expired? returns false when still valid" do
    code = verification_codes(:active_phone_code)
    assert_not code.expired?
  end

  test "locked_out? returns true at max attempts" do
    code = verification_codes(:locked_out_code)
    assert code.locked_out?
  end

  test "locked_out? returns false below max attempts" do
    code = verification_codes(:active_phone_code)
    assert_not code.locked_out?
  end

  test "generate_code produces 6-digit string" do
    code = VerificationCode.generate_code
    assert_match(/\A\d{6}\z/, code)
  end

  test "latest_active returns most recent unexpired unverified code" do
    code = verification_codes(:active_phone_code)
    result = VerificationCode.latest_active("phone", code.phone)
    assert_equal code, result
  end

  test "latest_active excludes expired codes" do
    code = verification_codes(:expired_code)
    result = VerificationCode.latest_active("phone", code.phone)
    assert_nil result
  end

  test "mark_verified! sets verified_at" do
    code = verification_codes(:active_phone_code)
    assert_nil code.verified_at
    code.mark_verified!
    assert_not_nil code.reload.verified_at
  end

  test "increment_attempts! increases attempts by 1" do
    code = verification_codes(:active_phone_code)
    assert_equal 0, code.attempts
    code.increment_attempts!
    assert_equal 1, code.reload.attempts
  end

  test "hourly_count counts codes created in last hour" do
    code = verification_codes(:active_phone_code)
    count = VerificationCode.hourly_count("phone", code.phone)
    assert_equal 1, count
  end
end
