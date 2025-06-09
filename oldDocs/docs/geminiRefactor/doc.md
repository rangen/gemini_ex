# Gemini Models API Implementation

This document provides comprehensive documentation for the refactored Gemini Models API implementation, including all features, capabilities, and usage patterns.

## Overview

The Models API provides programmatic access to information about available Gemini models, including their capabilities, token limits, supported methods, and generation parameters. This implementation follows the official Gemini API specification and adds extensive error handling, validation, telemetry, and developer-friendly features.

## Core Features

### 🔍 **Model Discovery**
- List all available models with pagination support
- Get detailed information about specific models
- Check model existence and availability
- Filter models by capabilities and requirements

### 📊 **Advanced Analytics**
- Comprehensive model statistics and insights
- Capability analysis and comparison
- Performance metrics and monitoring
- Model recommendation engine

### ⚡ **Performance & Reliability**
- Built-in telemetry and observability
- Comprehensive error handling and validation
- Caching strategies for production use
- Graceful fallback mechanisms

### 🛠️ **Developer Experience**
- Type-safe request/response structures
- Rich examples and usage patterns
- Production deployment guides
- Extensive test coverage

## API Reference

### Core Functions

#### `Gemini.Models.list/1`

Lists available models with optional pagination.

```elixir
# Basic usage
{:ok, response} = Gemini.Models.list()
models = response.models

# With pagination
{:ok, page1} = Gemini.Models.list(page_size: 10)
{:ok, page2} = Gemini.Models.list(
  page_size: 10, 
  page_token: page1.next_page_token
)
```

**Parameters:**
- `page_size` (integer, optional): Number of models per page (1-1000, default: 50)
- `page_token` (string, optional): Token for pagination

**Returns:**
- `{:ok, ListModelsResponse.t()}` - Success with models and pagination info
- `{:error, Gemini.Error.t()}` - Validation error or API failure

#### `Gemini.Models.get/1`

Gets detailed information about a specific model.

```elixir
# By base model ID
{:ok, model} = Gemini.Models.get("gemini-2.0-flash")

# By full resource name
{:ok, model} = Gemini.Models.get("models/gemini-1.5-pro")

# Error handling
case Gemini.Models.get("nonexistent-model") do
  {:ok, model} -> process_model(model)
  {:error, %{type: :api_error, http_status: 404}} -> handle_not_found()
  {:error, error} -> handle_other_error(error)
end
```

**Parameters:**
- `model_name` (string): Model identifier with or without "models/" prefix

**Returns:**
- `{:ok, Model.t()}` - Success with model details
- `{:error, Gemini.Error.t()}` - Model not found or other error

### Convenience Functions

#### `Gemini.Models.list_names/0`

Returns a simple list of model names.

```elixir
{:ok, names} = Gemini.Models.list_names()
# => ["gemini-2.0-flash", "gemini-1.5-pro", ...]
```

#### `Gemini.Models.exists?/1`

Checks if a model exists and is available.

```elixir
{:ok, true} = Gemini.Models.exists?("gemini-2.0-flash")
{:ok, false} = Gemini.Models.exists?("nonexistent-model")
```

#### `Gemini.Models.supporting_method/1`

Finds models that support a specific generation method.

```elixir
# Find streaming-capable models
{:ok, streaming_models} = Gemini.Models.supporting_method("streamGenerateContent")

# Find models with token counting
{:ok, token_models} = Gemini.Models.supporting_method("countTokens")
```

### Advanced Filtering

#### `Gemini.Models.filter/1`

Filters models by multiple criteria.

```elixir
# High-capacity models
{:ok, large_models} = Gemini.Models.filter(min_input_tokens: 1_000_000)

# Versatile models with multiple capabilities
{:ok, versatile} = Gemini.Models.filter(
  supports_methods: ["generateContent", "streamGenerateContent"],
  min_input_tokens: 100_000,
  has_temperature: true
)

# Models with advanced parameters
{:ok, tunable} = Gemini.Models.filter(
  has_temperature: true,
  has_top_k: true,
  has_top_p: true
)
```

**Filter Options:**
- `min_input_tokens` (integer): Minimum input token limit
- `min_output_tokens` (integer): Minimum output token limit
- `supports_methods` (list): Required generation methods
- `has_temperature` (boolean): Must have temperature parameter
- `has_top_k` (boolean): Must have top_k parameter
- `has_top_p` (boolean): Must have top_p parameter

