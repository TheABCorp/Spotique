require "test_helper"

class Api::V1::Auth::VerifyTest < ActionDispatch::IntegrationTest
  setup do
    @phone = "+13475550000"
    @code = "123456"
    @active_code = verification_codes(:active_phone_code)
  end

  test "verifies code and creates new user" do
    assert_difference "User.count", 1 do
      post api_v1_auth_verify_path, params: { phone: @phone, code: @code }, as: :json
    end

    assert_response :ok
    json = response.parsed_body["data"]
    assert json["is_new"]
    assert_not_nil json["token"]
    assert_nil json["user"]
  end

  test "verifies code and returns existing user" do
    user = User.create!(phone: @phone, first_name: "Jane", last_name: "Doe", address: "123 Main St", role: "host")

    post api_v1_auth_verify_path, params: { phone: @phone, code: @code }, as: :json

    assert_response :ok
    json = response.parsed_body["data"]
    assert_not json["is_new"]
    assert_not_nil json["token"]
    assert_equal user.id, json["user"]["id"]
    assert_equal "Jane", json["user"]["first_name"]
  end

  test "returns JWT that can be decoded" do
    post api_v1_auth_verify_path, params: { phone: @phone, code: @code }, as: :json

    token = response.parsed_body["data"]["token"]
    payload = JwtService.decode(token)
    assert_not_nil payload
    assert_equal User.last.id, payload["sub"]
  end

  test "rejects invalid code" do
    post api_v1_auth_verify_path, params: { phone: @phone, code: "000000" }, as: :json

    assert_response :unauthorized
    assert_includes response.parsed_body["error"]["message"], "Invalid code"
  end

  test "increments attempts on wrong code" do
    post api_v1_auth_verify_path, params: { phone: @phone, code: "000000" }, as: :json

    assert_equal 1, @active_code.reload.attempts
  end

  test "locks out after 5 failed attempts" do
    @active_code.update!(attempts: 4)

    post api_v1_auth_verify_path, params: { phone: @phone, code: "000000" }, as: :json

    assert_response :too_many_requests
    assert_includes response.parsed_body["error"]["message"], "Too many attempts"
  end

  test "rejects already locked out code" do
    post api_v1_auth_verify_path, params: { phone: verification_codes(:locked_out_code).phone, code: "111111" }, as: :json

    assert_response :too_many_requests
  end

  test "rejects expired code" do
    expired_phone = verification_codes(:expired_code).phone

    post api_v1_auth_verify_path, params: { phone: expired_phone, code: "654321" }, as: :json

    assert_response :unauthorized
    assert_includes response.parsed_body["error"]["message"], "No active verification code"
  end

  test "rejects request without phone or email" do
    post api_v1_auth_verify_path, params: { code: "123456" }, as: :json

    assert_response :bad_request
  end

  test "marks verification code as verified on success" do
    post api_v1_auth_verify_path, params: { phone: @phone, code: @code }, as: :json

    assert_not_nil @active_code.reload.verified_at
  end
end
