defmodule Gemini.Models do
  @moduledoc """
  API for managing and querying Gemini models.

  The Models API provides programmatic access to:
  - List available models with pagination
  - Get detailed model information including metadata
  - Query model capabilities and parameters
  - Check model existence and supported features

  ## Examples

      # List all available models
      {:ok, response} = Gemini.Models.list()
      models = response.models

      # Get specific model information
      {:ok, model} = Gemini.Models.get("gemini-2.0-flash")

      # Check if model exists
      {:ok, exists} = Gemini.Models.exists?("gemini-pro")

      # List models supporting streaming
      {:ok, streaming_models} = Gemini.Models.supporting_method("streamGenerateContent")

  ## Model Resource Structure

  Each model returned by the API contains:
  - `name` - Full resource name (e.g., "models/gemini-2.0-flash")
  - `base_model_id` - Base model identifier (e.g., "gemini-2.0-flash")
  - `version` - Model version number
  - `display_name` - Human-readable name
  - `description` - Model description
  - `input_token_limit` - Maximum input tokens
  - `output_token_limit` - Maximum output tokens
  - `supported_generation_methods` - Available API methods
  - Generation parameters like `temperature`, `top_p`, `top_k`
  """

  alias Gemini.Client.HTTP
  alias Gemini.Types.Request.ListModelsRequest
  alias Gemini.Types.Response.{ListModelsResponse, Model}
  alias Gemini.Error
  alias Gemini.Telemetry

  require Logger

  @doc """
  List available Gemini models with optional pagination.

  ## Parameters

  - `opts` - Keyword list of options:
    - `:page_size` - Maximum number of models per page (1-1000, default: 50)
    - `:page_token` - Token for retrieving the next page of results

  ## Returns

  - `{:ok, ListModelsResponse.t()}` - Success with models and pagination info
  - `{:error, Gemini.Error.t()}` - API error or network failure

  ## Examples

      # List first 50 models (default)
      {:ok, response} = Gemini.Models.list()
      models = response.models
      next_token = response.next_page_token

      # Custom page size
      {:ok, response} = Gemini.Models.list(page_size: 10)

      # Pagination
      {:ok, page1} = Gemini.Models.list(page_size: 10)
      {:ok, page2} = Gemini.Models.list(page_size: 10, page_token: page1.next_page_token)

  ## API Reference

  Corresponds to the `models.list` endpoint:
  `GET https://generativelanguage.googleapis.com/v1beta/models`
  """
  @spec list(keyword()) :: {:ok, ListModelsResponse.t()} | {:error, Gemini.Error.t()}
  def list(opts \\ []) do
    # Validate options
    with :ok <- validate_list_options(opts) do
      request = struct(ListModelsRequest, opts)
      query_params = build_list_query_params(request)
      path = "models#{query_params}"

      # Add telemetry metadata
      enhanced_opts = Keyword.merge(opts, function: :list_models)

      start_time = System.monotonic_time()

      case HTTP.get(path, enhanced_opts) do
        {:ok, response} ->
          result = parse_list_models_response(response)

          # Emit success telemetry
          duration = Telemetry.calculate_duration(start_time)
          model_count = case result do
            {:ok, %ListModelsResponse{models: models}} -> length(models)
            _ -> 0
          end

          Telemetry.execute(
            [:gemini, :models, :list, :success],
            %{duration: duration, model_count: model_count},
            %{page_size: Keyword.get(opts, :page_size)}
          )

          result

        {:error, error} ->
          # Emit error telemetry
          duration = Telemetry.calculate_duration(start_time)
          Telemetry.execute(
            [:gemini, :models, :list, :error],
            %{duration: duration},
            %{error_type: error.type}
          )

          {:error, error}
      end
    end
  end

  @doc """
  Get detailed information about a specific model.

  ## Parameters

  - `model_name` - The model identifier, with or without "models/" prefix
    Examples: "gemini-2.0-flash", "models/gemini-1.5-pro"

  ## Returns

  - `{:ok, Model.t()}` - Success with model details
  - `{:error, Gemini.Error.t()}` - Model not found or API error

  ## Examples

      # Get model by base ID
      {:ok, model} = Gemini.Models.get("gemini-2.0-flash")

      # Get model by full resource name
      {:ok, model} = Gemini.Models.get("models/gemini-1.5-pro")

      # Handle not found
      case Gemini.Models.get("invalid-model") do
        {:ok, model} -> IO.puts("Found: #{model.display_name}")
        {:error, %{type: :api_error, http_status: 404}} -> IO.puts("Model not found")
        {:error, error} -> IO.puts("Other error: #{error.message}")
      end

  ## API Reference

  Corresponds to the `models.get` endpoint:
  `GET https://generativelanguage.googleapis.com/v1beta/{name=models/*}`
  """
  @spec get(String.t()) :: {:ok, Model.t()} | {:error, Gemini.Error.t()}
  def get(model_name) when is_binary(model_name) and model_name != "" do
    # Normalize model name to full resource format
    full_name = normalize_model_name(model_name)

    # Validate model name format
    with :ok <- validate_model_name(full_name) do
      enhanced_opts = [function: :get_model, model: extract_base_model_id(full_name)]

      start_time = System.monotonic_time()

      case HTTP.get(full_name, enhanced_opts) do
        {:ok, response} ->
          result = parse_model_response(response)

          # Emit success telemetry
          duration = Telemetry.calculate_duration(start_time)
          Telemetry.execute(
            [:gemini, :models, :get, :success],
            %{duration: duration},
            %{model: extract_base_model_id(full_name)}
          )

          result

        {:error, error} ->
          # Emit error telemetry
          duration = Telemetry.calculate_duration(start_time)
          Telemetry.execute(
            [:gemini, :models, :get, :error],
            %{duration: duration},
            %{model: extract_base_model_id(full_name), error_type: error.type}
          )

          {:error, error}
      end
    end
  end

  def get("") do
    {:error, Error.validation_error("Model name cannot be empty")}
  end

  def get(_) do
    {:error, Error.validation_error("Model name must be a string")}
  end

  @doc """
  List all available model names as simple strings.

  This is a convenience function that extracts just the base model IDs
  from the full models list response.

  ## Returns

  - `{:ok, [String.t()]}` - List of base model IDs
  - `{:error, Gemini.Error.t()}` - API error

  ## Examples

      {:ok, names} = Gemini.Models.list_names()
      # => ["gemini-2.0-flash", "gemini-1.5-pro", "gemini-1.5-flash"]

      # Use with enum functions
      {:ok, names} = Gemini.Models.list_names()
      flash_models = Enum.filter(names, &String.contains?(&1, "flash"))
  """
  @spec list_names() :: {:ok, [String.t()]} | {:error, Gemini.Error.t()}
  def list_names do
    case list() do
      {:ok, %ListModelsResponse{models: models}} ->
        names =
          models
          |> Enum.map(fn model -> model.base_model_id || extract_base_model_id(model.name) end)
          |> Enum.uniq()
          |> Enum.sort()

        {:ok, names}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Check if a specific model exists and is available.

  ## Parameters

  - `model_name` - The model identifier to check

  ## Returns

  - `{:ok, true}` - Model exists and is available
  - `{:ok, false}` - Model does not exist
  - `{:error, Gemini.Error.t()}` - Network or other API error

  ## Examples

      {:ok, true} = Gemini.Models.exists?("gemini-2.0-flash")
      {:ok, false} = Gemini.Models.exists?("nonexistent-model")

      # Use in conditional logic
      case Gemini.Models.exists?("gemini-pro") do
        {:ok, true} -> generate_with_model("gemini-pro")
        {:ok, false} -> use_fallback_model()
        {:error, _} -> handle_api_error()
      end
  """
  @spec exists?(String.t()) :: {:ok, boolean()} | {:error, Gemini.Error.t()}
  def exists?(model_name) when is_binary(model_name) do
    case get(model_name) do
      {:ok, _model} ->
        {:ok, true}

      {:error, %Error{type: :api_error, http_status: 404}} ->
        {:ok, false}

      {:error, %Error{api_reason: 404}} ->
        {:ok, false}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Get models that support a specific generation method.

  ## Parameters

  - `method` - The generation method to filter by
    Examples: "generateContent", "streamGenerateContent", "countTokens"

  ## Returns

  - `{:ok, [Model.t()]}` - List of models supporting the method
  - `{:error, Gemini.Error.t()}` - API error

  ## Examples

      # Find streaming-capable models
      {:ok, streaming_models} = Gemini.Models.supporting_method("streamGenerateContent")

      # Find models that support content generation
      {:ok, generation_models} = Gemini.Models.supporting_method("generateContent")

      # Check capabilities
      {:ok, models} = Gemini.Models.supporting_method("countTokens")
      token_counting_available = length(models) > 0
  """
  @spec supporting_method(String.t()) :: {:ok, [Model.t()]} | {:error, Gemini.Error.t()}
  def supporting_method(method) when is_binary(method) and method != "" do
    case list() do
      {:ok, %ListModelsResponse{models: models}} ->
        supporting_models =
          models
          |> Enum.filter(fn model ->
            method in model.supported_generation_methods
          end)

        {:ok, supporting_models}

      {:error, error} ->
        {:error, error}
    end
  end

  def supporting_method("") do
    {:error, Error.validation_error("Generation method cannot be empty")}
  end

  def supporting_method(_) do
    {:error, Error.validation_error("Generation method must be a string")}
  end

  @doc """
  Get models filtered by capabilities or parameters.

  ## Parameters

  - `filter_opts` - Keyword list of filter criteria:
    - `:min_input_tokens` - Minimum input token limit
    - `:min_output_tokens` - Minimum output token limit
    - `:supports_methods` - List of required methods
    - `:has_temperature` - Boolean, requires temperature parameter
    - `:has_top_k` - Boolean, requires top_k parameter

  ## Returns

  - `{:ok, [Model.t()]}` - Filtered list of models
  - `{:error, Gemini.Error.t()}` - API error

  ## Examples

      # High-capacity models
      {:ok, large_models} = Gemini.Models.filter(min_input_tokens: 100_000)

      # Models with advanced parameters
      {:ok, tunable_models} = Gemini.Models.filter(has_temperature: true, has_top_k: true)

      # Multi-method support
      {:ok, versatile_models} = Gemini.Models.filter(
        supports_methods: ["generateContent", "streamGenerateContent"]
      )
  """
  @spec filter(keyword()) :: {:ok, [Model.t()]} | {:error, Gemini.Error.t()}
  def filter(filter_opts \\ []) do
    case list() do
      {:ok, %ListModelsResponse{models: models}} ->
        filtered_models =
          models
          |> Enum.filter(&model_matches_filter?(&1, filter_opts))

        {:ok, filtered_models}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Get comprehensive model statistics and summary.

  ## Returns

  - `{:ok, map()}` - Statistics about available models
  - `{:error, Gemini.Error.t()}` - API error

  ## Example Response

      {:ok, stats} = Gemini.Models.get_stats()
      # =>
      # %{
      #   total_models: 5,
      #   by_version: %{"1.5" => 3, "2.0" => 2},
      #   by_method: %{
      #     "generateContent" => 5,
      #     "streamGenerateContent" => 4,
      #     "countTokens" => 5
      #   },
      #   token_limits: %{
      #     max_input: 2_000_000,
      #     max_output: 8192,
      #     avg_input: 800_000,
      #     avg_output: 4096
      #   },
      #   capabilities: %{
      #     with_temperature: 5,
      #     with_top_k: 3,
      #     with_top_p: 5
      #   }
      # }
  """
  @spec get_stats() :: {:ok, map()} | {:error, Gemini.Error.t()}
  def get_stats do
    case list() do
      {:ok, %ListModelsResponse{models: models}} ->
        stats = %{
          total_models: length(models),
          by_version: count_by_version(models),
          by_method: count_by_methods(models),
          token_limits: calculate_token_stats(models),
          capabilities: count_capabilities(models),
          models_by_name: Enum.map(models, &{&1.base_model_id || extract_base_model_id(&1.name), &1.display_name})
        }

        {:ok, stats}

      {:error, error} ->
        {:error, error}
    end
  end

  # Private helper functions

  @spec validate_list_options(keyword()) :: :ok | {:error, Gemini.Error.t()}
  defp validate_list_options(opts) do
    with :ok <- validate_page_size(Keyword.get(opts, :page_size)),
         :ok <- validate_page_token(Keyword.get(opts, :page_token)) do
      :ok
    end
  end

  @spec validate_page_size(nil | integer()) :: :ok | {:error, Gemini.Error.t()}
  defp validate_page_size(nil), do: :ok
  defp validate_page_size(size) when is_integer(size) and size >= 1 and size <= 1000, do: :ok
  defp validate_page_size(size) when is_integer(size) do
    {:error, Error.validation_error("Page size must be between 1 and 1000, got: #{size}")}
  end
  defp validate_page_size(_) do
    {:error, Error.validation_error("Page size must be an integer")}
  end

  @spec validate_page_token(nil | String.t()) :: :ok | {:error, Gemini.Error.t()}
  defp validate_page_token(nil), do: :ok
  defp validate_page_token(token) when is_binary(token) and token != "", do: :ok
  defp validate_page_token("") do
    {:error, Error.validation_error("Page token cannot be empty string")}
  end
  defp validate_page_token(_) do
    {:error, Error.validation_error("Page token must be a string")}
  end

  @spec validate_model_name(String.t()) :: :ok | {:error, Gemini.Error.t()}
  defp validate_model_name(model_name) do
    if String.starts_with?(model_name, "models/") and String.length(model_name) > 7 do
      :ok
    else
      {:error, Error.validation_error("Invalid model name format: #{model_name}")}
    end
  end

  @spec normalize_model_name(String.t()) :: String.t()
  defp normalize_model_name(model_name) do
    if String.starts_with?(model_name, "models/") do
      model_name
    else
      "models/#{model_name}"
    end
  end

  @spec extract_base_model_id(String.t()) :: String.t()
  defp extract_base_model_id("models/" <> base_id), do: base_id
  defp extract_base_model_id(name), do: name

  @spec build_list_query_params(ListModelsRequest.t()) :: String.t()
  defp build_list_query_params(%ListModelsRequest{page_size: nil, page_token: nil}) do
    ""
  end

  defp build_list_query_params(%ListModelsRequest{page_size: page_size, page_token: page_token}) do
    params = []
    params = if page_size, do: [{"pageSize", page_size} | params], else: params
    params = if page_token, do: [{"pageToken", page_token} | params], else: params

    case params do
      [] -> ""
      _ -> "?" <> URI.encode_query(params)
    end
  end

  @spec parse_list_models_response(map()) :: {:ok, ListModelsResponse.t()} | {:error, Gemini.Error.t()}
  defp parse_list_models_response(response) do
    try do
      models =
        response
        |> Map.get("models", [])
        |> Enum.map(&parse_model_data/1)

      list_response = %ListModelsResponse{
        models: models,
        next_page_token: Map.get(response, "nextPageToken")
      }

      {:ok, list_response}
    rescue
      error ->
        Logger.error("Failed to parse models list response: #{inspect(error)}")
        {:error, Error.invalid_response("Failed to parse models response: #{inspect(error)}")}
    end
  end

  @spec parse_model_response(map()) :: {:ok, Model.t()} | {:error, Gemini.Error.t()}
  defp parse_model_response(response) do
    try do
      model = parse_model_data(response)
      {:ok, model}
    rescue
      error ->
        Logger.error("Failed to parse model response: #{inspect(error)}")
        {:error, Error.invalid_response("Failed to parse model response: #{inspect(error)}")}
    end
  end

  @spec parse_model_data(map()) :: Model.t()
  defp parse_model_data(model_data) do
    %Model{
      name: Map.get(model_data, "name", ""),
      base_model_id: Map.get(model_data, "baseModelId"),
      version: Map.get(model_data, "version", ""),
      display_name: Map.get(model_data, "displayName", ""),
      description: Map.get(model_data, "description", ""),
      input_token_limit: Map.get(model_data, "inputTokenLimit", 0),
      output_token_limit: Map.get(model_data, "outputTokenLimit", 0),
      supported_generation_methods: Map.get(model_data, "supportedGenerationMethods", []),
      temperature: Map.get(model_data, "temperature"),
      max_temperature: Map.get(model_data, "maxTemperature"),
      top_p: Map.get(model_data, "topP"),
      top_k: Map.get(model_data, "topK")
    }
  end

  @spec model_matches_filter?(Model.t(), keyword()) :: boolean()
  defp model_matches_filter?(model, filter_opts) do
    Enum.all?(filter_opts, fn {key, value} ->
      case key do
        :min_input_tokens -> model.input_token_limit >= value
        :min_output_tokens -> model.output_token_limit >= value
        :supports_methods when is_list(value) ->
          Enum.all?(value, &(&1 in model.supported_generation_methods))
        :has_temperature -> (value and not is_nil(model.temperature)) or (not value)
        :has_top_k -> (value and not is_nil(model.top_k)) or (not value)
        :has_top_p -> (value and not is_nil(model.top_p)) or (not value)
        _ -> true
      end
    end)
  end

  @spec count_by_version([Model.t()]) :: map()
  defp count_by_version(models) do
    models
    |> Enum.group_by(& &1.version)
    |> Enum.map(fn {version, models_list} -> {version, length(models_list)} end)
    |> Enum.into(%{})
  end

  @spec count_by_methods([Model.t()]) :: map()
  defp count_by_methods(models) do
    models
    |> Enum.flat_map(& &1.supported_generation_methods)
    |> Enum.frequencies()
  end

  @spec calculate_token_stats([Model.t()]) :: map()
  defp calculate_token_stats([]), do: %{max_input: 0, max_output: 0, avg_input: 0, avg_output: 0}
  defp calculate_token_stats(models) do
    input_limits = Enum.map(models, & &1.input_token_limit)
    output_limits = Enum.map(models, & &1.output_token_limit)

    %{
      max_input: Enum.max(input_limits),
      max_output: Enum.max(output_limits),
      avg_input: round(Enum.sum(input_limits) / length(input_limits)),
      avg_output: round(Enum.sum(output_limits) / length(output_limits))
    }
  end

  @spec count_capabilities([Model.t()]) :: map()
  defp count_capabilities(models) do
    %{
      with_temperature: Enum.count(models, &(not is_nil(&1.temperature))),
      with_top_k: Enum.count(models, &(not is_nil(&1.top_k))),
      with_top_p: Enum.count(models, &(not is_nil(&1.top_p))),
      with_max_temperature: Enum.count(models, &(not is_nil(&1.max_temperature)))
    }
  end
end
