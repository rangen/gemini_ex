# Multi-Auth Implementation Roadmap & Migration Guide

## 🎯 Implementation Roadmap

### Week 1: Foundation (Days 1-7)
**Goal**: Core multi-auth infrastructure working

#### Day 1-2: Multi-Auth Coordinator
- [ ] Implement `lib/gemini/auth/multi_auth_coordinator.ex`
- [ ] Write unit tests for auth coordination
- [ ] Test credential management and caching
- [ ] Validate auth strategy routing

#### Day 3-4: Configuration Enhancement
- [ ] Implement `lib/gemini/config/multi_auth_config.ex`
- [ ] Update main `Config` module for multi-auth
- [ ] Add environment variable detection
- [ ] Test configuration validation

#### Day 5-7: Integration Testing
- [ ] Create comprehensive auth tests
- [ ] Test both auth strategies independently
- [ ] Test auth strategy switching
- [ ] Fix any integration issues

**Success Criteria Week 1**:
```elixir
# Both auth strategies work independently
{:ok, _} = MultiAuthCoordinator.coordinate_auth(:gemini, [])
{:ok, _} = MultiAuthCoordinator.coordinate_auth(:vertex_ai, [])

# Configuration detection works
assert MultiAuthConfig.get_all_auth_configs() != %{}
```

### Week 2: Streaming Integration (Days 8-14)
**Goal**: Multi-auth streaming working with preserved excellence

#### Day 8-9: Unified Streaming Manager
- [ ] Implement `lib/gemini/streaming/unified_manager.ex`
- [ ] Preserve all ManagerV2 capabilities
- [ ] Add auth-aware stream creation
- [ ] Test streaming with both auth strategies

#### Day 10-11: HTTP Client Enhancement
- [ ] Update HTTP clients for multi-auth
- [ ] Enhance streaming client with auth routing
- [ ] Test SSE parsing with both auth strategies
- [ ] Ensure no regression in streaming performance

#### Day 12-14: Streaming Integration
- [ ] Integrate unified manager with existing system
- [ ] Test concurrent streaming with different auth
- [ ] Test stream lifecycle with auth metadata
- [ ] Performance testing and optimization

**Success Criteria Week 2**:
```elixir
# Concurrent streaming with different auth works
{:ok, gemini_stream} = UnifiedManager.start_stream("Hello", [auth: :gemini], self())
{:ok, vertex_stream} = UnifiedManager.start_stream("Hello", [auth: :vertex_ai], self())

# Original streaming excellence preserved
assert ManagerV2.get_stats().total_streams >= 0
```

### Week 3: API Coordination (Days 15-21)
**Goal**: Unified API interface with auth routing

#### Day 15-16: API Coordinator
- [ ] Implement `lib/gemini/apis/coordinator.ex`
- [ ] Add request routing logic
- [ ] Test API operations with both auth strategies
- [ ] Add fallback mechanisms

#### Day 17-18: API Integration
- [ ] Update Generate API for multi-auth
- [ ] Update Models API for multi-auth
- [ ] Update Tokens API for multi-auth
- [ ] Test all APIs with both auth strategies

#### Day 19-21: Main Module Integration
- [ ] Update main `Gemini` module
- [ ] Add convenience functions for multi-auth
- [ ] Test complete API surface
- [ ] Integration testing across all components

**Success Criteria Week 3**:
```elixir
# Unified API interface works
{:ok, _} = Gemini.generate("Hello", auth: :gemini)
{:ok, _} = Gemini.generate("Hello", auth: :vertex_ai)
{:ok, _} = Gemini.list_models(auth: :gemini)
{:ok, _} = Gemini.list_models(auth: :vertex_ai)

# API coordinator routes correctly
{:ok, _} = Coordinator.route_request(:generate, "Hello", auth: :gemini)
```

### Week 4: Polish & Documentation (Days 22-28)
**Goal**: Production-ready with comprehensive documentation

#### Day 22-23: Error Handling Enhancement
- [ ] Enhance error handling for multi-auth scenarios
- [ ] Add recovery suggestions for auth failures
- [ ] Test error propagation and handling
- [ ] Add error context for debugging

#### Day 24-25: Performance Optimization
- [ ] Optimize auth coordination overhead
- [ ] Cache credentials efficiently
- [ ] Test performance impact
- [ ] Memory usage optimization

#### Day 26-28: Documentation & Examples
- [ ] Complete API documentation
- [ ] Create usage examples
- [ ] Write migration guide
- [ ] Create troubleshooting guide

