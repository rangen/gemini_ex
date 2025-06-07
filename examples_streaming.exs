defmodule Gemini.StreamingExamples do
  @moduledoc """
  Complete examples demonstrating how to use the improved streaming implementation.
  """

  alias Gemini.Streaming.ManagerV2
  alias Gemini.SSE.Parser
  require Logger

  @doc """
  Example 1: Basic streaming with event handling
  """
  def basic_streaming_example do
    IO.puts("=== Basic Streaming Example ===")
    
    # Start the streaming manager
    {:ok, _pid} = ManagerV2.start_link()
    
    # Start a stream
    contents = "Write a short story about a robot discovering emotions"
    opts = [
      model: "gemini-2.0-flash",
      generation_config: %{
        temperature: 0.8,
        max_output_tokens: 500
      }
    ]
    
    case ManagerV2.start_stream(contents, opts, self()) do
      {:ok, stream_id} ->
        IO.puts("Started stream: #{stream_id}")
        
        # Handle events
        handle_stream_events(stream_id)
        
      {:error, reason} ->
        IO.puts("Failed to start stream: #{inspect(reason)}")
    end
  end

  @doc """
  Example 2: Multiple subscribers on same stream
  """
  def multi_subscriber_example do
    IO.puts("=== Multiple Subscribers Example ===")
    
    {:ok, _pid} = ManagerV2.start_link()
    
    contents = "Explain quantum computing in simple terms"
    
    case ManagerV2.start_stream(contents, [], self()) do
      {:ok, stream_id} ->
        IO.puts("Started stream: #{stream_id}")
        
        # Create additional subscribers
        subscriber1 = spawn(fn -> log_subscriber("SUB1", stream_id) end)
        subscriber2 = spawn(fn -> log_subscriber("SUB2", stream_id) end)
        
        # Subscribe them to the stream
        :ok = ManagerV2.subscribe_stream(stream_id, subscriber1)
        :ok = ManagerV2.subscribe_stream(stream_id, subscriber2)
        
        # Check stats
        {:ok, info} = ManagerV2.get_stream_info(stream_id)
        IO.puts("Subscribers: #{info.subscribers_count}")
        
        # Wait for completion
        handle_stream_events(stream_id)
        
      {:error, reason} ->
        IO.puts("Failed to start stream: #{inspect(reason)}")
    end
  end

  @doc """
  Example 3: Concurrent streams
  """
  def concurrent_streams_example do
    IO.puts("=== Concurrent Streams Example ===")
    
    {:ok, _pid} = ManagerV2.start_link()
    
    # Start multiple streams concurrently
    streams = [
      {"Tell me about Mars", [model: "gemini-2.0-flash"]},
      {"Explain photosynthesis", [model: "gemini-2.0-flash"]},
      {"Write a haiku about coding", [model: "gemini-2.0-flash"]}
    ]
    
    stream_ids = 
      Enum.map(streams, fn {content, opts} ->
        case ManagerV2.start_stream(content, opts, self()) do
          {:ok, stream_id} -> 
            IO.puts("Started stream: #{stream_id}")
            stream_id
          {:error, reason} -> 
            IO.puts("Failed: #{inspect(reason)}")
            nil
        end
      end)
      |> Enum.filter(&(&1 != nil))
    
    IO.puts("Managing #{length(stream_ids)} concurrent streams")
    
    # Monitor all streams
    monitor_concurrent_streams(stream_ids)
  end

  @doc """
  Example 4: Stream with error handling and retries
  """
  def error_handling_example do
    IO.puts("=== Error Handling Example ===")
    
    {:ok, _pid} = ManagerV2.start_link()
    
    # Try with invalid model to demonstrate error handling
    contents = "Hello world"
    opts = [
      model: "invalid-model-name",
      timeout: 5000,
      max_retries: 2
    ]
    
    case ManagerV2.start_stream(contents, opts, self()) do
      {:ok, stream_id} ->
        IO.puts("Started stream: #{stream_id}")
        handle_stream_with_error_recovery(stream_id)
        
      {:error, reason} ->
        IO.puts("Failed to start stream: #{inspect(reason)}")
        
        # Try with valid model as fallback
        fallback_opts = [model: "gemini-2.0-flash"]
        
        case ManagerV2.start_stream(contents, fallback_opts, self()) do
          {:ok, fallback_stream_id} ->
            IO.puts("Started fallback stream: #{fallback_stream_id}")
            handle_stream_events(fallback_stream_id)
            
          {:error, fallback_reason} ->
            IO.puts("Fallback also failed: #{inspect(fallback_reason)}")
        end
    end
  end

  @doc """
  Example 5: Building a chat interface with streaming
  """
  def chat_interface_example do
    IO.puts("=== Chat Interface Example ===")
    
    {:ok, _pid} = ManagerV2.start_link()
    
    # Simulate a chat conversation
    chat_history = []
    
    messages = [
      "Hello! What can you tell me about machine learning?",
      "Can you give me a specific example?",
      "How does this relate to artificial intelligence?"
    ]
    
    Enum.reduce(messages, chat_history, fn message, history ->
      IO.puts("\n👤 User: #{message}")
      
      # Build conversation context
      contents = build_conversation_context(history, message)
      opts = [
        model: "gemini-2.0-flash",
        generation_config: %{temperature: 0.7}
      ]
      
      case ManagerV2.start_stream(contents, opts, self()) do
        {:ok, stream_id} ->
          IO.write("🤖 Assistant: ")
          response_text = collect_stream_text(stream_id)
          IO.puts("")
          
          # Add to history
          history ++ [
            %{role: "user", content: message},
            %{role: "assistant", content: response_text}
          ]
          
        {:error, reason} ->
          IO.puts("🤖 Error: #{inspect(reason)}")
          history
      end
    end)
  end

  @doc """
  Example 6: Custom event processing with text accumulation
  """
  def text_accumulation_example do
    IO.puts("=== Text Accumulation Example ===")
    
    {:ok, _pid} = ManagerV2.start_link()
    
    contents = "Write a detailed explanation of how neural networks work"
    opts = [model: "gemini-2.0-flash"]
    
    case ManagerV2.start_stream(contents, opts, self()) do
      {:ok, stream_id} ->
        IO.puts("Started stream: #{stream_id}")
        
        # Use a GenServer to accumulate text
        {:ok, accumulator_pid} = TextAccumulator.start_link()
        :ok = ManagerV2.subscribe_stream(stream_id, accumulator_pid)
        
        # Wait for completion and get final text
        handle_stream_events(stream_id)
        
        final_text = TextAccumulator.get_text(accumulator_pid)
        IO.puts("\n=== Final accumulated text ===")
        IO.puts(final_text)
        
        TextAccumulator.stop(accumulator_pid)
        
      {:error, reason} ->
        IO.puts("Failed to start stream: #{inspect(reason)}")
    end
  end

  # Helper functions

  defp handle_stream_events(stream_id) do
    receive do
      {:stream_event, ^stream_id, event} ->
        case Parser.extract_text(event) do
          nil -> :ok
          text -> IO.write(text)
        end
        handle_stream_events(stream_id)
        
      {:stream_complete, ^stream_id} ->
        IO.puts("\n✅ Stream completed successfully")
        
      {:stream_error, ^stream_id, error} ->
        IO.puts("\n❌ Stream error: #{inspect(error)}")
        
        # Attempt recovery with different parameters
        IO.puts("🔄 Attempting recovery...")
        
        contents = "Hello world"  # Simpler content
        recovery_opts = [
          model: "gemini-2.0-flash",  # Use known good model
          generation_config: %{max_output_tokens: 50}
        ]
        
        case ManagerV2.start_stream(contents, recovery_opts, self()) do
          {:ok, recovery_stream_id} ->
            IO.puts("🆘 Recovery stream started: #{recovery_stream_id}")
            handle_stream_events(recovery_stream_id)
            
          {:error, recovery_error} ->
            IO.puts("💥 Recovery failed: #{inspect(recovery_error)}")
        end
        
      {:stream_stopped, ^stream_id} ->
        IO.puts("\n⏹️ Stream stopped")
    after
      15_000 ->
        IO.puts("\n⏰ Stream timeout during error recovery")
        ManagerV2.stop_stream(stream_id)
    end
  end

  defp log_subscriber(name, stream_id) do
    receive do
      {:stream_event, ^stream_id, event} ->
        case Parser.extract_text(event) do
          nil -> :ok
          text -> IO.puts("[#{name}] #{String.slice(text, 0, 20)}...")
        end
        log_subscriber(name, stream_id)
        
      {:stream_complete, ^stream_id} ->
        IO.puts("[#{name}] ✅ Complete")
        
      {:stream_error, ^stream_id, error} ->
        IO.puts("[#{name}] ❌ Error: #{inspect(error)}")
        
      {:stream_stopped, ^stream_id} ->
        IO.puts("[#{name}] ⏹️ Stopped")
    after
      30_000 ->
        IO.puts("[#{name}] ⏰ Timeout")
    end
  end

  defp monitor_concurrent_streams(stream_ids) do
    monitor_concurrent_streams(stream_ids, %{})
  end

  defp monitor_concurrent_streams([], results) do
    IO.puts("\n=== All streams completed ===")
    Enum.each(results, fn {stream_id, status} ->
      IO.puts("#{stream_id}: #{status}")
    end)
  end

  defp monitor_concurrent_streams(active_streams, results) do
    receive do
      {:stream_event, stream_id, event} ->
        case Parser.extract_text(event) do
          nil -> :ok
          text -> IO.puts("[#{String.slice(stream_id, -8, 8)}] #{String.slice(text, 0, 30)}...")
        end
        monitor_concurrent_streams(active_streams, results)
        
      {:stream_complete, stream_id} ->
        IO.puts("[#{String.slice(stream_id, -8, 8)}] ✅ Complete")
        new_active = List.delete(active_streams, stream_id)
        new_results = Map.put(results, stream_id, "completed")
        monitor_concurrent_streams(new_active, new_results)
        
      {:stream_error, stream_id, error} ->
        IO.puts("[#{String.slice(stream_id, -8, 8)}] ❌ Error: #{inspect(error)}")
        new_active = List.delete(active_streams, stream_id)
        new_results = Map.put(results, stream_id, "error: #{inspect(error)}")
        monitor_concurrent_streams(new_active, new_results)
        
      {:stream_stopped, stream_id} ->
        IO.puts("[#{String.slice(stream_id, -8, 8)}] ⏹️ Stopped")
        new_active = List.delete(active_streams, stream_id)
        new_results = Map.put(results, stream_id, "stopped")
        monitor_concurrent_streams(new_active, new_results)
    after
      45_000 ->
        IO.puts("\n⏰ Concurrent streams timeout")
        # Stop remaining streams
        Enum.each(active_streams, &ManagerV2.stop_stream/1)
        monitor_concurrent_streams([], results)
    end
  end

  defp build_conversation_context(history, new_message) do
    # Convert history to Gemini format
    context_parts = 
      Enum.map(history, fn %{role: role, content: content} ->
        %{role: role, parts: [%{text: content}]}
      end)
    
    # Add new user message
    user_message = %{role: "user", parts: [%{text: new_message}]}
    
    context_parts ++ [user_message]
  end

  defp collect_stream_text(stream_id) do
    collect_stream_text(stream_id, "")
  end

  defp collect_stream_text(stream_id, accumulated_text) do
    receive do
      {:stream_event, ^stream_id, event} ->
        case Parser.extract_text(event) do
          nil -> 
            collect_stream_text(stream_id, accumulated_text)
          text -> 
            IO.write(text)
            collect_stream_text(stream_id, accumulated_text <> text)
        end
        
      {:stream_complete, ^stream_id} ->
        accumulated_text
        
      {:stream_error, ^stream_id, _error} ->
        accumulated_text
        
      {:stream_stopped, ^stream_id} ->
        accumulated_text
    after
      30_000 ->
        ManagerV2.stop_stream(stream_id)
        accumulated_text
    end
  end
