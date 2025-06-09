# Multi-Auth Coordination Capability Specification

## 🎯 Overview

The **Multi-Auth Coordination** capability is the key differentiator of the Gemini Unified Implementation. It enables **simultaneous usage of both Gemini API and Vertex AI** within the same application instance, allowing developers to leverage the best of both platforms concurrently.

## 🌟 The Problem This Solves

### Current Limitation
Existing Elixir Gemini clients force developers to choose **one authentication strategy per application**:
- Either Gemini API (simple, fast setup, API key)
- Or Vertex AI (enterprise features, service accounts, regional deployment)

### Real-World Need
Modern applications often need **both**:
- **Gemini API** for rapid prototyping, simple integrations, public-facing features
- **Vertex AI** for enterprise workloads, fine-tuned models, compliance requirements, regional data residency

### Our Solution
**Per-request authentication strategy selection** with **concurrent coordination**:
```elixir
# Same application, same process, different auth strategies
{:ok, public_response} = Gemini.generate("Hello", auth: :gemini)
{:ok, enterprise_response} = Gemini.generate("Sensitive data", auth: :vertex_ai)

# Concurrent streaming with different auth strategies
Task.async(fn -> Gemini.stream_generate("Story", auth: :gemini) end)
Task.async(fn -> Gemini.stream_generate("Analysis", auth: :vertex_ai) end)
```

## 🏗️ Architecture Design

### Core Components

#### 1. **Multi-Auth Coordinator**
**File**: `lib/gemini/auth/multi_auth_coordinator.ex`

```elixir
defmodule Gemini.Auth.MultiAuthCoordinator do
  @moduledoc """
  Coordinates multiple authentication strategies for concurrent usage.
  
  Enables per-request auth strategy selection while maintaining
  independent credential management and request routing.
  """
  
  @type auth_strategy :: :gemini | :vertex_ai
  @type credentials :: map()
  @type auth_result :: {:ok, auth_strategy(), headers :: list()} | {:error, term()}
  
  @spec coordinate_auth(auth_strategy(), request_opts :: keyword()) :: auth_result()
  def coordinate_auth(strategy, opts \\ [])
  
  @spec refresh_credentials(auth_strategy()) :: {:ok, map()} | {:error, term()}
  def refresh_credentials(strategy)
  
  @spec validate_auth_config(auth_strategy()) :: :ok | {:error, term()}
  def validate_auth_config(strategy)
end
```

**Responsibilities**:
- Route authentication requests to appropriate strategy
- Manage independent credential lifecycles
- Handle concurrent auth strategy operations
- Validate and refresh credentials independently

#### 2. **Unified Streaming Manager**
**File**: `lib/gemini/streaming/unified_manager.ex`

```elixir
defmodule Gemini.Streaming.UnifiedManager do
  @moduledoc """
  Unified streaming manager supporting multi-auth coordination.
  
  Extends the excellent ManagerV2 streaming with auth-aware routing
  while preserving all streaming capabilities.
  """
  
  @spec start_stream(contents, opts, subscriber_pid) :: {:ok, stream_id()} | {:error, term()}
  def start_stream(contents, opts, subscriber_pid \\ self())
  
  # Auth-aware streaming with per-stream auth strategy
  @spec start_stream_with_auth(contents, auth_strategy(), opts, subscriber_pid) :: 
    {:ok, stream_id()} | {:error, term()}
  def start_stream_with_auth(contents, auth_strategy, opts, subscriber_pid \\ self())
end
```

**Key Features**:
- **Preserves ManagerV2 excellence** - All existing streaming capabilities
- **Adds auth routing** - Per-stream authentication strategy
- **Concurrent streams** - Different auth strategies in parallel
- **Auth-aware metadata** - Track which auth strategy per stream

#### 3. **API Coordinator**
**File**: `lib/gemini/apis/coordinator.ex`

```elixir
defmodule Gemini.APIs.Coordinator do
  @moduledoc """
  Unified API interface with auth-aware routing.
  
  Provides consistent API surface regardless of underlying auth strategy.
  Routes requests to appropriate endpoints based on auth configuration.
  """
  
  @spec route_request(operation, request, opts) :: {:ok, response} | {:error, term()}
  def route_request(operation, request, opts \\ [])
  
  @spec determine_auth_strategy(opts) :: auth_strategy()
  defp determine_auth_strategy(opts)
end
```

### Configuration Architecture

#### Multi-Auth Configuration
```elixir
# config/config.exs
config :gemini,
  # Default auth strategy when none specified
  default_auth: :gemini,
  
  # Gemini API configuration
  gemini: %{
    api_key: {:system, "GEMINI_API_KEY"},
    timeout: 30_000
  },
  
  # Vertex AI configuration  
  vertex_ai: %{
    project_id: {:system, "VERTEX_PROJECT_ID"},
    location: {:system, "VERTEX_LOCATION"},
    service_account_key: {:system, "VERTEX_SERVICE_ACCOUNT"},
    timeout: 45_000
  },
  
  # Global settings
  telemetry_enabled: true
```

