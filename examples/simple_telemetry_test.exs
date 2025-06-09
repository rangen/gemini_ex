defmodule TelemetryDemo do
  @moduledoc """
  Simple telemetry demonstration for the Gemini library.
  """

  def run do
    IO.puts("\n🔍 Gemini Telemetry Test")
    IO.puts("=" |> String.duplicate(30))

    # Test configuration
    Application.put_env(:gemini, :telemetry_enabled, true)
    IO.puts("Telemetry enabled: #{Gemini.Config.telemetry_enabled?()}")

    # Test helper functions
    IO.puts("\n🔧 Helper Functions:")
    stream_id = Gemini.Telemetry.generate_stream_id()
    IO.puts("Stream ID: #{stream_id}")

    content_type = Gemini.Telemetry.classify_contents("Hello world")
    IO.puts("Content type: #{content_type}")

    # Test telemetry emission (with handler)
    :telemetry.attach("test-handler", [:test, :event], fn _, measurements, metadata, _ ->
      IO.puts("📡 Event captured: #{inspect(measurements)} | #{inspect(metadata)}")
    end, nil)

    IO.puts("\n📡 Testing telemetry emission:")
    Gemini.Telemetry.execute([:test, :event], %{value: 42}, %{source: "demo"})

    :telemetry.detach("test-handler")

    IO.puts("\n✅ Telemetry demo complete!")
  end
end

TelemetryDemo.run()
