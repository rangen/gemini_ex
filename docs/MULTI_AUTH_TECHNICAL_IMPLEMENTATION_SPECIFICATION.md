# Multi-Auth Technical Implementation Specification

## 🏗️ Core Implementation Files

### 1. Multi-Auth Coordinator Implementation

**File**: `lib/gemini/auth/multi_auth_coordinator.ex`

```elixir
defmodule Gemini.Auth.MultiAuthCoordinator do
  @moduledoc """
  Coordinates multiple authentication strategies for concurrent usage.
  
  This module enables per-request authentication strategy selection while
  maintaining independent credential management and lifecycle handling.
  """
  
  @type auth_strategy :: :gemini | :vertex_ai
  @type credentials :: map()
  @type auth_config :: %{type: auth_strategy(), credentials: credentials()}
  @type auth_result :: {:ok, auth_strategy(), headers :: list()} | {:error, term()}
  @type coord_state :: %{
    strategies: %{auth_strategy() => auth_config()},
    default_strategy: auth_strategy(),
    credential_cache: %{auth_strategy() => {credentials(), expiry :: integer()}}
  }
  
  @doc """
  Coordinate authentication for the given strategy.
  
  ## Parameters
  - `strategy` - The authentication strategy to use (:gemini or :vertex_ai)
  - `opts` - Request options that may override default credentials
  
  ## Returns
  - `{:ok, strategy, headers}` - Success with auth headers
  - `{:error, reason}` - Authentication failure
  
  ## Examples
  
      iex> MultiAuthCoordinator.coordinate_auth(:gemini, [])
      {:ok, :gemini, [{"x-goog-api-key", "..."}, {"Content-Type", "application/json"}]}
      
      iex> MultiAuthCoordinator.coordinate_auth(:vertex_ai, [])
      {:ok, :vertex_ai, [{"Authorization", "Bearer ..."}, {"Content-Type", "application/json"}]}
  """
  @spec coordinate_auth(auth_strategy(), keyword()) :: auth_result()
  def coordinate_auth(strategy, opts \\ []) do
    with {:ok, auth_config} <- get_auth_config(strategy),
         {:ok, credentials} <- ensure_valid_credentials(strategy, auth_config),
         {:ok, headers} <- build_auth_headers(strategy, credentials) do
      {:ok, strategy, headers}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  @doc """
  Refresh credentials for the given strategy.
  
  ## Parameters
  - `strategy` - The authentication strategy to refresh
  
  ## Returns
  - `{:ok, credentials}` - Refreshed credentials
  - `{:error, reason}` - Refresh failure
  """
  @spec refresh_credentials(auth_strategy()) :: {:ok, credentials()} | {:error, term()}
  def refresh_credentials(strategy) do
    with {:ok, auth_config} <- get_auth_config(strategy),
         strategy_module = get_strategy_module(strategy),
         {:ok, refreshed_credentials} <- strategy_module.refresh_credentials(auth_config.credentials) do
      # Update cache with refreshed credentials
      cache_credentials(strategy, refreshed_credentials)
      {:ok, refreshed_credentials}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  @doc """
  Validate authentication configuration for the given strategy.
  
  ## Parameters
  - `strategy` - The authentication strategy to validate
  
  ## Returns
  - `:ok` - Configuration is valid
  - `{:error, reason}` - Configuration is invalid
  """
  @spec validate_auth_config(auth_strategy()) :: :ok | {:error, term()}
  def validate_auth_config(strategy) do
    case get_auth_config(strategy) do
      {:ok, auth_config} -> validate_strategy_config(strategy, auth_config)
      {:error, reason} -> {:error, reason}
    end
  end
  
  @doc """
  Get the base URL for the given authentication strategy.
  
  ## Parameters
  - `strategy` - The authentication strategy
  - `credentials` - The credentials for the strategy
  
  ## Returns
  - `{:ok, base_url}` - Success with base URL
  - `{:error, reason}` - Failure to determine base URL
  """
  @spec get_base_url(auth_strategy(), credentials()) :: {:ok, String.t()} | {:error, term()}
  def get_base_url(strategy, credentials) do
    strategy_module = get_strategy_module(strategy)
    
    case strategy_module.base_url(credentials) do
      url when is_binary(url) -> {:ok, url}
      {:error, reason} -> {:error, reason}
      _ -> {:error, "Invalid base URL response from strategy"}
    end
  end
  
  @doc """
  Build the API path for the given strategy, model, and endpoint.
  
  ## Parameters
  - `strategy` - The authentication strategy
  - `model` - The model name
  - `endpoint` - The API endpoint
  - `credentials` - The credentials for the strategy
  
  ## Returns
  - `{:ok, path}` - Success with API path
  - `{:error, reason}` - Failure to build path
  """
  @spec build_api_path(auth_strategy(), String.t(), String.t(), credentials()) :: 
    {:ok, String.t()} | {:error, term()}
  def build_api_path(strategy, model, endpoint, credentials) do
    strategy_module = get_strategy_module(strategy)
    
    try do
      path = strategy_module.build_path(model, endpoint, credentials)
      {:ok, path}
    rescue
      error -> {:error, "Failed to build API path: #{inspect(error)}"}
    end
  end
  
  # Private implementation functions
  
  @spec get_auth_config(auth_strategy()) :: {:ok, auth_config()} | {:error, term()}
  defp get_auth_config(strategy) do
    case strategy do
      :gemini -> get_gemini_config()
      :vertex_ai -> get_vertex_ai_config()
      _ -> {:error, :invalid_auth_strategy}
    end
  end
  
  @spec get_gemini_config() :: {:ok, auth_config()} | {:error, term()}
  defp get_gemini_config do
    case Application.get_env(:gemini, :gemini) do
      nil -> 
        # Fallback to legacy config format
        case Application.get_env(:gemini, :api_key) || System.get_env("GEMINI_API_KEY") do
          nil -> {:error, "No Gemini API key configured"}
          api_key -> {:ok, %{type: :gemini, credentials: %{api_key: api_key}}}
        end
      config when is_map(config) ->
        {:ok, %{type: :gemini, credentials: config}}
      _ ->
        {:error, "Invalid Gemini configuration format"}
    end
  end
  
  @spec get_vertex_ai_config() :: {:ok, auth_config()} | {:error, term()}
  defp get_vertex_ai_config do
    case Application.get_env(:gemini, :vertex_ai) do
      nil -> get_vertex_ai_from_env()
      config when is_map(config) -> 
        {:ok, %{type: :vertex_ai, credentials: config}}
      _ -> 
        {:error, "Invalid Vertex AI configuration format"}
    end
  end
  
  @spec get_vertex_ai_from_env() :: {:ok, auth_config()} | {:error, term()}
  defp get_vertex_ai_from_env do
    project_id = System.get_env("VERTEX_PROJECT_ID") || System.get_env("GOOGLE_CLOUD_PROJECT")
    location = System.get_env("VERTEX_LOCATION") || System.get_env("GOOGLE_CLOUD_LOCATION") || "us-central1"
    
    cond do
      access_token = System.get_env("VERTEX_ACCESS_TOKEN") ->
        credentials = %{
          access_token: access_token,
          project_id: project_id,
          location: location
        }
        {:ok, %{type: :vertex_ai, credentials: credentials}}
        
      service_account = System.get_env("VERTEX_SERVICE_ACCOUNT") || System.get_env("VERTEX_JSON_FILE") ->
        credentials = %{
          service_account_key: service_account,
          project_id: project_id,
          location: location
        }
        {:ok, %{type: :vertex_ai, credentials: credentials}}
        
      true ->
        {:error, "No Vertex AI credentials configured"}
    end
  end
  
  @spec ensure_valid_credentials(auth_strategy(), auth_config()) :: {:ok, credentials()} | {:error, term()}
  defp ensure_valid_credentials(strategy, auth_config) do
    case get_cached_credentials(strategy) do
      {:ok, credentials} -> {:ok, credentials}
      {:error, :not_cached} -> authenticate_and_cache(strategy, auth_config)
      {:error, :expired} -> refresh_and_cache(strategy, auth_config)
    end
  end
  
  @spec authenticate_and_cache(auth_strategy(), auth_config()) :: {:ok, credentials()} | {:error, term()}
  defp authenticate_and_cache(strategy, auth_config) do
    strategy_module = get_strategy_module(strategy)
    
    case strategy_module.authenticate(auth_config.credentials) do
      {:ok, credentials} ->
        cache_credentials(strategy, credentials)
        {:ok, credentials}
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @spec refresh_and_cache(auth_strategy(), auth_config()) :: {:ok, credentials()} | {:error, term()}
  defp refresh_and_cache(strategy, auth_config) do
    case refresh_credentials(strategy) do
      {:ok, credentials} -> {:ok, credentials}
      {:error, reason} -> {:error, reason}
    end
  end
  
  @spec build_auth_headers(auth_strategy(), credentials()) :: {:ok, list()} | {:error, term()}
  defp build_auth_headers(strategy, credentials) do
    strategy_module = get_strategy_module(strategy)
    
    try do
      headers = strategy_module.headers(credentials)
      {:ok, headers}
    rescue
      error -> {:error, "Failed to build auth headers: #{inspect(error)}"}
    end
  end
  
  @spec get_strategy_module(auth_strategy()) :: module()
  defp get_strategy_module(:gemini), do: Gemini.Auth.GeminiStrategy
  defp get_strategy_module(:vertex_ai), do: Gemini.Auth.VertexStrategy
  
  @spec validate_strategy_config(auth_strategy(), auth_config()) :: :ok | {:error, term()}
  defp validate_strategy_config(:gemini, %{credentials: %{api_key: api_key}}) when is_binary(api_key) do
    if String.length(api_key) > 0, do: :ok, else: {:error, "API key cannot be empty"}
  end
  
  defp validate_strategy_config(:vertex_ai, %{credentials: credentials}) do
    required_fields = [:project_id, :location]
    
    case Enum.find(required_fields, fn field -> not Map.has_key?(credentials, field) end) do
      nil -> :ok
      missing_field -> {:error, "Missing required field: #{missing_field}"}
    end
  end
  
  defp validate_strategy_config(_, _), do: {:error, "Invalid strategy configuration"}
  
  # Credential caching implementation
  
  @spec cache_credentials(auth_strategy(), credentials()) :: :ok
  defp cache_credentials(strategy, credentials) do
    expiry = System.system_time(:second) + get_cache_ttl(strategy)
    cache_entry = {credentials, expiry}
    
    # Store in process dictionary for now - could be enhanced with ETS or GenServer
    Process.put({:auth_cache, strategy}, cache_entry)
    :ok
  end
  
  @spec get_cached_credentials(auth_strategy()) :: {:ok, credentials()} | {:error, :not_cached | :expired}
  defp get_cached_credentials(strategy) do
    case Process.get({:auth_cache, strategy}) do
      nil -> {:error, :not_cached}
      {credentials, expiry} ->
        if System.system_time(:second) < expiry do
          {:ok, credentials}
        else
          {:error, :expired}
        end
    end
  end
  
  @spec get_cache_ttl(auth_strategy()) :: integer()
  defp get_cache_ttl(:gemini), do: 3600  # 1 hour for API keys
  defp get_cache_ttl(:vertex_ai), do: 300  # 5 minutes for OAuth tokens
end
```