### Analytics and Statistics

#### `Gemini.Models.get_stats/0`

Generates comprehensive model statistics.

```elixir
{:ok, stats} = Gemini.Models.get_stats()

# Access different statistics
IO.puts "Total models: #{stats.total_models}"
IO.puts "By version: #{inspect(stats.by_version)}"
IO.puts "Method support: #{inspect(stats.by_method)}"
IO.puts "Token limits: #{inspect(stats.token_limits)}"
```

**Statistics Include:**
- `total_models`: Total number of available models
- `by_version`: Count of models by version (e.g., %{"1.5" => 3, "2.0" => 2})
- `by_method`: Count of models supporting each method
- `token_limits`: Min/max/average token capacities
- `capabilities`: Count of models with advanced features

## Data Types

### Model Structure

The `Model` struct contains comprehensive information about each model:

```elixir
%Model{
  name: "models/gemini-2.0-flash-001",           # Full resource name
  base_model_id: "gemini-2.0-flash",            # Base identifier
  version: "2.0",                               # Version number
  display_name: "Gemini 2.0 Flash",            # Human-readable name
  description: "Fast and versatile model...",   # Description
  input_token_limit: 1_000_000,                # Max input tokens
  output_token_limit: 8192,                    # Max output tokens
  supported_generation_methods: [               # Available methods
    "generateContent",
    "streamGenerateContent",
    "countTokens"
  ],
  temperature: 1.0,                             # Default temperature
  max_temperature: 2.0,                        # Max temperature
  top_p: 0.95,                                 # Nucleus sampling param
  top_k: 40                                    # Top-k sampling param
}
```

### Model Capabilities

The `Model` module provides helper functions for analyzing capabilities:

```elixir
# Check specific capabilities
Model.supports_streaming?(model)           # true/false
Model.supports_token_counting?(model)      # true/false
Model.supports_embeddings?(model)          # true/false
Model.production_ready?(model)             # true/false

# Get comprehensive summary
capabilities = Model.capabilities_summary(model)
# => %{
#   supports_streaming: true,
#   supports_token_counting: true,
#   supports_embeddings: false,
#   has_temperature: true,
#   has_top_k: true,
#   method_count: 3,
#   input_capacity: :very_large,
#   output_capacity: :small
# }

# Compare models
Model.compare_capabilities(model_a, model_b)  # :lt | :eq | :gt

# Extract family and metadata
Model.model_family(model)                  # "gemini"
Model.effective_base_id(model)            # "gemini-2.0-flash"
Model.is_latest_version?(model)           # true/false
```

## Error Handling

The implementation provides comprehensive error handling with specific error types:

### Validation Errors

```elixir
# Invalid page size
{:error, %Error{type: :validation_error}} = Models.list(page_size: 9999)

# Empty model name
{:error, %Error{type: :validation_error}} = Models.get("")
```

### API Errors

```elixir
# Model not found
{:error, %Error{type: :api_error, http_status: 404}} = Models.get("nonexistent")

# Authentication failure
{:error, %Error{type: :api_error, http_status: 401}} = Models.list()
```

### Network Errors

```elixir
# Connection timeout
{:error, %Error{type: :network_error}} = Models.list()
```

### Error Handling Patterns

```elixir
# Graceful fallback
def get_model_with_fallback(preferred_models) do
  Enum.find_value(preferred_models, fn model_name ->
    case Models.get(model_name) do
      {:ok, model} -> model
      {:error, _} -> nil
    end
  end)
end

# Retry with exponential backoff
def get_model_with_retry(model_name, retries \\ 3) do
  case Models.get(model_name) do
    {:ok, model} -> {:ok, model}
    {:error, %{type: :network_error}} when retries > 0 ->
      :timer.sleep(1000 * (4 - retries))
      get_model_with_retry(model_name, retries - 1)
    {:error, _} = error -> error
  end
end
```

## Performance and Monitoring

### Telemetry Events

The implementation emits comprehensive telemetry events for monitoring:

#### Success Events
- `[:gemini, :models, :list, :success]`
- `[:gemini, :models, :get, :success]`

#### Error Events
- `[:gemini, :models, :list, :error]`
- `[:gemini, :models, :get, :error]`

#### Event Data

