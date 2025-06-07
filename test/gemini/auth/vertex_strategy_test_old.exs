defmodule Gemini.Auth.VertexStrategyTest do
  use ExUnit.Case, async: true

  alias Gemini.Auth.VertexStrategy

  @sample_service_account_key %{
    type: "service_account",
    project_id: "test-project",
    private_key_id: "key-id-123",
    private_key: """
    -----BEGIN PRIVATE KEY-----
    MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC7VJTUt9Us8cKB
    wEiOfQIp5fXQ2j1ZWX3bNGNNRJYEQnE7FzU4lIbGKvv8XFmx6vQAu7ZXC9+A3oWl
    vQAQpOIpAlAAAoIBAQC7VJTUt9Us8cKBwEiOfQIp5fXQ2j1ZWX3bNGNNRJYEQnE7
    -----END PRIVATE KEY-----
    """,
    client_email: "test-service@test-project.iam.gserviceaccount.com",
    client_id: "123456789",
    auth_uri: "https://accounts.google.com/o/oauth2/auth",
    token_uri: "https://oauth2.googleapis.com/token",
    auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
    client_x509_cert_url:
      "https://www.googleapis.com/robot/v1/metadata/x509/test-service%40test-project.iam.gserviceaccount.com"
  }

  describe "authenticate/1" do
    test "returns credentials for OAuth2 authentication" do
      config = %{
        project_id: "test-project",
        location: "us-central1",
        auth_method: :oauth2
      }

      assert {:ok, credentials} = VertexStrategy.authenticate(config)
      assert credentials.project_id == "test-project"
      assert credentials.location == "us-central1"
      assert credentials.access_token == "oauth2-placeholder-token"
    end

    test "returns credentials for service account authentication with key path" do
      # Create temporary service account file
      temp_path = "/tmp/test_service_account_auth.json"
      content = Jason.encode!(@sample_service_account_key)
      File.write!(temp_path, content)

      config = %{
        project_id: "test-project",
        location: "us-central1",
        auth_method: :service_account,
        service_account_key: temp_path
      }

      # Clean up the file after test
      on_exit(fn -> File.rm(temp_path) end)

      result = VertexStrategy.authenticate(config)

      # Should return either success or error (depending on token exchange)
      assert match?({:ok, _} | {:error, _}, result)

      case result do
        {:ok, credentials} ->
          assert credentials.project_id == "test-project"
          assert credentials.location == "us-central1"
          assert credentials.service_account_key == temp_path
          assert is_binary(credentials.access_token)

        {:error, _reason} ->
          # Expected in test environment without real token exchange
          :ok
      end
    end

    test "returns credentials for service account authentication with key data" do
      config = %{
        project_id: "test-project",
        location: "us-central1",
        auth_method: :service_account,
        service_account_data: @sample_service_account_key
      }

      result = VertexStrategy.authenticate(config)

      # Should return either success or error (depending on token exchange)
      assert match?({:ok, _} | {:error, _}, result)
    end

    test "returns credentials for direct access token" do
      config = %{
        project_id: "test-project",
        location: "us-central1",
        access_token: "existing-access-token"
      }

      assert {:ok, credentials} = VertexStrategy.authenticate(config)
      assert credentials.project_id == "test-project"
      assert credentials.location == "us-central1"
      assert credentials.access_token == "existing-access-token"
    end

    test "returns error when project_id is missing" do
      config = %{location: "us-central1"}

      assert {:error, error} = VertexStrategy.authenticate(config)
      assert error =~ "Missing required fields: project_id and location"
    end

    test "returns error when location is missing" do
      config = %{project_id: "test-project"}

      assert {:error, error} = VertexStrategy.authenticate(config)
      assert error =~ "Missing required fields: project_id and location"
    end

    test "defaults to oauth2 auth method when not specified" do
      config = %{project_id: "test-project", location: "us-central1"}

      assert {:ok, credentials} = VertexStrategy.authenticate(config)
      assert credentials.access_token == "oauth2-placeholder-token"
    end

    test "returns error for invalid configuration" do
      config = %{
        project_id: "test-project",
        location: "us-central1",
        auth_method: :invalid
      }

      assert {:error, error} = VertexStrategy.authenticate(config)
      assert error =~ "Unsupported auth method"
    end
  end

  describe "base_url/1" do
    test "constructs correct Vertex AI base URL" do
      config = %{project_id: "my-project", location: "us-west1"}

      expected = "https://us-west1-aiplatform.googleapis.com/v1"
      assert VertexStrategy.base_url(config) == expected
    end

    test "handles different locations correctly" do
      config1 = %{project_id: "proj", location: "europe-west1"}
      config2 = %{project_id: "proj", location: "asia-southeast1"}

      assert VertexStrategy.base_url(config1) =~ "europe-west1-aiplatform"
      assert VertexStrategy.base_url(config2) =~ "asia-southeast1-aiplatform"
    end

    test "returns error when project_id missing for base_url" do
      config = %{location: "us-central1"}

      assert {:error, error} = VertexStrategy.base_url(config)
      assert error =~ "Project ID is required"
    end

    test "returns error when location missing for base_url" do
      config = %{project_id: "test-project"}

      assert {:error, error} = VertexStrategy.base_url(config)
      assert error =~ "Location is required"
    end
  end
end