**Success Criteria Week 4**:
```elixir
# Production-ready concurrent usage
tasks = [
  Task.async(fn -> Gemini.generate("Task 1", auth: :gemini) end),
  Task.async(fn -> Gemini.generate("Task 2", auth: :vertex_ai) end),
  Task.async(fn -> Gemini.stream_generate("Task 3", auth: :gemini) end)
]
results = Task.await_many(tasks)
assert length(results) == 3
```

## 🔄 Migration Guide

### From Single Auth to Multi-Auth

#### Current Usage (Single Auth)
```elixir
# Before: Single auth strategy per application
config :gemini, api_key: "your_api_key"

# Usage was simple but limited
{:ok, response} = Gemini.generate("Hello")
```

#### New Usage (Multi-Auth)
```elixir
# After: Multiple auth strategies available
config :gemini,
  gemini: %{api_key: "your_gemini_key"},
  vertex_ai: %{
    project_id: "your-project",
    location: "us-central1",
    service_account_key: "/path/to/key.json"
  },
  default_auth: :gemini

# Usage is flexible and powerful
{:ok, response1} = Gemini.generate("Hello")  # Uses default
{:ok, response2} = Gemini.generate("Hello", auth: :gemini)
{:ok, response3} = Gemini.generate("Hello", auth: :vertex_ai)
```

### Migration Steps

#### Step 1: Update Configuration
```elixir
# Old config/config.exs
config :gemini,
  api_key: "your_api_key",
  timeout: 30_000

# New config/config.exs
config :gemini,
  # Gemini API configuration
  gemini: %{
    api_key: {:system, "GEMINI_API_KEY"},
    timeout: 30_000
  },
  
  # Vertex AI configuration (optional)
  vertex_ai: %{
    project_id: {:system, "VERTEX_PROJECT_ID"},
    location: {:system, "VERTEX_LOCATION"},
    service_account_key: {:system, "VERTEX_SERVICE_ACCOUNT"}
  },
  
  # Default auth strategy
  default_auth: :gemini,
  
  # Global settings
  telemetry_enabled: true
```

#### Step 2: Update Environment Variables
```bash
# Old environment variables
export GEMINI_API_KEY="your_api_key"

# New environment variables (backward compatible)
export GEMINI_API_KEY="your_gemini_key"

# Optional: Add Vertex AI
export VERTEX_PROJECT_ID="your-project"
export VERTEX_LOCATION="us-central1"
export VERTEX_SERVICE_ACCOUNT="/path/to/service-account.json"
```

#### Step 3: Update Application Code (Optional)
```elixir
# Existing code continues to work (backward compatible)
{:ok, response} = Gemini.generate("Hello")

# New code can specify auth strategy
{:ok, public_response} = Gemini.generate("Public content", auth: :gemini)
{:ok, enterprise_response} = Gemini.generate("Sensitive data", auth: :vertex_ai)

# Concurrent usage
Task.async(fn -> Gemini.generate("Task 1", auth: :gemini) end)
Task.async(fn -> Gemini.generate("Task 2", auth: :vertex_ai) end)
```

### Backward Compatibility

#### Configuration Compatibility
```elixir
# Old single-auth config still works
config :gemini, api_key: "your_key"

# Automatically mapped to:
config :gemini,
  gemini: %{api_key: "your_key"},
  default_auth: :gemini
```

#### API Compatibility
```elixir
# All existing function calls work unchanged
{:ok, response} = Gemini.generate("Hello")
{:ok, stream_id} = Gemini.start_stream("Hello")
{:ok, models} = Gemini.list_models()

# No breaking changes to existing APIs
```

#### Environment Variable Compatibility
```bash
# Old environment variables continue to work
export GEMINI_API_KEY="your_key"

# Automatically detected and used for :gemini strategy
```

### Migration Strategies

#### Strategy 1: Gradual Migration
1. **Start**: Keep existing single auth configuration
2. **Add**: Add Vertex AI configuration alongside
3. **Test**: Test Vertex AI for non-critical operations
4. **Migrate**: Gradually move operations to appropriate auth
5. **Optimize**: Use best auth strategy for each use case

