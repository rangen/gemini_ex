# Gemini

**Elixir client for Google's Gemini API**

A comprehensive, production-ready Elixir library for interacting with Google's Gemini generative AI API. Supports text generation, multimodal content, streaming, chat sessions, and more.

## Features

- ✅ **Text Generation** - Generate text content with configurable parameters
- ✅ **Multimodal Support** - Work with text, images, and other media types
- ✅ **Streaming Responses** - Real-time content generation with Server-Sent Events
- ✅ **Chat Sessions** - Multi-turn conversations with context preservation
- ✅ **Model Management** - List and query available Gemini models
- ✅ **Token Counting** - Calculate token usage for cost estimation
- ✅ **Safety Controls** - Configure content safety settings
- ✅ **Error Handling** - Structured error types with detailed information
- ✅ **Type Safety** - Full TypeSpec coverage with typed structs
- ✅ **Configuration** - Flexible configuration via environment variables or application config

## Installation

Add `gemini` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:gemini, "~> 0.1.0"}
  ]
end
```

## Quick Start

### 1. Get an API Key

Get your Gemini API key from [Google AI Studio](https://aistudio.google.com/app/apikey).

### 2. Configure

Set your API key either as an environment variable:

```bash
export GEMINI_API_KEY="your_api_key_here"
```

Or in your application configuration:

```elixir
config :gemini, api_key: "your_api_key_here"
```

### 3. Generate Content

```elixir
# Simple text generation
{:ok, text} = Gemini.text("What is the capital of France?")
IO.puts(text)
# => "The capital of France is Paris."

# More detailed response
{:ok, response} = Gemini.generate("Explain quantum physics")
{:ok, text} = Gemini.extract_text(response)
```

## Usage Examples

### Basic Text Generation

```elixir
# Simple text generation
{:ok, text} = Gemini.text("Write a haiku about programming")

# With configuration
alias Gemini.Types.GenerationConfig

config = GenerationConfig.creative(max_output_tokens: 100)
{:ok, response} = Gemini.generate("Tell me a story", generation_config: config)
```

### Multimodal Content

```elixir
alias Gemini.Types.Content

# Text and image
contents = [
  Content.text("What's in this image?"),
  Content.image("/path/to/image.jpg")
]
{:ok, response} = Gemini.generate(contents)

# Convenience function for multiple images
prompt = Gemini.multimodal_prompt(
  "Compare these images",
  ["/path/to/image1.jpg", "/path/to/image2.png"]
)
{:ok, response} = Gemini.generate(prompt)
```

### Chat Sessions

```elixir
# Start a chat
{:ok, chat} = Gemini.chat()

# Send messages
{:ok, response, chat} = Gemini.send_message(chat, "Hello! I'm learning Elixir.")
{:ok, response, chat} = Gemini.send_message(chat, "What are the main concepts?")
```

### Streaming

```elixir
# Stream responses for long content
{:ok, responses} = Gemini.stream_generate("Write a long essay about space exploration")

# Process each chunk as it arrives
Enum.each(responses, fn response ->
  case Gemini.extract_text(response) do
    {:ok, text} -> IO.write(text)
    _ -> :ok
  end
end)
```

### Model Information

```elixir
# List available models
{:ok, models_response} = Gemini.list_models()
model_names = Enum.map(models_response.models, & &1.name)

# Get specific model info
{:ok, model} = Gemini.get_model("gemini-2.0-flash")
IO.inspect(model.input_token_limit)

# Check if model exists
{:ok, exists} = Gemini.model_exists?("gemini-2.0-flash")
```

### Safety and Configuration

```elixir
alias Gemini.Types.{GenerationConfig, SafetySetting}

# Configure generation parameters
config = GenerationConfig.new(
  temperature: 0.7,
  max_output_tokens: 1000,
  top_p: 0.9
)

# Set safety settings
safety_settings = SafetySetting.permissive()

{:ok, response} = Gemini.generate(
  "Write about historical events",
  generation_config: config,
  safety_settings: safety_settings
)
```

### Token Counting

```elixir
# Count tokens for cost estimation
{:ok, count} = Gemini.count_tokens("This is a test message")
IO.puts("Tokens: #{count.total_tokens}")

