defmodule Gemini.Client.HTTP do
  @moduledoc """
  Unified HTTP client for both Gemini and Vertex AI APIs using Finch.

  Supports multiple authentication strategies and provides both
  regular and streaming request capabilities.
  """

  alias Gemini.Config
  alias Gemini.Auth
  alias Gemini.Error

  @doc """
  Start the Finch pool for HTTP requests.
  """
  def start_link do
    Finch.start_link(name: __MODULE__)
  end

  @doc """
  Make a GET request using the configured authentication.
  """
  def get(path, opts \\ []) do
    auth_config = Config.auth_config()
    request(:get, path, nil, auth_config, opts)
  end

  @doc """
  Make a POST request using the configured authentication.
  """
  def post(path, body, opts \\ []) do
    auth_config = Config.auth_config()
    request(:post, path, body, auth_config, opts)
  end

  @doc """
  Make an authenticated HTTP request.
  """
  def request(method, path, body, auth_config, opts \\ []) do
    Config.validate!()

    case auth_config do
      nil -> {:error, Error.config_error("No authentication configured")}
      %{type: auth_type, credentials: credentials} ->
        url = build_authenticated_url(auth_type, path, credentials)
        headers = Auth.build_headers(auth_type, credentials)
        finch_opts = [receive_timeout: Config.timeout()]

        body_encoded = if body, do: Jason.encode!(body), else: nil

        method
        |> Finch.build(url, headers, body_encoded)
        |> Finch.request(__MODULE__, finch_opts)
        |> handle_response()
    end
  end

  @doc """
  Stream a POST request for Server-Sent Events using configured authentication.
  """
  def stream_post(path, body, opts \\ []) do
    auth_config = Config.auth_config()
    stream_post_with_auth(path, body, auth_config, opts)
  end

  @doc """
  Stream a POST request with specific authentication configuration.
  """
  def stream_post_with_auth(path, body, auth_config, opts \\ []) do
    Config.validate!()

    case auth_config do
      nil -> {:error, Error.config_error("No authentication configured")}
      %{type: auth_type, credentials: credentials} ->
        url = build_authenticated_url(auth_type, path, credentials)
        headers = Auth.build_headers(auth_type, credentials)
        finch_opts = [receive_timeout: Config.timeout()]

        body_encoded = Jason.encode!(body)

        # Add SSE parameter to URL
        sse_url = if String.contains?(url, "?"), do: "#{url}&alt=sse", else: "#{url}?alt=sse"

        :post
        |> Finch.build(sse_url, headers, body_encoded)
        |> Finch.stream(__MODULE__, %{events: []}, fn
          {:status, status}, acc -> {:cont, Map.put(acc, :status, status)}
          {:headers, headers}, acc -> {:cont, Map.put(acc, :headers, headers)}
          {:data, data}, acc ->
            case parse_sse_chunk(data) do
              {:ok, events} -> {:cont, Map.update(acc, :events, events, &(&1 ++ events))}
              :error -> {:cont, acc}
            end
        end)
        |> case do
          {:ok, %{status: status, events: events}} when status in 200..299 ->
            {:ok, events}
          {:ok, %{status: status}} ->
            {:error, Error.http_error(status, "Stream request failed")}
          {:error, reason} ->
            {:error, Error.network_error(reason)}
        end
    end
  end

  @doc """
  Raw streaming POST with full URL (used by streaming manager).
  """
  def stream_post_raw(url, body, headers, opts \\ []) do
    finch_opts = [receive_timeout: Config.timeout()]
    body_encoded = Jason.encode!(body)

    :post
    |> Finch.build(url, headers, body_encoded)
    |> Finch.stream(__MODULE__, %{events: []}, fn
      {:status, status}, acc -> {:cont, Map.put(acc, :status, status)}
      {:headers, headers}, acc -> {:cont, Map.put(acc, :headers, headers)}
      {:data, data}, acc ->
        case parse_sse_chunk(data) do
          {:ok, events} -> {:cont, Map.update(acc, :events, events, &(&1 ++ events))}
          :error -> {:cont, acc}
        end
    end)
    |> case do
      {:ok, %{status: status, events: events}} when status in 200..299 ->
        {:ok, events}
      {:ok, %{status: status}} ->
        {:error, Error.http_error(status, "Stream request failed")}
      {:error, reason} ->
        {:error, Error.network_error(reason)}
    end
  end

  # Private functions

  defp build_authenticated_url(auth_type, path, credentials) do
    base_url = Auth.get_base_url(auth_type, credentials)

    # Check if this is a model-specific endpoint (contains ":" separator)
    # or a general endpoint like "models" for listing
    if String.contains?(path, ":") do
      # Model-specific endpoint, use the auth strategy to build the path
      full_path = Auth.build_path(auth_type, extract_model_from_path(path), extract_endpoint_from_path(path), credentials)
      "#{base_url}/#{full_path}"
    else
      # General endpoint (like "models"), use path directly
      "#{base_url}/#{path}"
    end
  end

  defp extract_model_from_path(path) do
    # Extract model from paths like "models/gemini-2.0-flash:generateContent"
    case String.split(path, ":") do
      [model_path, _endpoint] ->
        model_path |> String.replace_prefix("models/", "") |> String.trim_leading("/")
      _ ->
        "gemini-2.0-flash" # fallback
    end
  end

  defp extract_endpoint_from_path(path) do
    # Extract endpoint from paths like "models/gemini-2.0-flash:generateContent"
    case String.split(path, ":") do
      [_model, endpoint] -> String.split(endpoint, "?") |> hd()
      _ -> "generateContent" # fallback
    end
  end

  defp handle_response({:ok, %Finch.Response{status: status, body: body}}) when status in 200..299 do
    case Jason.decode(body) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, _} -> {:error, Error.invalid_response("Invalid JSON response")}
    end
  end

  defp handle_response({:ok, %Finch.Response{status: status, body: body}}) do
    error_info = case Jason.decode(body) do
      {:ok, %{"error" => error}} -> error
      _ -> %{"message" => "HTTP #{status}"}
    end

    {:error, Error.api_error(status, error_info)}
  end

  defp handle_response({:error, %Mint.TransportError{reason: reason}}) do
    {:error, Error.network_error(reason)}
  end

  defp handle_response({:error, reason}) do
    {:error, Error.network_error(reason)}
  end

  # Parse Server-Sent Events format
  defp parse_sse_chunk(data) do
    events =
      data
      |> String.split("\n\n")
      |> Enum.filter(&(String.trim(&1) != ""))
      |> Enum.map(&parse_sse_event/1)
      |> Enum.filter(&(&1 != nil))

    {:ok, events}
  rescue
    _ -> :error
  end

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
end
