defmodule Gemini do
  @moduledoc """
  Elixir client for Google's Gemini API - Phase 1 Implementation.

  This library provides a comprehensive interface to the Gemini API with
  a focus on the core functionality: Models, Content Generation, and Token Counting.

  ## Features

  - **Models API**: List, get, and query model capabilities
  - **Content Generation**: Text and multimodal content generation
  - **Streaming**: Real-time content generation with SSE
  - **Token Counting**: Accurate token counting for cost estimation
  - **Chat Sessions**: Multi-turn conversation management
  - **Error Handling**: Comprehensive error types and recovery
  - **Telemetry**: Built-in observability and metrics

  ## Quick Start

  First, configure your API key:

      config :gemini, api_key: "your_api_key_here"

  Or set the `GEMINI_API_KEY` environment variable.

  Then generate content:

      {:ok, response} = Gemini.generate("Hello, world!")
      {:ok, text} = Gemini.extract_text(response)
      IO.puts(text)

  ## Configuration

  - `:api_key` - Your Gemini API key (required)
  - `:default_model` - Default model to use (default: "gemini-2.0-flash")
  - `:timeout` - HTTP timeout in milliseconds (default: 30_000)
  - `:telemetry_enabled` - Enable telemetry events (default: true)

  ## Authentication

  The client supports multiple authentication methods:

      # Gemini API with API key
      Gemini.configure(:gemini, %{api_key: "your_api_key"})

      # Vertex AI with access token
      Gemini.configure(:vertex_ai, %{
        access_token: "your_token",
        project_id: "your-project",
        location: "us-central1"
      })

  """

  # Import the main API modules
  alias Gemini.APIs.{Models, Generate, Tokens}
  alias Gemini.{Config, Error}
  alias Gemini.Types.{Content, GenerationConfig, SafetySetting}
  alias Gemini.Types.Response.{GenerateContentResponse, Candidate, Model}
  alias Gemini.Streaming.ManagerV2

  @doc """
  Configure the client for a specific authentication type.

  ## Parameters
  - `auth_type` - Either `:gemini` or `:vertex_ai`
  - `credentials` - Map containing authentication credentials

  ## Examples

      # Configure for Gemini API
      Gemini.configure(:gemini, %{api_key: "your_api_key"})

      # Configure for Vertex AI with access token
      Gemini.configure(:vertex_ai, %{
        access_token: "your_token",
        project_id: "your-project",
        location: "us-central1"
      })

      # Configure for Vertex AI with service account
      Gemini.configure(:vertex_ai, %{
        service_account_key: "/path/to/key.json",
        project_id: "your-project",
        location: "us-central1"
      })
  """
  @spec configure(atom(), map()) :: :ok
  def configure(auth_type, credentials) do
    Application.put_env(:gemini, :auth, %{type: auth_type, credentials: credentials})
    :ok
  end

  @doc """
  Get the current authentication configuration.
  """
  @spec get_auth_config() :: map() | nil
  def get_auth_config do
    Config.auth_config()
  end

  # Content Generation API

  @doc """
  Generate content using the Gemini API.

  ## Parameters
  - `contents` - Content to generate from (string or list of Content structs)
  - `opts` - Options for generation (see `Generate.content/2`)

  ## Examples

      {:ok, response} = Gemini.generate("What is the capital of France?")
      {:ok, text} = Gemini.extract_text(response)
      # => "The capital of France is Paris."

      # With configuration
      config = GenerationConfig.creative()
      {:ok, response} = Gemini.generate("Write a poem", generation_config: config)

      # With multimodal content
      contents = [
        Content.text("What's in this image?"),
        Content.image("path/to/image.jpg")
      ]
      {:ok, response} = Gemini.generate(contents)

      # With safety settings
      safety = [SafetySetting.harassment(:block_only_high)]
      {:ok, response} = Gemini.generate("Tell me a story", safety_settings: safety)
  """
  @spec generate(String.t() | [Content.t()], keyword()) ::
          {:ok, GenerateContentResponse.t()} | {:error, Error.t()}
  def generate(contents, opts \\ []) do
    Generate.content(contents, opts)
  end

  @doc """
  Generate content with streaming support.

  Returns a list of partial responses as they become available.

  ## Examples

      {:ok, responses} = Gemini.stream_generate("Tell me a long story")
      
      # Process each streaming chunk
      Enum.each(responses, fn response ->
        case Gemini.extract_text(response) do
          {:ok, text} -> IO.write(text)
          {:error, _} -> :ok
        end
      end)
  """
  @spec stream_generate(String.t() | [Content.t()], keyword()) ::
          {:ok, [GenerateContentResponse.t()]} | {:error, Error.t()}
  def stream_generate(contents, opts \\ []) do
    Generate.stream_content(contents, opts)
  end

  @doc """
  Start a managed streaming session using GenServer.

  Returns a stream ID that can be used to subscribe to events.

  ## Examples

      {:ok, stream_id} = Gemini.start_stream("Write a long story")
      :ok = Gemini.subscribe_stream(stream_id)

      # Receive messages:
      # {:stream_event, stream_id, event}
      # {:stream_complete, stream_id}
      # {:stream_error, stream_id, error}
  """
  @spec start_stream(String.t() | [Content.t()], keyword()) ::
          {:ok, String.t()} | {:error, Error.t()}
  def start_stream(contents, opts \\ []) do
    ManagerV2.start_stream(contents, opts, self())
  end

  @doc """
  Subscribe to events from a streaming session.
  """
  @spec subscribe_stream(String.t(), pid()) :: :ok | {:error, Error.t()}
  def subscribe_stream(stream_id, subscriber_pid \\ self()) do
    ManagerV2.subscribe_stream(stream_id, subscriber_pid)
  end

  @doc """
  Unsubscribe from a streaming session.
  """
  @spec unsubscribe_stream(String.t(), pid()) :: :ok | {:error, Error.t()}
  def unsubscribe_stream(stream_id, subscriber_pid \\ self()) do
    ManagerV2.unsubscribe_stream(stream_id, subscriber_pid)
  end

  @doc """
  Stop a streaming session.
  """
  @spec stop_stream(String.t()) :: :ok | {:error, Error.t()}
  def stop_stream(stream_id) do
    ManagerV2.stop_stream(stream_id)
  end

  @doc """
  Get the status of a streaming session.
  """
  @spec get_stream_status(String.t()) :: {:ok, map()} | {:error, Error.t()}
  def get_stream_status(stream_id) do
    ManagerV2.get_stream_info(stream_id)
  end

  @doc """
  List all active streaming sessions.
  """
  @spec list_streams() :: [String.t()]
  def list_streams do
    ManagerV2.list_streams()
  end

  @doc """
  Generate text content and return only the text.

  This is a convenience function for simple text generation.

  ## Examples

      {:ok, text} = Gemini.text("What is 2+2?")
      # => "2 + 2 = 4"

      {:ok, poem} = Gemini.text("Write a haiku about coding",
        generation_config: GenerationConfig.creative())
  """
  @spec text(String.t() | [Content.t()], keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def text(contents, opts \\ []) do
    Generate.text(contents, opts)
  end

  # Chat API

  @doc """
  Start a new chat session.

  ## Examples

      {:ok, chat} = Gemini.chat()
      {:ok, response, chat} = Gemini.send_message(chat, "Hello!")

      # With configuration
      config = GenerationConfig.balanced()
      {:ok, chat} = Gemini.chat(generation_config: config)

      # With system instruction
      {:ok, chat} = Gemini.chat(
        system_instruction: "You are a helpful coding assistant."
      )
  """
  @spec chat(keyword()) :: {:ok, map()}
  def chat(opts \\ []) do
    Generate.chat(opts)
  end

  @doc """
  Send a message in a chat session.

  ## Examples

      {:ok, chat} = Gemini.chat()
      {:ok, response, chat} = Gemini.send_message(chat, "Hello!")
      {:ok, text} = Gemini.extract_text(response)
      IO.puts("Assistant: #{text}")

      # Continue conversation
      {:ok, response, chat} = Gemini.send_message(chat, "Tell me a joke")
  """
  @spec send_message(map(), String.t() | Content.t()) ::
          {:ok, GenerateContentResponse.t(), map()} | {:error, Error.t()}
  def send_message(chat, message) do
    Generate.send_message(chat, message)
  end

  # Token Counting API

  @doc """
  Count tokens in the given content.

  ## Examples

      {:ok, response} = Gemini.count_tokens("Hello, world!")
      total_tokens = response.total_tokens

      # For multimodal content
      contents = [
        Content.text("What's in this image?"),
        Content.image("path/to/image.jpg")
      ]
      {:ok, response} = Gemini.count_tokens(contents)

      # With specific model
      {:ok, response} = Gemini.count_tokens("Hello", model: "gemini-1.5-pro")
  """
  @spec count_tokens(String.t() | [Content.t()], keyword()) ::
          {:ok, Tokens.CountTokensResponse.t()} | {:error, Error.t()}
  def count_tokens(contents, opts \\ []) do
    Tokens.count(contents, opts)
  end

  @doc """
  Estimate tokens for content without making an API call.

  ## Examples

      {:ok, estimate} = Gemini.estimate_tokens("Hello, world!")
      # => {:ok, 3}
  """
  @spec estimate_tokens(String.t() | [Content.t()], keyword()) ::
          {:ok, integer()} | {:error, Error.t()}
  def estimate_tokens(content, opts \\ []) do
    Tokens.estimate(content, opts)
  end

  @doc """
  Check if content fits within a model's token limit.

  ## Examples

      {:ok, analysis} = Gemini.check_token_fit("Hello world", "gemini-2.0-flash")
      # => {:ok, %{fits: true, tokens: 3, limit: 1000000, remaining: 999997}}
  """
  @spec check_token_fit(String.t() | [Content.t()], String.t() | nil, keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def check_token_fit(content, model_name \\ nil, opts \\ []) do
    Tokens.check_fit(content, model_name, opts)
  end

  # Model Management API

  @doc """
  List available Gemini models.

  ## Examples

      {:ok, models_response} = Gemini.list_models()
      model_names = Enum.map(models_response.models, &Model.effective_base_id/1)

      # With pagination
      {:ok, page1} = Gemini.list_models(page_size: 10)
      {:ok, page2} = Gemini.list_models(page_size: 10, page_token: page1.next_page_token)
  """
  @spec list_models(keyword()) :: {:ok, Models.ListModelsResponse.t()} | {:error, Error.t()}
  def list_models(opts \\ []) do
    Models.list(opts)
  end

  @doc """
  Get information about a specific model.

  ## Examples

      {:ok, model} = Gemini.get_model("gemini-2.0-flash")
      IO.puts("Model: #{model.display_name}")
      IO.puts("Input limit: #{model.input_token_limit}")
  """
  @spec get_model(String.t()) :: {:ok, Model.t()} | {:error, Error.t()}
  def get_model(model_name) do
    Models.get(model_name)
  end

  @doc """
  List available model names.

  ## Examples

      {:ok, names} = Gemini.list_model_names()
      # => {:ok, ["gemini-2.0-flash", "gemini-1.5-pro", ...]}
  """
  @spec list_model_names() :: {:ok, [String.t()]} | {:error, Error.t()}
  def list_model_names do
    Models.list_names()
  end

  @doc """
  Check if a model exists.

  ## Examples

      {:ok, true} = Gemini.model_exists?("gemini-2.0-flash")
      {:ok, false} = Gemini.model_exists?("invalid-model")
  """
  @spec model_exists?(String.t()) :: {:ok, boolean()} | {:error, Error.t()}
  def model_exists?(model_name) do
    Models.exists?(model_name)
  end

  @doc """
  Get models that support a specific capability.

  ## Examples

      # Find streaming-capable models
      {:ok, streaming_models} = Gemini.models_supporting("streamGenerateContent")

      # Find models with high input capacity
      {:ok, large_models} = Gemini.filter_models(min_input_tokens: 1_000_000)
  """
  @spec models_supporting(String.t()) :: {:ok, [Model.t()]} | {:error, Error.t()}
  def models_supporting(method) do
    Models.supporting_method(method)
  end

  @doc """
  Filter models by capabilities.

  ## Examples

      # High-capacity models
      {:ok, large_models} = Gemini.filter_models(min_input_tokens: 100_000)

      # Production-ready streaming models
      {:ok, prod_models} = Gemini.filter_models(
        supports_methods: ["generateContent", "streamGenerateContent"],
        production_ready: true
      )

      # Models with advanced parameters
      {:ok, tunable_models} = Gemini.filter_models(
        has_temperature: true,
        has_top_k: true
      )
  """
  @spec filter_models(keyword()) :: {:ok, [Model.t()]} | {:error, Error.t()}
  def filter_models(filter_opts) do
    Models.filter(filter_opts)
  end

  @doc """
  Get comprehensive model statistics.

  ## Examples

      {:ok, stats} = Gemini.get_model_stats()
      IO.puts("Total models: #{stats.total_models}")
      IO.puts("Streaming support: #{stats.capabilities.supports_streaming}")
  """
  @spec get_model_stats() :: {:ok, map()} | {:error, Error.t()}
  def get_model_stats do
    Models.get_stats()
  end

  # Utility Functions

  @doc """
  Extract text from a GenerateContentResponse.

  Returns the text from the first candidate's first text part.

  ## Examples

      {:ok, response} = Gemini.generate("Hello")
      {:ok, text} = Gemini.extract_text(response)
      # => "Hello! How can I help you today?"

      # Handle errors gracefully
      case Gemini.extract_text(response) do
        {:ok, text} -> IO.puts(text)
        {:error, reason} -> IO.puts("No text found: #{reason}")
      end
  """
  @spec extract_text(GenerateContentResponse.t()) :: {:ok, String.t()} | {:error, String.t()}
  def extract_text(%GenerateContentResponse{} = response) do
    GenerateContentResponse.extract_text(response)
  end

  @doc """
  Extract all text parts from a GenerateContentResponse.

  Returns a list of all text strings from all candidates.

  ## Examples

      {:ok, response} = Gemini.generate("Hello")
      texts = Gemini.extract_all_text(response)
      # => ["Hello! How can I help you today?"]

      # Combine all text
      combined_text = Enum.join(texts, " ")
  """
  @spec extract_all_text(GenerateContentResponse.t()) :: [String.t()]
  def extract_all_text(%GenerateContentResponse{} = response) do
    GenerateContentResponse.extract_all_text(response)
  end

  @doc """
  Create a multimodal prompt with text and images.

  ## Examples

      prompt = Gemini.multimodal_prompt(
        "What's in these images?",
        ["image1.jpg", "image2.png"]
      )
      {:ok, response} = Gemini.generate(prompt)

      # Single image
      prompt = Gemini.multimodal_prompt("Describe this image", ["photo.jpg"])
      {:ok, response} = Gemini.generate(prompt)
  """
  @spec multimodal_prompt(String.t(), [String.t()]) :: [Content.t()]
  def multimodal_prompt(text, image_paths) when is_list(image_paths) do
    image_contents = Enum.map(image_paths, &Content.image/1)
    [Content.text(text)] ++ image_contents
  end

  @doc """
  Generate content with system instruction.

  Convenience function for adding system instructions to generation requests.

  ## Examples

      {:ok, response} = Gemini.with_system_instruction(
        "What is the capital of France?",
        "You are a helpful geography teacher. Be concise and educational."
      )

      # With additional options
      {:ok, response} = Gemini.with_system_instruction(
        "Explain quantum physics",
        "You are a physics professor",
        generation_config: GenerationConfig.precise()
      )
  """
  @spec with_system_instruction(String.t() | [Content.t()], String.t(), keyword()) ::
          {:ok, GenerateContentResponse.t()} | {:error, Error.t()}
  def with_system_instruction(contents, instruction, opts \\ []) do
    updated_opts = Keyword.put(opts, :system_instruction, instruction)
    generate(contents, updated_opts)
  end

  # Batch Operations

  @doc """
  Generate content for multiple inputs in parallel.

  ## Examples

      inputs = [
        "What is AI?",
        "Explain machine learning",
        "Define neural networks"
      ]
      
      {:ok, responses} = Gemini.generate_batch(inputs)
      
      # Process results
      Enum.zip(inputs, responses)
      |> Enum.each(fn {input, response} ->
        {:ok, text} = Gemini.extract_text(response)
        IO.puts("Q: #{input}")
        IO.puts("A: #{text}\n")
      end)
  """
  @spec generate_batch([String.t() | [Content.t()]], keyword()) ::
          {:ok, [GenerateContentResponse.t()]} | {:error, Error.t()}
  def generate_batch(inputs, opts \\ []) when is_list(inputs) do
    max_concurrency = Keyword.get(opts, :max_concurrency, 5)
    timeout = Keyword.get(opts, :timeout, 30_000)

    try do
      results =
        inputs
        |> Task.async_stream(
          fn input -> generate(input, opts) end,
          max_concurrency: max_concurrency,
          timeout: timeout,
          on_timeout: :kill_task
        )
        |> Enum.map(fn
          {:ok, {:ok, result}} -> result
          {:ok, {:error, error}} -> throw({:batch_error, error})
          {:exit, reason} -> throw({:batch_error, Error.network_error("Task failed: #{inspect(reason)}")})
        end)

      {:ok, results}
    catch
      {:batch_error, error} -> {:error, error}
    end
  end

  # Configuration and Status

  @doc """
  Validate the current configuration.

  Checks that all required configuration is present and valid.

  ## Examples

      case Gemini.validate_config() do
        :ok -> IO.puts("Configuration is valid")
        {:error, reason} -> IO.puts("Configuration error: #{reason}")
      end
  """
  @spec validate_config() :: :ok | {:error, String.t()}
  def validate_config do
    try do
      Config.validate!()
      :ok
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  @doc """
  Get current configuration summary.

  Returns a summary of the current configuration without sensitive data.

  ## Examples

      config = Gemini.get_config_summary()
      # => %{
      #   auth_type: :gemini,
      #   default_model: "gemini-2.0-flash",
      #   timeout: 30000,
      #   telemetry_enabled: true
      # }
  """
  @spec get_config_summary() :: map()
  def get_config_summary do
    auth_config = Config.auth_config()
    
    %{
      auth_type: if(auth_config, do: auth_config.type, else: nil),
      default_model: Config.default_model(),
      timeout: Config.timeout(),
      telemetry_enabled: Config.telemetry_enabled?(),
      base_url: if(auth_config, do: mask_sensitive_url(Config.base_url()), else: nil)
    }
  end

  @doc """
  Check API connectivity and authentication.

  Performs a simple API call to verify that the client can connect
  to the API and authenticate successfully.

  ## Examples

      case Gemini.health_check() do
        :ok -> IO.puts("API is accessible")
        {:error, error} -> IO.puts("Health check failed: #{Error.format(error)}")
      end
  """
  @spec health_check() :: :ok | {:error, Error.t()}
  def health_check do
    case list_models(page_size: 1) do
      {:ok, %{models: [_model | _]}} -> :ok
      {:ok, %{models: []}} -> {:error, Error.api_error(200, "No models available")}
      {:error, error} -> {:error, error}
    end
  end

  # Error Handling Helpers

  @doc """
  Check if an error is retryable.

  ## Examples

      case Gemini.generate("Hello") do
        {:ok, response} -> process_response(response)
        {:error, error} ->
          if Gemini.retryable_error?(error) do
            # Implement retry logic
            retry_request()
          else
            handle_permanent_error(error)
          end
      end
  """
  @spec retryable_error?(Error.t()) :: boolean()
  def retryable_error?(%Error{} = error) do
    Error.retryable?(error)
  end

  @doc """
  Get suggested retry delay for an error.

  Returns the suggested delay in milliseconds, or nil if not retryable.

  ## Examples

      case Gemini.generate("Hello") do
        {:error, error} ->
          case Gemini.retry_delay(error) do
            nil -> handle_permanent_error(error)
            delay -> 
              Process.sleep(delay)
              retry_request()
          end
      end
  """
  @spec retry_delay(Error.t()) :: integer() | nil
  def retry_delay(%Error{} = error) do
    Error.retry_delay(error)
  end

  @doc """
  Format an error for user display.

  ## Examples

      case Gemini.generate("Hello") do
        {:error, error} ->
          formatted = Gemini.format_error(error)
          IO.puts("Error: #{formatted}")
      end
  """
  @spec format_error(Error.t()) :: String.t()
  def format_error(%Error{} = error) do
    Error.format(error)
  end

  # Development and Debugging Helpers

  @doc """
  Enable debug logging for requests.

  Useful for development and troubleshooting.

  ## Examples

      Gemini.enable_debug_logging()
      {:ok, response} = Gemini.generate("Hello")  # Will log request details
      Gemini.disable_debug_logging()
  """
  @spec enable_debug_logging() :: :ok
  def enable_debug_logging do
    Logger.put_module_level(__MODULE__, :debug)
    :ok
  end

  @doc """
  Disable debug logging.
  """
  @spec disable_debug_logging() :: :ok
  def disable_debug_logging do
    Logger.delete_module_level(__MODULE__)
    :ok
  end

  @doc """
  Get library version information.

  ## Examples

      version_info = Gemini.version_info()
      # => %{version: "1.0.0", build_date: "2024-01-01", features: [...]}
  """
  @spec version_info() :: map()
  def version_info do
    %{
      version: Application.spec(:gemini, :vsn) |> to_string(),
      phase: "Phase 1 - Core APIs",
      features: [
        "Models API",
        "Content Generation",
        "Streaming Support", 
        "Token Counting",
        "Chat Sessions",
        "Error Handling",
        "Telemetry"
      ],
      supported_apis: [
        "models.list",
        "models.get", 
        "models.generateContent",
        "models.streamGenerateContent",
        "models.countTokens"
      ]
    }
  end

  # Private helper functions

  @spec mask_sensitive_url(String.t()) :: String.t()
  defp mask_sensitive_url(url) when is_binary(url) do
    # Remove API keys or sensitive parameters from URL for logging
    String.replace(url, ~r/[?&]key=[^&]+/, "?key=***")
  end
  defp mask_sensitive_url(_), do: "unknown"
end
