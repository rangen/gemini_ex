defmodule Gemini.Auth.VertexStrategyTest do
  use ExUnit.Case, async: true

  alias Gemini.Auth.VertexStrategy

  describe "authenticate/1" do
    test "returns placeholder headers for OAuth2 authentication" do
      config = %{
        project_id: "test-project",
        location: "us-central1",
        auth_method: :oauth2
      }

      assert {:ok, headers} = VertexStrategy.authenticate(config)
      assert headers == [{"Content-Type", "application/json"}, {"Authorization", "Bearer oauth2-placeholder-token"}]
    end

    test "returns placeholder headers for service account authentication" do
      config = %{
        project_id: "test-project",
        location: "us-central1",
        auth_method: :service_account,
        service_account_path: "/path/to/service-account.json"
      }

      assert {:ok, headers} = VertexStrategy.authenticate(config)
      assert headers == [{"Content-Type", "application/json"}, {"Authorization", "Bearer service-account-placeholder-token"}]
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

      assert {:ok, headers} = VertexStrategy.authenticate(config)
      assert headers == [{"Content-Type", "application/json"}, {"Authorization", "Bearer oauth2-placeholder-token"}]
    end

    test "returns error for unsupported auth method" do
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