### 2. Unified Streaming Manager Implementation

**File**: `lib/gemini/streaming/unified_manager.ex`

```elixir
defmodule Gemini.Streaming.UnifiedManager do
  @moduledoc """
  Unified streaming manager that extends ManagerV2 with multi-auth support.
  
  Preserves all the excellent streaming capabilities from ManagerV2 while
  adding auth-aware routing and coordination.
  """
  
  use GenServer
  require Logger
  
  alias Gemini.Streaming.ManagerV2
  alias Gemini.Auth.MultiAuthCoordinator
  alias Gemini.Client.HTTPStreaming
  alias Gemini.{Config, Error, Telemetry}
  
  @type stream_id :: String.t()
  @type auth_strategy :: MultiAuthCoordinator.auth_strategy()
  @type stream_opts :: keyword()
  
  # Delegate most functionality to ManagerV2
  defdelegate subscribe_stream(stream_id, subscriber_pid), to: ManagerV2
  defdelegate unsubscribe_stream(stream_id, subscriber_pid), to: ManagerV2
  defdelegate stop_stream(stream_id), to: ManagerV2
  defdelegate list_streams(), to: ManagerV2
  defdelegate get_stats(), to: ManagerV2
  
  @doc """
  Start a streaming session with auth-aware routing.
  
  ## Parameters
  - `contents` - Content to stream
  - `opts` - Options including :auth strategy
  - `subscriber_pid` - Process to receive stream events
  
  ## Returns
  - `{:ok, stream_id}` - Success with stream ID
  - `{:error, reason}` - Failure details
  
  ## Examples
  
      {:ok, stream_id} = UnifiedManager.start_stream("Hello", [auth: :gemini], self())
      {:ok, stream_id} = UnifiedManager.start_stream("Hello", [auth: :vertex_ai], self())
  """
  @spec start_stream(term(), stream_opts(), pid()) :: {:ok, stream_id()} | {:error, term()}
  def start_stream(contents, opts \\ [], subscriber_pid \\ self()) do
    # Extract auth strategy from options
    auth_strategy = Keyword.get(opts, :auth, Config.default_auth())
    
    # Enhance options with auth-specific configuration
    case enhance_opts_with_auth(opts, auth_strategy) do
      {:ok, enhanced_opts} ->
        # Delegate to ManagerV2 with enhanced options
        ManagerV2.start_stream(contents, enhanced_opts, subscriber_pid)
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Start a streaming session with explicit auth strategy.
  
  ## Parameters
  - `contents` - Content to stream
  - `auth_strategy` - Authentication strategy to use
  - `opts` - Additional streaming options
  - `subscriber_pid` - Process to receive stream events
  
  ## Returns
  - `{:ok, stream_id}` - Success with stream ID
  - `{:error, reason}` - Failure details
  """
  @spec start_stream_with_auth(term(), auth_strategy(), stream_opts(), pid()) :: 
    {:ok, stream_id()} | {:error, term()}
  def start_stream_with_auth(contents, auth_strategy, opts \\ [], subscriber_pid \\ self()) do
    enhanced_opts = Keyword.put(opts, :auth, auth_strategy)
    start_stream(contents, enhanced_opts, subscriber_pid)
  end
  
  @doc """
  Get stream information with auth metadata.
  
  ## Parameters
  - `stream_id` - The stream identifier
  
  ## Returns
  - `{:ok, stream_info}` - Stream info with auth metadata
  - `{:error, reason}` - Stream not found or error
  """
  @spec get_stream_info(stream_id()) :: {:ok, map()} | {:error, term()}
  def get_stream_info(stream_id) do
    case ManagerV2.get_stream_info(stream_id) do
      {:ok, info} ->
        # Enhance with auth metadata if available
        enhanced_info = add_auth_metadata(info)
        {:ok, enhanced_info}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  # Private implementation functions
  
  @spec enhance_opts_with_auth(stream_opts(), auth_strategy()) :: 
    {:ok, stream_opts()} | {:error, term()}
  defp enhance_opts_with_auth(opts, auth_strategy) do
    with {:ok, auth_strategy, headers} <- MultiAuthCoordinator.coordinate_auth(auth_strategy, opts),
         {:ok, base_url} <- get_base_url_for_strategy(auth_strategy, opts),
         {:ok, enhanced_opts} <- build_enhanced_opts(opts, auth_strategy, headers, base_url) do
      {:ok, enhanced_opts}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  @spec get_base_url_for_strategy(auth_strategy(), stream_opts()) :: 
    {:ok, String.t()} | {:error, term()}
  defp get_base_url_for_strategy(auth_strategy, opts) do
    # Get credentials for the strategy to determine base URL
    case MultiAuthCoordinator.get_auth_config(auth_strategy) do
      {:ok, auth_config} ->
        MultiAuthCoordinator.get_base_url(auth_strategy, auth_config.credentials)
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @spec build_enhanced_opts(stream_opts(), auth_strategy(), list(), String.t()) :: 
    {:ok, stream_opts()} | {:error, term()}
  defp build_enhanced_opts(opts, auth_strategy, headers, base_url) do
    enhanced_opts = opts
    |> Keyword.put(:auth_strategy, auth_strategy)
    |> Keyword.put(:auth_headers, headers)
    |> Keyword.put(:base_url, base_url)
    |> Keyword.put(:telemetry_metadata, build_telemetry_metadata(auth_strategy, opts))
    
    {:ok, enhanced_opts}
  end
  
  @spec build_telemetry_metadata(auth_strategy(), stream_opts()) :: map()
  defp build_telemetry_metadata(auth_strategy, opts) do
    %{
      auth_strategy: auth_strategy,
      model: Keyword.get(opts, :model, Config.default_model()),
      streaming_type: :unified,
      multi_auth_enabled: true
    }
  end
  
  @spec add_auth_metadata(map()) :: map()
  defp add_auth_metadata(stream_info) do
    # Extract auth metadata from stream configuration if available
    auth_metadata = %{
      auth_strategy: Map.get(stream_info, :auth_strategy),
      auth_enabled: true,
      multi_auth_capable: true
    }
    
    Map.put(stream_info, :auth_metadata, auth_metadata)
  end
end
```

