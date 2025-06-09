defmodule Gemini.ModelsTest do
  @moduledoc """
  Comprehensive test suite for the Models API implementation.

  Tests cover:
  - Basic CRUD operations
  - Pagination and filtering
  - Error handling and validation
  - Response parsing and type safety
  - Performance and telemetry
  """

  use ExUnit.Case, async: true
  import Mox

  alias Gemini.Models
  alias Gemini.Types.Response.{ListModelsResponse, Model}
  alias Gemini.Types.Request.{ListModelsRequest, GetModelRequest}
  alias Gemini.Error

  # Mock setup
  setup :verify_on_exit!

  describe "list/1" do
    test "lists models with default parameters" do
      mock_response = %{
        "models" => [
          sample_model_data("gemini-2.0-flash"),
          sample_model_data("gemini-1.5-pro")
        ]
      }

      expect_http_get("models", mock_response)

      assert {:ok, %ListModelsResponse{models: models, next_page_token: nil}} = Models.list()
      assert length(models) == 2
      assert Enum.any?(models, &(&1.base_model_id == "gemini-2.0-flash"))
    end

    test "handles pagination parameters" do
      mock_response = %{
        "models" => [sample_model_data("gemini-2.0-flash")],
        "nextPageToken" => "next_token_123"
      }

      expect_http_get("models?pageSize=10&pageToken=token_123", mock_response)

      opts = [page_size: 10, page_token: "token_123"]
      assert {:ok, %ListModelsResponse{next_page_token: "next_token_123"}} = Models.list(opts)
    end

    test "validates page_size parameter" do
      assert {:error, %Error{type: :validation_error}} = Models.list(page_size: 0)
      assert {:error, %Error{type: :validation_error}} = Models.list(page_size: 1001)
      assert {:error, %Error{type: :validation_error}} = Models.list(page_size: "invalid")
    end

    test "validates page_token parameter" do
      assert {:error, %Error{type: :validation_error}} = Models.list(page_token: "")
      assert {:error, %Error{type: :validation_error}} = Models.list(page_token: 123)
    end

    test "handles empty models list" do
      mock_response = %{"models" => []}
      expect_http_get("models", mock_response)

      assert {:ok, %ListModelsResponse{models: [], next_page_token: nil}} = Models.list()
    end

    test "handles API errors" do
      expect_http_get_error("models", %Error{type: :api_error, http_status: 403})

      assert {:error, %Error{type: :api_error, http_status: 403}} = Models.list()
    end

    test "handles malformed response" do
      mock_response = %{"invalid" => "response"}
      expect_http_get("models", mock_response)

      assert {:error, %Error{type: :invalid_response}} = Models.list()
    end

    test "emits telemetry on success" do
      mock_response = %{"models" => [sample_model_data("gemini-2.0-flash")]}
      expect_http_get("models", mock_response)

      :telemetry_test.attach_event_handlers(self(), [
        [:gemini, :models, :list, :success]
      ])

      assert {:ok, _} = Models.list()

      assert_receive {[:gemini, :models, :list, :success], %{duration: _, model_count: 1}, %{}}
    end

    test "emits telemetry on error" do
      expect_http_get_error("models", %Error{type: :network_error})

      :telemetry_test.attach_event_handlers(self(), [
        [:gemini, :models, :list, :error]
      ])

      assert {:error, _} = Models.list()

      assert_receive {[:gemini, :models, :list, :error], %{duration: _}, %{error_type: :network_error}}
    end
  end

  describe "get/1" do
    test "gets model by base ID" do
      model_data = sample_model_data("gemini-2.0-flash")
      expect_http_get("models/gemini-2.0-flash", model_data)

      assert {:ok, %Model{base_model_id: "gemini-2.0-flash"}} = Models.get("gemini-2.0-flash")
    end

    test "gets model by full resource name" do
      model_data = sample_model_data("gemini-1.5-pro")
      expect_http_get("models/gemini-1.5-pro", model_data)

      assert {:ok, %Model{}} = Models.get("models/gemini-1.5-pro")
    end

    test "validates model name" do
      assert {:error, %Error{type: :validation_error}} = Models.get("")
      assert {:error, %Error{type: :validation_error}} = Models.get(123)
      assert {:error, %Error{type: :validation_error}} = Models.get("models/")
    end

    test "handles model not found" do
      expect_http_get_error("models/nonexistent", %Error{type: :api_error, http_status: 404})

      assert {:error, %Error{type: :api_error, http_status: 404}} = Models.get("nonexistent")
    end

    test "handles malformed model response" do
      mock_response = %{"invalid" => "model_data"}
      expect_http_get("models/gemini-2.0-flash", mock_response)

      assert {:error, %Error{type: :invalid_response}} = Models.get("gemini-2.0-flash")
    end

    test "emits success telemetry" do
      model_data = sample_model_data("gemini-2.0-flash")
      expect_http_get("models/gemini-2.0-flash", model_data)

      :telemetry_test.attach_event_handlers(self(), [
        [:gemini, :models, :get, :success]
      ])

      assert {:ok, _} = Models.get("gemini-2.0-flash")

      assert_receive {[:gemini, :models, :get, :success], %{duration: _}, %{model: "gemini-2.0-flash"}}
    end

    test "emits error telemetry" do
      expect_http_get_error("models/gemini-2.0-flash", %Error{type: :network_error})

      :telemetry_test.attach_event_handlers(self(), [
        [:gemini, :models, :get, :error]
      ])

      assert {:error, _} = Models.get("gemini-2.0-flash")

      assert_receive {[:gemini, :models, :get, :error], %{duration: _},
        %{model: "gemini-2.0-flash", error_type: :network_error}}
    end
  end

  describe "list_names/0" do
    test "extracts model names from list response" do
      mock_response = %{
        "models" => [
          sample_model_data("gemini-2.0-flash"),
          sample_model_data("gemini-1.5-pro"),
          sample_model_data("gemini-1.5-flash")
        ]
      }

      expect_http_get("models", mock_response)

      assert {:ok, names} = Models.list_names()
      assert "gemini-2.0-flash" in names
      assert "gemini-1.5-pro" in names
      assert "gemini-1.5-flash" in names
      assert length(names) == 3
    end

    test "handles empty models list" do
      mock_response = %{"models" => []}
      expect_http_get("models", mock_response)

      assert {:ok, []} = Models.list_names()
    end

    test "deduplicates and sorts names" do
      mock_response = %{
        "models" => [
          Map.put(sample_model_data("gemini-2.0-flash"), "baseModelId", "gemini-2.0-flash"),
          Map.put(sample_model_data("gemini-1.5-pro"), "baseModelId", "gemini-1.5-pro"),
          Map.put(sample_model_data("gemini-2.0-flash"), "baseModelId", "gemini-2.0-flash") # duplicate
        ]
      }

      expect_http_get("models", mock_response)

      assert {:ok, names} = Models.list_names()
      assert length(names) == 2
      assert names == Enum.sort(names) # Should be sorted
    end
  end

  describe "exists?/1" do
    test "returns true for existing model" do
      model_data = sample_model_data("gemini-2.0-flash")
      expect_http_get("models/gemini-2.0-flash", model_data)

      assert {:ok, true} = Models.exists?("gemini-2.0-flash")
    end

    test "returns false for non-existent model" do
      expect_http_get_error("models/nonexistent", %Error{type: :api_error, http_status: 404})

      assert {:ok, false} = Models.exists?("nonexistent")
    end

    test "handles API errors" do
      expect_http_get_error("models/gemini-2.0-flash", %Error{type: :network_error})

      assert {:error, %Error{type: :network_error}} = Models.exists?("gemini-2.0-flash")
    end
  end

  describe "supporting_method/1" do
    test "filters models by generation method" do
      mock_response = %{
        "models" => [
          sample_model_data("gemini-2.0-flash", ["generateContent", "streamGenerateContent"]),
          sample_model_data("gemini-1.5-pro", ["generateContent"]),
          sample_model_data("text-embedding", ["embedContent"])
        ]
      }

      expect_http_get("models", mock_response)

      assert {:ok, streaming_models} = Models.supporting_method("streamGenerateContent")
      assert length(streaming_models) == 1
      assert hd(streaming_models).base_model_id == "gemini-2.0-flash"
    end

    test "returns empty list when no models support method" do
      mock_response = %{
        "models" => [
          sample_model_data("gemini-2.0-flash", ["generateContent"])
        ]
      }

      expect_http_get("models", mock_response)

      assert {:ok, []} = Models.supporting_method("nonexistentMethod")
    end

    test "validates method parameter" do
      assert {:error, %Error{type: :validation_error}} = Models.supporting_method("")
      assert {:error, %Error{type: :validation_error}} = Models.supporting_method(123)
    end
  end

  describe "filter/1" do
    test "filters by minimum input tokens" do
      mock_response = %{
        "models" => [
          sample_model_data("high-capacity", [], 1_000_000),
          sample_model_data("low-capacity", [], 10_000)
        ]
      }

      expect_http_get("models", mock_response)

      assert {:ok, filtered} = Models.filter(min_input_tokens: 500_000)
      assert length(filtered) == 1
      assert hd(filtered).base_model_id == "high-capacity"
    end

    test "filters by supported methods" do
      mock_response = %{
        "models" => [
          sample_model_data("versatile", ["generateContent", "streamGenerateContent", "countTokens"]),
          sample_model_data("basic", ["generateContent"])
        ]
      }

      expect_http_get("models", mock_response)

      assert {:ok, filtered} = Models.filter(supports_methods: ["generateContent", "streamGenerateContent"])
      assert length(filtered) == 1
      assert hd(filtered).base_model_id == "versatile"
    end

    test "filters by parameter availability" do
      model_with_temp = sample_model_data("with-temp")
      model_with_temp = Map.put(model_with_temp, "temperature", 1.0)

      model_without_temp = sample_model_data("without-temp")

      mock_response = %{
        "models" => [model_with_temp, model_without_temp]
      }

      expect_http_get("models", mock_response)

      assert {:ok, filtered} = Models.filter(has_temperature: true)
      assert length(filtered) == 1
      assert hd(filtered).base_model_id == "with-temp"
    end

    test "handles multiple filter criteria" do
      mock_response = %{
        "models" => [
          sample_model_data("perfect-match", ["generateContent", "streamGenerateContent"], 100_000),
          sample_model_data("partial-match", ["generateContent"], 200_000),
          sample_model_data("no-match", ["generateContent"], 50_000)
        ]
      }

      expect_http_get("models", mock_response)

      filter_opts = [
        min_input_tokens: 75_000,
        supports_methods: ["generateContent", "streamGenerateContent"]
      ]

      assert {:ok, filtered} = Models.filter(filter_opts)
      assert length(filtered) == 1
      assert hd(filtered).base_model_id == "perfect-match"
    end
  end

  describe "get_stats/0" do
    test "calculates comprehensive model statistics" do
      mock_response = %{
        "models" => [
          sample_model_data("gemini-2.0-flash", ["generateContent"], 1_000_000, 8192, %{"version" => "2.0", "temperature" => 1.0}),
          sample_model_data("gemini-1.5-pro", ["generateContent", "streamGenerateContent"], 2_000_000, 8192, %{"version" => "1.5"}),
          sample_model_data("gemini-1.5-flash", ["generateContent"], 1_000_000, 8192, %{"version" => "1.5", "topK" => 40})
        ]
      }

      expect_http_get("models", mock_response)

      assert {:ok, stats} = Models.get_stats()

      assert stats.total_models == 3
      assert stats.by_version == %{"2.0" => 1, "1.5" => 2}
      assert stats.by_method["generateContent"] == 3
      assert stats.by_method["streamGenerateContent"] == 1
      assert stats.token_limits.max_input == 2_000_000
      assert stats.capabilities.with_temperature == 1
      assert stats.capabilities.with_top_k == 1
    end

    test "handles empty models list" do
      mock_response = %{"models" => []}
      expect_http_get("models", mock_response)

      assert {:ok, stats} = Models.get_stats()
      assert stats.total_models == 0
      assert stats.by_version == %{}
      assert stats.token_limits.max_input == 0
    end
  end

  # Test helper functions

  defp sample_model_data(base_id, methods \\ ["generateContent"], input_limit \\ 1_000_000, output_limit \\ 8192, extra_fields \\ %{}) do
    base_data = %{
      "name" => "models/#{base_id}",
      "baseModelId" => base_id,
      "version" => "1.0",
      "displayName" => String.replace(base_id, "-", " ") |> String.split() |> Enum.map(&String.capitalize/1) |> Enum.join(" "),
      "description" => "Test model: #{base_id}",
      "inputTokenLimit" => input_limit,
      "outputTokenLimit" => output_limit,
      "supportedGenerationMethods" => methods
    }

    Map.merge(base_data, extra_fields)
  end

  defp expect_http_get(path, response) do
    Gemini.Client.HTTPMock
    |> expect(:get, fn ^path, _opts ->
      {:ok, response}
    end)
  end

  defp expect_http_get_error(path, error) do
    Gemini.Client.HTTPMock
    |> expect(:get, fn ^path, _opts ->
      {:error, error}
    end)
  end
