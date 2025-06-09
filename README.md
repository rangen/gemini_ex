# Gemini Elixir Client

A comprehensive Elixir client for Google's Gemini API, supporting both Gemini API and Vertex AI endpoints.

## Features

- **Dual Authentication**: Support for both Gemini API keys and Vertex AI OAuth/Service Accounts
- **Advanced Streaming**: Production-grade Server-Sent Events streaming with real-time processing
- **Comprehensive APIs**: Models, Content Generation, Token Counting, and more
- **Type Safety**: Full TypeScript-style type definitions with validation
- **Error Handling**: Detailed error types with recovery suggestions
- **Telemetry**: Built-in observability and metrics
- **Chat Sessions**: Multi-turn conversation management
- **Multimodal**: Text, image, audio, and video support

## Quick Start

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:gemini, "~> 1.0"}
  ]
end
```

Configure your API key:

```elixir
config :gemini, api_key: "your_api_key_here"
```

Generate content:

```elixir
{:ok, response} = Gemini.generate("Hello, world!")
{:ok, text} = Gemini.extract_text(response)
IO.puts(text)
```

## Documentation

See the [documentation](https://hexdocs.pm/gemini) for comprehensive guides and API reference.

## License

MIT License - see LICENSE file for details.
