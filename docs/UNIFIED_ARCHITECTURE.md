# Gemini Unified Authentication Architecture

This document describes the unified authentication architecture that supports both Gemini API and Vertex AI authentication methods in a single, cohesive system.

## Overview

The unified architecture provides:
- **Strategy Pattern Authentication**: Pluggable authentication strategies for different services
- **Auto-Detection**: Automatic authentication type detection based on environment variables
- **GenServer Streaming**: Sophisticated streaming management with concurrent sessions
- **Unified Configuration**: Single configuration system for both auth types
- **Backward Compatibility**: Existing code continues to work without changes

## Architecture Components

### Authentication Strategy Pattern

The authentication system uses a behavior-based strategy pattern:

```elixir
# Core behavior definition
defmodule Gemini.Auth do
  @callback authenticate(config :: map()) :: {:ok, headers :: list()} | {:error, reason :: any()}
  @callback base_url(config :: map()) :: binary() | {:error, reason :: any()}
end

# Gemini API strategy
defmodule Gemini.Auth.GeminiStrategy do
  @behaviour Gemini.Auth.Strategy
  
  def authenticate(%{api_key: api_key}) do
    {:ok, [{"x-goog-api-key", api_key}]}
  end
  
  def base_url(_config) do
    "https://generativelanguage.googleapis.com/v1beta"
  end
end

# Vertex AI strategy  
defmodule Gemini.Auth.VertexStrategy do
  @behaviour Gemini.Auth.Strategy
  
  def authenticate(%{project_id: project, location: location}) do
    # OAuth2 or Service Account authentication
    {:ok, [{"authorization", "Bearer #{access_token}"}]}
  end
  
  def base_url(%{project_id: project, location: location}) do
    "https://#{location}-aiplatform.googleapis.com/v1/projects/#{project}/locations/#{location}"
  end
end
```

### Unified Configuration System

The configuration system automatically detects the authentication type:

```elixir
# Environment variable priority:
# 1. GEMINI_API_KEY -> :gemini auth type
# 2. GOOGLE_CLOUD_PROJECT + GOOGLE_CLOUD_LOCATION -> :vertex auth type  
# 3. Application config
# 4. Defaults

config = Gemini.Config.get()
# %{
#   auth_type: :gemini | :vertex,
#   api_key: "...",           # For Gemini
#   project_id: "...",        # For Vertex AI
#   location: "us-central1",  # For Vertex AI
#   model: "gemini-1.5-pro-latest"
# }
```

### GenServer Streaming Manager

Advanced streaming capabilities with concurrent session management:

```elixir
# Start a streaming session
{:ok, stream_id} = Gemini.start_stream(["Hello, world!"], [], self())

# Subscribe additional processes to the stream
:ok = Gemini.subscribe_stream(stream_id, other_pid)

# Get stream information
{:ok, info} = Gemini.get_stream_info(stream_id)

# List all active streams
stream_ids = Gemini.list_streams()

# Stop a stream
:ok = Gemini.stop_stream(stream_id)
```

## Usage Examples

### Gemini API Authentication

```elixir
# Set environment variable
System.put_env("GEMINI_API_KEY", "your-api-key")

# Or configure directly
config = Gemini.Config.get(auth_type: :gemini, api_key: "your-api-key")

# Generate content
{:ok, response} = Gemini.generate_content("Explain quantum physics")

# Stream content
{:ok, stream_id} = Gemini.start_stream(["Tell me a story"], [], self())
```

### Vertex AI Authentication

```elixir
# Set environment variables
System.put_env("GOOGLE_CLOUD_PROJECT", "your-project-id")
System.put_env("GOOGLE_CLOUD_LOCATION", "us-central1")

# Or configure directly
config = Gemini.Config.get(
  auth_type: :vertex,
  project_id: "your-project-id", 
  location: "us-central1",
  auth_method: :oauth2
)

# Generate content (same API)
{:ok, response} = Gemini.generate_content("Explain quantum physics")

# Stream content (same API)
{:ok, stream_id} = Gemini.start_stream(["Tell me a story"], [], self())
```

