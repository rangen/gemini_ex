# Additional Helpful Documents

## 1. PATTERNS.md - Implementation Patterns

```markdown
# Implementation Patterns for Gemini Unified

## Auth Strategy Pattern
```elixir
# Follow this pattern for auth strategies:
defmodule Gemini.Auth.Strategy do
  @callback authenticate(config :: map()) :: {:ok, map()} | {:error, term()}
  @callback headers(credentials :: map()) :: [{String.t(), String.t()}]
  @callback base_url(credentials :: map()) :: String.t() | {:error, term()}
  @callback build_path(model :: String.t(), endpoint :: String.t(), credentials :: map()) :: String.t()
  @callback refresh_credentials(credentials :: map()) :: {:ok, map()} | {:error, term()}
end
```

## Multi-Auth Coordinator Pattern
```elixir
# The coordinator should route based on strategy:
@spec route_request(auth_strategy(), request(), opts()) :: result()
def route_request(:gemini, request, opts) do
  # Use Gemini auth strategy
end

def route_request(:vertex_ai, request, opts) do  
  # Use Vertex AI auth strategy
end
```

## Streaming Integration Pattern
```elixir
# Preserve existing streaming while adding auth routing:
defmodule Gemini.Streaming.UnifiedManager do
  # Delegate to manager_v2 but add auth coordination
  def start_stream(contents, opts) do
    auth_strategy = Keyword.get(opts, :auth, :gemini)
    enhanced_opts = add_auth_headers(opts, auth_strategy)
    ManagerV2.start_stream(contents, enhanced_opts)
  end
end
```
```

## 2. TESTING_STRATEGY.md - Testing Approach

```markdown
# Testing Strategy for Multi-Auth

## Concurrent Auth Test
```elixir
test "supports concurrent auth strategies" do
  # Setup both auth configs
  Application.put_env(:gemini, :gemini_auth, %{api_key: "test"})
  Application.put_env(:gemini, :vertex_auth, %{project_id: "test", location: "us-central1"})
  
  # Test concurrent usage
  task1 = Task.async(fn -> Gemini.generate("Hello", auth: :gemini) end)
  task2 = Task.async(fn -> Gemini.generate("Hello", auth: :vertex_ai) end)
  
  result1 = Task.await(task1)
  result2 = Task.await(task2)
  
  assert {:ok, _} = result1
  assert {:ok, _} = result2
end
```

## Streaming Test Pattern
```elixir
test "streaming works with both auth strategies" do
  [:gemini, :vertex_ai]
  |> Enum.each(fn auth_strategy ->
    {:ok, stream_id} = Gemini.start_stream("Tell a story", auth: auth_strategy)
    
    assert_receive {:stream_event, ^stream_id, _event}, 5000
    assert_receive {:stream_complete, ^stream_id}, 10000
  end)
end
```
```

## 3. ARCHITECTURE_DECISIONS.md - Key Decisions

```markdown
# Architecture Decisions

## Decision 1: Per-Request Auth Strategy
**Choice:** Allow auth strategy selection per request via `:auth` option
**Rationale:** Maximum flexibility, supports concurrent usage patterns
**Implementation:** Router pattern in coordinator

## Decision 2: Preserve Streaming Excellence  
**Choice:** Keep manager_v2.ex as foundation, enhance rather than replace
**Rationale:** It's production-tested and excellent
**Implementation:** Wrapper/enhancement pattern

## Decision 3: Gradual Error Enhancement
**Choice:** Build on working error.ex, gradually add enhanced_error.ex features
**Rationale:** Maintain stability while improving
**Implementation:** Composition over replacement

## Decision 4: Type Safety First
**Choice:** Follow CODE_QUALITY.md patterns for all new code
**Rationale:** Consistency and reliability
**Implementation:** @type t, @enforce_keys, @spec for everything
```
```

## 4. MIGRATION_GUIDE.md - For Future Reference

```markdown
# Migration Guide

## From Single Auth to Multi-Auth

### Before:
```elixir
# App only supported one auth strategy
Gemini.generate("Hello")
```

### After:
```elixir
# App supports both, defaults to configured strategy
Gemini.generate("Hello")

# Or specify explicitly:
Gemini.generate("Hello", auth: :gemini)
Gemini.generate("Hello", auth: :vertex_ai)
```

## Configuration Migration

### Before:
```elixir
config :gemini, api_key: "..."
```

### After:
```elixir
config :gemini,
  gemini: %{api_key: "..."},
  vertex_ai: %{project_id: "...", location: "..."},
  default_auth: :gemini
```
```

## 5. Place These Files in gemini_unified/

1. **CLAUDE.md** (main context file)
2. **PATTERNS.md** (implementation patterns)  
3. **TESTING_STRATEGY.md** (testing approach)
4. **ARCHITECTURE_DECISIONS.md** (key decisions)
5. **MIGRATION_GUIDE.md** (future reference)

## 6. Regarding CODE_QUALITY.md

The CODE_QUALITY.md you provided is **excellent and should be kept as-is**. It perfectly covers:

- ✅ `@type t` patterns for structs
- ✅ `@enforce_keys` usage
- ✅ `@spec` for all public functions
- ✅ `@moduledoc` and `@doc` standards
- ✅ Proper struct patterns
- ✅ Module organization
- ✅ Tool usage (mix format, dialyzer, credo)

This will ensure all new code follows consistent, high-quality patterns that integrate well with the existing excellent streaming implementation.