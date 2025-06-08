defmodule Gemini.Examples.ModelsAPI do
  @moduledoc """
  Comprehensive examples showing how to use the Gemini Models API.

  This module demonstrates various patterns and use cases for working with
  the Models API, from basic operations to advanced filtering and analysis.
  """

  alias Gemini.Models
  alias Gemini.Types.Response.{ListModelsResponse, Model}

  @doc """
  Basic model listing and information retrieval.
  """
  def basic_model_operations do
    IO.puts("=== Basic Model Operations ===\n")

    # List all available models
    case Models.list() do
      {:ok, %ListModelsResponse{models: models}} ->
        IO.puts("Found #{length(models)} available models:")

        # Display basic info for each model
        Enum.each(models, fn model ->
          IO.puts("  • #{model.display_name}")
          IO.puts("    ID: #{Model.effective_base_id(model)}")
          IO.puts("    Input limit: #{format_tokens(model.input_token_limit)}")
          IO.puts("    Output limit: #{format_tokens(model.output_token_limit)}")
          IO.puts("    Methods: #{Enum.join(model.supported_generation_methods, ", ")}")
          IO.puts("")
        end)

      {:error, error} ->
        IO.puts("Error listing models: #{error.message}")
    end

    # Get detailed information about a specific model
    IO.puts("\n--- Model Details ---")
    case Models.get("gemini-2.0-flash") do
      {:ok, model} ->
        print_detailed_model_info(model)
      {:error, error} ->
        IO.puts("Error getting model details: #{error.message}")
    end

    # Check if a model exists
    IO.puts("\n--- Model Existence Check ---")
    case Models.exists?("gemini-2.0-flash") do
      {:ok, true} -> IO.puts("✓ gemini-2.0-flash is available")
      {:ok, false} -> IO.puts("✗ gemini-2.0-flash is not available")
      {:error, _} -> IO.puts("Error checking model existence")
    end
  end

  @doc """
  Demonstrate model filtering and capability analysis.
  """
  def advanced_model_filtering do
    IO.puts("=== Advanced Model Filtering ===\n")

    # Find models that support streaming
    case Models.supporting_method("streamGenerateContent") do
      {:ok, streaming_models} ->
        IO.puts("Models supporting streaming (#{length(streaming_models)}):")
        Enum.each(streaming_models, fn model ->
          IO.puts("  • #{Model.effective_base_id(model)} - #{model.display_name}")
        end)
      {:error, _} ->
        IO.puts("Error finding streaming models")
    end

    IO.puts("")

    # Find high-capacity models
    case Models.filter(min_input_tokens: 1_000_000) do
      {:ok, high_capacity_models} ->
        IO.puts("High-capacity models (1M+ input tokens):")
        Enum.each(high_capacity_models, fn model ->
          IO.puts("  • #{Model.effective_base_id(model)}: #{format_tokens(model.input_token_limit)}")
        end)
      {:error, _} ->
        IO.puts("Error finding high-capacity models")
    end

    IO.puts("")

    # Find versatile models (support multiple methods)
    case Models.filter(supports_methods: ["generateContent", "streamGenerateContent", "countTokens"]) do
      {:ok, versatile_models} ->
        IO.puts("Versatile models (content + streaming + tokens):")
        Enum.each(versatile_models, fn model ->
          capabilities = Model.capabilities_summary(model)
          IO.puts("  • #{Model.effective_base_id(model)}")
          IO.puts("    Methods: #{capabilities.method_count}")
          IO.puts("    Streaming: #{if capabilities.supports_streaming, do: "✓", else: "✗"}")
          IO.puts("    Token counting: #{if capabilities.supports_token_counting, do: "✓", else: "✗"}")
        end)
      {:error, _} ->
        IO.puts("Error finding versatile models")
    end

    IO.puts("")

    # Find models with advanced generation parameters
    case Models.filter(has_temperature: true, has_top_k: true) do
      {:ok, tunable_models} ->
        IO.puts("Models with advanced tuning parameters:")
        Enum.each(tunable_models, fn model ->
          IO.puts("  • #{Model.effective_base_id(model)}")
          IO.puts("    Temperature: #{model.temperature}")
          IO.puts("    Top-K: #{model.top_k}")
          IO.puts("    Top-P: #{model.top_p}")
        end)
      {:error, _} ->
        IO.puts("Error finding tunable models")
    end
  end

  @doc """
  Demonstrate pagination for handling large model lists.
  """
  def pagination_example do
    IO.puts("=== Pagination Example ===\n")

    page_size = 3
    page_num = 1
    page_token = nil

    paginate_through_models(page_size, page_num, page_token)
  end

  defp paginate_through_models(page_size, page_num, page_token) do
    IO.puts("--- Page #{page_num} ---")

    opts = [page_size: page_size]
    opts = if page_token, do: Keyword.put(opts, :page_token, page_token), else: opts

    case Models.list(opts) do
      {:ok, %ListModelsResponse{models: models, next_page_token: next_token}} ->
        Enum.each(models, fn model ->
          IO.puts("  #{page_num}.#{length(models)} #{Model.effective_base_id(model)} - #{model.display_name}")
        end)

        if next_token do
          IO.puts("\nContinuing to next page...\n")
          paginate_through_models(page_size, page_num + 1, next_token)
        else
          IO.puts("\nReached end of model list")
        end

      {:error, error} ->
        IO.puts("Error during pagination: #{error.message}")
    end
  end

  @doc """
  Generate comprehensive model statistics and analysis.
  """
  def model_analytics do
    IO.puts("=== Model Analytics ===\n")

    case Models.get_stats() do
      {:ok, stats} ->
        IO.puts("📊 Total Models: #{stats.total_models}")
        IO.puts("")

        # Version distribution
        IO.puts("📈 Models by Version:")
        Enum.each(stats.by_version, fn {version, count} ->
          percentage = round(count / stats.total_models * 100)
          IO.puts("  #{version}: #{count} models (#{percentage}%)")
        end)
        IO.puts("")

        # Method support analysis
        IO.puts("🔧 Method Support:")
        most_common_methods =
          stats.by_method
          |> Enum.sort_by(fn {_method, count} -> count end, :desc)
          |> Enum.take(5)

        Enum.each(most_common_methods, fn {method, count} ->
          percentage = round(count / stats.total_models * 100)
          IO.puts("  #{method}: #{count} models (#{percentage}%)")
        end)
        IO.puts("")

        # Token capacity analysis
        IO.puts("💾 Token Capacity:")
        IO.puts("  Max Input: #{format_tokens(stats.token_limits.max_input)}")
        IO.puts("  Max Output: #{format_tokens(stats.token_limits.max_output)}")
        IO.puts("  Avg Input: #{format_tokens(stats.token_limits.avg_input)}")
        IO.puts("  Avg Output: #{format_tokens(stats.token_limits.avg_output)}")
        IO.puts("")

        # Advanced capabilities
        IO.puts("⚙️  Advanced Capabilities:")
        total = stats.total_models
        IO.puts("  Temperature control: #{stats.capabilities.with_temperature}/#{total}")
        IO.puts("  Top-K sampling: #{stats.capabilities.with_top_k}/#{total}")
        IO.puts("  Top-P sampling: #{stats.capabilities.with_top_p}/#{total}")
        IO.puts("")

        # Model recommendations
        generate_model_recommendations(stats)

      {:error, error} ->
        IO.puts("Error generating analytics: #{error.message}")
    end
  end

  @doc """
  Find the best model for specific use cases.
  """
  def model_selection_guide do
    IO.puts("=== Model Selection Guide ===\n")

    use_cases = [
      %{
        name: "Real-time Chat Application",
        requirements: [supports_methods: ["generateContent", "streamGenerateContent"]],
        description: "Fast response with streaming support"
      },
      %{
        name: "Document Analysis",
        requirements: [min_input_tokens: 500_000],
        description: "Large context window for long documents"
      },
      %{
        name: "Production API",
        requirements: [
          supports_methods: ["generateContent", "streamGenerateContent", "countTokens"],
          min_input_tokens: 100_000,
          min_output_tokens: 4000
        ],
        description: "Comprehensive feature set with good capacity"
      },
      %{
        name: "Fine-tuned Applications",
        requirements: [has_temperature: true, has_top_k: true],
        description: "Precise control over generation parameters"
      }
    ]

    Enum.each(use_cases, fn use_case ->
      IO.puts("🎯 #{use_case.name}")
      IO.puts("   #{use_case.description}")

      case Models.filter(use_case.requirements) do
        {:ok, suitable_models} ->
          if length(suitable_models) > 0 do
            # Sort by capability score to find the best options
            best_models =
              suitable_models
              |> Enum.sort(&(Model.compare_capabilities(&1, &2) == :gt))
              |> Enum.take(3)

            IO.puts("   ✓ Recommended models:")
            Enum.with_index(best_models, 1) do |{model, index}|
              production_ready = if Model.production_ready?(model), do: "🟢", else: "🟡"
              IO.puts("     #{index}. #{production_ready} #{Model.effective_base_id(model)}")
              IO.puts("        #{model.display_name}")

              caps = Model.capabilities_summary(model)
              IO.puts("        Input: #{format_tokens(model.input_token_limit)}, Output: #{format_tokens(model.output_token_limit)}")
              IO.puts("        Methods: #{caps.method_count}, Streaming: #{caps.supports_streaming}")
            end
          else
            IO.puts("   ✗ No models match these requirements")
          end

        {:error, _} ->
          IO.puts("   ✗ Error finding suitable models")
      end

      IO.puts("")
    end
  end

  @doc """
  Demonstrate error handling patterns.
  """
  def error_handling_examples do
    IO.puts("=== Error Handling Examples ===\n")

    # Handle non-existent model
    IO.puts("--- Non-existent Model ---")
    case Models.get("definitely-does-not-exist") do
      {:ok, model} ->
        IO.puts("Unexpected success: #{model.name}")
      {:error, %{type: :api_error, http_status: 404}} ->
        IO.puts("✓ Correctly handled 404 - model not found")
      {:error, error} ->
        IO.puts("Other error: #{error.message}")
    end

    # Handle invalid parameters
    IO.puts("\n--- Invalid Parameters ---")
    case Models.list(page_size: 9999) do
      {:ok, _} ->
        IO.puts("Unexpected success with invalid page size")
      {:error, %{type: :validation_error}} ->
        IO.puts("✓ Correctly caught validation error")
      {:error, error} ->
        IO.puts("Other error: #{error.message}")
    end

    # Graceful degradation example
    IO.puts("\n--- Graceful Degradation ---")
    fallback_models = ["gemini-2.0-flash", "gemini-1.5-pro", "gemini-1.5-flash"]

    selected_model = find_available_model(fallback_models)
    case selected_model do
      {:ok, model_name} ->
        IO.puts("✓ Selected available model: #{model_name}")
      {:error, :no_models_available} ->
        IO.puts("✗ No fallback models are available")
    end
  end

  # Helper functions

  defp print_detailed_model_info(model) do
    IO.puts("Model: #{model.display_name}")
    IO.puts("ID: #{Model.effective_base_id(model)}")
    IO.puts("Version: #{model.version}")
    IO.puts("Description: #{model.description}")
    IO.puts("")

    IO.puts("Capacity:")
    IO.puts("  Input tokens: #{format_tokens(model.input_token_limit)}")
    IO.puts("  Output tokens: #{format_tokens(model.output_token_limit)}")
    IO.puts("")

    IO.puts("Supported methods:")
    Enum.each(model.supported_generation_methods, fn method ->
      IO.puts("  • #{method}")
    end)
    IO.puts("")

    if Model.has_advanced_params?(model) do
      IO.puts("Generation parameters:")
      if model.temperature, do: IO.puts("  Temperature: #{model.temperature} (max: #{model.max_temperature})")
      if model.top_p, do: IO.puts("  Top-P: #{model.top_p}")
      if model.top_k, do: IO.puts("  Top-K: #{model.top_k}")
      IO.puts("")
    end

    capabilities = Model.capabilities_summary(model)
    IO.puts("Capabilities:")
    IO.puts("  Streaming: #{if capabilities.supports_streaming, do: "✓", else: "✗"}")
    IO.puts("  Token counting: #{if capabilities.supports_token_counting, do: "✓", else: "✗"}")
    IO.puts("  Embeddings: #{if capabilities.supports_embeddings, do: "✓", else: "✗"}")
    IO.puts("  Production ready: #{if Model.production_ready?(model), do: "✓", else: "✗"}")
    IO.puts("  Latest version: #{if Model.is_latest_version?(model), do: "✓", else: "✗"}")
  end

  defp format_tokens(count) when count >= 1_000_000 do
    "#{Float.round(count / 1_000_000, 1)}M"
  end

  defp format_tokens(count) when count >= 1_000 do
    "#{Float.round(count / 1_000, 1)}K"
  end

  defp format_tokens(count) do
    "#{count}"
  end

  defp generate_model_recommendations(stats) do
    IO.puts("💡 Recommendations:")

    cond do
      stats.capabilities.with_temperature < stats.total_models / 2 ->
        IO.puts("  • Most models don't support temperature control")
        IO.puts("    Consider using models with advanced parameters for better control")

      stats.by_method["streamGenerateContent"] < stats.total_models / 2 ->
        IO.puts("  • Limited streaming support available")
        IO.puts("    Choose streaming-capable models for real-time applications")

      stats.token_limits.avg_input < 100_000 ->
        IO.puts("  • Average input capacity is relatively low")
        IO.puts("    Use high-capacity models for document processing")

      true ->
        IO.puts("  • Good variety of models with different capabilities")
        IO.puts("    Select based on your specific use case requirements")
    end
  end

  defp find_available_model([]), do: {:error, :no_models_available}

  defp find_available_model([model_name | rest]) do
    case Models.exists?(model_name) do
      {:ok, true} -> {:ok, model_name}
      {:ok, false} -> find_available_model(rest)
      {:error, _} -> find_available_model(rest)
    end
  end

  @doc """
  Run all examples.
  """
  def run_all_examples do
    basic_model_operations()
    IO.puts("\n" <> String.duplicate("=", 60) <> "\n")

    advanced_model_filtering()
    IO.puts("\n" <> String.duplicate("=", 60) <> "\n")

    pagination_example()
    IO.puts("\n" <> String.duplicate("=", 60) <> "\n")

    model_analytics()
    IO.puts("\n" <> String.duplicate("=", 60) <> "\n")

    model_selection_guide()
    IO.puts("\n" <> String.duplicate("=", 60) <> "\n")

    error_handling_examples()
  end
end

# Usage in IEx:
# iex> Gemini.Examples.ModelsAPI.run_all_examples()
#
# Or run individual examples:
# iex> Gemini.Examples.ModelsAPI.basic_model_operations()
# iex> Gemini.Examples.ModelsAPI.model_selection_guide()
# iex> Gemini.Examples.ModelsAPI.model_analytics()
end

# Performance monitoring example
defmodule Gemini.Examples.ModelsPerformance do
  @moduledoc """
  Examples of monitoring Models API performance and implementing caching strategies.
  """

  alias Gemini.Models
  alias Gemini.Types.Response.{ListModelsResponse, Model}

  @doc """
  Demonstrate performance monitoring with telemetry.
  """
  def performance_monitoring_example do
    IO.puts("=== Performance Monitoring ===\n")

    # Attach telemetry handlers for performance monitoring
    :telemetry.attach_many(
      "models-performance-monitor",
      [
        [:gemini, :models, :list, :success],
        [:gemini, :models, :list, :error],
        [:gemini, :models, :get, :success],
        [:gemini, :models, :get, :error]
      ],
      &handle_telemetry_event/4,
      %{}
    )

    IO.puts("📊 Starting performance test...")

    # Test list performance
    list_start = System.monotonic_time(:millisecond)
    case Models.list() do
      {:ok, response} ->
        list_duration = System.monotonic_time(:millisecond) - list_start
        IO.puts("✓ List models: #{list_duration}ms (#{length(response.models)} models)")
      {:error, _} ->
        IO.puts("✗ List models failed")
    end

    # Test get performance with multiple models
    if true do
      test_models = ["gemini-2.0-flash", "gemini-1.5-pro", "gemini-1.5-flash"]

      IO.puts("\n📈 Testing individual model retrieval:")
      Enum.each(test_models, fn model_name ->
        get_start = System.monotonic_time(:millisecond)
        case Models.get(model_name) do
          {:ok, _model} ->
            get_duration = System.monotonic_time(:millisecond) - get_start
            IO.puts("  ✓ #{model_name}: #{get_duration}ms")
          {:error, _} ->
            IO.puts("  ✗ #{model_name}: failed")
        end
      end)
    end

    # Clean up telemetry handlers
    :telemetry.detach("models-performance-monitor")
  end

  @doc """
  Implement a simple caching strategy for model information.
  """
  def caching_example do
    IO.puts("=== Caching Strategy Example ===\n")

    # Start the cache process
    {:ok, cache_pid} = ModelCache.start_link()

    IO.puts("🗄️  Testing cached model operations...")

    # First call - will hit the API
    IO.puts("\n--- First call (cache miss) ---")
    {duration1, result1} = :timer.tc(fn -> ModelCache.get_model(cache_pid, "gemini-2.0-flash") end)
    IO.puts("Duration: #{duration1 / 1000}ms")
    case result1 do
      {:ok, model} -> IO.puts("✓ Retrieved: #{model.display_name}")
      {:error, _} -> IO.puts("✗ Failed to retrieve model")
    end

    # Second call - should hit the cache
    IO.puts("\n--- Second call (cache hit) ---")
    {duration2, result2} = :timer.tc(fn -> ModelCache.get_model(cache_pid, "gemini-2.0-flash") end)
    IO.puts("Duration: #{duration2 / 1000}ms")
    case result2 do
      {:ok, model} -> IO.puts("✓ Retrieved: #{model.display_name}")
      {:error, _} -> IO.puts("✗ Failed to retrieve model")
    end

    speedup = if duration2 > 0, do: duration1 / duration2, else: "∞"
    IO.puts("\n📊 Cache speedup: #{Float.round(speedup, 1)}x")

    # Test cache with model list
    IO.puts("\n--- Cached model list ---")
    {list_duration, list_result} = :timer.tc(fn -> ModelCache.list_models(cache_pid) end)
    IO.puts("Duration: #{list_duration / 1000}ms")
    case list_result do
      {:ok, models} -> IO.puts("✓ Retrieved #{length(models)} models")
      {:error, _} -> IO.puts("✗ Failed to retrieve models")
    end

    # Clean up
    GenServer.stop(cache_pid)
  end

  @doc """
  Demonstrate batch operations for efficiency.
  """
  def batch_operations_example do
    IO.puts("=== Batch Operations Example ===\n")

    # Get multiple models efficiently
    model_names = ["gemini-2.0-flash", "gemini-1.5-pro", "gemini-1.5-flash"]

    IO.puts("🔄 Fetching models in parallel...")

    start_time = System.monotonic_time(:millisecond)

    # Use Task.async_stream for parallel fetching
    results =
      model_names
      |> Task.async_stream(
        fn model_name -> {model_name, Models.get(model_name)} end,
        max_concurrency: 3,
        timeout: 10_000
      )
      |> Enum.map(fn {:ok, result} -> result end)

    total_duration = System.monotonic_time(:millisecond) - start_time

    IO.puts("📊 Batch operation completed in #{total_duration}ms")
    IO.puts("\nResults:")

    Enum.each(results, fn {model_name, result} ->
      case result do
        {:ok, model} ->
          IO.puts("  ✓ #{model_name}: #{model.display_name}")
        {:error, error} ->
          IO.puts("  ✗ #{model_name}: #{error.message}")
      end
    end)

    # Calculate efficiency metrics
    successful_count = Enum.count(results, fn {_, result} -> match?({:ok, _}, result) end)
    success_rate = successful_count / length(results) * 100
    avg_time_per_model = total_duration / length(results)

    IO.puts("\n📈 Efficiency metrics:")
    IO.puts("  Success rate: #{Float.round(success_rate, 1)}%")
    IO.puts("  Avg time per model: #{Float.round(avg_time_per_model, 1)}ms")
  end

  # Telemetry event handler
  defp handle_telemetry_event([:gemini, :models, operation, status], measurements, metadata, _config) do
    operation_str = operation |> Atom.to_string() |> String.upcase()
    status_str = status |> Atom.to_string() |> String.upcase()

    case status do
      :success ->
        duration = Map.get(measurements, :duration, 0)
        IO.puts("📈 #{operation_str} #{status_str}: #{duration}ms")

        if operation == :list and Map.has_key?(measurements, :model_count) do
          IO.puts("   Models returned: #{measurements.model_count}")
        end

      :error ->
        duration = Map.get(measurements, :duration, 0)
        error_type = Map.get(metadata, :error_type, :unknown)
        IO.puts("📉 #{operation_str} #{status_str}: #{duration}ms (#{error_type})")
    end
  end
end

# Simple model cache implementation
defmodule ModelCache do
  @moduledoc """
  Simple in-memory cache for model information with TTL support.
  """

  use GenServer

  alias Gemini.Models
  alias Gemini.Types.Response.{ListModelsResponse, Model}

  @default_ttl_ms 5 * 60 * 1000  # 5 minutes

  defstruct models: %{}, model_list: nil, timestamps: %{}

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def get_model(cache_pid, model_name) do
    GenServer.call(cache_pid, {:get_model, model_name})
  end

  def list_models(cache_pid) do
    GenServer.call(cache_pid, :list_models)
  end

  def clear_cache(cache_pid) do
    GenServer.call(cache_pid, :clear_cache)
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call({:get_model, model_name}, _from, state) do
    now = System.monotonic_time(:millisecond)

    case get_cached_model(state, model_name, now) do
      {:hit, model} ->
        {:reply, {:ok, model}, state}

      :miss ->
        case Models.get(model_name) do
          {:ok, model} ->
            new_state = cache_model(state, model_name, model, now)
            {:reply, {:ok, model}, new_state}

          {:error, _} = error ->
            {:reply, error, state}
        end
    end
  end

  @impl true
  def handle_call(:list_models, _from, state) do
    now = System.monotonic_time(:millisecond)

    case get_cached_model_list(state, now) do
      {:hit, models} ->
        {:reply, {:ok, models}, state}

      :miss ->
        case Models.list() do
          {:ok, %ListModelsResponse{models: models}} ->
            new_state = cache_model_list(state, models, now)
            {:reply, {:ok, models}, new_state}

          {:error, _} = error ->
            {:reply, error, state}
        end
    end
  end

  @impl true
  def handle_call(:clear_cache, _from, _state) do
    {:reply, :ok, %__MODULE__{}}
  end

  # Private helper functions

  defp get_cached_model(state, model_name, now) do
    case Map.get(state.models, model_name) do
      nil -> :miss
      model ->
        timestamp = Map.get(state.timestamps, {:model, model_name}, 0)
        if now - timestamp < @default_ttl_ms do
          {:hit, model}
        else
          :miss
        end
    end
  end

  defp get_cached_model_list(state, now) do
    case state.model_list do
      nil -> :miss
      models ->
        timestamp = Map.get(state.timestamps, :model_list, 0)
        if now - timestamp < @default_ttl_ms do
          {:hit, models}
        else
          :miss
        end
    end
  end

  defp cache_model(state, model_name, model, now) do
    %{
      state |
      models: Map.put(state.models, model_name, model),
      timestamps: Map.put(state.timestamps, {:model, model_name}, now)
    }
  end

  defp cache_model_list(state, models, now) do
    %{
      state |
      model_list: models,
      timestamps: Map.put(state.timestamps, :model_list, now)
    }
  end
end

# Production deployment example
defmodule Gemini.Examples.ProductionSetup do
  @moduledoc """
  Examples for production deployment and monitoring of the Models API.
  """

  @doc """
  Set up production-ready telemetry and monitoring.
  """
  def setup_production_monitoring do
    # Attach comprehensive telemetry handlers
    :telemetry.attach_many(
      "gemini-models-production",
      [
        [:gemini, :models, :list, :success],
        [:gemini, :models, :list, :error],
        [:gemini, :models, :get, :success],
        [:gemini, :models, :get, :error]
      ],
      &production_telemetry_handler/4,
      %{service: "gemini-models-api"}
    )

    # Set up periodic health checks
    schedule_health_checks()

    IO.puts("✓ Production monitoring setup complete")
  end

  @doc """
  Implement graceful fallback strategies for production.
  """
  def fallback_strategy_example do
    IO.puts("=== Production Fallback Strategy ===\n")

    # Primary model preference order
    preferred_models = [
      "gemini-2.0-flash",    # Latest, fastest
      "gemini-1.5-pro",     # Stable, capable
      "gemini-1.5-flash"    # Fallback
    ]

    case select_best_available_model(preferred_models) do
      {:ok, {model_name, model}} ->
        IO.puts("✓ Selected model: #{model_name}")
        IO.puts("  Display name: #{model.display_name}")
        IO.puts("  Capabilities: #{Model.capabilities_summary(model) |> inspect}")

      {:error, :no_models_available} ->
        IO.puts("✗ No fallback models available - system degraded")
        # In production, you might:
        # - Switch to cached responses
        # - Use a different AI provider
        # - Return pre-computed responses
        # - Gracefully degrade service features
    end
  end

  # Private helper functions

  defp production_telemetry_handler(event, measurements, metadata, config) do
    # In production, you would typically send these metrics to:
    # - Prometheus/Grafana
    # - DataDog
    # - New Relic
    # - CloudWatch
    # - Your logging system

    service = Map.get(config, :service, "gemini-api")

    case event do
      [:gemini, :models, operation, :success] ->
        duration = Map.get(measurements, :duration, 0)

        # Log success metrics
        Logger.info("#{service}.#{operation}.success",
          duration_ms: duration,
          operation: operation,
          metadata: metadata
        )

        # Send to metrics collector (example)
        # MetricsCollector.increment("#{service}.#{operation}.success")
        # MetricsCollector.histogram("#{service}.#{operation}.duration", duration)

      [:gemini, :models, operation, :error] ->
        duration = Map.get(measurements, :duration, 0)
        error_type = Map.get(metadata, :error_type, "unknown")

        # Log error metrics
        Logger.error("#{service}.#{operation}.error",
          duration_ms: duration,
          operation: operation,
          error_type: error_type,
          metadata: metadata
        )

        # Send to metrics collector and alerting
        # MetricsCollector.increment("#{service}.#{operation}.error", %{error_type: error_type})
        # AlertManager.notify_if_threshold_exceeded("#{service}.error_rate")
    end
  end

  defp schedule_health_checks do
    # In production, you would set up periodic health checks
    # This is a simplified example

    :timer.apply_interval(
      60_000,  # Every minute
      __MODULE__,
      :health_check,
      []
    )
  end

  def health_check do
    case Models.list(page_size: 1) do
      {:ok, %ListModelsResponse{models: [_model | _]}} ->
        Logger.info("Models API health check: OK")
        # Send success metric to monitoring system

      {:ok, %ListModelsResponse{models: []}} ->
        Logger.warn("Models API health check: No models available")
        # Send warning metric

      {:error, error} ->
        Logger.error("Models API health check: FAILED", error: error)
        # Send error metric and trigger alerts
    end
  end

  defp select_best_available_model([]), do: {:error, :no_models_available}

  defp select_best_available_model([model_name | rest]) do
    case Models.get(model_name) do
      {:ok, model} ->
        if Model.production_ready?(model) do
          {:ok, {model_name, model}}
        else
          select_best_available_model(rest)
        end

      {:error, _} ->
        select_best_available_model(rest)
    end
  end
end
