require "test_helper"

class Api::V1::Auth::CompleteProfileTest < ActionDispatch::IntegrationTest
  setup do
    @incomplete_user = users(:incomplete_user)
    @token = JwtService.encode(@incomplete_user.id)
    @headers = { "Authorization" => "Bearer #{@token}" }
    @valid_params = {
      user: {
        first_name: "Jane",
        last_name: "Doe",
        address: "34-15 74th Street, Jackson Heights, NY 11372",
        role: "host"
      }
    }
  end

  test "completes profile for new user" do
    post api_v1_auth_complete_profile_path, params: @valid_params, headers: @headers, as: :json

    assert_response :created
    json = response.parsed_body["data"]
    assert_equal "Jane", json["first_name"]
    assert_equal "Doe", json["last_name"]
    assert_equal "host", json["role"]
    assert_equal @incomplete_user.id, json["id"]
  end

  test "returns 409 if profile already complete" do
    complete_user = users(:complete_phone_user)
    token = JwtService.encode(complete_user.id)

    post api_v1_auth_complete_profile_path,
      params: @valid_params,
      headers: { "Authorization" => "Bearer #{token}" },
      as: :json

    assert_response :conflict
    assert_includes response.parsed_body["error"]["message"], "already completed"
  end

  test "returns 401 without auth token" do
    post api_v1_auth_complete_profile_path, params: @valid_params, as: :json

    assert_response :unauthorized
  end

  test "returns 401 with invalid token" do
    post api_v1_auth_complete_profile_path,
      params: @valid_params,
      headers: { "Authorization" => "Bearer invalid.token.here" },
      as: :json

    assert_response :unauthorized
  end

  test "returns 422 when first_name is missing" do
    @valid_params[:user].delete(:first_name)
    post api_v1_auth_complete_profile_path, params: @valid_params, headers: @headers, as: :json

    assert_response :unprocessable_entity
  end

  test "returns 422 when first_name exceeds 50 chars" do
    @valid_params[:user][:first_name] = "A" * 51
    post api_v1_auth_complete_profile_path, params: @valid_params, headers: @headers, as: :json

    assert_response :unprocessable_entity
  end

  test "returns 422 when last_name is missing" do
    @valid_params[:user].delete(:last_name)
    post api_v1_auth_complete_profile_path, params: @valid_params, headers: @headers, as: :json

    assert_response :unprocessable_entity
  end

  test "returns 422 when address is missing" do
    @valid_params[:user].delete(:address)
    post api_v1_auth_complete_profile_path, params: @valid_params, headers: @headers, as: :json

    assert_response :unprocessable_entity
  end

  test "returns 422 with invalid role" do
    @valid_params[:user][:role] = "admin"
    post api_v1_auth_complete_profile_path, params: @valid_params, headers: @headers, as: :json

    assert_response :unprocessable_entity
  end

  test "accepts all valid roles" do
    %w[host driver both].each do |role|
      incomplete = User.create!(phone: "+1347555#{rand(1000..9999)}")
      token = JwtService.encode(incomplete.id)

      post api_v1_auth_complete_profile_path,
        params: { user: @valid_params[:user].merge(role: role) },
        headers: { "Authorization" => "Bearer #{token}" },
        as: :json

      assert_response :created, "Expected 201 for role '#{role}'"
    end
  end
end
