# Gemini Elixir Client Examples

This file contains examples of how to use the Gemini Elixir client.

## Configuration

Set your API key either as an environment variable:
```bash
export GEMINI_API_KEY="your_api_key_here"
```

Or in your config:
```elixir
config :gemini_ex, api_key: "your_api_key_here"
```

## Examples

Start an IEx session in the project:
```bash
cd gemini
iex -S mix
```

### Basic Text Generation
```elixir
# Simple text generation
{:ok, text} = Gemini.text("What is the capital of France?")
IO.puts(text)

# More detailed response
{:ok, response} = Gemini.generate("Explain quantum physics in simple terms")
{:ok, text} = Gemini.extract_text(response)
IO.puts(text)
```

### Model Information
```elixir
# List available models
{:ok, models_response} = Gemini.list_models()
model_names = Enum.map(models_response.models, & &1.name)
IO.inspect(model_names)

# Get specific model info
{:ok, model} = Gemini.get_model("gemini-2.0-flash")
IO.inspect(model)

# Check if model exists
{:ok, exists} = Gemini.model_exists?("gemini-2.0-flash")
IO.puts("Model exists: #{exists}")
```

### Generation Configuration
```elixir
alias Gemini.Types.GenerationConfig

# Creative generation
config = GenerationConfig.creative()
{:ok, text} = Gemini.text("Write a creative story about a robot", generation_config: config)
IO.puts(text)

# Precise generation
config = GenerationConfig.precise()
{:ok, text} = Gemini.text("What is 2+2?", generation_config: config)
IO.puts(text)

# Custom configuration
config = GenerationConfig.new(
  temperature: 0.5,
  max_output_tokens: 100,
  top_p: 0.9
)
{:ok, text} = Gemini.text("Explain machine learning", generation_config: config)
```

### Safety Settings
```elixir
alias Gemini.Types.SafetySetting

# Use permissive safety settings
safety_settings = SafetySetting.permissive()
{:ok, text} = Gemini.text("Write about historical conflicts", safety_settings: safety_settings)
```

### Chat Sessions
```elixir
# Start a chat session
{:ok, chat} = Gemini.chat()

# Send messages
{:ok, response, chat} = Gemini.send_message(chat, "Hello! My name is Alice.")
{:ok, text} = Gemini.extract_text(response)
IO.puts("Assistant: #{text}")

{:ok, response, chat} = Gemini.send_message(chat, "What's my name?")
{:ok, text} = Gemini.extract_text(response)
IO.puts("Assistant: #{text}")
```

### Multimodal Content
```elixir
alias Gemini.Types.Content

# Create multimodal content with text and image
# (You'll need an actual image file for this to work)
contents = [
  Content.text("What's in this image?"),
  Content.image("/path/to/your/image.jpg")
]
{:ok, response} = Gemini.generate(contents)
{:ok, text} = Gemini.extract_text(response)
IO.puts(text)

# Using the convenience function
prompt = Gemini.multimodal_prompt(
  "Describe these images",
  ["/path/to/image1.jpg", "/path/to/image2.png"]
)
{:ok, response} = Gemini.generate(prompt)
```

### Token Counting
```elixir
# Count tokens in content
{:ok, count_response} = Gemini.count_tokens("This is a test message for token counting.")
IO.puts("Total tokens: #{count_response.total_tokens}")

# Count tokens with multimodal content
contents = [
  Content.text("Analyze this image:"),
  Content.image("/path/to/image.jpg")
]
{:ok, count_response} = Gemini.count_tokens(contents)
IO.puts("Total tokens: #{count_response.total_tokens}")
```

### Streaming Responses
```elixir
# Stream content generation (returns list of partial responses)
{:ok, responses} = Gemini.stream_generate("Write a long story about space exploration")

# Extract text from each response
texts = Enum.map(responses, fn response ->
  case Gemini.extract_text(response) do
    {:ok, text} -> text
    {:error, _} -> ""
  end
end)

# Print the streaming text
Enum.each(texts, &IO.write/1)
```

### Error Handling
```elixir
case Gemini.text("What is the meaning of life?") do
  {:ok, text} ->
    IO.puts("Response: #{text}")
  
  {:error, %Gemini.Error{type: :api_error, message: message}} ->
    IO.puts("API Error: #{message}")
  
  {:error, %Gemini.Error{type: :network_error, message: message}} ->
    IO.puts("Network Error: #{message}")
  
  {:error, error} ->
    IO.puts("Unknown Error: #{inspect(error)}")
end
```

### System Instructions
```elixir
# Generate with system instruction
{:ok, response} = Gemini.generate(
  "What is the capital of France?",
  system_instruction: "You are a helpful geography teacher. Always provide additional context."
)
{:ok, text} = Gemini.extract_text(response)
IO.puts(text)

# Using the convenience function
{:ok, response} = Gemini.with_system_instruction(
  "Explain quantum physics",
  "You are a physics professor explaining to undergraduate students"
)
```

## Testing with Integration Tests

To run integration tests (requires API key):

```bash
# Set your API key
export GEMINI_API_KEY="your_api_key_here"

# Run integration tests
mix test --include integration
```

## Notes

- The client automatically starts the HTTP pool when the application starts
- All functions return `{:ok, result}` on success or `{:error, error}` on failure
- Errors are structured using the `Gemini.Error` type for consistent handling
- The client supports both simple text and complex multimodal content
- Streaming is useful for long-form content generation
- Always handle errors appropriately in production code
