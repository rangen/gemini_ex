# Gemini Elixir Implementation Plan

## Phase 1: Core Foundation (APIs 01, 02, 04)

### 1.1 Refactor Current Architecture

**Type System Enhancement:**
```elixir
# Enhanced response types with proper error handling
defmodule Gemini.Types.Response.Model do
  use TypedStruct
  
  typedstruct do
    field(:name, String.t(), enforce: true)
    field(:base_model_id, String.t(), enforce: true)
    field(:version, String.t(), enforce: true)
    field(:display_name, String.t(), enforce: true)
    field(:description, String.t(), enforce: true)
    field(:input_token_limit, integer(), enforce: true)
    field(:output_token_limit, integer(), enforce: true)
    field(:supported_generation_methods, [String.t()], default: [])
    field(:temperature, float() | nil, default: nil)
    field(:max_temperature, float() | nil, default: nil)
    field(:top_p, float() | nil, default: nil)
    field(:top_k, integer() | nil, default: nil)
  end
end
```

**Unified API Client:**
```elixir
defmodule Gemini.Client do
  @moduledoc """
  Unified HTTP client with proper error handling and response parsing
  """
  
  def request(method, path, body \\ nil, opts \\ []) do
    with {:ok, response} <- make_http_request(method, path, body, opts),
         {:ok, parsed} <- parse_response(response) do
      {:ok, parsed}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp parse_response(%{status: status, body: body}) when status in 200..299 do
    Jason.decode(body)
  end
  
  defp parse_response(%{status: status, body: body}) do
    error = parse_api_error(body, status)
    {:error, error}
  end
end
```

### 1.2 Models API Implementation

**Complete models.ex:**
```elixir
defmodule Gemini.Models do
  @moduledoc """
  Complete Models API implementation
  """
  
  alias Gemini.Client
  alias Gemini.Types.Response.{Model, ListModelsResponse}
  
  def list(opts \\ []) do
    query_params = build_query_params(opts)
    path = "models#{query_params}"
    
    with {:ok, response} <- Client.get(path),
         {:ok, models_response} <- parse_list_response(response) do
      {:ok, models_response}
    end
  end
  
  def get(model_name) do
    full_name = normalize_model_name(model_name)
    
    with {:ok, response} <- Client.get(full_name),
         {:ok, model} <- parse_model_response(response) do
      {:ok, model}
    end
  end
  
  def exists?(model_name) do
    case get(model_name) do
      {:ok, _model} -> {:ok, true}
      {:error, %{type: :api_error, http_status: 404}} -> {:ok, false}
      {:error, error} -> {:error, error}
    end
  end
  
  # Additional helper functions
  def list_names, do: # Implementation
  def supporting_method(method), do: # Implementation
  
  # Private functions for parsing and validation
end
```

### 1.3 Content Generation API

**Enhanced generate.ex:**
```elixir
defmodule Gemini.Generate do
  @moduledoc """
  Content generation with full request/response handling
  """
  
  # Streaming support
  def stream_content(contents, opts \\ []) do
    model = Keyword.get(opts, :model, Config.default_model())
    request = build_generate_request(contents, opts)
    path = "models/#{model}:streamGenerateContent"
    
    with {:ok, events} <- Client.stream_post(path, request, opts),
         {:ok, responses} <- parse_stream_responses(events) do
      {:ok, responses}
    end
  end
  
  # Request builders with proper validation
  def build_generate_request(contents, opts) do
    %{
      contents: normalize_contents(contents),
      generation_config: build_generation_config(opts),
      safety_settings: build_safety_settings(opts),
      system_instruction: build_system_instruction(opts),
      tools: Keyword.get(opts, :tools, []),
      tool_config: Keyword.get(opts, :tool_config)
    }
    |> remove_nil_values()
  end
  
  # Response parsers with error handling
  defp parse_generate_response(response) do
    # Comprehensive parsing with validation
  end
end
```

### 1.4 Token Counting API

**New tokens.ex module:**
```elixir
defmodule Gemini.Tokens do
  @moduledoc """
  Token counting functionality
  """
  
  alias Gemini.Client
  alias Gemini.Types.Response.CountTokensResponse
  
  def count(contents, opts \\ []) do
    model = Keyword.get(opts, :model, Config.default_model())
    request = build_count_request(contents, opts)
    path = "models/#{model}:countTokens"
    
    with {:ok, response} <- Client.post(path, request),
         {:ok, count_response} <- parse_count_response(response) do
      {:ok, count_response}
    end
  end
  
  # Support for both contents and full GenerateContentRequest
  defp build_count_request(contents, opts) do
    case Keyword.get(opts, :generate_content_request) do
      nil -> %{contents: normalize_contents(contents)}
      request -> %{generate_content_request: request}
    end
  end
end
```

## Phase 2: Advanced Features

### 2.1 Streaming Architecture
- Real-time SSE parsing (already partially implemented)
- Backpressure handling
- Connection management
- Error recovery

### 2.2 Authentication Strategy
- Multiple auth types (API key, OAuth2, Service Account)
- Token refresh mechanisms
- Environment detection

### 2.3 Safety and Configuration
- Complete SafetySetting types
- GenerationConfig validation
- Request/response middleware

## Phase 3: Extended APIs

### 3.1 Files API (05)
- File upload/download
- Multimodal content support
- Resumable uploads

### 3.2 Embeddings API (07)
- Text embeddings
- Batch operations
- Task type support

### 3.3 Caching API (06)
- Content caching
- TTL management
- Cache invalidation

## Phase 4: Advanced Features

### 4.1 Live API (03)
- WebSocket connections
- Real-time streaming
- Session management

### 4.2 Tuning APIs (08-09)
- Model fine-tuning
- Permission management
- Training monitoring

### 4.3 Semantic Retrieval (10-15)
- Corpus management
- Document/chunk operations
- Question answering

## Implementation Strategy

### Code Organization
```
lib/
├── gemini/
│   ├── client/           # HTTP clients and streaming
│   ├── types/           # All type definitions
│   │   ├── request/     # Request types
│   │   ├── response/    # Response types
│   │   └── common/      # Shared types
│   ├── auth/            # Authentication strategies
│   ├── apis/            # API modules
│   │   ├── models.ex
│   │   ├── generate.ex
│   │   ├── tokens.ex
│   │   ├── files.ex
│   │   └── embeddings.ex
│   ├── streaming/       # Streaming management
│   ├── config.ex        # Configuration
│   ├── error.ex         # Error handling
│   └── telemetry.ex     # Observability
└── gemini.ex            # Main API
```

### Testing Strategy
- Unit tests for each API module
- Integration tests with mock responses
- Live API tests (optional with real keys)
- Property-based testing for type validation

### Documentation
- Complete @doc coverage
- API examples for each function
- Migration guides
- Best practices documentation

## Next Steps

1. **Refactor existing code** to match new architecture
2. **Implement Models API** completely with all endpoints
3. **Enhance Content Generation** with streaming and all options
4. **Add Token Counting** as new module
5. **Comprehensive testing** for Phase 1 APIs
6. **Plan Phase 2** based on usage patterns

This approach ensures:
- ✅ Solid foundation with core APIs
- ✅ Extensible architecture for future APIs
- ✅ Proper error handling and type safety
- ✅ Comprehensive testing strategy
- ✅ Clear migration path from current implementation