### Mixed Usage

```elixir
# Configure for Gemini
gemini_config = Gemini.Config.get(auth_type: :gemini, api_key: "key")
{:ok, response1} = Gemini.generate_content("Hello", config: gemini_config)

# Configure for Vertex AI  
vertex_config = Gemini.Config.get(
  auth_type: :vertex,
  project_id: "project",
  location: "us-central1"
)
{:ok, response2} = Gemini.generate_content("Hello", config: vertex_config)
```

## Streaming Architecture

The streaming system uses GenServer for robust session management:

```elixir
# Each stream has:
# - Unique stream_id (UUID)
# - List of subscriber processes
# - Original request parameters
# - Current status (:active, :completed, :error)

# Automatic cleanup when subscriber processes die
# Concurrent streams with independent lifecycles
# Subscriber pattern for multiple listeners per stream
```

### Stream State Management

```elixir
%{
  streams: %{
    "abc123..." => %{
      contents: ["Hello"],
      opts: [model: "gemini-1.5-pro"],
      subscribers: [#PID<0.123.0>, #PID<0.124.0>],
      status: :active,
      started_at: ~U[2024-01-01 12:00:00Z]
    }
  }
}
```

## HTTP Client Integration

The HTTP client supports both authentication strategies transparently:

```elixir
# The client automatically:
# 1. Detects auth type from config
# 2. Applies appropriate strategy
# 3. Constructs correct URLs and headers
# 4. Handles different API path structures

# Gemini API: /models/{model}:generateContent
# Vertex AI: /projects/{project}/locations/{location}/publishers/google/models/{model}:generateContent
```

## Migration Guide

### From Pure Gemini to Unified

Existing code requires no changes:

```elixir
# This continues to work exactly as before
{:ok, response} = Gemini.generate_content("Hello, world!")
{:ok, text} = Gemini.generate_text("What is AI?")
```

### Adding Vertex AI Support

Simply set environment variables or pass configuration:

```elixir
# Option 1: Environment variables
System.put_env("GOOGLE_CLOUD_PROJECT", "my-project")
System.put_env("GOOGLE_CLOUD_LOCATION", "us-central1")

# Option 2: Direct configuration
Gemini.configure(auth_type: :vertex, project_id: "my-project", location: "us-central1")

# Same API, different backend
{:ok, response} = Gemini.generate_content("Hello from Vertex AI!")
```

## Testing

Comprehensive test coverage includes:

- **Authentication Strategy Tests**: Each strategy tested independently
- **Configuration Detection Tests**: Auto-detection logic verification  
- **Streaming Manager Tests**: GenServer state management and cleanup
- **Integration Tests**: End-to-end authentication flows
- **Error Handling Tests**: Graceful degradation and error reporting

```bash
# Run all tests
mix test

# Run specific test suites
mix test test/gemini/auth_test.exs
mix test test/gemini/streaming/manager_test.exs
mix test test/gemini/config_test.exs
```

## Performance Characteristics

- **Authentication**: Cached strategy instances, minimal overhead
- **Streaming**: GenServer provides reliable state management
- **Configuration**: Environment detection cached on first access
- **HTTP**: Finch connection pooling for both authentication types

## Future Enhancements

1. **Complete OAuth2 Implementation**: Full token refresh cycle
2. **Service Account JWT**: Complete JWT generation and signing
3. **Authentication Caching**: Token caching with automatic refresh
4. **Metrics and Monitoring**: Stream analytics and performance metrics
5. **Configuration Validation**: Enhanced validation and error reporting

## Security Considerations

- **API Keys**: Never logged or exposed in error messages
- **OAuth2 Tokens**: Automatic refresh before expiration
- **Service Accounts**: Secure key file handling
- **Network**: TLS-only connections for all authentication methods

This unified architecture provides a solid foundation for supporting both Gemini and Vertex AI authentication while maintaining simplicity and performance.
