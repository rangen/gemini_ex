#!/usr/bin/env elixir

# Demo script for the Gemini Elixir client
# Run with: elixir demo.exs
# Requires GEMINI_API_KEY environment variable

Mix.install([
  {:gemini, path: "."}
])

defmodule GeminiDemo do
  alias Gemini.Types.{GenerationConfig, SafetySetting}

  def run do
    IO.puts("🤖 Gemini Elixir Client Demo")
    IO.puts("=" <> String.duplicate("=", 50))

    # Check if API key is configured
    case Gemini.Config.api_key() do
      nil ->
        IO.puts("❌ No API key found. Please set GEMINI_API_KEY environment variable.")
        System.halt(1)

      _key ->
        IO.puts("✅ API key configured")
    end

    demo_models()
    demo_simple_generation()
    demo_configured_generation()
    demo_chat_session()
    demo_token_counting()

    IO.puts("\n🎉 Demo completed!")
  end

  defp demo_models do
    section("Model Information")

    IO.puts("Listing available models...")
    case Gemini.list_models() do
      {:ok, response} ->
        IO.puts("Found #{length(response.models)} models:")
        response.models
        |> Enum.take(3)
        |> Enum.each(fn model ->
          IO.puts("  • #{model.display_name} (#{model.name})")
          IO.puts("    Input limit: #{format_number(model.input_token_limit)} tokens")
          IO.puts("    Output limit: #{format_number(model.output_token_limit)} tokens")
        end)

      {:error, error} ->
        IO.puts("❌ Error listing models: #{error.message}")
    end

    IO.puts("\nChecking specific model...")
    case Gemini.get_model("gemini-2.0-flash") do
      {:ok, model} ->
        IO.puts("✅ Found #{model.display_name}")
        IO.puts("   #{model.description}")

      {:error, error} ->
        IO.puts("❌ Error getting model: #{error.message}")
    end
  end

  defp demo_simple_generation do
    section("Simple Text Generation")

    prompts = [
      "Write a haiku about programming",
      "Explain quantum computing in one sentence",
      "What's the capital of Japan?"
    ]

    Enum.each(prompts, fn prompt ->
      IO.puts("💭 Prompt: #{prompt}")

      case Gemini.text(prompt) do
        {:ok, text} ->
          IO.puts("🤖 Response: #{text}")

        {:error, error} ->
          IO.puts("❌ Error: #{error.message}")
      end

      IO.puts("")
    end)
  end

  defp demo_configured_generation do
    section("Configured Generation")

    # Creative mode
    IO.puts("🎨 Creative mode (high temperature):")
    config = GenerationConfig.creative(max_output_tokens: 100)

    case Gemini.text("Write a creative opening line for a sci-fi novel", generation_config: config) do
      {:ok, text} ->
        IO.puts("🤖 #{text}")

      {:error, error} ->
        IO.puts("❌ Error: #{error.message}")
    end

    # Precise mode
    IO.puts("\n🎯 Precise mode (low temperature):")
    config = GenerationConfig.precise(max_output_tokens: 50)

    case Gemini.text("What is 15 * 23?", generation_config: config) do
      {:ok, text} ->
        IO.puts("🤖 #{text}")

      {:error, error} ->
        IO.puts("❌ Error: #{error.message}")
    end
  end

  defp demo_chat_session do
    section("Chat Session")

    case Gemini.chat() do
      {:ok, chat} ->
        IO.puts("💬 Starting chat session...")

        # First message
        {:ok, response, chat} = Gemini.send_message(chat, "Hi! I'm learning about Elixir. Can you help?")
        {:ok, text} = Gemini.extract_text(response)
        IO.puts("🧑 User: Hi! I'm learning about Elixir. Can you help?")
        IO.puts("🤖 Assistant: #{text}")

        # Follow-up message
        {:ok, response, _chat} = Gemini.send_message(chat, "What's the difference between processes and threads in Elixir?")
        {:ok, text} = Gemini.extract_text(response)
        IO.puts("\n🧑 User: What's the difference between processes and threads in Elixir?")
        IO.puts("🤖 Assistant: #{text}")

      {:error, error} ->
        IO.puts("❌ Error starting chat: #{error.message}")
    end
  end

  defp demo_token_counting do
    section("Token Counting")

    texts = [
      "Hello, world!",
      "This is a longer message that should use more tokens than the simple greeting above.",
      "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris."
    ]

    Enum.each(texts, fn text ->
      case Gemini.count_tokens(text) do
        {:ok, count} ->
          IO.puts("📝 Text: \"#{String.slice(text, 0, 50)}#{if String.length(text) > 50, do: "...", else: ""}\"")
          IO.puts("🔢 Tokens: #{count.total_tokens}")

        {:error, error} ->
          IO.puts("❌ Error counting tokens: #{error.message}")
      end

      IO.puts("")
    end)
  end

  defp section(title) do
    IO.puts("\n" <> title)
    IO.puts(String.duplicate("-", String.length(title)))
  end

  defp format_number(num) when is_integer(num) do
    num
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end
end

# Run the demo
GeminiDemo.run()
