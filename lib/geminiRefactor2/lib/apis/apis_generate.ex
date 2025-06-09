defmodule Gemini.APIs.Generate do
  @moduledoc """
  Complete Content Generation API implementation following the unified architecture.

  Provides comprehensive content generation capabilities including:
  - Text and multimodal content generation
  - Streaming responses with real-time events
  - Chat session management
  - Safety settings and content filtering
  - Tool usage and function calling

  ## Examples

      # Simple text generation
      {:ok, response} = Generate.content("What is the capital of France?")
      {:ok, text} = GenerateContentResponse.extract_text(response)

      # Streaming generation
      {:ok, events} = Generate.stream_content("Write a long story")

      # Multimodal generation
      contents = [
        Content.text("What's in this image?"),
        Content.image("path/to/image.jpg")
      ]
      {:ok, response} = Generate.content(contents)

      # Chat session
      {:ok, chat} = Generate.chat()
      {:ok, response, chat} = Generate.send_message(chat, "Hello!")
  """

  alias Gemini.Client
  alias Gemini.Config
  alias Gemini.Types.{Content, Part, GenerationConfig, SafetySetting}
  alias Gemini.Types.Request.{GenerateContentRequest, CountTokensRequest}
  alias Gemini.Types.Response.{GenerateContentResponse, CountTokensResponse, Candidate}
  alias Gemini.{Error, Telemetry}

  require Logger

  @doc """
  Generate content using a Gemini model.

  ## Parameters
  - `contents` - Content to generate from (string or list of Content structs)
  - `opts` - Options for generation:
    - `:model` - Model name (default: from config)
    - `:generation_config` - GenerationConfig struct
    - `:safety_settings` - List of SafetySetting structs
    - `:system_instruction` - System instruction as Content or string
    - `:tools` - List of tool definitions
    - `:tool_config` - Tool configuration

  ## Returns
  - `{:ok, GenerateContentResponse.t()}` - Success with generated content
  - `{:error, Error.t()}` - Validation error, API error, or network failure

  ## Examples

      {:ok, response} = Generate.content("Hello, world!")
      {:ok, text} = GenerateContentResponse.extract_text(response)
      # => "Hello! How can I help you today?"

      # With configuration
      config = GenerationConfig.creative()
      {:ok, response} = Generate.content("Write a poem", generation_config: config)

      # With safety settings
      safety = [SafetySetting.harassment(:block_only_high)]
      {:ok, response} = Generate.content("Tell me a story", safety_settings: safety)

      # Multimodal content
      contents = [
        Content.text("What's in this image?"),
        Content.image("path/to/image.jpg")
      ]
      {:ok, response} = Generate.content(contents)
  """
  @spec content(String.t() | [Content.t()], keyword()) ::
          {:ok, GenerateContentResponse.t()} | {:error, Error.t()}
  def content(contents, opts \\ []) do
    model = Keyword.get(opts, :model, Config.default_model())
    start_time = System.monotonic_time()

    with {:ok, request} <- GenerateContentRequest.new(contents, opts),
         request_map = GenerateContentRequest.to_json_map(request),
         path = "models/#{model}:generateContent",
         telemetry_opts = build_telemetry_opts(:generate_content, model, opts),
         {:ok, response} <- Client.post(path, request_map, telemetry_opts),
         {:ok, parsed_response} <- parse_generate_response(response) do
      
      # Emit success telemetry
      emit_generate_telemetry(:generate, :success, start_time, model, %{
        candidate_count: length(parsed_response.candidates),
        finish_reason: GenerateContentResponse.finish_reason(parsed_response),
        token_usage: GenerateContentResponse.token_usage(parsed_response)
      })

      {:ok, parsed_response}
    else
      {:error, %Error{} = error} ->
        emit_generate_telemetry(:generate, :error, start_time, model, %{error_type: error.type})
        {:error, error}

      {:error, reason} when is_binary(reason) ->
        error = Error.validation_error(reason)
        emit_generate_telemetry(:generate, :error, start_time, model, %{error_type: :validation_error})
        {:error, error}
    end
  end

  @doc """
  Generate content with streaming support.

  Returns a list of partial responses as they become available from the server.
  This provides real-time generation updates for long-form content.

  ## Parameters
  - `contents` - Content to generate from (string or list of Content structs)
  - `opts` - Same options as `content/2`

  ## Returns
  - `{:ok, [GenerateContentResponse.t()]}` - List of streaming responses
  - `{:error, Error.t()}` - Error details

  ## Examples

      {:ok, responses} = Generate.stream_content("Write a long story")
      
      # Process each streaming chunk
      Enum.each(responses, fn response ->
        case GenerateContentResponse.extract_text(response) do
          {:ok, text} -> IO.write(text)
          {:error, _} -> :ok
        end
      end)

      # Combine all text
      full_text = 
        responses
        |> Enum.map(&GenerateContentResponse.extract_text/1)
        |> Enum.filter(&match?({:ok, _}, &1))
        |> Enum.map(fn {:ok, text} -> text end)
        |> Enum.join("")
  """
  @spec stream_content(String.t() | [Content.t()], keyword()) ::
          {:ok, [GenerateContentResponse.t()]} | {:error, Error.t()}
  def stream_content(contents, opts \\ []) do
    model = Keyword.get(opts, :model, Config.default_model())
    start_time = System.monotonic_time()

    with {:ok, request} <- GenerateContentRequest.new(contents, opts),
         request_map = GenerateContentRequest.to_json_map(request),
         path = "models/#{model}:streamGenerateContent",
         telemetry_opts = build_telemetry_opts(:stream_generate_content, model, opts),
         {:ok, events} <- Client.stream_post(path, request_map, telemetry_opts),
         {:ok, responses} <- parse_stream_responses(events) do
      
      # Emit success telemetry
      emit_generate_telemetry(:stream, :success, start_time, model, %{
        response_count: length(responses),
        total_candidates: count_total_candidates(responses)
      })

      {:ok, responses}
    else
      {:error, %Error{} = error} ->
        emit_generate_telemetry(:stream, :error, start_time, model, %{error_type: error.type})
        {:error, error}

      {:error, reason} when is_binary(reason) ->
        error = Error.validation_error(reason)
        emit_generate_telemetry(:stream, :error, start_time, model, %{error_type: :validation_error})
        {:error, error}
    end
  end

  @doc """
  Generate content and return only the text from the first candidate.

  This is a convenience function for simple text generation use cases
  where you only need the generated text without response metadata.

  ## Parameters
  - `contents` - Content to generate from
  - `opts` - Same options as `content/2`

  ## Returns
  - `{:ok, String.t()}` - Generated text
  - `{:error, Error.t()}` - Error details

  ## Examples

      {:ok, text} = Generate.text("What is 2+2?")
      # => "2 + 2 = 4"

      {:ok, poem} = Generate.text("Write a haiku about coding", 
        generation_config: GenerationConfig.creative())
  """
  @spec text(String.t() | [Content.t()], keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def text(contents, opts \\ []) do
    case content(contents, opts) do
      {:ok, response} ->
        GenerateContentResponse.extract_text(response)

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Start a chat session for multi-turn conversations.

  Chat sessions maintain conversation history and allow for natural
  back-and-forth interactions with consistent context.

  ## Parameters
  - `opts` - Options for the chat session:
    - `:model` - Model name (default: from config)
    - `:history` - Initial chat history as list of Content structs
    - `:generation_config` - GenerationConfig struct
    - `:safety_settings` - List of SafetySetting structs
    - `:system_instruction` - System instruction
    - `:tools` - List of tool definitions
    - `:tool_config` - Tool configuration

  ## Returns
  - `{:ok, chat_session}` - Chat session map

  ## Examples

      {:ok, chat} = Generate.chat()
      {:ok, response, chat} = Generate.send_message(chat, "Hello!")
      {:ok, response, chat} = Generate.send_message(chat, "How are you?")

      # With configuration
      config = GenerationConfig.balanced()
      {:ok, chat} = Generate.chat(generation_config: config)

      # With system instruction
      {:ok, chat} = Generate.chat(
        system_instruction: "You are a helpful coding assistant."
      )
  """
  @spec chat(keyword()) :: {:ok, map()}
  def chat(opts \\ []) do
    chat_session = %{
      model: Keyword.get(opts, :model, Config.default_model()),
      history: Keyword.get(opts, :history, []),
      generation_config: Keyword.get(opts, :generation_config),
      safety_settings: Keyword.get(opts, :safety_settings),
      system_instruction: Keyword.get(opts, :system_instruction),
      tools: Keyword.get(opts, :tools),
      tool_config: Keyword.get(opts, :tool_config),
      metadata: %{
        created_at: DateTime.utc_now(),
        message_count: 0
      }
    }

    {:ok, chat_session}
  end

  @doc """
  Send a message in a chat session.

  Adds the message to the conversation history, generates a response,
  and updates the session with both the user message and assistant response.

  ## Parameters
  - `chat_session` - Chat session from `chat/1`
  - `message` - Message content as string or Content struct

  ## Returns
  - `{:ok, response, updated_chat}` - Response and updated session
  - `{:error, Error.t()}` - Error details

  ## Examples

      {:ok, chat} = Generate.chat()
      {:ok, response, chat} = Generate.send_message(chat, "Hello!")
      
      # Extract response text
      {:ok, text} = GenerateContentResponse.extract_text(response)
      IO.puts("Assistant: #{text}")

      # Continue conversation
      {:ok, response, chat} = Generate.send_message(chat, "Tell me a joke")
  """
  @spec send_message(map(), String.t() | Content.t()) ::
          {:ok, GenerateContentResponse.t(), map()} | {:error, Error.t()}
  def send_message(chat_session, message) do
    user_content = normalize_content(message)
    contents = chat_session.history ++ [user_content]

    opts =
      [
        model: chat_session.model,
        generation_config: chat_session.generation_config,
        safety_settings: chat_session.safety_settings,
        system_instruction: chat_session.system_instruction,
        tools: chat_session.tools,
        tool_config: chat_session.tool_config
      ]
      |> Enum.filter(fn {_k, v} -> v != nil end)

    case content(contents, opts) do
      {:ok, response} ->
        # Extract assistant response for history
        assistant_content = extract_assistant_content(response)
        
        updated_chat = %{
          chat_session
          | history: contents ++ [assistant_content],
            metadata: %{
              chat_session.metadata
              | message_count: chat_session.metadata.message_count + 1
            }
        }

        {:ok, response, updated_chat}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Build a generate content request structure.

  This function is exposed publicly to allow the streaming manager and other
  components to construct requests using the same validation and normalization
  logic as the main content generation functions.

  ## Parameters
  - `contents` - Content to generate from
  - `opts` - Generation options

  ## Returns
  - Map representing the request structure ready for JSON encoding
  """
  @spec build_generate_request(String.t() | [Content.t()], keyword()) :: map()
  def build_generate_request(contents, opts) do
    case GenerateContentRequest.new(contents, opts) do
      {:ok, request} -> GenerateContentRequest.to_json_map(request)
      {:error, _reason} -> %{contents: normalize_contents_fallback(contents)}
    end
  end

  # Private implementation functions

  @spec build_telemetry_opts(atom(), String.t(), keyword()) :: keyword()
  defp build_telemetry_opts(function, model, opts) do
    telemetry_metadata = %{
      function: function,
      api: :generate,
      model: model,
      contents_type: Telemetry.classify_contents(Keyword.get(opts, :contents, []))
    }

    [telemetry_metadata: telemetry_metadata]
  end

  @spec emit_generate_telemetry(atom(), atom(), integer(), String.t(), map()) :: :ok
  defp emit_generate_telemetry(operation, status, start_time, model, additional_metadata \\ %{}) do
    duration = Telemetry.calculate_duration(start_time)

    measurements = %{duration: duration}
    
    # Add token usage to measurements if available
    measurements =
      case Map.get(additional_metadata, :token_usage) do
        %{total: total, input: input, output: output} ->
          Map.merge(measurements, %{
            total_tokens: total,
            input_tokens: input,
            output_tokens: output
          })
        _ ->
          measurements
      end

    # Add response counts to measurements
    measurements =
      measurements
      |> maybe_add_measurement(:candidate_count, additional_metadata)
      |> maybe_add_measurement(:response_count, additional_metadata)
      |> maybe_add_measurement(:total_candidates, additional_metadata)

    metadata = %{
      api: :generate,
      operation: operation,
      model: model
    }
    metadata = Map.merge(metadata, Map.drop(additional_metadata, [
      :token_usage, :candidate_count, :response_count, :total_candidates
    ]))

    Telemetry.execute([:gemini, :generate, operation, status], measurements, metadata)
  end

  @spec maybe_add_measurement(map(), atom(), map()) :: map()
  defp maybe_add_measurement(measurements, key, additional_metadata) do
    case Map.get(additional_metadata, key) do
      nil -> measurements
      value -> Map.put(measurements, key, value)
    end
  end

  @spec parse_generate_response(map()) :: {:ok, GenerateContentResponse.t()} | {:error, Error.t()}
  defp parse_generate_response(response) do
    try do
      candidates =
        response
        |> Map.get("candidates", [])
        |> Enum.map(&parse_candidate/1)

      prompt_feedback = parse_prompt_feedback(Map.get(response, "promptFeedback"))
      usage_metadata = parse_usage_metadata(Map.get(response, "usageMetadata"))

      generate_response = %GenerateContentResponse{
        candidates: candidates,
        prompt_feedback: prompt_feedback,
        usage_metadata: usage_metadata
      }

      {:ok, generate_response}
    rescue
      error ->
        Logger.error("Failed to parse generate response: #{inspect(error)}")
        {:error, Error.invalid_response("Failed to parse generate response: #{inspect(error)}")}
    end
  end

  @spec parse_stream_responses([map()]) :: {:ok, [GenerateContentResponse.t()]} | {:error, Error.t()}
  defp parse_stream_responses(events) do
    try do
      responses =
        events
        |> Enum.map(&parse_generate_response/1)
        |> Enum.map(fn
          {:ok, response} -> response
          {:error, _} -> nil
        end)
        |> Enum.filter(&(&1 != nil))

      {:ok, responses}
    rescue
      error ->
        Logger.error("Failed to parse stream responses: #{inspect(error)}")
        {:error, Error.invalid_response("Failed to parse stream responses: #{inspect(error)}")}
    end
  end

  @spec parse_candidate(map()) :: Candidate.t()
  defp parse_candidate(candidate_data) do
    content =
      case Map.get(candidate_data, "content") do
        nil -> nil
        content_data -> parse_content(content_data)
      end

    safety_ratings =
      candidate_data
      |> Map.get("safetyRatings", [])
      |> Enum.map(&parse_safety_rating/1)

    %Candidate{
      content: content,
      finish_reason: Map.get(candidate_data, "finishReason"),
      safety_ratings: safety_ratings,
      citation_metadata: parse_citation_metadata(Map.get(candidate_data, "citationMetadata")),
      token_count: Map.get(candidate_data, "tokenCount"),
      grounding_attributions: parse_grounding_attributions(Map.get(candidate_data, "groundingAttributions", [])),
      index: Map.get(candidate_data, "index")
    }
  end

  @spec parse_content(map()) :: Content.t()
  defp parse_content(content_data) do
    parts =
      content_data
      |> Map.get("parts", [])
      |> Enum.map(&parse_part/1)

    %Content{
      parts: parts,
      role: Map.get(content_data, "role", "user")
    }
  end

  @spec parse_part(map()) :: Part.t()
  defp parse_part(part_data) do
    cond do
      Map.has_key?(part_data, "text") ->
        Part.text(Map.get(part_data, "text"))

      Map.has_key?(part_data, "inlineData") ->
        inline_data = Map.get(part_data, "inlineData")
        Part.blob(
          Map.get(inline_data, "data"),
          Map.get(inline_data, "mimeType")
        )

      true ->
        Part.text("")
    end
  end

  @spec parse_safety_rating(map()) :: map()
  defp parse_safety_rating(rating_data) do
    %{
      category: Map.get(rating_data, "category"),
      probability: Map.get(rating_data, "probability"),
      blocked: Map.get(rating_data, "blocked")
    }
  end

  @spec parse_prompt_feedback(map() | nil) :: map() | nil
  defp parse_prompt_feedback(nil), do: nil
  defp parse_prompt_feedback(feedback_data) do
    safety_ratings =
      feedback_data
      |> Map.get("safetyRatings", [])
      |> Enum.map(&parse_safety_rating/1)

    %{
      block_reason: Map.get(feedback_data, "blockReason"),
      safety_ratings: safety_ratings
    }
  end

  @spec parse_usage_metadata(map() | nil) :: map() | nil
  defp parse_usage_metadata(nil), do: nil
  defp parse_usage_metadata(metadata) do
    %{
      prompt_token_count: Map.get(metadata, "promptTokenCount"),
      candidates_token_count: Map.get(metadata, "candidatesTokenCount"),
      total_token_count: Map.get(metadata, "totalTokenCount", 0),
      cached_content_token_count: Map.get(metadata, "cachedContentTokenCount")
    }
  end

  @spec parse_citation_metadata(map() | nil) :: map() | nil
  defp parse_citation_metadata(nil), do: nil
  defp parse_citation_metadata(_metadata) do
    # TODO: Implement complete citation metadata parsing
    # This is a placeholder for the more complex citation structure
    nil
  end

  @spec parse_grounding_attributions([map()]) :: [map()]
  defp parse_grounding_attributions(attributions) when is_list(attributions) do
    # TODO: Implement complete grounding attributions parsing
    # This is a placeholder for the more complex grounding structure
    []
  end
  defp parse_grounding_attributions(_), do: []

  @spec normalize_content(String.t() | Content.t()) :: Content.t()
  defp normalize_content(%Content{} = content), do: content
  defp normalize_content(text) when is_binary(text), do: Content.text(text)

  @spec normalize_contents_fallback(term()) :: [Content.t()]
  defp normalize_contents_fallback(contents) when is_binary(contents) do
    [Content.text(contents)]
  end
  defp normalize_contents_fallback(contents) when is_list(contents) do
    Enum.map(contents, fn
      %Content{} = content -> content
      text when is_binary(text) -> Content.text(text)
      _ -> Content.text("")
    end)
  end
  defp normalize_contents_fallback(_), do: [Content.text("")]

  @spec extract_assistant_content(GenerateContentResponse.t()) :: Content.t()
  defp extract_assistant_content(%GenerateContentResponse{
         candidates: [%Candidate{content: content} | _]
       }) when not is_nil(content) do
    %{content | role: "model"}
  end

  defp extract_assistant_content(_) do
    Content.text("", "model")
  end

  @spec count_total_candidates([GenerateContentResponse.t()]) :: integer()
  defp count_total_candidates(responses) do
    Enum.reduce(responses, 0, fn response, acc ->
      acc + length(response.candidates)
    end)
  end
end
