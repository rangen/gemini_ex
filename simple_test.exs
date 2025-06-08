#!/usr/bin/env elixir

# Simple test to see raw streaming
defmodule SimpleTest do
  def run do
    IO.puts("Testing basic streaming...")
    
    # Configure auth - try Gemini API first
    cond do
      api_key = System.get_env("GEMINI_API_KEY") ->
        IO.puts("Using Gemini API")
        Gemini.configure(:gemini, %{api_key: api_key})
        
      vertex_key = System.get_env("VERTEX_JSON_FILE") ->
        IO.puts("Using Vertex AI")
        Gemini.configure(:vertex_ai, %{
          service_account_key: vertex_key,
          project_id: System.get_env("VERTEX_PROJECT_ID"),
          location: System.get_env("VERTEX_LOCATION") || "us-central1"
        })
        
      true ->
        IO.puts("No auth found")
        System.halt(1)
    end
    
    # Try a simple streaming request
    prompt = "Count from 1 to 5."
    
    IO.puts("Prompt: #{prompt}")
    
    case Gemini.start_stream(prompt) do
      {:ok, stream_id} ->
        IO.puts("Started stream: #{stream_id}")
        :ok = Gemini.subscribe_stream(stream_id)
        
        # Listen for ALL messages
        listen_all()
        
      {:error, reason} ->
        IO.puts("Error: #{inspect(reason)}")
    end
  end
  
  defp listen_all do
    receive do
      msg ->
        IO.puts("📨 Received: #{inspect(msg)}")
        listen_all()
    after
      10_000 ->
        IO.puts("⏰ Timeout")
    end
  end
end

SimpleTest.run()