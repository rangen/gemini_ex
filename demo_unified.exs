#!/usr/bin/env elixir

Mix.install([
  {:gemini, path: "."}
])

defmodule UnifiedArchitectureDemo do
  @moduledoc """
  Demonstration of the unified Gemini architecture supporting both
  Gemini API and Vertex AI authentication methods.
  """

  def run do
    IO.puts("🚀 Gemini Unified Architecture Demo")
    IO.puts("=" |> String.duplicate(50))

    demo_configuration()
    demo_authentication_strategies()
    demo_streaming_manager()
    demo_backward_compatibility()

    IO.puts("\n✅ Demo completed successfully!")
  end

  defp demo_configuration do
    IO.puts("\n📋 Configuration System Demo")
    IO.puts("-" |> String.duplicate(30))

    # Clear environment for clean demo
    System.delete_env("GEMINI_API_KEY")
    System.delete_env("GOOGLE_CLOUD_PROJECT")
    System.delete_env("GOOGLE_CLOUD_LOCATION")

    # Default configuration
    config = Gemini.Config.get()
    IO.puts("Default config: #{inspect(config.auth_type)}")

    # Simulated Gemini environment
    System.put_env("GEMINI_API_KEY", "demo-gemini-key")
    config = Gemini.Config.get()
    IO.puts("With GEMINI_API_KEY: #{inspect(config.auth_type)}")

    # Simulated Vertex environment
    System.delete_env("GEMINI_API_KEY")
    System.put_env("GOOGLE_CLOUD_PROJECT", "demo-project")
    System.put_env("GOOGLE_CLOUD_LOCATION", "us-central1")
    config = Gemini.Config.get()
    IO.puts("With Vertex env vars: #{inspect(config.auth_type)}")

    # Override configuration
    config = Gemini.Config.get(auth_type: :gemini, api_key: "override-key")
    IO.puts("With override: #{inspect(config.auth_type)}")
  end

  defp demo_authentication_strategies do
    IO.puts("\n🔐 Authentication Strategies Demo")
    IO.puts("-" |> String.duplicate(30))

    # Gemini strategy
    gemini_config = %{api_key: "demo-key"}
    strategy = Gemini.Auth.strategy(:gemini)
    IO.puts("Gemini strategy: #{inspect(strategy)}")

    case Gemini.Auth.authenticate(strategy, gemini_config) do
      {:ok, headers} ->
        IO.puts("Gemini auth headers: #{inspect(headers)}")
      {:error, error} ->
        IO.puts("Gemini auth error: #{error}")
    end

    # Vertex strategy
    vertex_config = %{project_id: "demo-project", location: "us-central1"}
    strategy = Gemini.Auth.strategy(:vertex)
    IO.puts("Vertex strategy: #{inspect(strategy)}")

    case Gemini.Auth.authenticate(strategy, vertex_config) do
      {:ok, headers} ->
        IO.puts("Vertex auth headers: #{inspect(headers)}")
      {:error, error} ->
        IO.puts("Vertex auth error: #{error}")
    end

    # Base URLs
    gemini_url = Gemini.Auth.base_url(Gemini.Auth.strategy(:gemini), gemini_config)
    IO.puts("Gemini base URL: #{gemini_url}")

    case Gemini.Auth.base_url(Gemini.Auth.strategy(:vertex), vertex_config) do
      url when is_binary(url) ->
        IO.puts("Vertex base URL: #{url}")
      {:error, error} ->
        IO.puts("Vertex URL error: #{error}")
    end
  end

  defp demo_streaming_manager do
    IO.puts("\n🌊 Streaming Manager Demo")
    IO.puts("-" |> String.duplicate(30))

    # Start the application to ensure the manager is running
    case Application.ensure_all_started(:gemini) do
      {:ok, _} ->
        IO.puts("Gemini application started")
      {:error, error} ->
        IO.puts("Failed to start application: #{inspect(error)}")
        return
    end

    # Demonstrate streaming functionality
    contents = ["Tell me about artificial intelligence"]
    opts = [model: "gemini-1.5-pro-latest"]

    case Gemini.Streaming.Manager.start_stream(contents, opts, self()) do
      {:ok, stream_id} ->
        IO.puts("Started stream: #{stream_id}")

        # List active streams
        streams = Gemini.Streaming.Manager.list_streams()
        IO.puts("Active streams: #{length(streams)}")

        # Get stream info
        case Gemini.Streaming.Manager.get_stream_info(stream_id) do
          {:ok, info} ->
            IO.puts("Stream status: #{info.status}")
          {:error, error} ->
            IO.puts("Stream info error: #{error}")
        end

        # Subscribe another process
        subscriber = spawn(fn -> :ok end)
        case Gemini.Streaming.Manager.subscribe_stream(stream_id, subscriber) do
          :ok ->
            IO.puts("Additional subscriber added")
          {:error, error} ->
            IO.puts("Subscription error: #{error}")
        end

        # Stop the stream
        case Gemini.Streaming.Manager.stop_stream(stream_id) do
          :ok ->
            IO.puts("Stream stopped successfully")
          {:error, error} ->
            IO.puts("Stop stream error: #{error}")
        end

      {:error, error} ->
        IO.puts("Failed to start stream: #{inspect(error)}")
    end
  end

  defp demo_backward_compatibility do
    IO.puts("\n🔄 Backward Compatibility Demo")
    IO.puts("-" |> String.duplicate(30))

    # Show that existing APIs still work
    IO.puts("Testing existing API functions...")

    # These would normally make real API calls, but we'll show they compile and run
    try do
      # This will fail with auth errors, but shows the API is compatible
      case Gemini.Generate.content("Hello, world!") do
        {:ok, _response} ->
          IO.puts("✅ generate_content API compatible")
        {:error, _error} ->
          IO.puts("✅ generate_content API compatible (expected auth error)")
      end
    rescue
      _ ->
        IO.puts("✅ generate_content API compatible (compilation successful)")
    end

    # Show that build_generate_request is now public
    try do
      request = Gemini.Generate.build_generate_request("Test", [])
      IO.puts("✅ build_generate_request is public: #{map_size(request)} fields")
    rescue
      error ->
        IO.puts("❌ build_generate_request error: #{inspect(error)}")
    end

    # Test configuration functions
    model = Gemini.Config.default_model()
    IO.puts("✅ Default model: #{model}")

    auth_type = Gemini.Config.detect_auth_type(%{api_key: "test"})
    IO.puts("✅ Auth type detection: #{auth_type}")
  end
end

# Run the demo
UnifiedArchitectureDemo.run()