### 3. API Coordinator Implementation

**File**: `lib/gemini/apis/coordinator.ex`

```elixir
defmodule Gemini.APIs.Coordinator do
  @moduledoc """
  Unified API interface with auth-aware routing.
  
  Provides a consistent API surface that routes requests to appropriate
  auth strategies while maintaining the same interface.
  """
  
  alias Gemini.Auth.MultiAuthCoordinator
  alias Gemini.APIs.{Generate, Models, Tokens}
  alias Gemini.{Config, Error}
  
  @type operation :: :generate | :stream_generate | :list_models | :get_model | :count_tokens
  @type request :: map() | String.t() | list()
  @type response :: {:ok, term()} | {:error, Error.t()}
  @type request_opts :: keyword()
  
  @doc """
  Route a request to the appropriate API with auth coordination.
  
  ## Parameters
  - `operation` - The API operation to perform
  - `request` - The request data
  - `opts` - Options including auth strategy
  
  ## Returns
  - `{:ok, response}` - Success with response data
  - `{:error, error}` - Failure with error details
  
  ## Examples
  
      {:ok, response} = Coordinator.route_request(:generate, "Hello", auth: :gemini)
      {:ok, models} = Coordinator.route_request(:list_models, %{}, auth: :vertex_ai)
  """
  @spec route_request(operation(), request(), request_opts()) :: response()
  def route_request(operation, request, opts \\ []) do
    auth_strategy = determine_auth_strategy(opts)
    
    # Enhance options with auth coordination
    case prepare_request_with_auth(auth_strategy, opts) do
      {:ok, enhanced_opts} ->
        execute_operation(operation, request, enhanced_opts)
        
      {:error, reason} ->
        {:error, Error.config_error("Auth coordination failed: #{inspect(reason)}")}
    end
  end
  
  @doc """
  Determine the authentication strategy for a request.
  
  ## Parameters
  - `opts` - Request options that may specify auth strategy
  
  ## Returns
  - `auth_strategy()` - The determined authentication strategy
  
  ## Examples
  
      strategy = Coordinator.determine_auth_strategy(auth: :vertex_ai)
      # => :vertex_ai
      
      strategy = Coordinator.determine_auth_strategy([])
      # => :gemini (default)
  """
  @spec determine_auth_strategy(request_opts()) :: MultiAuthCoordinator.auth_strategy()
  def determine_auth_strategy(opts) do
    case Keyword.get(opts, :auth) do
      nil -> Config.default_auth()
      :gemini -> :gemini
      :vertex_ai -> :vertex_ai
      strategy when is_atom(strategy) -> 
        # Log warning for unknown strategy and use default
        require Logger
        Logger.warning("Unknown auth strategy: #{strategy}, using default")
        Config.default_auth()
      _ -> 
        Config.default_auth()
    end
  end
  
  @doc """
  Check if an auth strategy is available.
  
  ## Parameters
  - `strategy` - The auth strategy to check
  
  ## Returns
  - `true` - Strategy is available and configured
  - `false` - Strategy is not available
  """
  @spec auth_strategy_available?(MultiAuthCoordinator.auth_strategy()) :: boolean()
  def auth_strategy_available?(strategy) do
    case MultiAuthCoordinator.validate_auth_config(strategy) do
      :ok -> true
      {:error, _} -> false
    end
  end
  
  @doc """
  Get available auth strategies.
  
  ## Returns
  - `[auth_strategy()]` - List of available and configured auth strategies
  """
  @spec available_auth_strategies() :: [MultiAuthCoordinator.auth_strategy()]
  def available_auth_strategies do
    [:gemini, :vertex_ai]
    |> Enum.filter(&auth_strategy_available?/1)
  end
  
  @doc """
  Execute operation with fallback to alternative auth strategy.
  
  ## Parameters
  - `operation` - The API operation
  - `request` - The request data
  - `primary_strategy` - Primary auth strategy to try
  - `fallback_strategy` - Fallback auth strategy
  - `opts` - Request options
  
  ## Returns
  - `{:ok, response}` - Success with response
  - `{:error, error}` - Both strategies failed
  """
  @spec route_with_fallback(operation(), request(), 
    MultiAuthCoordinator.auth_strategy(), 
    MultiAuthCoordinator.auth_strategy(), 
    request_opts()) :: response()
  def route_with_fallback(operation, request, primary_strategy, fallback_strategy, opts \\ []) do
    primary_opts = Keyword.put(opts, :auth, primary_strategy)
    
    case route_request(operation, request, primary_opts) do
      {:ok, response} -> 
        {:ok, response}
        
      {:error, %Error{type: error_type}} when error_type in [:rate_limit_error, :quota_exceeded] ->
        # Retry with fallback strategy for rate limiting issues
        fallback_opts = Keyword.put(opts, :auth, fallback_strategy)
        route_request(operation, request, fallback_opts)
        
      {:error, error} ->
        {:error, error}
    end
  end
  
  # Private implementation functions
  
  @spec prepare_request_with_auth(MultiAuthCoordinator.auth_strategy(), request_opts()) :: 
    {:ok, request_opts()} | {:error, term()}
  defp prepare_request_with_auth(auth_strategy, opts) do
    case MultiAuthCoordinator.coordinate_auth(auth_strategy, opts) do
      {:ok, strategy, headers} ->
        enhanced_opts = opts
        |> Keyword.put(:auth_strategy, strategy)
        |> Keyword.put(:auth_headers, headers)
        |> add_strategy_specific_opts(strategy)
        
        {:ok, enhanced_opts}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @spec add_strategy_specific_opts(request_opts(), MultiAuthCoordinator.auth_strategy()) :: request_opts()
  defp add_strategy_specific_opts(opts, :gemini) do
    # Add Gemini-specific options
    opts
    |> Keyword.put_new(:timeout, 30_000)
    |> Keyword.put(:base_url, "https://generativelanguage.googleapis.com/v1beta")
  end
  
  defp add_strategy_specific_opts(opts, :vertex_ai) do
    # Add Vertex AI-specific options
    opts
    |> Keyword.put_new(:timeout, 45_000)
    # Base URL will be determined by MultiAuthCoordinator based on project/location
  end
  
  @spec execute_operation(operation(), request(), request_opts()) :: response()
  defp execute_operation(:generate, request, opts) do
    Generate.content(request, opts)
  end
  
  defp execute_operation(:stream_generate, request, opts) do
    Generate.stream_content(request, opts)
  end
  
  defp execute_operation(:list_models, _request, opts) do
    Models.list(opts)
  end
  
  defp execute_operation(:get_model, model_name, opts) when is_binary(model_name) do
    Models.get(model_name, opts)
  end
  
  defp execute_operation(:count_tokens, request, opts) do
    Tokens.count(request, opts)
  end
  
  defp execute_operation(operation, _request, _opts) do
    {:error, Error.validation_error("Unknown operation: #{operation}")}
  end
end
```

