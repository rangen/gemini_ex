#!/usr/bin/env elixir

Mix.install([
  {:gemini, path: "."},
  {:telemetry, "~> 1.2"}
])

defmodule TelemetryDemo do
  @moduledoc """
  Demonstration of Gemini telemetry events.

  This script shows how telemetry events are emitted during API calls.
  """

  require Logger

  def run do
    IO.puts("\n🔍 Gemini Telemetry Demonstration")
    IO.puts("=" |> String.duplicate(50))

    # Enable telemetry
    Application.put_env(:gemini, :telemetry_enabled, true)

    # Attach telemetry handlers
    attach_telemetry_handlers()

    # Demonstrate configuration detection
    demonstrate_config()

    # Demonstrate telemetry functions
    demonstrate_telemetry_functions()

    IO.puts("\n✅ Telemetry demonstration complete!")
    IO.puts("\nNote: To see actual API telemetry events, set GEMINI_API_KEY and run live tests:")
    IO.puts("  export GEMINI_API_KEY='your-key'")
    IO.puts("  mix test test/live_api_test.exs --include live_api")
  end

  defp attach_telemetry_handlers do
    IO.puts("\n📡 Attaching telemetry handlers...")

    events = [
      [:gemini, :request, :start],
      [:gemini, :request, :stop],
      [:gemini, :request, :exception],
      [:gemini, :stream, :start],
      [:gemini, :stream, :chunk],
      [:gemini, :stream, :stop],
      [:gemini, :stream, :exception]
    ]

    Enum.each(events, fn event ->
      :telemetry.attach(
        "demo-#{Enum.join(event, "-")}",
        event,
        &handle_telemetry_event/4,
        %{}
      )
    end)

    IO.puts("   ✓ Attached handlers for #{length(events)} event types")
  end

  defp handle_telemetry_event(event, measurements, metadata, _config) do
    event_name = Enum.join(event, ":")
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    IO.puts("🔔 [#{timestamp}] #{event_name}")
    IO.puts("   📊 Measurements: #{inspect(measurements, pretty: true)}")
    IO.puts("   📋 Metadata: #{inspect(metadata, pretty: true)}")
    IO.puts("")
  end

  defp demonstrate_config do
    IO.puts("\n⚙️  Telemetry Configuration:")
    IO.puts("   Telemetry enabled: #{Gemini.Config.telemetry_enabled?()}")

    # Test disabling telemetry
    Application.put_env(:gemini, :telemetry_enabled, false)
    IO.puts("   After disabling: #{Gemini.Config.telemetry_enabled?()}")

    # Re-enable for demo
    Application.put_env(:gemini, :telemetry_enabled, true)
    IO.puts("   Re-enabled: #{Gemini.Config.telemetry_enabled?()}")
  end

  defp demonstrate_telemetry_functions do
    IO.puts("\n🔧 Telemetry Helper Functions:")

    # Test content classification
    text_content = "Hello, world!"
    multimodal_content = [%{parts: [%{text: "Hello"}, %{image: "data"}]}]

    IO.puts("   Text content type: #{Gemini.Telemetry.classify_contents(text_content)}")
    IO.puts("   Multimodal content type: #{Gemini.Telemetry.classify_contents(multimodal_content)}")

    # Test stream ID generation
    stream_id = Gemini.Telemetry.generate_stream_id()
    IO.puts("   Generated stream ID: #{stream_id}")

    # Test metadata building
    opts = [model: "gemini-2.0-flash", function: :generate_content, contents_type: :text]
    metadata = Gemini.Telemetry.build_request_metadata("https://example.com/api", :post, opts)
    IO.puts("   Request metadata sample:")
    IO.puts("     Model: #{metadata.model}")
    IO.puts("     Function: #{metadata.function}")
    IO.puts("     Contents type: #{metadata.contents_type}")

    # Demonstrate manual telemetry event
    IO.puts("\n🧪 Emitting test telemetry event...")

    test_measurements = %{
      duration: 1250,
      status: 200
    }

    test_metadata = %{
      url: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent",
      method: :post,
      model: "gemini-2.0-flash",
      function: :generate_content,
      contents_type: :text
    }

    Gemini.Telemetry.execute([:gemini, :request, :stop], test_measurements, test_metadata)
  end
end

# Run the demonstration
TelemetryDemo.run()
