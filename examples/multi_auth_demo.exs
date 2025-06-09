#!/usr/bin/env elixir

# Multi-Authentication Demo
# Shows concurrent usage of both Gemini API and Vertex AI authentication
# Set environment variables as needed:
# - GEMINI_API_KEY for Gemini API
# - VERTEX_JSON_FILE for Vertex AI

Mix.install([
  {:gemini, path: "."}
])

defmodule MultiAuthDemo do
  @moduledoc """
  Demonstrates the multi-authentication capabilities of the unified Gemini client.
  
  This example shows how to use both Gemini API and Vertex AI authentication
  simultaneously, which is the key differentiator of this implementation.
  """

  def run do
    IO.puts("🔄 Gemini Multi-Authentication Demo")
    IO.puts("=" <> String.duplicate("=", 50))

    # Check available authentication methods
    check_available_auth_methods()
    
    # Demonstrate concurrent usage
    demonstrate_concurrent_usage()
    
    # Show configuration flexibility
    demonstrate_explicit_auth_selection()

    IO.puts("\n🎉 Multi-auth demo completed!")
  end

  defp check_available_auth_methods do
    IO.puts("\n🔍 Available Authentication Methods")
    IO.puts("-" <> String.duplicate("-", 40))

    gemini_available = not is_nil(System.get_env("GEMINI_API_KEY"))
    vertex_available = not is_nil(System.get_env("VERTEX_JSON_FILE"))

    IO.puts("Gemini API: #{if gemini_available, do: "✅ Available", else: "❌ Not configured"}")
    IO.puts("Vertex AI:  #{if vertex_available, do: "✅ Available", else: "❌ Not configured"}")

    if not (gemini_available or vertex_available) do
      IO.puts("\n⚠️  No authentication configured. Please set:")
      IO.puts("   - GEMINI_API_KEY for Gemini API, or")
      IO.puts("   - VERTEX_JSON_FILE for Vertex AI")
      System.halt(1)
    end

    {gemini_available, vertex_available}
  end

  defp demonstrate_concurrent_usage do
    IO.puts("\n🚀 Concurrent API Usage")
    IO.puts("-" <> String.duplicate("-", 40))

    # Test the same operation with different auth strategies if both are available
    gemini_available = not is_nil(System.get_env("GEMINI_API_KEY"))
    vertex_available = not is_nil(System.get_env("VERTEX_JSON_FILE"))

    tasks = []

    # Add Gemini API task if available
    tasks = if gemini_available do
      IO.puts("🔑 Starting Gemini API task...")
      task = Task.async(fn ->
        case Gemini.text("What's 2+2?", auth: :gemini) do
          {:ok, text} -> {:gemini, :success, text}
          {:error, error} -> {:gemini, :error, format_error(error)}
        end
      end)
      [task | tasks]
    else
      tasks
    end

    # Add Vertex AI task if available
    tasks = if vertex_available do
      IO.puts("🔑 Starting Vertex AI task...")
      task = Task.async(fn ->
        case Gemini.text("What's 3+3?", auth: :vertex_ai) do
          {:ok, text} -> {:vertex_ai, :success, text}
          {:error, error} -> {:vertex_ai, :error, format_error(error)}
        end
      end)
      [task | tasks]
    else
      tasks
    end

    # Wait for all tasks to complete
    IO.puts("⏳ Waiting for concurrent requests to complete...")
    results = Task.await_many(tasks, 30_000)

    # Display results
    IO.puts("\n📊 Results:")
    Enum.each(results, fn
      {auth_type, :success, text} ->
        IO.puts("✅ #{auth_type}: #{String.slice(text, 0, 100)}")
      {auth_type, :error, error} ->
        IO.puts("❌ #{auth_type}: #{error}")
    end)
  end

  defp demonstrate_explicit_auth_selection do
    IO.puts("\n⚙️  Explicit Authentication Selection")
    IO.puts("-" <> String.duplicate("-", 40))

    # Show how to explicitly choose auth strategy per request
    operations = [
      {"List models", fn -> Gemini.list_models() end},
      {"Get specific model", fn -> Gemini.get_model("gemini-2.0-flash") end},
      {"Count tokens", fn -> Gemini.count_tokens("Hello world") end}
    ]

    Enum.each(operations, fn {operation, func} ->
      IO.puts("🔧 #{operation}:")
      
      case func.() do
        {:ok, _result} ->
          IO.puts("   ✅ Success with default authentication")
        {:error, error} ->
          IO.puts("   ❌ Error: #{format_error(error)}")
      end
    end)
  end

  defp format_error(error) do
    cond do
      is_map(error) and Map.has_key?(error, "message") -> error["message"]
      is_binary(error) -> error
      true -> inspect(error)
    end
  end
end

# Run the demo
MultiAuthDemo.run()