#### Strategy 2: Environment-Based Migration
```elixir
# Use different auth strategies per environment
defmodule MyApp.AIConfig do
  def auth_strategy do
    case Mix.env() do
      :prod -> :vertex_ai     # Enterprise auth in production
      :staging -> :vertex_ai  # Test enterprise features
      :dev -> :gemini         # Simple auth in development
      :test -> :gemini        # Mock-friendly testing
    end
  end
  
  def generate_content(prompt, opts \\ []) do
    auth_strategy = Keyword.get(opts, :auth, auth_strategy())
    Gemini.generate(prompt, [auth: auth_strategy] ++ opts)
  end
end
```

#### Strategy 3: Feature-Based Migration
```elixir
# Route based on content sensitivity or features needed
defmodule MyApp.SmartRouter do
  def generate_content(prompt, opts \\ []) do
    auth_strategy = determine_auth_strategy(prompt, opts)
    Gemini.generate(prompt, [auth: auth_strategy] ++ opts)
  end
  
  defp determine_auth_strategy(prompt, opts) do
    cond do
      Keyword.get(opts, :sensitive, false) -> :vertex_ai
      Keyword.get(opts, :enterprise, false) -> :vertex_ai
      Keyword.get(opts, :region) == "eu" -> :vertex_ai
      String.contains?(prompt, "confidential") -> :vertex_ai
      true -> :gemini
    end
  end
end
```

## 🚀 Deployment Guide

### Production Deployment

#### Docker Configuration
```dockerfile
# Dockerfile
FROM elixir:1.15-alpine AS builder

WORKDIR /app
COPY mix.exs mix.lock ./
COPY config config
COPY lib lib

RUN mix deps.get --only prod
RUN mix compile
RUN mix release

FROM elixir:1.15-alpine AS runner

# Install runtime dependencies
RUN apk add --no-cache openssl ncurses-libs

WORKDIR /app
COPY --from=builder /app/_build/prod/rel/myapp ./

# Multi-auth environment variables
ENV GEMINI_API_KEY=""
ENV VERTEX_PROJECT_ID=""
ENV VERTEX_LOCATION="us-central1"
ENV VERTEX_SERVICE_ACCOUNT=""

CMD ["./bin/myapp", "start"]
```

#### Kubernetes Deployment
```yaml
# k8s-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gemini-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: gemini-app
  template:
    metadata:
      labels:
        app: gemini-app
    spec:
      containers:
      - name: app
        image: myapp:latest
        env:
        - name: GEMINI_API_KEY
          valueFrom:
            secretKeyRef:
              name: gemini-secrets
              key: api-key
        - name: VERTEX_PROJECT_ID
          value: "my-production-project"
        - name: VERTEX_LOCATION
          value: "us-central1"
        - name: VERTEX_SERVICE_ACCOUNT
          value: "/etc/service-account/key.json"
        volumeMounts:
        - name: service-account-volume
          mountPath: /etc/service-account
          readOnly: true
      volumes:
      - name: service-account-volume
        secret:
          secretName: vertex-service-account
---
apiVersion: v1
kind: Secret
metadata:
  name: gemini-secrets
type: Opaque
data:
  api-key: <base64-encoded-gemini-api-key>
---
apiVersion: v1
kind: Secret
metadata:
  name: vertex-service-account
type: Opaque
data:
  key.json: <base64-encoded-service-account-json>
```

#### Security Best Practices
```elixir
# config/runtime.exs
import Config

# Production configuration with secure defaults
if config_env() == :prod do
  # Gemini API configuration
  if gemini_api_key = System.get_env("GEMINI_API_KEY") do
    config :gemini, :gemini, %{
      api_key: gemini_api_key,
      timeout: 30_000
    }
  end
  
  # Vertex AI configuration
  vertex_project = System.get_env("VERTEX_PROJECT_ID")
  vertex_location = System.get_env("VERTEX_LOCATION") || "us-central1"
  
  cond do
    service_account = System.get_env("VERTEX_SERVICE_ACCOUNT") ->
      config :gemini, :vertex_ai, %{
        project_id: vertex_project,
        location: vertex_location,
        service_account_key: service_account,
        timeout: 45_000
      }
    
    access_token = System.get_env("VERTEX_ACCESS_TOKEN") ->
      config :gemini, :vertex_ai, %{
        project_id: vertex_project,
        location: vertex_location,
        access_token: access_token,
        timeout: 45_000
      }
    
    true ->
      # Log warning but don't fail - app can still use Gemini auth
      require Logger
      Logger.warning("No Vertex AI credentials configured")
  end
  
  # Default auth strategy
  default_auth = case System.get_env("DEFAULT_AUTH_STRATEGY") do
    "vertex_ai" -> :vertex_ai
    "gemini" -> :gemini
    _ -> :gemini  # Safe default
  end
  
  config :gemini,
    default_auth: default_auth,
    telemetry_enabled: true
end
```