end

# Type tests for requests and responses
defmodule Gemini.Types.Request.ModelsTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.Request.{ListModelsRequest, GetModelRequest}

  describe "ListModelsRequest" do
    test "creates valid request with default values" do
      request = %ListModelsRequest{}
      assert request.page_size == nil
      assert request.page_token == nil
    end

    test "validates page_size constraints" do
      assert {:ok, _} = ListModelsRequest.new(page_size: 1)
      assert {:ok, _} = ListModelsRequest.new(page_size: 1000)
      assert {:error, _} = ListModelsRequest.new(page_size: 0)
      assert {:error, _} = ListModelsRequest.new(page_size: 1001)
    end

    test "validates page_token format" do
      assert {:ok, _} = ListModelsRequest.new(page_token: "valid_token")
      assert {:error, _} = ListModelsRequest.new(page_token: "")
      assert {:error, _} = ListModelsRequest.new(page_token: 123)
    end
  end

  describe "GetModelRequest" do
    test "normalizes model names" do
      assert {:ok, request} = GetModelRequest.new("gemini-2.0-flash")
      assert request.name == "models/gemini-2.0-flash"

      assert {:ok, request} = GetModelRequest.new("models/gemini-1.5-pro")
      assert request.name == "models/gemini-1.5-pro"
    end

    test "validates model name format" do
      assert {:error, _} = GetModelRequest.new("")
      assert {:error, _} = GetModelRequest.new(123)
      assert {:error, _} = GetModelRequest.new("models/")
    end
  end