# With multimodal content
contents = [Content.text("Describe"), Content.image("image.jpg")]
{:ok, count} = Gemini.count_tokens(contents)
```

## Configuration Options

Configure the client in your `config/config.exs`:

```elixir
config :gemini,
  api_key: "your_api_key",
  base_url: "https://generativelanguage.googleapis.com/v1beta",
  default_model: "gemini-2.0-flash",
  timeout: 30_000
```

### Environment Variables

- `GEMINI_API_KEY` - Your Gemini API key (overrides config)

## Error Handling

The library provides structured error handling:

```elixir
case Gemini.text("Hello") do
  {:ok, text} ->
    IO.puts("Success: #{text}")
  
  {:error, %Gemini.Error{type: :api_error, message: message}} ->
    IO.puts("API Error: #{message}")
  
  {:error, %Gemini.Error{type: :network_error, message: message}} ->
    IO.puts("Network Error: #{message}")
  
  {:error, %Gemini.Error{type: :config_error, message: message}} ->
    IO.puts("Config Error: #{message}")
end
```

Error types include:
- `:api_error` - Errors from the Gemini API
- `:network_error` - Connection or HTTP errors  
- `:config_error` - Configuration issues
- `:validation_error` - Request validation errors
- `:invalid_response` - Response parsing errors

## API Reference

### Core Functions

- `Gemini.generate/2` - Generate content with full options
- `Gemini.text/2` - Simple text generation
- `Gemini.stream_generate/2` - Streaming content generation
- `Gemini.count_tokens/2` - Count tokens in content

### Chat Functions

- `Gemini.chat/1` - Start a chat session
- `Gemini.send_message/2` - Send message in chat

### Model Functions

- `Gemini.list_models/1` - List available models
- `Gemini.get_model/1` - Get model information
- `Gemini.model_exists?/1` - Check if model exists

### Utility Functions

- `Gemini.extract_text/1` - Extract text from response
- `Gemini.multimodal_prompt/2` - Create multimodal prompts

## Type System

The library uses TypedStruct for compile-time type checking:

```elixir
alias Gemini.Types.{Content, Part, GenerationConfig, SafetySetting}

# All types are fully specified
content = %Content{
  role: "user",
  parts: [%Part{text: "Hello"}]
}
```

## Testing

### Running Unit Tests

Run the standard test suite with mocked API responses:

```bash
mix test
```

This runs all tests except live API tests, using mock adapters for fast, reliable testing.

### Running Live API Tests

To test against the actual Google APIs, you can run live integration tests. These require valid credentials and will make real API calls.

#### Gemini API Live Tests

Set up your Gemini API key and run live tests:

```bash
export GEMINI_API_KEY="your_api_key_here"
mix test --include live_api
```

#### Vertex AI Live Tests

Set up your Google Cloud service account and run live tests:

```bash
export VERTEX_JSON_FILE="/path/to/your/service-account.json"
export VERTEX_PROJECT_ID="your-gcp-project-id"  # Optional, auto-detected from JSON
export VERTEX_LOCATION="us-central1"            # Optional, defaults to us-central1
mix test --include live_api
```

#### Running Both Authentication Methods

To test both Gemini API and Vertex AI authentication:

```bash
export GEMINI_API_KEY="your_api_key_here"
export VERTEX_JSON_FILE="/path/to/your/service-account.json"
mix test --include live_api
```

#### Running Specific Live API Tests

Run only the live API test file:

```bash
# With environment variables set
mix test test/live_api_test.exs --include live_api
```

**Note:** Live API tests make real requests to Google's services and may incur costs. Use test credentials when possible.

## Examples

See [EXAMPLES.md](EXAMPLES.md) for comprehensive usage examples.

## Documentation

Generate documentation:

```bash
mix docs
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Built for the Google Gemini API
- Uses Finch for HTTP client functionality
- TypedStruct for type safety
- Jason for JSON handling
