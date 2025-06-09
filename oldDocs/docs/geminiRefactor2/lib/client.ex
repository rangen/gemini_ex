defmodule Gemini.Client do
  @moduledoc """
  Unified HTTP client with comprehensive error handling and response parsing.

  Provides a consistent interface for all Gemini API endpoints with:
  - Automatic authentication
  - Response parsing and validation
  - Error handling and classification
  - Telemetry integration
  - Retry logic
  """

  alias Gemini.{Config, Auth, Error, Telemetry}

  require Logger

  @typedoc "HTTP method types"
  @type http_method :: :get | :post | :put | :delete | :patch

  @typedoc "Request options"
  @type request_opts :: [
          timeout: integer(),
          retry_attempts: integer(),
          retry_delay: integer(),
          telemetry_metadata: map()
        ]

  @doc """
  Make an authenticated HTTP request.

  ## Parameters
  - `method` - HTTP method (:get, :post, etc.)
  - `path` - API endpoint path (without base URL)
  - `body` - Request body (will be JSON encoded if not nil)
  - `opts` - Request options

  ## Returns
  - `{:ok, parsed_response}` - Success with parsed JSON
  - `{:error, Gemini.Error.t()}` - Error with details

  ## Examples

      iex> Client.request(:get, "models")
      {:ok, %{"models" => [...]}}

      iex> Client.request(:post, "models/gemini-2.0-flash:generateContent", request_body)
      {:ok, %{"candidates" => [...]}}
  """
  @spec request(http_method(), String.t(), map() | nil, request_opts()) ::
          {:ok, map()} | {:error, Error.t()}
  def request(method, path, body \\ nil, opts \\ []) do
    with {:ok, _} <- Config.validate!(),
         {:ok, auth_config} <- get_auth_config(),
         {:ok, url} <- build_url(path, auth_config),
         {:ok, headers} <- build_headers(auth_config),
         {:ok, response} <- make_http_request(method, url, headers, body, opts),
         {:ok, parsed} <- parse_response(response) do
      {:ok, parsed}
    else
      {:error, %Error{} = error} -> {:error, error}
      {:error, reason} -> {:error, Error.network_error("Request failed: #{inspect(reason)}")}
    end
  end

  @doc """
  Make a GET request.
  """
  @spec get(String.t(), request_opts()) :: {:ok, map()} | {:error, Error.t()}
  def get(path, opts \\ []) do
    request(:get, path, nil, opts)
  end

  @doc """
  Make a POST request.
  """
  @spec post(String.t(), map(), request_opts()) :: {:ok, map()} | {:error, Error.t()}
  def post(path, body, opts \\ []) do
    request(:post, path, body, opts)
  end

  @doc """
  Make a streaming POST request for Server-Sent Events.

  ## Returns
  - `{:ok, [map()]}` - List of parsed SSE events
  - `{:error, Error.t()}` - Error details

  ## Examples

      iex> Client.stream_post("models/gemini-2.0-flash:streamGenerateContent", body)
      {:ok, [%{"candidates" => [...]}, ...]}
  """
  @spec stream_post(String.t(), map(), request_opts()) ::
          {:ok, [map()]} | {:error, Error.t()}
  def stream_post(path, body, opts \\ []) do
    with {:ok, _} <- Config.validate!(),
         {:ok, auth_config} <- get_auth_config(),
         {:ok, url} <- build_streaming_url(path, auth_config),
         {:ok, headers} <- build_streaming_headers(auth_config),
         {:ok, events} <- make_streaming_request(url, headers, body, opts) do
      {:ok, events}
    else
      {:error, %Error{} = error} -> {:error, error}
      {:error, reason} -> {:error, Error.network_error("Streaming request failed: #{inspect(reason)}")}
    end
  end

  # Private implementation functions

  @spec get_auth_config() :: {:ok, map()} | {:error, Error.t()}
  defp get_auth_config do
    case Config.auth_config() do
      nil -> {:error, Error.config_error("No authentication configured")}
      config -> {:ok, config}
    end
  end

  @spec build_url(String.t(), map()) :: {:ok, String.t()} | {:error, Error.t()}
  defp build_url(path, %{type: auth_type, credentials: credentials}) do
    case Auth.get_base_url(auth_type, credentials) do
      {:error, reason} -> {:error, Error.config_error("Failed to build URL: #{reason}")}
      base_url when is_binary(base_url) -> {:ok, "#{base_url}/#{path}"}
    end
  end

  @spec build_streaming_url(String.t(), map()) :: {:ok, String.t()} | {:error, Error.t()}
  defp build_streaming_url(path, auth_config) do
    with {:ok, base_url} <- build_url(path, auth_config) do
      separator = if String.contains?(base_url, "?"), do: "&", else: "?"
      {:ok, "#{base_url}#{separator}alt=sse"}
    end
  end

  @spec build_headers(map()) :: {:ok, [{String.t(), String.t()}]} | {:error, Error.t()}
  defp build_headers(%{type: auth_type, credentials: credentials}) do
    try do
      headers = Auth.build_headers(auth_type, credentials)
      {:ok, headers}
    rescue
      error -> {:error, Error.config_error("Failed to build headers: #{inspect(error)}")}
    end
  end

  @spec build_streaming_headers(map()) :: {:ok, [{String.t(), String.t()}]} | {:error, Error.t()}
  defp build_streaming_headers(auth_config) do
    with {:ok, base_headers} <- build_headers(auth_config) do
      streaming_headers = [
        {"Accept", "text/event-stream"},
        {"Cache-Control", "no-cache"}
      ]

      # Merge headers, avoiding duplicates
      existing_keys = Enum.map(base_headers, fn {key, _} -> String.downcase(key) end)

      additional_headers =
        streaming_headers
        |> Enum.reject(fn {key, _} -> String.downcase(key) in existing_keys end)

      {:ok, base_headers ++ additional_headers}
    end
  end

  @spec make_http_request(http_method(), String.t(), [{String.t(), String.t()}], map() | nil, request_opts()) ::
          {:ok, Req.Response.t()} | {:error, term()}
  defp make_http_request(method, url, headers, body, opts) do
    timeout = Keyword.get(opts, :timeout, Config.timeout())
    retry_attempts = Keyword.get(opts, :retry_attempts, 3)
    telemetry_metadata = Keyword.get(opts, :telemetry_metadata, %{})

    # Build request options
    req_opts = [
      method: method,
      url: url,
      headers: headers,
      receive_timeout: timeout,
      retry: [max_retries: retry_attempts]
    ]

    req_opts = if body, do: Keyword.put(req_opts, :json, body), else: req_opts

    # Emit telemetry for request start
    start_time = System.monotonic_time()
    metadata = Map.merge(%{url: url, method: method}, telemetry_metadata)
    Telemetry.execute([:gemini, :request, :start], %{system_time: System.system_time()}, metadata)

    try do
      case Req.request(req_opts) do
        {:ok, response} ->
          duration = Telemetry.calculate_duration(start_time)
          Telemetry.execute(
            [:gemini, :request, :stop],
            %{duration: duration, status: response.status},
            metadata
          )
          {:ok, response}

        {:error, reason} ->
          duration = Telemetry.calculate_duration(start_time)
          Telemetry.execute(
            [:gemini, :request, :exception],
            %{duration: duration},
            Map.put(metadata, :reason, reason)
          )
          {:error, reason}
      end
    rescue
      exception ->
        duration = Telemetry.calculate_duration(start_time)
        Telemetry.execute(
          [:gemini, :request, :exception],
          %{duration: duration},
          Map.put(metadata, :reason, exception)
        )
        reraise exception, __STACKTRACE__
    end
  end

  @spec make_streaming_request(String.t(), [{String.t(), String.t()}], map(), request_opts()) ::
          {:ok, [map()]} | {:error, term()}
  defp make_streaming_request(url, headers, body, opts) do
    timeout = Keyword.get(opts, :timeout, Config.timeout())
    telemetry_metadata = Keyword.get(opts, :telemetry_metadata, %{})

    # Generate stream ID for telemetry
    stream_id = Telemetry.generate_stream_id()
    metadata = 
      telemetry_metadata
      |> Map.merge(%{url: url, method: :post, stream_id: stream_id})

    start_time = System.monotonic_time()
    Telemetry.execute([:gemini, :stream, :start], %{system_time: System.system_time()}, metadata)

    try do
      req_opts = [
        method: :post,
        url: url,
        headers: headers,
        json: body,
        receive_timeout: timeout,
        into: :self
      ]

      case Req.request(req_opts) do
        {:ok, %Req.Response{status: status, body: _body}} when status in 200..299 ->
          # Process streaming response
          events = collect_sse_events(timeout)
          
          duration = Telemetry.calculate_duration(start_time)
          Telemetry.execute(
            [:gemini, :stream, :stop],
            %{total_duration: duration, total_chunks: length(events)},
            metadata
          )
          
          {:ok, events}

        {:ok, %Req.Response{status: status, body: body}} ->
          error = parse_api_error(body, status)
          
          duration = Telemetry.calculate_duration(start_time)
          Telemetry.execute(
            [:gemini, :stream, :exception],
            %{duration: duration},
            Map.put(metadata, :reason, error)
          )
          
          {:error, error}

        {:error, reason} ->
          error = Error.network_error("Streaming request failed: #{inspect(reason)}")
          
          duration = Telemetry.calculate_duration(start_time)
          Telemetry.execute(
            [:gemini, :stream, :exception],
            %{duration: duration},
            Map.put(metadata, :reason, error)
          )
          
          {:error, error}
      end
    rescue
      exception ->
        duration = Telemetry.calculate_duration(start_time)
        Telemetry.execute(
          [:gemini, :stream, :exception],
          %{duration: duration},
          Map.put(metadata, :reason, exception)
        )
        reraise exception, __STACKTRACE__
    end
  end

  @spec collect_sse_events(integer()) :: [map()]
  defp collect_sse_events(timeout) do
    collect_sse_events([], timeout)
  end

  @spec collect_sse_events([map()], integer()) :: [map()]
  defp collect_sse_events(events, timeout) do
    receive do
      {:data, chunk} ->
        case parse_sse_chunk(chunk) do
          {:ok, new_events} -> collect_sse_events(events ++ new_events, timeout)
          {:error, _reason} -> collect_sse_events(events, timeout)
        end

      :done ->
        events

      _other ->
        collect_sse_events(events, timeout)
    after
      timeout ->
        Logger.warning("SSE stream timeout after #{timeout}ms")
        events
    end
  end

  @spec parse_sse_chunk(String.t()) :: {:ok, [map()]} | {:error, term()}
  defp parse_sse_chunk(chunk) do
    try do
      events =
        chunk
        |> String.split("\n\n")
        |> Enum.filter(&(String.trim(&1) != ""))
        |> Enum.map(&parse_sse_event/1)
        |> Enum.filter(&(&1 != nil))

      {:ok, events}
    rescue
      error -> {:error, error}
    end
  end

  @spec parse_sse_event(String.t()) :: map() | nil
  defp parse_sse_event(event_data) do
    lines = String.split(event_data, "\n")

    Enum.reduce(lines, %{}, fn line, acc ->
      case String.split(line, ": ", parts: 2) do
        ["data", json_data] ->
          case Jason.decode(json_data) do
            {:ok, decoded} -> Map.put(acc, :data, decoded)
            _ -> acc
          end

        [field, value] ->
          Map.put(acc, String.to_atom(field), value)

        _ ->
          acc
      end
    end)
    |> case do
      %{data: data} -> data
      _ -> nil
    end
  end

  @spec parse_response(Req.Response.t()) :: {:ok, map()} | {:error, Error.t()}
  defp parse_response(%Req.Response{status: status, body: body}) when status in 200..299 do
    case body do
      decoded when is_map(decoded) ->
        {:ok, decoded}

      json_string when is_binary(json_string) ->
        case Jason.decode(json_string) do
          {:ok, decoded} -> {:ok, decoded}
          {:error, _} -> {:error, Error.invalid_response("Invalid JSON response")}
        end

      _ ->
        {:error, Error.invalid_response("Invalid response format")}
    end
  end

  defp parse_response(%Req.Response{status: status, body: body}) do
    error = parse_api_error(body, status)
    {:error, error}
  end

  @spec parse_api_error(term(), integer()) :: Error.t()
  defp parse_api_error(body, status) do
    error_info = extract_error_info(body)
    Error.api_error(status, extract_error_message(error_info), error_info)
  end

  @spec extract_error_info(term()) :: map()
  defp extract_error_info(body) when is_map(body) do
    Map.get(body, "error", %{})
  end

  defp extract_error_info(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, %{"error" => error}} -> error
      _ -> %{"message" => "HTTP error"}
    end
  end

  defp extract_error_info(_), do: %{"message" => "Unknown error"}

  @spec extract_error_message(map()) :: String.t()
  defp extract_error_message(%{"message" => message}) when is_binary(message), do: message
  defp extract_error_message(%{"details" => details}) when is_binary(details), do: details
  defp extract_error_message(_), do: "API error"
end