## 🔧 Configuration Management

### Enhanced Configuration Module

**File**: `lib/gemini/config/multi_auth_config.ex`

```elixir
defmodule Gemini.Config.MultiAuthConfig do
  @moduledoc """
  Enhanced configuration management for multi-auth support.
  """
  
  @type auth_strategy :: :gemini | :vertex_ai
  @type auth_config :: map()
  
  @doc """
  Get configuration for all available auth strategies.
  
  ## Returns
  - `%{auth_strategy() => auth_config()}` - Map of available configurations
  """
  @spec get_all_auth_configs() :: %{auth_strategy() => auth_config()}
  def get_all_auth_configs do
    %{}
    |> maybe_add_gemini_config()
    |> maybe_add_vertex_ai_config()
  end
  
  @doc """
  Validate all configured auth strategies.
  
  ## Returns
  - `:ok` - All configurations valid
  - `{:error, errors}` - List of validation errors
  """
  @spec validate_all_auth_configs() :: :ok | {:error, [{auth_strategy(), term()}]}
  def validate_all_auth_configs do
    configs = get_all_auth_configs()
    
    errors = 
      configs
      |> Enum.map(fn {strategy, _config} ->
        case MultiAuthCoordinator.validate_auth_config(strategy) do
          :ok -> nil
          {:error, reason} -> {strategy, reason}
        end
      end)
      |> Enum.filter(&(&1 != nil))
    
    case errors do
      [] -> :ok
      errors -> {:error, errors}
    end
  end
  
  @doc """
  Get default auth strategy based on available configurations.
  
  ## Returns
  - `auth_strategy()` - The default auth strategy to use
  """
  @spec get_default_auth_strategy() :: auth_strategy()
  def get_default_auth_strategy do
    case Application.get_env(:gemini, :default_auth) do
      strategy when strategy in [:gemini, :vertex_ai] -> strategy
      _ -> determine_default_from_available()
    end
  end
  
  # Private functions
  
  @spec maybe_add_gemini_config(map()) :: map()
  defp maybe_add_gemini_config(configs) do
    case get_gemini_config() do
      {:ok, config} -> Map.put(configs, :gemini, config)
      {:error, _} -> configs
    end
  end
  
  @spec maybe_add_vertex_ai_config(map()) :: map()
  defp maybe_add_vertex_ai_config(configs) do
    case get_vertex_ai_config() do
      {:ok, config} -> Map.put(configs, :vertex_ai, config)
      {:error, _} -> configs
    end
  end
  
  @spec get_gemini_config() :: {:ok, auth_config()} | {:error, term()}
  defp get_gemini_config do
    api_key = Application.get_env(:gemini, :api_key) || System.get_env("GEMINI_API_KEY")
    
    case api_key do
      nil -> {:error, "No Gemini API key configured"}
      key when is_binary(key) -> {:ok, %{api_key: key}}
      _ -> {:error, "Invalid Gemini API key format"}
    end
  end
  
  @spec get_vertex_ai_config() :: {:ok, auth_config()} | {:error, term()}
  defp get_vertex_ai_config do
    project_id = System.get_env("VERTEX_PROJECT_ID") || System.get_env("GOOGLE_CLOUD_PROJECT")
    location = System.get_env("VERTEX_LOCATION") || "us-central1"
    
    cond do
      access_token = System.get_env("VERTEX_ACCESS_TOKEN") ->
        {:ok, %{access_token: access_token, project_id: project_id, location: location}}
        
      service_account = System.get_env("VERTEX_SERVICE_ACCOUNT") ->
        {:ok, %{service_account_key: service_account, project_id: project_id, location: location}}
        
      true ->
        {:error, "No Vertex AI credentials configured"}
    end
  end
  
  @spec determine_default_from_available() :: auth_strategy()
  defp determine_default_from_available do
    configs = get_all_auth_configs()
    
    cond do
      Map.has_key?(configs, :gemini) -> :gemini
      Map.has_key?(configs, :vertex_ai) -> :vertex_ai
      true -> :gemini  # Fallback default
    end
  end
end
```