end

defmodule Gemini.Types.Response.ModelsTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.Response.{ListModelsResponse, Model}

  describe "ListModelsResponse" do
    test "detects pagination availability" do
      response_with_token = %ListModelsResponse{next_page_token: "token"}
      assert ListModelsResponse.has_next_page?(response_with_token)

      response_without_token = %ListModelsResponse{next_page_token: nil}
      refute ListModelsResponse.has_next_page?(response_without_token)

      response_empty_token = %ListModelsResponse{next_page_token: ""}
      refute ListModelsResponse.has_next_page?(response_empty_token)
    end

    test "counts models correctly" do
      models = [%Model{name: "models/test1"}, %Model{name: "models/test2"}]
      response = %ListModelsResponse{models: models}
      assert ListModelsResponse.model_count(response) == 2
    end

    test "extracts model names" do
      models = [
        %Model{name: "models/gemini-2.0-flash", base_model_id: "gemini-2.0-flash"},
        %Model{name: "models/gemini-1.5-pro", base_model_id: nil}
      ]
      response = %ListModelsResponse{models: models}
      names = ListModelsResponse.model_names(response)
      assert "gemini-2.0-flash" in names
      assert "gemini-1.5-pro" in names
    end
  end

  describe "Model" do
    test "detects method support" do
      model = %Model{
        name: "models/test",
        supported_generation_methods: ["generateContent", "streamGenerateContent"]
      }

      assert Model.supports_method?(model, "generateContent")
      assert Model.supports_method?(model, "streamGenerateContent")
      refute Model.supports_method?(model, "countTokens")
    end

    test "detects streaming support" do
      streaming_model = %Model{
        name: "models/test",
        supported_generation_methods: ["generateContent", "streamGenerateContent"]
      }

      non_streaming_model = %Model{
        name: "models/test",
        supported_generation_methods: ["generateContent"]
      }

      assert Model.supports_streaming?(streaming_model)
      refute Model.supports_streaming?(non_streaming_model)
    end

    test "detects token counting support" do
      model_with_tokens = %Model{
        name: "models/test",
        supported_generation_methods: ["generateContent", "countTokens"]
      }

      model_without_tokens = %Model{
        name: "models/test",
        supported_generation_methods: ["generateContent"]
      }

      assert Model.supports_token_counting?(model_with_tokens)
      refute Model.supports_token_counting?(model_without_tokens)
    end

    test "detects embeddings support" do
      embedding_model = %Model{
        name: "models/test",
        supported_generation_methods: ["embedContent", "batchEmbedContents"]
      }

      regular_model = %Model{
        name: "models/test",
        supported_generation_methods: ["generateContent"]
      }

      assert Model.supports_embeddings?(embedding_model)
      refute Model.supports_embeddings?(regular_model)
    end

    test "extracts effective base ID" do
      model_with_base_id = %Model{
        name: "models/gemini-2.0-flash-001",
        base_model_id: "gemini-2.0-flash"
      }

      model_without_base_id = %Model{
        name: "models/gemini-1.5-pro-001",
        base_model_id: nil
      }

      assert Model.effective_base_id(model_with_base_id) == "gemini-2.0-flash"
      assert Model.effective_base_id(model_without_base_id) == "gemini-1.5-pro"
    end

    test "detects advanced parameters" do
      advanced_model = %Model{
        name: "models/test",
        temperature: 1.0,
        top_p: 0.95,
        top_k: 40
      }

      basic_model = %Model{
        name: "models/test",
        temperature: nil,
        top_p: nil,
        top_k: nil
      }

      assert Model.has_advanced_params?(advanced_model)
      refute Model.has_advanced_params?(basic_model)
    end

    test "generates capabilities summary" do
      model = %Model{
        name: "models/gemini-2.0-flash",
        supported_generation_methods: ["generateContent", "streamGenerateContent", "countTokens"],
        input_token_limit: 1_000_000,
        output_token_limit: 8192,
        temperature: 1.0,
        top_k: 40,
        top_p: nil
      }

      summary = Model.capabilities_summary(model)

      assert summary.supports_streaming == true
      assert summary.supports_token_counting == true
      assert summary.has_temperature == true
      assert summary.has_top_k == true
      assert summary.has_top_p == false
      assert summary.method_count == 3
      assert summary.input_capacity == :very_large
      assert summary.output_capacity == :small
    end

    test "compares model capabilities" do
      high_capability_model = %Model{
        name: "models/advanced",
        supported_generation_methods: ["generateContent", "streamGenerateContent", "countTokens", "embedContent"],
        input_token_limit: 2_000_000,
        output_token_limit: 8192,
        temperature: 1.0,
        top_k: 40,
        top_p: 0.95
      }

      basic_model = %Model{
        name: "models/basic",
        supported_generation_methods: ["generateContent"],
        input_token_limit: 30_000,
        output_token_limit: 1024,
        temperature: nil,
        top_k: nil,
        top_p: nil
      }

      assert Model.compare_capabilities(basic_model, high_capability_model) == :lt
      assert Model.compare_capabilities(high_capability_model, basic_model) == :gt
      assert Model.compare_capabilities(basic_model, basic_model) == :eq
    end

    test "detects latest version" do
      latest_model = %Model{name: "models/gemini-2.0-flash"}
      versioned_model = %Model{name: "models/gemini-1.5-pro-001"}
      latest_explicit = %Model{name: "models/gemini-latest"}

      assert Model.is_latest_version?(latest_model)
      assert Model.is_latest_version?(latest_explicit)
      refute Model.is_latest_version?(versioned_model)
    end

    test "extracts model family" do
      gemini_model = %Model{name: "models/gemini-2.0-flash", base_model_id: "gemini-2.0-flash"}
      text_model = %Model{name: "models/text-embedding-004", base_model_id: "text-embedding-004"}
      single_name = %Model{name: "models/bard", base_model_id: "bard"}

      assert Model.model_family(gemini_model) == "gemini"
      assert Model.model_family(text_model) == "text"
      assert Model.model_family(single_name) == "bard"
    end

    test "determines production readiness" do
      production_ready = %Model{
        name: "models/gemini-2.0-flash",
        supported_generation_methods: ["generateContent", "streamGenerateContent"],
        input_token_limit: 1_000_000,
        output_token_limit: 8192
      }

      limited_model = %Model{
        name: "models/limited",
        supported_generation_methods: ["generateContent"],
        input_token_limit: 8000,
        output_token_limit: 512
      }

      embedding_only = %Model{
        name: "models/embedding",
        supported_generation_methods: ["embedContent"],
        input_token_limit: 1_000_000,
        output_token_limit: 0
      }

      assert Model.production_ready?(production_ready)
      refute Model.production_ready?(limited_model)
      refute Model.production_ready?(embedding_only)
    end
  end
