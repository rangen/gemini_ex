# Gemini Elixir Client

[![CI](https://github.com/nshkrdotcom/gemini_ex/actions/workflows/elixir.yaml/badge.svg)](https://github.com/nshkrdotcom/gemini_ex/actions/workflows/elixir.yaml)
[![Elixir](https://img.shields.io/badge/elixir-1.18.3-purple.svg)](https://elixir-lang.org)
[![OTP](https://img.shields.io/badge/otp-27.3.3-blue.svg)](https://www.erlang.org)
[![Hex.pm](https://img.shields.io/hexpm/v/gemini.svg)](https://hex.pm/packages/gemini)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-purple.svg)](https://hexdocs.pm/gemini)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/nshkrdotcom/gemini_ex/blob/main/LICENSE)

A comprehensive Elixir client for Google's Gemini AI API with dual authentication support, advanced streaming capabilities, type safety, and built-in telemetry.

## ✨ Features

- **🔐 Dual Authentication**: Seamless support for both Gemini API keys and Vertex AI OAuth/Service Accounts
- **⚡ Advanced Streaming**: Production-grade Server-Sent Events streaming with real-time processing
- **🛡️ Type Safety**: Complete type definitions with runtime validation
- **📊 Built-in Telemetry**: Comprehensive observability and metrics out of the box
- **💬 Chat Sessions**: Multi-turn conversation management with state persistence
- **🎭 Multimodal**: Full support for text, image, audio, and video content
- **🚀 Production Ready**: Robust error handling, retry logic, and performance optimizations
- **🔧 Flexible Configuration**: Environment variables, application config, and per-request overrides

## 📦 Installation

Add `gemini` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:gemini_ex, "~> 0.0.2"}
  ]
end
```

## 🚀 Quick Start

### Basic Configuration

Configure your API key in `config/runtime.exs`:

```elixir
import Config

config :gemini_ex,
  api_key: System.get_env("GEMINI_API_KEY")
```

Or set the environment variable:

```bash
export GEMINI_API_KEY="your_api_key_here"
```

### Simple Content Generation

```elixir
# Basic text generation
{:ok, response} = Gemini.generate("Tell me about Elixir programming")
{:ok, text} = Gemini.extract_text(response)
IO.puts(text)

# With options
{:ok, response} = Gemini.generate("Explain quantum computing", [
  model: "gemini-1.5-pro",
  temperature: 0.7,
  max_output_tokens: 1000
])
```

### Advanced Streaming

```elixir
# Start a streaming session
{:ok, stream_id} = Gemini.stream_generate("Write a long story about AI", [
  on_chunk: fn chunk -> IO.write(chunk) end,
  on_complete: fn -> IO.puts("\n✅ Stream complete!") end,
  on_error: fn error -> IO.puts("❌ Error: #{inspect(error)}") end
])

# Stream management
Gemini.Streaming.pause_stream(stream_id)
Gemini.Streaming.resume_stream(stream_id)
Gemini.Streaming.stop_stream(stream_id)
```

### Multi-turn Conversations

```elixir
# Create a chat session
{:ok, session} = Gemini.create_chat_session([
  model: "gemini-1.5-pro",
  system_instruction: "You are a helpful programming assistant."
])

# Send messages
{:ok, response1} = Gemini.send_message(session, "What is functional programming?")
{:ok, response2} = Gemini.send_message(session, "Show me an example in Elixir")

# Get conversation history
history = Gemini.get_conversation_history(session)
```

## 🔐 Authentication

### Gemini API Key (Recommended for Development)

```elixir
# Environment variable (recommended)
export GEMINI_API_KEY="your_api_key"

# Application config
config :gemini_ex, api_key: "your_api_key"

# Per-request override
Gemini.generate("Hello", api_key: "specific_key")
```

### Vertex AI (Recommended for Production)

```elixir
# Service Account JSON file
export VERTEX_SERVICE_ACCOUNT="/path/to/service-account.json"
export VERTEX_PROJECT_ID="your-gcp-project"
export VERTEX_LOCATION="us-central1"

# Application config
config :gemini_ex, :auth,
  type: :vertex_ai,
  credentials: %{
    service_account_key: System.get_env("VERTEX_SERVICE_ACCOUNT"),
    project_id: System.get_env("VERTEX_PROJECT_ID"),
    location: "us-central1"
  }
```

## 📚 Documentation

- **[API Reference](https://hexdocs.pm/gemini)** - Complete function documentation
- **[Architecture Guide](https://hexdocs.pm/gemini/architecture.html)** - System design and components
- **[Authentication System](https://hexdocs.pm/gemini/authentication_system.html)** - Detailed auth configuration
- **[Examples](https://github.com/nshkrdotcom/gemini_ex/tree/main/examples)** - Working code examples

## 🏗️ Architecture

The library features a modular, layered architecture:

- **Authentication Layer**: Multi-strategy auth with automatic credential resolution
- **Coordination Layer**: Unified API coordinator for all operations
- **Streaming Layer**: Advanced SSE processing with state management
- **HTTP Layer**: Dual client system for standard and streaming requests
- **Type Layer**: Comprehensive schemas with runtime validation

## 🔧 Advanced Usage

### Custom Model Configuration

```elixir
# List available models
{:ok, models} = Gemini.list_models()

# Get model details
{:ok, model_info} = Gemini.get_model("gemini-1.5-pro")

# Count tokens
{:ok, token_count} = Gemini.count_tokens("Your text here", model: "gemini-1.5-pro")
```

### Multimodal Content

```elixir
# Text with images
content = [
  %{type: "text", text: "What's in this image?"},
  %{type: "image", source: %{type: "base64", data: base64_image}}
]

{:ok, response} = Gemini.generate(content)
```

### Error Handling

```elixir
case Gemini.generate("Hello world") do
  {:ok, response} -> 
    # Handle success
    {:ok, text} = Gemini.extract_text(response)
    
  {:error, %Gemini.Error{type: :rate_limit} = error} -> 
    # Handle rate limiting
    IO.puts("Rate limited. Retry after: #{error.retry_after}")
    
  {:error, %Gemini.Error{type: :authentication} = error} -> 
    # Handle auth errors
    IO.puts("Auth error: #{error.message}")
    
  {:error, error} -> 
    # Handle other errors
    IO.puts("Unexpected error: #{inspect(error)}")
end
```

## 🧪 Testing

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover

# Run integration tests (requires API key)
GEMINI_API_KEY="your_key" mix test --only integration
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/nshkrdotcom/gemini_ex/blob/main/LICENSE) file for details.

## 🙏 Acknowledgments

- Google AI team for the Gemini API
- Elixir community for excellent tooling and libraries
- Contributors and maintainers