## 🧪 Testing Framework Extensions

### Multi-Auth Test Helpers

**File**: `test/support/multi_auth_helpers.ex`

```elixir
defmodule Gemini.Test.MultiAuthHelpers do
  @moduledoc """
  Test helpers for multi-auth functionality.
  """
  
  import ExUnit.Assertions
  
  @doc """
  Test that both auth strategies work for the same operation.
  """
  def assert_both_auth_strategies_work(operation_fn) do
    # Test with Gemini auth
    with_mock_gemini_auth(fn ->
      case operation_fn.(:gemini) do
        {:ok, _result} -> :ok
        {:error, reason} -> 
          # Allow certain errors in test environment
          unless reason in [:no_auth_config, :network_error] do
            flunk("Gemini auth failed: #{inspect(reason)}")
          end
      end
    end)
    
    # Test with Vertex AI auth
    with_mock_vertex_auth(fn ->
      case operation_fn.(:vertex_ai) do
        {:ok, _result} -> :ok
        {:error, reason} ->
          # Allow certain errors in test environment
          unless reason in [:no_auth_config, :network_error] do
            flunk("Vertex AI auth failed: #{inspect(reason)}")
          end
      end
    end)
  end
  
  @doc """
  Test concurrent usage of both auth strategies.
  """
  def assert_concurrent_auth_usage(operation_fn) do
    with_concurrent_auth(fn ->
      # Start both operations concurrently
      task1 = Task.async(fn -> operation_fn.(:gemini) end)
      task2 = Task.async(fn -> operation_fn.(:vertex_ai) end)
      
      # Wait for both to complete
      results = Task.await_many([task1, task2], 10_000)
      
      # Both should succeed or fail gracefully
      Enum.each(results, fn result ->
        case result do
          {:ok, _} -> :ok
          {:error, reason} ->
            # Allow test-environment errors
            assert reason in [:no_auth_config, :network_error, :timeout]
        end
      end)
    end)
  end
  
  @doc """
  Mock setup for testing auth strategy isolation.
  """
  def with_isolated_auth_strategies(test_fn) do
    original = TestAuth.save_original_auth()
    
    try do
      TestAuth.clear_all_auth()
      
      # Set up both strategies independently
      Application.put_env(:gemini, :gemini, %{api_key: "test_gemini_key"})
      Application.put_env(:gemini, :vertex_ai, %{
        project_id: "test-project",
        location: "us-central1",
        access_token: "test_vertex_token"
      })
      
      test_fn.()
    after
      TestAuth.restore_original_auth(original)
    end
  end
  
  # Additional helper functions...
  
  defp with_mock_gemini_auth(test_fn) do
    Gemini.Test.AuthHelpers.with_mock_gemini_auth(test_fn)
  end
  
  defp with_mock_vertex_auth(test_fn) do
    Gemini.Test.AuthHelpers.with_mock_vertex_auth(test_fn)
  end
  
  defp with_concurrent_auth(test_fn) do
    Gemini.Test.AuthHelpers.with_concurrent_auth(test_fn)
  end
end
```

## 📋 Implementation Checklist

### Phase 1: Core Infrastructure
- [ ] Implement `MultiAuthCoordinator` module
- [ ] Implement `UnifiedManager` module
- [ ] Implement `Coordinator` module
- [ ] Update `Config` module for multi-auth support
- [ ] Create multi-auth test helpers

### Phase 2: Integration
- [ ] Update main `Gemini` module to use coordinators
- [ ] Update existing API modules to accept auth options
- [ ] Update streaming system to use unified manager
- [ ] Update error handling for multi-auth scenarios

### Phase 3: Testing
- [ ] Unit tests for all coordinator modules
- [ ] Integration tests for concurrent usage
- [ ] Property tests for auth isolation
- [ ] Performance tests for auth overhead

### Phase 4: Documentation
- [ ] Update API documentation
- [ ] Create migration guide
- [ ] Add usage examples
- [ ] Create troubleshooting guide

This technical specification provides the complete implementation blueprint for the multi-auth coordination capability, ensuring it integrates seamlessly with the existing excellent streaming infrastructure while adding the key differentiator of concurrent authentication strategy support.
