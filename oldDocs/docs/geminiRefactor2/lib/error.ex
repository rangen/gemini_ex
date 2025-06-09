defmodule Gemini.Error do
  @moduledoc """
  Comprehensive error handling system for the Gemini client.

  Provides structured error types with detailed context, recovery suggestions,
  and proper categorization for different types of failures.

  ## Error Types

  - `:api_error` - API responded with an error status
  - `:network_error` - Network or connection failures
  - `:config_error` - Configuration or authentication issues
  - `:validation_error` - Input validation failures
  - `:serialization_error` - JSON encoding/decoding issues
  - `:invalid_response` - Unexpected response format
  - `:rate_limit_error` - Rate limiting by the API
  - `:quota_exceeded` - API quota exhaustion
  - `:model_error` - Model-specific issues
  - `:safety_error` - Content safety violations
  - `:timeout_error` - Request timeouts

  ## Examples

      # API error with specific details
      error = Error.api_error(404, "Model not found", %{model: "invalid-model"})

      # Network error with recovery suggestion
      error = Error.network_error("Connection timeout", retry: true)

      # Validation error with field details
      error = Error.validation_error("Invalid page size", field: :page_size, value: 2000)

      # Check error types
      Error.retryable?(error)  # => true/false
      Error.client_error?(error)  # => true/false
      Error.server_error?(error)  # => true/false
  """

  use TypedStruct

  @typedoc "Error type categories"
  @type error_type ::
          :api_error
          | :network_error
          | :config_error
          | :validation_error
          | :serialization_error
          | :invalid_response
          | :rate_limit_error
          | :quota_exceeded
          | :model_error
          | :safety_error
          | :timeout_error

  @typedoc "HTTP status codes"
  @type http_status :: integer() | nil

  @typedoc "Error severity levels"
  @type severity :: :low | :medium | :high | :critical

  typedstruct do
    field(:type, error_type(), enforce: true)
    field(:message, String.t(), enforce: true)
    field(:http_status, http_status(), default: nil)
    field(:api_reason, String.t() | nil, default: nil)
    field(:details, map(), default: %{})
    field(:original_error, term() | nil, default: nil)
    field(:retryable, boolean(), default: false)
    field(:severity, severity(), default: :medium)
    field(:suggestions, [String.t()], default: [])
    field(:context, map(), default: %{})
  end

  @doc """
  Create a generic error with type and message.

  ## Examples

      iex> Error.new(:validation_error, "Invalid input")
      %Error{type: :validation_error, message: "Invalid input", ...}
  """
  @spec new(error_type(), String.t(), keyword()) :: t()
  def new(type, message, opts \\ []) do
    struct!(__MODULE__, [{:type, type}, {:message, message} | opts])
  end

  @doc """
  Create an API error from HTTP response.

  ## Parameters
  - `status` - HTTP status code
  - `message` - Error message
  - `details` - Additional error details from API response

  ## Examples

      iex> Error.api_error(404, "Model not found")
      %Error{type: :api_error, http_status: 404, ...}

      iex> Error.api_error(429, "Rate limit exceeded", %{retry_after: 60})
      %Error{type: :rate_limit_error, http_status: 429, ...}
  """
  @spec api_error(integer(), String.t(), map()) :: t()
  def api_error(status, message, details \\ %{}) do
    {error_type, retryable, severity, suggestions} = classify_api_error(status, details)

    %__MODULE__{
      type: error_type,
      message: message,
      http_status: status,
      api_reason: Map.get(details, "code"),
      details: details,
      retryable: retryable,
      severity: severity,
      suggestions: suggestions
    }
  end

  @doc """
  Create a network error.

  ## Examples

      iex> Error.network_error("Connection timeout")
      %Error{type: :network_error, retryable: true, ...}

      iex> Error.network_error("DNS resolution failed", retryable: false)
      %Error{type: :network_error, retryable: false, ...}
  """
  @spec network_error(String.t(), keyword()) :: t()
  def network_error(message, opts \\ []) do
    retryable = Keyword.get(opts, :retryable, true)
    original_error = Keyword.get(opts, :original_error)

    suggestions = if retryable do
      ["Check your internet connection", "Retry the request", "Verify API endpoint URL"]
    else
      ["Check your network configuration", "Contact support if the issue persists"]
    end

    %__MODULE__{
      type: :network_error,
      message: message,
      original_error: original_error,
      retryable: retryable,
      severity: :medium,
      suggestions: suggestions
    }
  end

  @doc """
  Create a configuration error.

  ## Examples

      iex> Error.config_error("API key is missing")
      %Error{type: :config_error, severity: :high, ...}

      iex> Error.config_error("Invalid project ID", field: :project_id)
      %Error{type: :config_error, details: %{field: :project_id}, ...}
  """
  @spec config_error(String.t(), keyword()) :: t()
  def config_error(message, opts \\ []) do
    details = Keyword.take(opts, [:field, :value, :expected])

    suggestions = [
      "Check your configuration settings",
      "Verify environment variables",
      "Review authentication setup"
    ]

    %__MODULE__{
      type: :config_error,
      message: message,
      details: Map.new(details),
      retryable: false,
      severity: :high,
      suggestions: suggestions
    }
  end

  @doc """
  Create a validation error.

  ## Examples

      iex> Error.validation_error("Page size must be between 1 and 1000")
      %Error{type: :validation_error, ...}

      iex> Error.validation_error("Invalid model name", field: :model, value: "")
      %Error{type: :validation_error, details: %{field: :model, value: ""}, ...}
  """
  @spec validation_error(String.t(), keyword()) :: t()
  def validation_error(message, opts \\ []) do
    details = Keyword.take(opts, [:field, :value, :constraint, :allowed_values])

    suggestions = [
      "Check the parameter documentation",
      "Verify input format and constraints",
      "Use valid parameter values"
    ]

    %__MODULE__{
      type: :validation_error,
      message: message,
      details: Map.new(details),
      retryable: false,
      severity: :low,
      suggestions: suggestions
    }
  end

  @doc """
  Create a serialization error.

  ## Examples

      iex> Error.serialization_error("Invalid JSON format")
      %Error{type: :serialization_error, ...}
  """
  @spec serialization_error(String.t(), keyword()) :: t()
  def serialization_error(message, opts \\ []) do
    original_error = Keyword.get(opts, :original_error)

    %__MODULE__{
      type: :serialization_error,
      message: message,
      original_error: original_error,
      retryable: false,
      severity: :medium,
      suggestions: ["Check data format", "Verify JSON structure"]
    }
  end

  @doc """
  Create an invalid response error.

  ## Examples

      iex> Error.invalid_response("Unexpected response format")
      %Error{type: :invalid_response, ...}
  """
  @spec invalid_response(String.t(), keyword()) :: t()
  def invalid_response(message, opts \\ []) do
    details = Keyword.get(opts, :details, %{})

    %__MODULE__{
      type: :invalid_response,
      message: message,
      details: details,
      retryable: true,
      severity: :medium,
      suggestions: ["Retry the request", "Check API version compatibility"]
    }
  end

  @doc """
  Create a rate limit error.

  ## Examples

      iex> Error.rate_limit_error("Rate limit exceeded", retry_after: 60)
      %Error{type: :rate_limit_error, details: %{retry_after: 60}, ...}
  """
  @spec rate_limit_error(String.t(), keyword()) :: t()
  def rate_limit_error(message, opts \\ []) do
    retry_after = Keyword.get(opts, :retry_after)
    details = if retry_after, do: %{retry_after: retry_after}, else: %{}

    suggestions = if retry_after do
      ["Wait #{retry_after} seconds before retrying", "Implement exponential backoff"]
    else
      ["Reduce request frequency", "Implement rate limiting", "Wait before retrying"]
    end

    %__MODULE__{
      type: :rate_limit_error,
      message: message,
      http_status: 429,
      details: details,
      retryable: true,
      severity: :medium,
      suggestions: suggestions
    }
  end

  @doc """
  Create a quota exceeded error.

  ## Examples

      iex> Error.quota_exceeded("Monthly quota exceeded")
      %Error{type: :quota_exceeded, retryable: false, ...}
  """
  @spec quota_exceeded(String.t(), keyword()) :: t()
  def quota_exceeded(message, opts \\ []) do
    details = Keyword.get(opts, :details, %{})

    %__MODULE__{
      type: :quota_exceeded,
      message: message,
      http_status: 429,
      details: details,
      retryable: false,
      severity: :high,
      suggestions: [
        "Check your quota limits",
        "Wait for quota reset",
        "Upgrade your plan if needed"
      ]
    }
  end

  @doc """
  Create a model-specific error.

  ## Examples

      iex> Error.model_error("Model does not support streaming", model: "text-embedding")
      %Error{type: :model_error, details: %{model: "text-embedding"}, ...}
  """
  @spec model_error(String.t(), keyword()) :: t()
  def model_error(message, opts \\ []) do
    model = Keyword.get(opts, :model)
    details = if model, do: %{model: model}, else: %{}

    %__MODULE__{
      type: :model_error,
      message: message,
      details: details,
      retryable: false,
      severity: :medium,
      suggestions: [
        "Check model capabilities",
        "Use a compatible model",
        "Review model documentation"
      ]
    }
  end

  @doc """
  Create a safety error.

  ## Examples

      iex> Error.safety_error("Content violates safety policies")
      %Error{type: :safety_error, ...}
  """
  @spec safety_error(String.t(), keyword()) :: t()
  def safety_error(message, opts \\ []) do
    details = Keyword.get(opts, :details, %{})

    %__MODULE__{
      type: :safety_error,
      message: message,
      details: details,
      retryable: false,
      severity: :medium,
      suggestions: [
        "Review content guidelines",
        "Modify the input content",
        "Adjust safety settings if appropriate"
      ]
    }
  end

  @doc """
  Create a timeout error.

  ## Examples

      iex> Error.timeout_error("Request timed out after 30 seconds")
      %Error{type: :timeout_error, retryable: true, ...}
  """
  @spec timeout_error(String.t(), keyword()) :: t()
  def timeout_error(message, opts \\ []) do
    timeout_duration = Keyword.get(opts, :timeout)
    details = if timeout_duration, do: %{timeout: timeout_duration}, else: %{}

    %__MODULE__{
      type: :timeout_error,
      message: message,
      details: details,
      retryable: true,
      severity: :medium,
      suggestions: [
        "Increase request timeout",
        "Retry the request",
        "Break down large requests"
      ]
    }
  end

  # Error classification and utility functions

  @doc """
  Check if an error is retryable.

  ## Examples

      iex> Error.retryable?(network_error)
      true

      iex> Error.retryable?(validation_error)
      false
  """
  @spec retryable?(t()) :: boolean()
  def retryable?(%__MODULE__{retryable: retryable}), do: retryable

  @doc """
  Check if an error is a client error (4xx HTTP status).
  """
  @spec client_error?(t()) :: boolean()
  def client_error?(%__MODULE__{http_status: status}) when status in 400..499, do: true
  def client_error?(%__MODULE__{type: type}) when type in [:validation_error, :config_error], do: true
  def client_error?(%__MODULE__{}), do: false

  @doc """
  Check if an error is a server error (5xx HTTP status).
  """
  @spec server_error?(t()) :: boolean()
  def server_error?(%__MODULE__{http_status: status}) when status in 500..599, do: true
  def server_error?(%__MODULE__{type: :network_error}), do: true
  def server_error?(%__MODULE__{}), do: false

  @doc """
  Get the appropriate retry delay for an error.

  Returns the suggested delay in milliseconds, or nil if not retryable.

  ## Examples

      iex> Error.retry_delay(rate_limit_error)
      60000  # 60 seconds

      iex> Error.retry_delay(network_error)
      1000   # 1 second

      iex> Error.retry_delay(validation_error)
      nil    # Not retryable
  """
  @spec retry_delay(t()) :: integer() | nil
  def retry_delay(%__MODULE__{retryable: false}), do: nil
  def retry_delay(%__MODULE__{type: :rate_limit_error, details: %{retry_after: seconds}}) do
    seconds * 1000
  end
  def retry_delay(%__MODULE__{type: :timeout_error}), do: 2000
  def retry_delay(%__MODULE__{type: :network_error}), do: 1000
  def retry_delay(%__MODULE__{retryable: true}), do: 500

  @doc """
  Format error for user display.

  ## Examples

      iex> Error.format(error)
      "API Error (404): Model not found. Suggestions: Check model name, verify model availability."
  """
  @spec format(t()) :: String.t()
  def format(%__MODULE__{} = error) do
    base_message = case error.http_status do
      nil -> "#{format_type(error.type)}: #{error.message}"
      status -> "#{format_type(error.type)} (#{status}): #{error.message}"
    end

    suggestion_text = case error.suggestions do
      [] -> ""
      suggestions -> ". Suggestions: " <> Enum.join(suggestions, ", ") <> "."
    end

    base_message <> suggestion_text
  end

  @doc """
  Format error for logging with full context.

  ## Examples

      iex> Error.format_for_logging(error)
      "[API_ERROR] Model not found (404) - Details: %{model: \"invalid\"} - Context: %{api: :models}"
  """
  @spec format_for_logging(t()) :: String.t()
  def format_for_logging(%__MODULE__{} = error) do
    type_str = error.type |> Atom.to_string() |> String.upcase()
    
    status_str = case error.http_status do
      nil -> ""
      status -> " (#{status})"
    end

    details_str = case map_size(error.details) do
      0 -> ""
      _ -> " - Details: #{inspect(error.details)}"
    end

    context_str = case map_size(error.context) do
      0 -> ""
      _ -> " - Context: #{inspect(error.context)}"
    end

    "[#{type_str}] #{error.message}#{status_str}#{details_str}#{context_str}"
  end

  @doc """
  Add context to an error.

  ## Examples

      iex> error |> Error.add_context(api: :models, operation: :get)
      %Error{context: %{api: :models, operation: :get}, ...}
  """
  @spec add_context(t(), keyword() | map()) :: t()
  def add_context(%__MODULE__{} = error, context) when is_list(context) do
    add_context(error, Map.new(context))
  end

  def add_context(%__MODULE__{context: existing_context} = error, context) when is_map(context) do
    %{error | context: Map.merge(existing_context, context)}
  end

  # Private helper functions

  @spec classify_api_error(integer(), map()) :: {error_type(), boolean(), severity(), [String.t()]}
  defp classify_api_error(status, details) do
    case status do
      400 ->
        {:validation_error, false, :low, ["Check request format", "Verify parameters"]}

      401 ->
        {:config_error, false, :high, ["Check API key", "Verify authentication"]}

      403 ->
        {:config_error, false, :high, ["Check permissions", "Verify project access"]}

      404 ->
        {:api_error, false, :medium, ["Check resource name", "Verify resource exists"]}

      429 ->
        case Map.get(details, "reason") do
          "RATE_LIMIT_EXCEEDED" ->
            {:rate_limit_error, true, :medium, ["Reduce request rate", "Implement backoff"]}
          
          "QUOTA_EXCEEDED" ->
            {:quota_exceeded, false, :high, ["Check quota limits", "Upgrade plan"]}
          
          _ ->
            {:rate_limit_error, true, :medium, ["Wait before retrying"]}
        end

      status when status in 500..599 ->
        {:api_error, true, :high, ["Retry the request", "Check service status"]}

      _ ->
        {:api_error, false, :medium, ["Check API documentation"]}
    end
  end

  @spec format_type(error_type()) :: String.t()
  defp format_type(:api_error), do: "API Error"
  defp format_type(:network_error), do: "Network Error"
  defp format_type(:config_error), do: "Configuration Error"
  defp format_type(:validation_error), do: "Validation Error"
  defp format_type(:serialization_error), do: "Serialization Error"
  defp format_type(:invalid_response), do: "Invalid Response"
  defp format_type(:rate_limit_error), do: "Rate Limit Error"
  defp format_type(:quota_exceeded), do: "Quota Exceeded"
  defp format_type(:model_error), do: "Model Error"
  defp format_type(:safety_error), do: "Safety Error"
  defp format_type(:timeout_error), do: "Timeout Error"
end

# Exception implementation for interoperability
defimpl Exception, for: Gemini.Error do
  def exception(%Gemini.Error{} = error) do
    error
  end

  def message(%Gemini.Error{} = error) do
    Gemini.Error.format(error)
  end
end