## 🔧 Troubleshooting Guide

### Common Issues and Solutions

#### Issue 1: "No authentication configured"
**Symptoms**: `{:error, :no_auth_config}`

**Diagnosis**:
```elixir
# Check auth configuration
Gemini.Config.MultiAuthConfig.get_all_auth_configs()
# => %{}  # Empty means no auth configured

# Validate specific strategy
Gemini.Auth.MultiAuthCoordinator.validate_auth_config(:gemini)
# => {:error, "No Gemini API key configured"}
```

**Solutions**:
1. **Check environment variables**:
   ```bash
   echo $GEMINI_API_KEY
   echo $VERTEX_PROJECT_ID
   echo $VERTEX_SERVICE_ACCOUNT
   ```

2. **Check application configuration**:
   ```elixir
   Application.get_env(:gemini, :gemini)
   Application.get_env(:gemini, :vertex_ai)
   ```

3. **Add missing configuration**:
   ```elixir
   # In config/config.exs or runtime.exs
   config :gemini,
     gemini: %{api_key: "your_key_here"}
   ```

#### Issue 2: "Vertex AI authentication failed"
**Symptoms**: `{:error, "Failed to authenticate with Vertex AI"}`

**Diagnosis**:
```elixir
# Test Vertex AI configuration
case Gemini.Auth.MultiAuthCoordinator.coordinate_auth(:vertex_ai, []) do
  {:ok, _, _} -> IO.puts("Vertex AI auth working")
  {:error, reason} -> IO.puts("Vertex AI auth failed: #{reason}")
end
```

**Solutions**:
1. **Check service account file**:
   ```bash
   # Verify file exists and is readable
   ls -la /path/to/service-account.json
   
   # Verify JSON format
   cat /path/to/service-account.json | jq .
   ```

2. **Verify project and location**:
   ```bash
   export VERTEX_PROJECT_ID="correct-project-id"
   export VERTEX_LOCATION="us-central1"
   ```

3. **Test service account permissions**:
   ```bash
   # Use gcloud to test service account
   gcloud auth activate-service-account --key-file=/path/to/service-account.json
   gcloud ai models list --project=your-project --region=us-central1
   ```

#### Issue 3: "Concurrent streams failing"
**Symptoms**: Some streams work, others fail with auth errors

**Diagnosis**:
```elixir
# Test concurrent auth coordination
Task.async(fn -> 
  Gemini.Auth.MultiAuthCoordinator.coordinate_auth(:gemini, [])
end)
Task.async(fn -> 
  Gemini.Auth.MultiAuthCoordinator.coordinate_auth(:vertex_ai, [])
end)
```

**Solutions**:
1. **Check credential caching**:
   ```elixir
   # Clear credential cache if stale
   Process.delete({:auth_cache, :gemini})
   Process.delete({:auth_cache, :vertex_ai})
   ```

2. **Verify auth isolation**:
   ```elixir
   # Test strategies independently
   {:ok, _} = Gemini.generate("Test", auth: :gemini)
   {:ok, _} = Gemini.generate("Test", auth: :vertex_ai)
   ```

#### Issue 4: "Performance degradation"
**Symptoms**: Requests slower with multi-auth enabled

**Diagnosis**:
```elixir
# Measure auth coordination overhead
{time, _result} = :timer.tc(fn ->
  Gemini.Auth.MultiAuthCoordinator.coordinate_auth(:gemini, [])
end)
IO.puts("Auth coordination took #{time} microseconds")
```

**Solutions**:
1. **Enable credential caching**:
   ```elixir
   # Ensure caching is working
   # First call should be slower, subsequent calls faster
   ```

2. **Optimize default auth strategy**:
   ```elixir
   # Use faster auth strategy as default
   config :gemini, default_auth: :gemini
   ```

3. **Use strategy-specific clients**:
   ```elixir
   # Pre-create clients to avoid auth overhead
   gemini_client = Gemini.client(:gemini)
   vertex_client = Gemini.client(:vertex_ai)
   ```

### Monitoring and Observability