```elixir
# Measurements
%{
  duration: 150,      # Request duration in milliseconds
  model_count: 10     # Number of models (list operations only)
}

# Metadata
%{
  function: :list_models,
  model: "gemini-2.0-flash",    # For get operations
  error_type: :network_error    # For error events
}
```

### Monitoring Setup

```elixir
# Attach telemetry handlers
:telemetry.attach_many(
  "models-monitoring",
  [
    [:gemini, :models, :list, :success],
    [:gemini, :models, :list, :error],
    [:gemini, :models, :get, :success],
    [:gemini, :models, :get, :error]
  ],
  &handle_telemetry/4,
  %{}
)

def handle_telemetry(event, measurements, metadata, _config) do
  # Send to your monitoring system
  MyMetrics.emit(event, measurements, metadata)
end
```

### Caching Strategy

For production use, implement caching to reduce API calls:

```elixir
defmodule ModelCache do
  @cache_ttl 5 * 60 * 1000  # 5 minutes

  def get_model(model_name) do
    case :ets.lookup(:model_cache, model_name) do
      [{^model_name, model, timestamp}] ->
        if System.monotonic_time(:millisecond) - timestamp < @cache_ttl do
          {:ok, model}
        else
          fetch_and_cache(model_name)
        end
      [] ->
        fetch_and_cache(model_name)
    end
  end

  defp fetch_and_cache(model_name) do
    case Models.get(model_name) do
      {:ok, model} ->
        :ets.insert(:model_cache, {
          model_name, 
          model, 
          System.monotonic_time(:millisecond)
        })
        {:ok, model}
      error ->
        error
    end
  end
end
```

## Production Deployment

### Configuration

```elixir
# config/prod.exs
config :gemini,
  api_key: System.get_env("GEMINI_API_KEY"),
  timeout: 30_000,
  telemetry_enabled: true

# Optional: Configure rate limiting
config :gemini, :rate_limit,
  max_requests: 100,
  time_window: 60_000  # 1 minute
```

### Health Checks

```elixir
defmodule MyApp.HealthCheck do
  def models_api_health do
    case Models.list(page_size: 1) do
      {:ok, %{models: [_model | _]}} -> :ok
      {:ok, %{models: []}} -> {:warning, "No models available"}
      {:error, error} -> {:error, error}
    end
  end
end
```

### Circuit Breaker Pattern

```elixir
defmodule ModelService do
  use CircuitBreaker

  def get_model_safe(model_name) do
    circuit_breaker("models_api", fn ->
      Models.get(model_name)
    end)
  end
end
```

## Usage Examples

### Model Selection for Use Cases

```elixir
# Real-time chat application
{:ok, chat_models} = Models.filter(
  supports_methods: ["generateContent", "streamGenerateContent"],
  min_output_tokens: 2000
)

# Document analysis
{:ok, doc_models} = Models.filter(
  min_input_tokens: 1_000_000,
  supports_methods: ["generateContent"]
)

# Fine-tuned applications
{:ok, tunable_models} = Models.filter(
  has_temperature: true,
  has_top_k: true,
  has_top_p: true
)
```

### Batch Operations

```elixir
# Fetch multiple models in parallel
model_names = ["gemini-2.0-flash", "gemini-1.5-pro", "gemini-1.5-flash"]

results = 
  model_names
  |> Task.async_stream(&Models.get/1, max_concurrency: 3)
  |> Enum.map(fn {:ok, result} -> result end)
```

### Model Comparison

```elixir
# Compare models by capability
{:ok, models} = Models.list()

best_model = 
  models
  |> Enum.filter(&Model.production_ready?/1)
  |> Enum.max_by(&Model.capability_score/1)

# Group by family
models_by_family = 
  models
  |> Enum.group_by(&Model.model_family/1)

# Find best streaming model
{:ok, streaming_models} = Models.supporting_method("streamGenerateContent")
best_streaming = 
  streaming_models
  |> Enum.max_by(& &1.input_token_limit)
```

### Analytics Dashboard