end

# Integration tests that verify real API behavior
defmodule Gemini.ModelsIntegrationTest do
  use ExUnit.Case

  @moduletag :integration
  @moduletag timeout: 30_000

  alias Gemini.Models
  alias Gemini.Types.Response.{ListModelsResponse, Model}

  setup do
    # Skip if no API key configured
    unless System.get_env("GEMINI_API_KEY") do
      {:skip, "No GEMINI_API_KEY configured"}
    else
      :ok
    end
  end

  describe "real API integration" do
    test "can list actual models" do
      assert {:ok, %ListModelsResponse{models: models}} = Models.list()
      assert length(models) > 0

      # Verify at least some expected models exist
      model_names = Enum.map(models, &Model.effective_base_id/1)
      assert Enum.any?(model_names, &String.contains?(&1, "gemini"))
    end

    test "can get specific model details" do
      # First get a list to find a valid model name
      {:ok, %ListModelsResponse{models: [first_model | _]}} = Models.list(page_size: 1)
      model_name = Model.effective_base_id(first_model)

      assert {:ok, %Model{} = model} = Models.get(model_name)
      assert model.name != ""
      assert model.display_name != ""
      assert model.input_token_limit > 0
      assert model.output_token_limit > 0
      assert length(model.supported_generation_methods) > 0
    end

    test "handles non-existent model gracefully" do
      assert {:ok, false} = Models.exists?("definitely-does-not-exist-model-12345")
    end

    test "can filter models by capabilities" do
      assert {:ok, streaming_models} = Models.supporting_method("streamGenerateContent")
      # Most modern Gemini models should support streaming
      assert length(streaming_models) > 0

      # Verify all returned models actually support streaming
      Enum.each(streaming_models, fn model ->
        assert Model.supports_streaming?(model)
      end)
    end

    test "can get comprehensive model statistics" do
      assert {:ok, stats} = Models.get_stats()
      assert stats.total_models > 0
      assert is_map(stats.by_version)
      assert is_map(stats.by_method)
      assert is_map(stats.token_limits)
      assert is_map(stats.capabilities)

      # Verify some basic expectations about Google's models
      assert stats.by_method["generateContent"] > 0
      assert stats.token_limits.max_input > 30_000
    end

    test "pagination works correctly" do
      # Get first page with small page size
      assert {:ok, page1} = Models.list(page_size: 2)
      assert length(page1.models) <= 2

      # If there's a next page token, get the next page
      if Models.ListModelsResponse.has_next_page?(page1) do
        assert {:ok, page2} = Models.list(page_size: 2, page_token: page1.next_page_token)
        assert length(page2.models) <= 2

        # Pages should have different models
        page1_names = Models.ListModelsResponse.model_names(page1)
        page2_names = Models.ListModelsResponse.model_names(page2)
        assert MapSet.disjoint?(MapSet.new(page1_names), MapSet.new(page2_names))
      end
    end

    test "model filtering works with real data" do
      # Test high-capacity model filtering
      assert {:ok, large_models} = Models.filter(min_input_tokens: 500_000)

      Enum.each(large_models, fn model ->
        assert model.input_token_limit >= 500_000
      end)

      # Test method filtering
      assert {:ok, versatile_models} = Models.filter(
        supports_methods: ["generateContent", "streamGenerateContent"]
      )

      Enum.each(versatile_models, fn model ->
        assert "generateContent" in model.supported_generation_methods
        assert "streamGenerateContent" in model.supported_generation_methods
      end)
    end
  end
