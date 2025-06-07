defmodule Gemini do
  @moduledoc """
  Elixir client for Google's Gemini API.

  This library provides a comprehensive interface to the Gemini API, including:
  - Content generation (text and multimodal)
  - Streaming responses
  - Model management
  - Chat sessions
  - Token counting

  ## Quick Start

  First, configure your API key:

      config :gemini, api_key: "your_api_key_here"

  Or set the `GEMINI_API_KEY` environment variable.

  Then generate content:

      {:ok, response} = Gemini.generate("Hello, world!")
      text = Gemini.extract_text(response)

  ## Configuration

  - `:api_key` - Your Gemini API key (required)
  - `:base_url` - API base URL (default: Google's production URL)
  - `:default_model` - Default model to use (default: "gemini-2.0-flash")
  - `:timeout` - HTTP timeout in milliseconds (default: 30_000)

  """

  alias Gemini.{Generate, Models}
  alias Gemini.{Config, Auth}
  alias Gemini.Types.{Content, Part, GenerationConfig, SafetySetting}
  alias Gemini.Types.Response.{GenerateContentResponse, Candidate}
  alias Gemini.Client.HTTP
  alias Gemini.Streaming.Manager

  @doc """
  Start the Gemini client.

  This starts the underlying HTTP client pool and streaming manager.
  """
  def start_link do
    with {:ok, _http} <- HTTP.start_link(),
         {:ok, _stream} <- Manager.start_link() do
      {:ok, :started}
    end
  end

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
  def configure(auth_type, credentials) do
    Application.put_env(:gemini, :auth, %{type: auth_type, credentials: credentials})
    :ok
  end

  @doc """
  Get the current authentication configuration.
  """
  def get_auth_config do
    Config.auth_config()
  end

  # Content Generation

  @doc """
  Generate content using the Gemini API.

  ## Parameters
    - `contents` - Content to generate from (string or list of Content structs)
    - `opts` - Options for generation (see `Gemini.Generate.content/2`)

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

  """
  def generate(contents, opts \\ []) do
    Generate.content(contents, opts)
  end

  @doc """
  Generate content with streaming support.

  Returns a list of partial responses as they become available.

  ## Examples

      {:ok, responses} = Gemini.stream_generate("Tell me a long story")
      texts = Enum.map(responses, &Gemini.extract_text/1)

  """
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
  def start_stream(contents, opts \\ []) do
    auth_config = Config.auth_config()
    model = Keyword.get(opts, :model, Config.default_model())
    request = Generate.build_generate_request(contents, opts)

    Manager.start_stream(
      auth_config.type,
      auth_config.credentials,
      model,
      "streamGenerateContent",
      request,
      opts
    )
  end

  @doc """
  Subscribe to events from a streaming session.
  """
  def subscribe_stream(stream_id, subscriber_pid \\ self()) do
    Manager.subscribe(stream_id, subscriber_pid)
  end

  @doc """
  Unsubscribe from a streaming session.
  """
  def unsubscribe_stream(stream_id, subscriber_pid \\ self()) do
    Manager.unsubscribe(stream_id, subscriber_pid)
  end

  @doc """
  Stop a streaming session.
  """
  def stop_stream(stream_id) do
    Manager.stop_stream(stream_id)
  end

  @doc """
  Get the status of a streaming session.
  """
  def get_stream_status(stream_id) do
    Manager.get_stream_status(stream_id)
  end

  @doc """
  List all active streaming sessions.
  """
  def list_streams do
    Manager.list_streams()
  end

  @doc """
  Generate text content and return only the text.

  This is a convenience function for simple text generation.

  ## Examples

      {:ok, text} = Gemini.text("What is 2+2?")
      # => "2 + 2 = 4"

  """
  def text(contents, opts \\ []) do
    Generate.text(contents, opts)
  end

  @doc """
  Count tokens in the given content.

  ## Examples

      {:ok, count} = Gemini.count_tokens("Hello, world!")
      # => {:ok, %CountTokensResponse{total_tokens: 3}}

  """
  def count_tokens(contents, opts \\ []) do
    Generate.count_tokens(contents, opts)
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

  """
  def chat(opts \\ []) do
    Generate.chat(opts)
  end

  @doc """
  Send a message in a chat session.

  ## Examples

      {:ok, chat} = Gemini.chat()
      {:ok, response, chat} = Gemini.send_message(chat, "Hello!")
      {:ok, response, chat} = Gemini.send_message(chat, "How are you?")

  """
  def send_message(chat, message) do
    Generate.send_message(chat, message)
  end

  # Model Management

  @doc """
  List available Gemini models.

  ## Examples

      {:ok, models_response} = Gemini.list_models()
      model_names = Enum.map(models_response.models, & &1.name)

  """
  def list_models(opts \\ []) do
    Models.list(opts)
  end

  @doc """
  Get information about a specific model.

  ## Examples

      {:ok, model} = Gemini.get_model("gemini-2.0-flash")

  """
  def get_model(model_name) do
    Models.get(model_name)
  end

  @doc """
  List available model names.

  ## Examples

      {:ok, names} = Gemini.list_model_names()
      # => {:ok, ["gemini-2.0-flash", "gemini-1.5-pro", ...]}

  """
  def list_model_names do
    Models.list_names()
  end

  @doc """
  Check if a model exists.

  ## Examples

      {:ok, true} = Gemini.model_exists?("gemini-2.0-flash")
      {:ok, false} = Gemini.model_exists?("invalid-model")

  """
  def model_exists?(model_name) do
    Models.exists?(model_name)
  end

  # Utility Functions

  @doc """
  Extract text from a GenerateContentResponse.

  Returns the text from the first candidate's first text part.

  ## Examples

      {:ok, response} = Gemini.generate("Hello")
      {:ok, text} = Gemini.extract_text(response)

  """
  def extract_text(%GenerateContentResponse{candidates: [%Candidate{content: %Content{parts: [%Part{text: text} | _]}} | _]}) do
    {:ok, text}
  end

  def extract_text(%GenerateContentResponse{candidates: []}) do
    {:error, "No candidates in response"}
  end

  def extract_text(%GenerateContentResponse{candidates: [%Candidate{content: nil} | _]}) do
    {:error, "Candidate has no content"}
  end

  def extract_text(_) do
    {:error, "Invalid response format"}
  end

  @doc """
  Extract all text parts from a GenerateContentResponse.

  ## Examples

      {:ok, response} = Gemini.generate("Hello")
      texts = Gemini.extract_all_text(response)

  """
  def extract_all_text(%GenerateContentResponse{candidates: candidates}) do
    candidates
    |> Enum.flat_map(fn %Candidate{content: content} ->
      case content do
        %Content{parts: parts} ->
          parts
          |> Enum.filter(fn part -> match?(%Part{text: text} when is_binary(text), part) end)
          |> Enum.map(fn %Part{text: text} -> text end)
        _ ->
          []
      end
    end)
  end

  @doc """
  Create a multimodal prompt with text and images.

  ## Examples

      prompt = Gemini.multimodal_prompt(
        "What's in these images?",
        ["image1.jpg", "image2.png"]
      )
      {:ok, response} = Gemini.generate(prompt)

  """
  def multimodal_prompt(text, image_paths) when is_list(image_paths) do
    image_contents = Enum.map(image_paths, &Content.image/1)
    [Content.text(text)] ++ image_contents
  end

  @doc """
  Create a system-instructed prompt.

  ## Examples

      {:ok, response} = Gemini.generate(
        "What is the capital of France?",
        system_instruction: "You are a helpful geography teacher."
      )

  """
  def with_system_instruction(contents, instruction) do
    Generate.content(contents, system_instruction: instruction)
  end
end
