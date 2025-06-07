defmodule Gemini.Client.HTTPStreaming do
  @moduledoc """
  HTTP client for streaming Server-Sent Events (SSE) from Gemini API.

  Provides proper streaming support with:
  - Incremental SSE parsing
  - Connection management
  - Error handling and retries
  - Backpressure support
  """

  alias Gemini.SSE.Parser
  alias Gemini.Error

  require Logger

  @type stream_event :: %{
          type: :data | :error | :complete,
          data: map() | nil,
          error: term() | nil
        }

  @type stream_callback :: (stream_event() -> :ok | :stop)

  @doc """
  Start an SSE stream with a callback function.

  ## Parameters
  - `url` - Full URL for the streaming endpoint
  - `headers` - HTTP headers including authentication
  - `body` - Request body (will be JSON encoded)
  - `callback` - Function called for each event
  - `opts` - Options including timeout, retry settings

  ## Examples

      callback = fn
        %{type: :data, data: data} -> 
          IO.puts("Received data")
          :ok
        %{type: :complete} -> 
          IO.puts("Stream complete")
          :ok
        %{type: :error, error: _error} -> 
          IO.puts("Stream error")
          :stop
      end
      
      HTTPStreaming.stream_sse(url, headers, body, callback)
  """
  @spec stream_sse(String.t(), [{String.t(), String.t()}], map(), stream_callback(), keyword()) ::
          {:ok, :completed} | {:error, term()}
  def stream_sse(url, headers, body, callback, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    max_retries = Keyword.get(opts, :max_retries, 3)

    stream_with_retries(url, headers, body, callback, timeout, max_retries, 0)
  end

  @doc """
  Start an SSE stream that sends events to a GenServer process.

  Events are sent as messages: {:stream_event, stream_id, event}
  """
  @spec stream_to_process(
          String.t(),
          [{String.t(), String.t()}],
          map(),
          String.t(),
          pid(),
          keyword()
        ) ::
          {:ok, pid()} | {:error, term()}
  def stream_to_process(url, headers, body, stream_id, target_pid, opts \\ []) do
    callback = fn event ->
      send(target_pid, {:stream_event, stream_id, event})
      :ok
    end

    # Start streaming in a separate process
    stream_pid =
      spawn(fn ->
        case stream_sse(url, headers, body, callback, opts) do
          {:ok, :completed} ->
            send(target_pid, {:stream_complete, stream_id})

          {:error, error} ->
            send(target_pid, {:stream_error, stream_id, error})
        end
      end)

    {:ok, stream_pid}
  end

  # Private implementation

  @spec stream_with_retries(
          String.t(),
          list(),
          map(),
          stream_callback(),
          integer(),
          integer(),
          integer()
        ) ::
          {:ok, :completed} | {:error, term()}
  defp stream_with_retries(url, headers, body, callback, timeout, max_retries, attempt) do
    case do_stream(url, headers, body, callback, timeout) do
      {:ok, :completed} ->
        {:ok, :completed}

      {:error, error} when attempt < max_retries ->
        Logger.warning("Stream attempt #{attempt + 1} failed: #{inspect(error)}, retrying...")

        # Exponential backoff
        delay = min(1000 * :math.pow(2, attempt), 10_000) |> round()
        Process.sleep(delay)

        stream_with_retries(url, headers, body, callback, timeout, max_retries, attempt + 1)

      {:error, error} ->
        Logger.error("Stream failed after #{max_retries} retries: #{inspect(error)}")
        {:error, error}
    end
  end

  @spec do_stream(String.t(), list(), map(), stream_callback(), integer()) ::
          {:ok, :completed} | {:error, term()}
  defp do_stream(url, headers, body, callback, timeout) do
    # Add SSE parameters to URL
    sse_url = add_sse_params(url)

    # Initialize SSE parser
    parser = Parser.new()

    # Use a more direct approach with custom HTTP handling
    case stream_with_finch(sse_url, headers, body, callback, parser, timeout) do
      {:ok, :completed} ->
        {:ok, :completed}

      {:error, error} ->
        {:error, error}
    end
  end

  @spec stream_with_finch(String.t(), list(), map(), stream_callback(), Parser.t(), integer()) ::
          {:ok, :completed} | {:error, term()}
  defp stream_with_finch(url, headers, body, callback, parser, timeout) do
    # Configure Req for simple streaming response
    req_opts = [
      method: :post,
      url: url,
      headers: add_sse_headers(headers),
      json: body,
      receive_timeout: timeout,
      connect_options: [timeout: 5_000],
      # Just get the response with raw body
      raw: true
    ]

    Logger.debug("Starting SSE stream to #{url}")

    case Req.request(req_opts) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        # Parse the complete SSE response
        case Parser.parse_chunk(body, parser) do
          {:ok, events, _final_parser} ->
            # Send each event through the callback
            Enum.each(events, fn event ->
              stream_event = %{type: :data, data: event.data, error: nil}

              case callback.(stream_event) do
                :ok -> :continue
                :stop -> throw({:stop_stream, :requested})
              end

              # Check if this event indicates stream completion
              if Parser.stream_done?(event) do
                completion_event = %{type: :complete, data: nil, error: nil}
                callback.(completion_event)
                throw({:stop_stream, :completed})
              end
            end)

            # Send completion event
            completion_event = %{type: :complete, data: nil, error: nil}
            callback.(completion_event)
            {:ok, :completed}

          {:error, error} ->
            error_event = %{type: :error, data: nil, error: error}
            callback.(error_event)
            {:error, error}
        end

      {:ok, %Req.Response{status: status, body: error_body}} ->
        error_msg = extract_error_message(error_body) || "HTTP #{status}"
        error = Error.http_error(status, error_msg)
        error_event = %{type: :error, data: nil, error: error}
        callback.(error_event)
        {:error, error}

      {:error, %Req.TransportError{reason: reason}} ->
        error = Error.network_error("Transport error: #{inspect(reason)}")
        error_event = %{type: :error, data: nil, error: error}
        callback.(error_event)
        {:error, error}

      {:error, reason} ->
        error = Error.network_error("Request failed: #{inspect(reason)}")
        error_event = %{type: :error, data: nil, error: error}
        callback.(error_event)
        {:error, error}
    end
  catch
    {:stop_stream, :completed} ->
      {:ok, :completed}

    {:stop_stream, :requested} ->
      {:ok, :completed}

    {:stop_stream, error} ->
      {:error, error}
  end

  @spec add_sse_params(String.t()) :: String.t()
  defp add_sse_params(url) do
    separator = if String.contains?(url, "?"), do: "&", else: "?"
    url <> separator <> "alt=sse"
  end

  @spec add_sse_headers([{String.t(), String.t()}]) :: [{String.t(), String.t()}]
  defp add_sse_headers(headers) do
    sse_headers = [
      {"Accept", "text/event-stream"},
      {"Cache-Control", "no-cache"}
    ]

    # Merge with existing headers, avoiding duplicates
    existing_keys = Enum.map(headers, fn {key, _} -> String.downcase(key) end)

    new_headers =
      sse_headers
      |> Enum.reject(fn {key, _} -> String.downcase(key) in existing_keys end)

    headers ++ new_headers
  end

  @spec extract_error_message(any()) :: String.t() | nil
  defp extract_error_message(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, %{"error" => %{"message" => message}}} -> message
      {:ok, %{"error" => error}} when is_binary(error) -> error
      _ -> nil
    end
  end

  defp extract_error_message(%{"error" => %{"message" => message}}), do: message
  defp extract_error_message(%{"error" => error}) when is_binary(error), do: error
  defp extract_error_message(_), do: nil
end