end

# Property-based tests for robust validation
defmodule Gemini.ModelsPropertyTest do
  use ExUnit.Case
  use PropCheck

  alias Gemini.Types.Response.Model
  alias Gemini.Types.Request.{ListModelsRequest, GetModelRequest}

  property "ListModelsRequest always validates page_size correctly" do
    forall page_size <- oneof([nil, integer()]) do
      case ListModelsRequest.new(page_size: page_size) do
        {:ok, _} -> page_size == nil or (page_size >= 1 and page_size <= 1000)
        {:error, _} -> page_size != nil and (page_size < 1 or page_size > 1000)
      end
    end
  end

  property "GetModelRequest normalizes model names consistently" do
    forall model_name <- non_empty(utf8()) do
      case GetModelRequest.new(model_name) do
        {:ok, request} ->
          String.starts_with?(request.name, "models/")
        {:error, _} ->
          true # Invalid names should error
      end
    end
  end

  property "Model capability scoring is monotonic" do
    forall {methods1, methods2} <- {list(utf8()), list(utf8())} do
      model1 = %Model{
        name: "models/test1",
        supported_generation_methods: methods1,
        input_token_limit: 1000,
        output_token_limit: 1000,
        temperature: nil,
        top_k: nil,
        top_p: nil
      }

      model2 = %Model{
        name: "models/test2",
        supported_generation_methods: methods1 ++ methods2,
        input_token_limit: 1000,
        output_token_limit: 1000,
        temperature: 1.0,
        top_k: 40,
        top_p: 0.95
      }

      # Model2 should have equal or higher capability score
      Model.compare_capabilities(model1, model2) in [:lt, :eq]
    end
  end

  property "Model family extraction is consistent" do
    forall base_id <- non_empty(utf8()) do
      model = %Model{
        name: "models/#{base_id}",
        base_model_id: base_id
      }

      family = Model.model_family(model)
      # Family should be the first part before any dash
      case String.split(base_id, "-", parts: 2) do
        [expected_family | _] -> family == expected_family
        [] -> family == base_id
      end
    end
  end
end
