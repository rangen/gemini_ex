defmodule CoordinatorIntegrationTest do
  use ExUnit.Case, async: false

  alias Gemini.APIs.Coordinator

  @moduletag :live_api

  describe "Text generation with real API" do
    test "generate_content works and extract_text succeeds" do
      # Skip if no API key configured
      if System.get_env("GEMINI_API_KEY") do
        prompt = "Say 'Hello World' exactly"

        # Test the full flow that was previously failing
        case Coordinator.generate_content(prompt) do
          {:ok, response} ->
            IO.puts("✅ generate_content succeeded")
            IO.puts("Response type: #{inspect(response.__struct__)}")

            # This was the failing part - extract_text should now work
            case Coordinator.extract_text(response) do
              {:ok, text} ->
                IO.puts("✅ extract_text succeeded: '#{text}'")
                assert String.contains?(text, "Hello")

              {:error, reason} ->
                flunk("extract_text failed: #{inspect(reason)}")
            end

          {:error, reason} ->
            flunk("generate_content failed: #{inspect(reason)}")
        end
      else
        IO.puts("Skipping live API test - no GEMINI_API_KEY configured")
      end
    end

    test "list_models works and returns models" do
      if System.get_env("GEMINI_API_KEY") do
        case Coordinator.list_models() do
          {:ok, response} ->
            IO.puts("✅ list_models succeeded")
            IO.puts("Response type: #{inspect(response.__struct__)}")
            assert is_struct(response)

          {:error, reason} ->
            flunk("list_models failed: #{inspect(reason)}")
        end
      else
        IO.puts("Skipping live API test - no GEMINI_API_KEY configured")
      end
    end
  end
end
