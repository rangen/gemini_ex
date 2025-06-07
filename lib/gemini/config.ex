defmodule Gemini.Config do
  @moduledoc """
  Unified configuration management for both Gemini and Vertex AI authentication.

  Supports multiple authentication strategies:
  - Gemini: API key authentication
  - Vertex AI: OAuth2 or Service Account authentication
  """

  @type auth_config :: %{
    type: :gemini | :vertex_ai,
    credentials: map()
  }

  @default_model "gemini-1.5-pro-latest"

  @doc """
  Get configuration based on environment variables and application config.
  Returns a structured configuration map.
  """
  def get do
    auth_type = detect_auth_type()

    case auth_type do
      :gemini ->
        %{
          auth_type: :gemini,
          api_key: gemini_api_key() || Application.get_env(:gemini, :api_key),
          model: default_model()
        }

      :vertex ->
        %{
          auth_type: :vertex,
          project_id: vertex_project_id(),
          location: vertex_location(),
          model: default_model()
        }
    end
  end

  @doc """
  Get configuration with overrides.
  """
  def get(overrides) when is_list(overrides) do
    base_config = get()
    override_map = Enum.into(overrides, %{})

    Map.merge(base_config, override_map)
  end

  @doc """
  Detect authentication type based on environment variables.
  """
  def detect_auth_type do
    cond do
      gemini_api_key() -> :gemini
      vertex_project_id() && vertex_project_id() != "" -> :vertex
      true -> :gemini  # default
    end
  end

  @doc """
  Detect authentication type based on configuration map.
  """
  def detect_auth_type(%{api_key: api_key, project_id: _project_id}) when not is_nil(api_key) do
    :gemini  # gemini takes priority
  end

  def detect_auth_type(%{project_id: project_id}) when not is_nil(project_id) do
    :vertex
  end

  def detect_auth_type(%{api_key: api_key}) when not is_nil(api_key) do
    :gemini
  end

  def detect_auth_type(%{}) do
    :gemini  # default
  end

  @doc """
  Get the authentication configuration.

  Returns a map with the authentication type and credentials.
  Priority order:
  1. Environment variables
  2. Application configuration
  3. Default to Gemini with API key
  """
  def auth_config do
    cond do
      gemini_api_key() ->
        %{
          type: :gemini,
          credentials: %{api_key: gemini_api_key()}
        }

      vertex_access_token() ->
        %{
          type: :vertex_ai,
          credentials: %{
            access_token: vertex_access_token(),
            project_id: vertex_project_id(),
            location: vertex_location()
          }
        }

      vertex_service_account() ->
        %{
          type: :vertex_ai,
          credentials: %{
            service_account_key: vertex_service_account(),
            project_id: vertex_project_id(),
            location: vertex_location()
          }
        }

      true ->
        # Check application config
        case Application.get_env(:gemini, :auth) do
          nil ->
            # Default to looking for basic API key config
            case Application.get_env(:gemini, :api_key) do
              nil -> nil
              api_key -> %{type: :gemini, credentials: %{api_key: api_key}}
            end
          config -> config
        end
    end
  end

  @doc """
  Get the API key from environment or application config.
  (Legacy function for backward compatibility)
  """
  def api_key do
    gemini_api_key() || Application.get_env(:gemini, :api_key)
  end

  @doc """
  Get the default model to use.
  """
  def default_model do
    Application.get_env(:gemini, :default_model, @default_model)
  end

  @doc """
  Get HTTP timeout in milliseconds.
  """
  def timeout do
    Application.get_env(:gemini, :timeout, 30_000)
  end

  @doc """
  Get the base URL for the current authentication type.
  (Legacy function - now determined by auth strategy)
  """
  def base_url do
    case auth_config() do
      %{type: :gemini, credentials: credentials} ->
        Gemini.Auth.get_base_url(:gemini, credentials)
      %{type: :vertex_ai, credentials: credentials} ->
        Gemini.Auth.get_base_url(:vertex_ai, credentials)
      _ ->
        Application.get_env(:gemini, :base_url, "https://generativelanguage.googleapis.com/v1beta")
    end
  end

  @doc """
  Validate that required configuration is present.
  """
  def validate! do
    case auth_config() do
      nil ->
        raise """
        No authentication configured. Please set one of:

        For Gemini API:
        - Environment variable: GEMINI_API_KEY
        - Application config: config :gemini, api_key: "your_api_key"

        For Vertex AI:
        - Environment variables: VERTEX_ACCESS_TOKEN, VERTEX_PROJECT_ID, VERTEX_LOCATION
        - Environment variables: VERTEX_SERVICE_ACCOUNT, VERTEX_PROJECT_ID, VERTEX_LOCATION
        - Application config: config :gemini, auth: %{type: :vertex_ai, credentials: %{...}}
        """

      %{type: :gemini, credentials: %{api_key: nil}} ->
        raise "Gemini API key is nil"

      %{type: :vertex_ai, credentials: credentials} ->
        validate_vertex_config!(credentials)

      %{type: :gemini} ->
        :ok

      _ ->
        raise "Invalid authentication configuration"
    end
  end

  # Private functions for environment variable access

  defp gemini_api_key do
    System.get_env("GEMINI_API_KEY")
  end

  defp vertex_access_token do
    System.get_env("VERTEX_ACCESS_TOKEN")
  end

  defp vertex_service_account do
    System.get_env("VERTEX_SERVICE_ACCOUNT")
  end

  defp vertex_project_id do
    System.get_env("VERTEX_PROJECT_ID") || System.get_env("GOOGLE_CLOUD_PROJECT")
  end

  defp vertex_location do
    System.get_env("VERTEX_LOCATION") || System.get_env("GOOGLE_CLOUD_LOCATION") || "us-central1"
  end

  defp validate_vertex_config!(%{access_token: token, project_id: project, location: location})
       when is_binary(token) and is_binary(project) and is_binary(location) do
    :ok
  end

  defp validate_vertex_config!(%{service_account_key: key, project_id: project, location: location})
       when is_binary(key) and is_binary(project) and is_binary(location) do
    :ok
  end

  defp validate_vertex_config!(credentials) do
    raise "Invalid Vertex AI configuration: #{inspect(credentials)}"
  end
end
