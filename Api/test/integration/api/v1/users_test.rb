require "test_helper"

class Api::V1::UsersTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:complete_phone_user)
    @headers = { "Authorization" => "Bearer #{JwtService.encode(@user.id)}" }
  end

  # GET /users/:id

  test "returns the signed-in user" do
    get api_v1_user_path(@user), headers: @headers, as: :json

    assert_response :ok
    json = response.parsed_body["data"]
    assert_equal @user.id, json["id"]
    assert_equal "Jane", json["first_name"]
    assert_equal "host", json["role"]
  end

  test "show response matches the users table shape" do
    get api_v1_user_path(@user), headers: @headers, as: :json

    assert_equal %w[addresses created_at email first_name id last_name phone role updated_at],
      response.parsed_body["data"].keys.sort
  end

  test "show returns 403 for another user's record" do
    get api_v1_user_path(users(:complete_email_user)), headers: @headers, as: :json

    assert_response :forbidden
    assert_equal "forbidden", response.parsed_body["error"]["code"]
  end

  test "show returns 403 profile_incomplete for an incomplete user" do
    incomplete = users(:incomplete_user)
    headers = { "Authorization" => "Bearer #{JwtService.encode(incomplete.id)}" }

    get api_v1_user_path(incomplete), headers: headers, as: :json

    assert_response :forbidden
    assert_equal "profile_incomplete", response.parsed_body["error"]["code"]
  end

  test "show returns 401 without auth token" do
    get api_v1_user_path(@user), as: :json

    assert_response :unauthorized
  end

  test "show returns 401 with invalid token" do
    get api_v1_user_path(@user), headers: { "Authorization" => "Bearer invalid.token.here" }, as: :json

    assert_response :unauthorized
  end

  # PATCH /users/:id

  test "updates name and role" do
    patch api_v1_user_path(@user),
      params: { user: { first_name: "Janet", last_name: "Dough", role: "both" } },
      headers: @headers,
      as: :json

    assert_response :ok
    json = response.parsed_body["data"]
    assert_equal "Janet", json["first_name"]
    assert_equal "Dough", json["last_name"]
    assert_equal "both", json["role"]
    assert_equal "Janet", @user.reload.first_name
  end

  test "updates only the fields provided" do
    patch api_v1_user_path(@user), params: { user: { role: "driver" } }, headers: @headers, as: :json

    assert_response :ok
    @user.reload
    assert_equal "driver", @user.role
    assert_equal "Jane", @user.first_name
    assert_equal "Doe", @user.last_name
  end

  test "ignores fields that cannot be updated" do
    patch api_v1_user_path(@user),
      params: { user: { first_name: "Janet", phone: "+13475550000", email: "new@example.com" } },
      headers: @headers,
      as: :json

    assert_response :ok
    @user.reload
    assert_equal "+13475551234", @user.phone
    assert_nil @user.email
  end

  test "update returns 422 when clearing a required field" do
    patch api_v1_user_path(@user), params: { user: { first_name: "" } }, headers: @headers, as: :json

    assert_response :unprocessable_entity
    assert response.parsed_body["error"]["details"].key?("first_name")
    assert_equal "Jane", @user.reload.first_name
  end

  test "update returns 422 when setting a required field to null" do
    patch api_v1_user_path(@user), params: { user: { last_name: nil } }, headers: @headers, as: :json

    assert_response :unprocessable_entity
    assert_equal "Doe", @user.reload.last_name
  end

  test "update returns 422 when first_name exceeds 50 chars" do
    patch api_v1_user_path(@user), params: { user: { first_name: "A" * 51 } }, headers: @headers, as: :json

    assert_response :unprocessable_entity
  end

  test "update returns 422 with invalid role" do
    patch api_v1_user_path(@user), params: { user: { role: "admin" } }, headers: @headers, as: :json

    assert_response :unprocessable_entity
    assert_equal "host", @user.reload.role
  end

  test "update returns 403 for another user's record" do
    other = users(:complete_email_user)

    patch api_v1_user_path(other), params: { user: { first_name: "Hacked" } }, headers: @headers, as: :json

    assert_response :forbidden
    assert_equal "John", other.reload.first_name
  end

  test "update returns 401 without auth token" do
    patch api_v1_user_path(@user), params: { user: { first_name: "Janet" } }, as: :json

    assert_response :unauthorized
  end
end