#### Environment Variable Support
```bash
# Gemini API
export GEMINI_API_KEY="your_gemini_key"

# Vertex AI Option 1: Service Account
export VERTEX_PROJECT_ID="your-project"
export VERTEX_LOCATION="us-central1"
export VERTEX_SERVICE_ACCOUNT="/path/to/service-account.json"

# Vertex AI Option 2: Access Token
export VERTEX_ACCESS_TOKEN="your_access_token"
export VERTEX_PROJECT_ID="your-project"
export VERTEX_LOCATION="us-central1"
```

## 💡 Usage Patterns

### 1. **Explicit Auth Strategy Selection**
```elixir
# Per-request auth specification
{:ok, response} = Gemini.generate("Public content", auth: :gemini)
{:ok, response} = Gemini.generate("Enterprise content", auth: :vertex_ai)

# Streaming with explicit auth
{:ok, stream_id} = Gemini.start_stream("Story", auth: :gemini)
{:ok, stream_id} = Gemini.start_stream("Analysis", auth: :vertex_ai)
```

### 2. **Client-Specific Configuration**
```elixir
# Create auth-specific clients
gemini_client = Gemini.client(:gemini)
vertex_client = Gemini.client(:vertex_ai)

# Use clients independently
{:ok, response1} = Gemini.generate(gemini_client, "Content 1")
{:ok, response2} = Gemini.generate(vertex_client, "Content 2")
```

### 3. **Fallback and Load Balancing**
```elixir
# Try primary auth, fallback to secondary
case Gemini.generate("Content", auth: :vertex_ai) do
  {:ok, response} -> {:ok, response}
  {:error, %{type: :quota_exceeded}} -> 
    Gemini.generate("Content", auth: :gemini)
  {:error, error} -> 
    {:error, error}
end
```

### 4. **Concurrent Operations**
```elixir
# Parallel processing with different auth strategies
tasks = [
  Task.async(fn -> Gemini.generate("Public task", auth: :gemini) end),
  Task.async(fn -> Gemini.generate("Enterprise task", auth: :vertex_ai) end),
  Task.async(fn -> Gemini.stream_generate("Streaming task", auth: :gemini) end)
]

results = Task.await_many(tasks)
```

### 5. **Environment-Based Routing**
```elixir
# Dynamic auth strategy based on environment
auth_strategy = case Mix.env() do
  :prod -> :vertex_ai  # Enterprise auth in production
  :dev -> :gemini      # Simple auth in development
  :test -> :gemini     # Mock-friendly auth in tests
end

{:ok, response} = Gemini.generate("Content", auth: auth_strategy)
```

## 🔧 Implementation Details

### Request Flow with Multi-Auth

1. **Request Initiation**
   ```elixir
   Gemini.generate("Hello", auth: :vertex_ai, model: "gemini-2.0-flash")
   ```

2. **Auth Strategy Resolution**
   ```elixir
   # Coordinator determines auth strategy
   auth_strategy = Keyword.get(opts, :auth, Config.default_auth())
   # => :vertex_ai
   ```

3. **Auth Coordination**
   ```elixir
   # MultiAuthCoordinator routes to appropriate strategy
   {:ok, :vertex_ai, headers} = MultiAuthCoordinator.coordinate_auth(:vertex_ai, opts)
   ```

4. **Request Building**
   ```elixir
   # Build request with appropriate base URL and headers
   base_url = Auth.get_base_url(:vertex_ai, credentials)
   # => "https://us-central1-aiplatform.googleapis.com/v1"
   
   path = Auth.build_path(:vertex_ai, model, endpoint, credentials)
   # => "projects/project/locations/us-central1/publishers/google/models/gemini-2.0-flash:generateContent"
   ```

5. **Request Execution**
   ```elixir
   # Execute with auth-specific configuration
   Client.post(full_url, request_body, headers)
   ```

### Streaming Flow with Multi-Auth

1. **Stream Initiation**
   ```elixir
   Gemini.start_stream("Tell a story", auth: :gemini)
   ```

2. **Auth-Aware Stream Creation**
   ```elixir
   # UnifiedManager preserves ManagerV2 excellence
   # but adds auth routing
   {:ok, stream_id} = UnifiedManager.start_stream(contents, opts, self())
   ```

3. **Stream Metadata Enhancement**
   ```elixir
   stream_metadata = %{
     stream_id: stream_id,
     auth_strategy: :gemini,
     model: "gemini-2.0-flash",
     auth_headers: headers,
     base_url: base_url
   }
   ```

4. **Auth-Aware HTTP Streaming**
   ```elixir
   # HTTPStreaming uses auth-specific headers and URLs
   HTTPStreaming.stream_to_process(auth_url, auth_headers, body, stream_id, self())
   ```

## 🎯 Key Benefits