end

defmodule TextAccumulator do
  @moduledoc """
  GenServer for accumulating streaming text responses.
  
  Demonstrates how to build custom processors for streaming events.
  """
  
  use GenServer
  
  alias Gemini.SSE.Parser

  defstruct text: "", word_count: 0, started_at: nil

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def get_text(pid) do
    GenServer.call(pid, :get_text)
  end

  def get_stats(pid) do
    GenServer.call(pid, :get_stats)
  end

  def stop(pid) do
    GenServer.stop(pid)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    state = %__MODULE__{
      started_at: DateTime.utc_now()
    }
    {:ok, state}
  end

  @impl true
  def handle_call(:get_text, _from, state) do
    {:reply, state.text, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = %{
      text_length: String.length(state.text),
      word_count: state.word_count,
      started_at: state.started_at,
      duration_seconds: DateTime.diff(DateTime.utc_now(), state.started_at)
    }
    {:reply, stats, state}
  end

  @impl true
  def handle_info({:stream_event, _stream_id, event}, state) do
    case Parser.extract_text(event) do
      nil ->
        {:noreply, state}
      
      text ->
        new_text = state.text <> text
        new_word_count = count_words(new_text)
        
        new_state = %{
          state |
          text: new_text,
          word_count: new_word_count
        }
        
        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info({:stream_complete, _stream_id}, state) do
    IO.puts("\n📊 Text accumulation complete:")
    IO.puts("   Length: #{String.length(state.text)} characters")
    IO.puts("   Words: #{state.word_count}")
    duration = DateTime.diff(DateTime.utc_now(), state.started_at)
    IO.puts("   Duration: #{duration} seconds")
    {:noreply, state}
  end

  @impl true
  def handle_info({:stream_error, _stream_id, error}, state) do
    IO.puts("📊 Text accumulation stopped due to error: #{inspect(error)}")
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp count_words(text) do
    text
    |> String.split(~r/\s+/, trim: true)
    |> length()
  end
end

defmodule Gemini.StreamingDemo do
  @moduledoc """
  Demo script to run all streaming examples.
  """

  alias Gemini.StreamingExamples

  def run_all_examples do
    IO.puts("🚀 Running Gemini Streaming Examples")
    IO.puts("=" |> String.duplicate(50))

    examples = [
      {"Basic Streaming", &StreamingExamples.basic_streaming_example/0},
      {"Multiple Subscribers", &StreamingExamples.multi_subscriber_example/0},
      {"Concurrent Streams", &StreamingExamples.concurrent_streams_example/0},
      {"Error Handling", &StreamingExamples.error_handling_example/0},
      {"Chat Interface", &StreamingExamples.chat_interface_example/0},
      {"Text Accumulation", &StreamingExamples.text_accumulation_example/0}
    ]

    Enum.each(examples, fn {name, example_fn} ->
      IO.puts("\n" <> String.duplicate("=", 20))
      IO.puts("Running: #{name}")
      IO.puts(String.duplicate("=", 20))
      
      try do
        example_fn.()
        IO.puts("✅ #{name} completed")
      rescue
        error ->
          IO.puts("❌ #{name} failed: #{inspect(error)}")
      end
      
      # Small delay between examples
      Process.sleep(1000)
    end)

    IO.puts("\n🎉 All examples completed!")
  end

  def run_single_example(example_name) do
    case example_name do
      "basic" -> StreamingExamples.basic_streaming_example()
      "multi" -> StreamingExamples.multi_subscriber_example()
      "concurrent" -> StreamingExamples.concurrent_streams_example()
      "error" -> StreamingExamples.error_handling_example()
      "chat" -> StreamingExamples.chat_interface_example()
      "accumulate" -> StreamingExamples.text_accumulation_example()
      _ -> 
        IO.puts("Unknown example: #{example_name}")
        IO.puts("Available examples: basic, multi, concurrent, error, chat, accumulate")
    end
  end
end

# Usage examples:
#
# # Run all examples
# Gemini.StreamingDemo.run_all_examples()
#
# # Run specific example
# Gemini.StreamingDemo.run_single_example("basic")
#
# # Or run individual examples
# Gemini.StreamingExamples.basic_streaming_example()
# Gemini.StreamingExamples.chat_interface_example()
#✅ Stream completed")
        
      {:stream_error, ^stream_id, error} ->
        IO.puts("\n❌ Stream error: #{inspect(error)}")
        
      {:stream_stopped, ^stream_id} ->
        IO.puts("\n⏹️ Stream stopped")
    after
      30_000 ->
        IO.puts("\n⏰ Stream timeout")
        ManagerV2.stop_stream(stream_id)
    end
  end

  defp handle_stream_with_error_recovery(stream_id) do
    receive do
      {:stream_event, ^stream_id, event} ->
        case Parser.extract_text(event) do
          nil -> :ok
          text -> IO.write(text)
        end
        handle_stream_with_error_recovery(stream_id)
        
      {:stream_complete, ^stream_id} ->
        IO.puts("\n