#### Telemetry Events
```elixir
# Set up telemetry handlers for multi-auth monitoring
:telemetry.attach_many(
  "multi-auth-handler",
  [
    [:gemini, :auth, :coordinate, :start],
    [:gemini, :auth, :coordinate, :stop],
    [:gemini, :auth, :coordinate, :exception],
    [:gemini, :auth, :strategy, :switch]
  ],
  &handle_auth_telemetry/4,
  %{}
)

def handle_auth_telemetry(event, measurements, metadata, _config) do
  case event do
    [:gemini, :auth, :coordinate, :start] ->
      Logger.debug("Auth coordination started", 
        strategy: metadata.auth_strategy)
    
    [:gemini, :auth, :coordinate, :stop] ->
      Logger.debug("Auth coordination completed", 
        strategy: metadata.auth_strategy,
        duration: measurements.duration)
    
    [:gemini, :auth, :coordinate, :exception] ->
      Logger.error("Auth coordination failed",
        strategy: metadata.auth_strategy,
        error: metadata.reason)
    
    [:gemini, :auth, :strategy, :switch] ->
      Logger.info("Auth strategy switch",
        from: metadata.from_strategy,
        to: metadata.to_strategy,
        reason: metadata.reason)
  end
end
```

#### Health Checks
```elixir
defmodule MyApp.HealthCheck do
  def check_auth_health do
    strategies = [:gemini, :vertex_ai]
    
    results = Enum.map(strategies, fn strategy ->
      case Gemini.Auth.MultiAuthCoordinator.validate_auth_config(strategy) do
        :ok -> {strategy, :healthy}
        {:error, reason} -> {strategy, {:unhealthy, reason}}
      end
    end)
    
    healthy_count = results |> Enum.count(fn {_, status} -> status == :healthy end)
    
    %{
      overall_status: if(healthy_count > 0, do: :healthy, else: :unhealthy),
      auth_strategies: Map.new(results),
      healthy_strategies: healthy_count,
      total_strategies: length(strategies)
    }
  end
end
```

## 📊 Performance Benchmarks

### Expected Performance Characteristics

#### Auth Coordination Overhead
- **First request**: ~5-10ms (credential setup)
- **Subsequent requests**: ~0.1-0.5ms (cached credentials)
- **Strategy switching**: ~1-2ms (cache lookup + header building)

#### Memory Usage
- **Base overhead**: ~50KB per auth strategy
- **Credential cache**: ~1-5KB per cached credential set
- **Concurrent streams**: No significant additional overhead

#### Concurrent Usage
- **Stream isolation**: No performance impact between auth strategies
- **Request parallelism**: Full concurrency across auth strategies
- **Rate limiting**: Independent per auth strategy

### Benchmark Tests
```elixir
defmodule Gemini.Benchmarks.MultiAuth do
  def run_auth_coordination_benchmark do
    Benchee.run(%{
      "gemini_auth_cold" => fn -> 
        Process.delete({:auth_cache, :gemini})
        Gemini.Auth.MultiAuthCoordinator.coordinate_auth(:gemini, [])
      end,
      "gemini_auth_warm" => fn ->
        Gemini.Auth.MultiAuthCoordinator.coordinate_auth(:gemini, [])
      end,
      "vertex_auth_cold" => fn ->
        Process.delete({:auth_cache, :vertex_ai})
        Gemini.Auth.MultiAuthCoordinator.coordinate_auth(:vertex_ai, [])
      end,
      "vertex_auth_warm" => fn ->
        Gemini.Auth.MultiAuthCoordinator.coordinate_auth(:vertex_ai, [])
      end
    })
  end
  
  def run_concurrent_usage_benchmark do
    Benchee.run(%{
      "concurrent_same_auth" => fn ->
        tasks = Enum.map(1..10, fn _ ->
          Task.async(fn -> 
            Gemini.Auth.MultiAuthCoordinator.coordinate_auth(:gemini, [])
          end)
        end)
        Task.await_many(tasks)
      end,
      "concurrent_mixed_auth" => fn ->
        tasks = Enum.map(1..10, fn i ->
          strategy = if rem(i, 2) == 0, do: :gemini, else: :vertex_ai
          Task.async(fn -> 
            Gemini.Auth.MultiAuthCoordinator.coordinate_auth(strategy, [])
          end)
        end)
        Task.await_many(tasks)
      end
    })
  end
end
```

This comprehensive roadmap and migration guide provides everything needed to successfully implement and deploy the multi-auth coordination capability while maintaining backward compatibility and production readiness.
