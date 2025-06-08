#!/usr/bin/env elixir

# Simple Live Streaming Demo
# Usage: mix run streaming_demo.exs

defmodule StreamingDemo do
  def run do
    IO.puts("🌊 Gemini Streaming Demo")
    IO.puts("========================")
    
    # Configure authentication
    case configure_auth() do
      :ok ->
        IO.puts("✅ Authentication configured successfully")
        start_streaming_demo()
      {:error, reason} ->
        IO.puts("❌ Authentication failed: #{reason}")
        System.halt(1)
    end
  end

  defp configure_auth do
    cond do
      vertex_key = System.get_env("VERTEX_JSON_FILE") ->
        IO.puts("🔑 Using Vertex AI authentication")
        Gemini.configure(:vertex_ai, %{
          service_account_key: vertex_key,
          project_id: System.get_env("VERTEX_PROJECT_ID"),
          location: System.get_env("VERTEX_LOCATION") || "us-central1"
        })
        :ok
        
      api_key = System.get_env("GEMINI_API_KEY") ->
        IO.puts("🔑 Using Gemini API authentication")
        Gemini.configure(:gemini, %{api_key: api_key})
        :ok
        
      true ->
        {:error, "No authentication credentials found. Set VERTEX_JSON_FILE or GEMINI_API_KEY"}
    end
  end

  defp start_streaming_demo do
    prompt = "Write a short creative story about a robot learning to paint. Make it about 3 paragraphs."
    
    IO.puts("\n📝 Prompt: #{prompt}")
    IO.puts("\n🚀 Starting stream...\n")
    
    case Gemini.start_stream(prompt) do
      {:ok, stream_id} ->
        IO.puts("Stream ID: #{stream_id}")
        
        # Subscribe to the stream
        :ok = Gemini.subscribe_stream(stream_id)
        
        # Let's also check stream info
        case Gemini.get_stream_status(stream_id) do
          {:ok, info} -> IO.puts("Stream info: #{inspect(info)}")
          _ -> :ok
        end
        
        # Listen for streaming events
        listen_for_events()
        
      {:error, reason} ->
        IO.puts("❌ Failed to start stream: #{inspect(reason)}")
    end
  end

  defp listen_for_events do
    receive do
      {:stream_event, _stream_id, %{type: :data, data: data}} ->
        # Extract text content from the streaming response
        text_content = extract_text_from_stream_data(data)
        if text_content && text_content != "" do
          IO.write(text_content)
        end
        listen_for_events()
        
      {:stream_complete, _stream_id} ->
        IO.puts("\n\n✅ Stream completed!")
        
      {:stream_error, _stream_id, error} ->
        IO.puts("\n❌ Stream error: #{inspect(error)}")
        
    after
      30_000 ->
        IO.puts("\n⏰ Stream timeout after 30 seconds")
    end
  end

  defp extract_text_from_stream_data(%{"candidates" => [%{"content" => %{"parts" => parts}} | _]}) do
    parts
    |> Enum.find(&Map.has_key?(&1, "text"))
    |> case do
      %{"text" => text} -> text
      _ -> nil
    end
  end

  defp extract_text_from_stream_data(_), do: nil
end

StreamingDemo.run()