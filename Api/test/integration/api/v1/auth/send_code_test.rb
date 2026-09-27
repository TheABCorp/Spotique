require "test_helper"

class Api::V1::Auth::SendCodeTest < ActionDispatch::IntegrationTest
  setup do
    SmsService.stubs(:send_verification_code)
  end

  test "sends code for valid US phone" do
    assert_difference "VerificationCode.count", 1 do
      post api_v1_auth_send_code_path, params: { phone: "+13475551234" }, as: :json
    end

    assert_response :ok
    json = response.parsed_body
    assert_equal "phone", json["data"]["medium"]
    assert_equal "+1347***1234", json["data"]["masked"]
    assert_equal 600, json["data"]["expires_in"]
  end

  test "sends code for valid email" do
    assert_difference "VerificationCode.count", 1 do
      post api_v1_auth_send_code_path, params: { email: "jane@example.com" }, as: :json
    end

    assert_response :ok
    json = response.parsed_body
    assert_equal "email", json["data"]["medium"]
    assert_equal "ja***@example.com", json["data"]["masked"]
    assert_equal 600, json["data"]["expires_in"]
  end

  test "rejects request with both phone and email" do
    post api_v1_auth_send_code_path, params: { phone: "+13475551234", email: "jane@example.com" }, as: :json

    assert_response :bad_request
    assert_includes response.parsed_body["error"]["message"], "exactly one"
  end

  test "rejects request with neither phone nor email" do
    post api_v1_auth_send_code_path, params: {}, as: :json

    assert_response :bad_request
  end

  test "rejects invalid US phone format" do
    post api_v1_auth_send_code_path, params: { phone: "555-1234" }, as: :json

    assert_response :unprocessable_entity
    assert_includes response.parsed_body["error"]["message"], "US phone"
  end

  test "rejects non-US phone" do
    post api_v1_auth_send_code_path, params: { phone: "+4420712345678" }, as: :json

    assert_response :unprocessable_entity
  end

  test "rejects invalid email" do
    post api_v1_auth_send_code_path, params: { email: "not-an-email" }, as: :json

    assert_response :unprocessable_entity
    assert_includes response.parsed_body["error"]["message"], "email"
  end

  test "rate limits to 3 codes per phone per hour" do
    phone = "+13475550100"
    3.times do
      post api_v1_auth_send_code_path, params: { phone: phone }, as: :json
      assert_response :ok
    end

    post api_v1_auth_send_code_path, params: { phone: phone }, as: :json
    assert_response :too_many_requests
    assert_includes response.parsed_body["error"]["message"], "Too many"
  end

  test "rate limits to 3 codes per email per hour" do
    email = "ratelimit@example.com"
    3.times do
      post api_v1_auth_send_code_path, params: { email: email }, as: :json
      assert_response :ok
    end

    post api_v1_auth_send_code_path, params: { email: email }, as: :json
    assert_response :too_many_requests
  end

  test "expires previous codes for the same phone" do
    phone = "+13475550200"
    post api_v1_auth_send_code_path, params: { phone: phone }, as: :json
    assert_response :ok

    first_code = VerificationCode.for_phone(phone).recent.first

    post api_v1_auth_send_code_path, params: { phone: phone }, as: :json
    assert_response :ok

    first_code.reload
    assert first_code.expired?, "Previous code should be expired"
  end

  test "stores hashed code, not plaintext" do
    post api_v1_auth_send_code_path, params: { phone: "+13475550300" }, as: :json
    code = VerificationCode.last
    assert code.code_digest.start_with?("$2a$"), "Code should be BCrypt hashed"
  end

  test "sends SMS for phone verification" do
    SmsService.expects(:send_verification_code).with("+13475550400", instance_of(String)).once
    post api_v1_auth_send_code_path, params: { phone: "+13475550400" }, as: :json
    assert_response :ok
  end

  test "enqueues email for email verification" do
    assert_enqueued_emails 1 do
      post api_v1_auth_send_code_path, params: { email: "mailer@example.com" }, as: :json
    end
    assert_response :ok
  end
end