```elixir
defmodule ModelsDashboard do
  def generate_report do
    {:ok, stats} = Models.get_stats()
    {:ok, models} = Models.list()
    
    %{
      overview: %{
        total_models: stats.total_models,
        version_distribution: stats.by_version,
        capability_coverage: calculate_coverage(stats.by_method, stats.total_models)
      },
      capacity_analysis: %{
        token_limits: stats.token_limits,
        high_capacity_count: count_high_capacity(models),
        capacity_tiers: group_by_capacity(models)
      },
      recommendations: %{
        best_for_production: find_production_models(models),
        most_versatile: find_versatile_models(models),
        latest_models: find_latest_models(models)
      }
    }
  end
  
  defp calculate_coverage(method_counts, total) do
    method_counts
    |> Enum.map(fn {method, count} -> 
      {method, Float.round(count / total * 100, 1)} 
    end)
    |> Enum.into(%{})
  end
  
  defp count_high_capacity(models) do
    Enum.count(models, & &1.input_token_limit >= 1_000_000)
  end
  
  defp group_by_capacity(models) do
    models
    |> Enum.group_by(fn model ->
      cond do
        model.input_token_limit >= 1_000_000 -> :very_large
        model.input_token_limit >= 100_000 -> :large
        model.input_token_limit >= 30_000 -> :medium
        true -> :small
      end
    end)
    |> Enum.map(fn {tier, models} -> {tier, length(models)} end)
    |> Enum.into(%{})
  end
  
  defp find_production_models(models) do
    models
    |> Enum.filter(&Model.production_ready?/1)
    |> Enum.sort(&(Model.compare_capabilities(&1, &2) == :gt))
    |> Enum.take(3)
    |> Enum.map(&Model.effective_base_id/1)
  end
  
  defp find_versatile_models(models) do
    models
    |> Enum.filter(fn model ->
      Model.supports_streaming?(model) and
      Model.supports_token_counting?(model) and
      Model.has_advanced_params?(model)
    end)
    |> Enum.map(&Model.effective_base_id/1)
  end
  
  defp find_latest_models(models) do
    models
    |> Enum.filter(&Model.is_latest_version?/1)
    |> Enum.map(&Model.effective_base_id/1)
  end
end
```

## Testing

### Unit Tests

The implementation includes comprehensive unit tests covering:

- **Basic Operations**: List, get, exists functionality
- **Validation**: Parameter validation and error handling
- **Filtering**: Advanced filtering with multiple criteria
- **Analytics**: Statistics generation and model comparison
- **Edge Cases**: Empty responses, malformed data, network errors
- **Performance**: Telemetry emission and timing

### Integration Tests

Real API integration tests verify:

- **Live API**: Actual API connectivity and responses
- **Pagination**: Multi-page result handling
- **Error Scenarios**: 404 responses, rate limiting
- **Performance**: Response times and throughput

### Property-Based Tests

Property tests ensure:

- **Invariants**: Consistent behavior across inputs
- **Model Properties**: Capability scoring monotonicity
- **Request Validation**: Input sanitization and normalization

### Running Tests

```bash
# Unit tests only
mix test --exclude integration

# Include integration tests (requires API key)
GEMINI_API_KEY=your_key mix test

# Property-based tests
mix test test/gemini/models_property_test.exs

# Performance benchmarks
mix test test/gemini/models_performance_test.exs
```

## Migration Guide

### From Previous Implementation

The refactored implementation maintains backward compatibility while adding new features:

#### Breaking Changes
- `Models.list/1` now returns `ListModelsResponse` struct instead of raw map
- Enhanced error types with more specific categorization
- Stricter validation on input parameters

#### New Features
- `filter/1` function for advanced model filtering
- `get_stats/0` for comprehensive analytics
- Enhanced `Model` struct with capability helpers
- Comprehensive telemetry events

#### Migration Steps

1. **Update Response Handling**:
   ```elixir
   # Old
   {:ok, response} = Models.list()
   models = response["models"]
   
   # New
   {:ok, response} = Models.list()
   models = response.models
   ```

2. **Update Error Handling**:
   ```elixir
   # Old
   case Models.get(model_name) do
     {:ok, model} -> process(model)
     {:error, _} -> handle_error()
   end
   
   # New - more specific error handling
   case Models.get(model_name) do
     {:ok, model} -> process(model)
     {:error, %{type: :api_error, http_status: 404}} -> handle_not_found()
     {:error, %{type: :validation_error}} -> handle_invalid_input()
     {:error, error} -> handle_other_error(error)
   end
   ```

3. **Leverage New Capabilities**:
   ```elixir
   # Use new filtering capabilities
   {:ok, suitable_models} = Models.filter(
     min_input_tokens: 100_000,
     supports_methods: ["generateContent", "streamGenerateContent"]
   )
   
   # Use model analytics
   {:ok, stats} = Models.get_stats()
   IO.puts "#{stats.total_models} models available"
   ```