### 1. **Flexibility**
- **Environment Adaptation**: Different auth strategies per environment
- **Feature Selection**: Use best platform for each use case
- **Migration Path**: Gradual migration between platforms

### 2. **Performance**
- **Load Distribution**: Spread load across both platforms
- **Failover**: Automatic fallback between auth strategies
- **Regional Optimization**: Use Vertex AI for data residency, Gemini for speed

### 3. **Cost Optimization**
- **Tier Selection**: Use appropriate pricing tier per request
- **Quota Management**: Distribute requests across quotas
- **Feature Optimization**: Pay only for needed features

### 4. **Developer Experience**
- **Consistent API**: Same interface regardless of auth strategy
- **Easy Testing**: Mock-friendly auth in development
- **Gradual Adoption**: Start simple, add enterprise features

## ⚡ Performance Characteristics

### Memory Usage
- **Minimal Overhead**: Single process with multiple auth strategies
- **Efficient Coordination**: Lazy credential loading and caching
- **Stream Optimization**: Shared SSE parsing across auth strategies

### Latency Impact
- **Auth Coordination**: < 1ms per request
- **Strategy Routing**: Compile-time optimization where possible
- **Credential Caching**: Avoid repeated auth token generation

### Concurrency
- **Independent Streams**: No blocking between auth strategies
- **Parallel Processing**: Full concurrency across auth types
- **Resource Isolation**: Independent rate limiting and error handling

## 🔒 Security Considerations

### Credential Isolation
- **Independent Storage**: Separate credential management per strategy
- **Secure Defaults**: No credential leakage between strategies
- **Audit Trail**: Track which auth strategy for each request

### Configuration Security
- **Environment Variables**: Secure credential configuration
- **Runtime Validation**: Validate credentials before use
- **Error Handling**: No credential exposure in error messages

## 🧪 Testing Strategy

### Unit Tests
```elixir
# Test auth coordination
test "coordinates gemini auth strategy"
test "coordinates vertex_ai auth strategy" 
test "handles concurrent auth strategies"
test "manages independent credential refresh"

# Test streaming coordination
test "starts stream with gemini auth"
test "starts stream with vertex_ai auth"
test "handles concurrent streams with different auth"

# Test API coordination
test "routes requests to correct auth strategy"
test "maintains consistent API interface"
```

### Integration Tests
```elixir
# Test concurrent usage
test "concurrent gemini and vertex_ai requests"
test "concurrent streaming with different auths"
test "auth strategy isolation"
test "mixed request types with different auths"

# Test real API usage
test "end-to-end with both auth strategies"
test "fallback between auth strategies"
test "load balancing across strategies"
```

### Property Tests
```elixir
# Test auth strategy consistency
property "auth strategy selection is deterministic"
property "concurrent requests maintain isolation"
property "credential refresh is thread-safe"
```

## 📚 Documentation Examples

### Quick Start
```elixir
# Configure both auth strategies
Gemini.configure(:gemini, %{api_key: "your_gemini_key"})
Gemini.configure(:vertex_ai, %{
  project_id: "your-project",
  location: "us-central1",
  service_account_key: "/path/to/key.json"
})

# Use both in same application
{:ok, public_response} = Gemini.generate("Hello", auth: :gemini)
{:ok, enterprise_response} = Gemini.generate("Sensitive", auth: :vertex_ai)
```

### Advanced Usage
```elixir
# Environment-based routing
defmodule MyApp.AIService do
  def generate_content(prompt, opts \\ []) do
    auth_strategy = determine_auth_strategy(opts)
    Gemini.generate(prompt, [auth: auth_strategy] ++ opts)
  end
  
  defp determine_auth_strategy(opts) do
    cond do
      Keyword.get(opts, :enterprise, false) -> :vertex_ai
      Keyword.get(opts, :region) == "eu" -> :vertex_ai
      true -> :gemini
    end
  end
end
```

## 🎉 Competitive Advantage

This multi-auth coordination capability is **unique in the Elixir ecosystem** and provides:

1. **First-to-Market**: No other Elixir Gemini client supports concurrent auth strategies
2. **Enterprise Ready**: Enables enterprise adoption without sacrificing developer experience
3. **Future Proof**: Architecture supports additional auth strategies (Azure OpenAI, AWS Bedrock)
4. **Migration Friendly**: Smooth path from simple to enterprise usage
5. **Cost Effective**: Optimize usage across multiple platforms

## 🔄 Future Extensions

The architecture supports future expansion:
- **Additional Platforms**: Azure OpenAI, AWS Bedrock, Anthropic Claude
- **Smart Routing**: ML-based auth strategy selection
- **Cost Optimization**: Automatic cost-based routing
- **Performance Monitoring**: Per-auth-strategy metrics and optimization

This multi-auth coordination capability transforms the Gemini Unified Implementation from a simple API client into a **comprehensive AI platform integration layer** for Elixir applications.