## Best Practices

### Production Usage

1. **Implement Caching**: Cache model information to reduce API calls
2. **Monitor Performance**: Use telemetry for observability
3. **Handle Errors Gracefully**: Implement fallback strategies
4. **Use Filtering**: Leverage advanced filtering for model selection
5. **Rate Limiting**: Respect API rate limits with circuit breakers

### Security Considerations

1. **API Key Management**: Store API keys securely
2. **Input Validation**: Validate all user inputs
3. **Error Information**: Don't expose sensitive error details
4. **Logging**: Log operations without exposing credentials

### Performance Optimization

1. **Batch Operations**: Use parallel processing for multiple models
2. **Pagination**: Use appropriate page sizes for large datasets
3. **Caching Strategy**: Implement TTL-based caching
4. **Connection Pooling**: Reuse HTTP connections
5. **Request Deduplication**: Avoid duplicate API calls

## FAQ

### Q: How do I find the best model for my use case?

Use the filtering capabilities:

```elixir
# For chat applications
{:ok, chat_models} = Models.filter(
  supports_methods: ["generateContent", "streamGenerateContent"],
  min_output_tokens: 2000,
  has_temperature: true
)

# For document processing
{:ok, doc_models} = Models.filter(
  min_input_tokens: 500_000,
  supports_methods: ["generateContent"]
)
```

### Q: How do I handle model deprecation?

Implement a fallback strategy:

```elixir
preferred_models = [
  "gemini-2.0-flash",     # Latest
  "gemini-1.5-pro",      # Stable fallback
  "gemini-1.5-flash"     # Last resort
]

case find_available_model(preferred_models) do
  {:ok, model_name} -> use_model(model_name)
  {:error, :no_models_available} -> handle_degraded_service()
end
```

### Q: How do I monitor API usage and performance?

Set up telemetry handlers:

```elixir
:telemetry.attach_many(
  "models-monitoring",
  [
    [:gemini, :models, :list, :success],
    [:gemini, :models, :get, :success],
    [:gemini, :models, :list, :error],
    [:gemini, :models, :get, :error]
  ],
  &send_to_monitoring_system/4,
  %{}
)
```

### Q: How do I implement caching for better performance?

Use ETS or a caching library:

```elixir
defmodule ModelCache do
  @ttl 300_000  # 5 minutes
  
  def get_model(name) do
    case :ets.lookup(:models, name) do
      [{^name, model, time}] when time + @ttl > :erlang.system_time(:millisecond) ->
        {:ok, model}
      _ ->
        fetch_and_cache(name)
    end
  end
  
  defp fetch_and_cache(name) do
    case Models.get(name) do
      {:ok, model} ->
        :ets.insert(:models, {name, model, :erlang.system_time(:millisecond)})
        {:ok, model}
      error ->
        error
    end
  end
end
```

### Q: What's the difference between `base_model_id` and `name`?

- `name`: Full resource identifier (e.g., "models/gemini-2.0-flash-001")
- `base_model_id`: Base model identifier (e.g., "gemini-2.0-flash")

Use `Model.effective_base_id/1` to get the base ID regardless of which field is populated.

### Q: How do I check if a model supports specific features?

Use the capability helper functions:

```elixir
model = get_model("gemini-2.0-flash")

# Check specific capabilities
Model.supports_streaming?(model)        # true/false
Model.supports_token_counting?(model)   # true/false
Model.production_ready?(model)          # true/false

# Get full capability summary
Model.capabilities_summary(model)
```

## Conclusion

The refactored Gemini Models API implementation provides a robust, production-ready interface for working with Gemini models. It includes comprehensive error handling, advanced filtering capabilities, performance monitoring, and extensive documentation to support both development and production usage.

Key benefits of this implementation:

- ✅ **Complete API Coverage**: Full implementation of the Models API specification
- ✅ **Production Ready**: Comprehensive error handling, telemetry, and monitoring
- ✅ **Developer Friendly**: Rich examples, type safety, and clear documentation
- ✅ **Performance Optimized**: Caching strategies, batch operations, and monitoring
- ✅ **Extensible**: Clean architecture supporting future enhancements

For more examples and advanced usage patterns, see the included example modules and test suites.