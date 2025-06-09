defmodule Gemini.Types.Response.GenerateContentResponse do
  @moduledoc """
  Response from content generation requests.

  Contains candidates with generated content, usage metadata,
  and any safety or prompt feedback.
  """

  use TypedStruct

  alias Gemini.Types.Response.{Candidate, PromptFeedback, UsageMetadata}

  @derive Jason.Encoder
  typedstruct do
    field(:candidates, [Candidate.t()], default: [])
    field(:prompt_feedback, PromptFeedback.t() | nil, default: nil)
    field(:usage_metadata, UsageMetadata.t() | nil, default: nil)
  end

  @doc """
  Extract text from the first candidate.

  ## Examples

      iex> GenerateContentResponse.extract_text(response)
      {:ok, "Generated text content"}

      iex> GenerateContentResponse.extract_text(empty_response)
      {:error, "No candidates in response"}
  """
  @spec extract_text(t()) :: {:ok, String.t()} | {:error, String.t()}
  def extract_text(%__MODULE__{candidates: [candidate | _]}) do
    Candidate.extract_text(candidate)
  end

  def extract_text(%__MODULE__{candidates: []}) do
    {:error, "No candidates in response"}
  end

  @doc """
  Extract all text from all candidates.
  """
  @spec extract_all_text(t()) :: [String.t()]
  def extract_all_text(%__MODULE__{candidates: candidates}) do
    candidates
    |> Enum.map(&Candidate.extract_text/1)
    |> Enum.filter(&match?({:ok, _}, &1))
    |> Enum.map(fn {:ok, text} -> text end)
  end

  @doc """
  Check if the response was blocked by safety filters.
  """
  @spec blocked?(t()) :: boolean()
  def blocked?(%__MODULE__{prompt_feedback: %PromptFeedback{block_reason: reason}}) do
    not is_nil(reason)
  end

  def blocked?(%__MODULE__{}), do: false

  @doc """
  Get the finish reason from the first candidate.
  """
  @spec finish_reason(t()) :: String.t() | nil
  def finish_reason(%__MODULE__{candidates: [%Candidate{finish_reason: reason} | _]}) do
    reason
  end

  def finish_reason(%__MODULE__{}), do: nil

  @doc """
  Get total token usage information.
  """
  @spec token_usage(t()) :: %{input: integer(), output: integer(), total: integer()} | nil
  def token_usage(%__MODULE__{usage_metadata: %UsageMetadata{} = metadata}) do
    %{
      input: metadata.prompt_token_count || 0,
      output: metadata.candidates_token_count || 0,
      total: metadata.total_token_count
    }
  end

  def token_usage(%__MODULE__{}), do: nil
end

defmodule Gemini.Types.Response.Candidate do
  @moduledoc """
  A single candidate response from content generation.

  Contains the generated content, safety ratings, citations,
  and metadata about the generation process.
  """

  use TypedStruct

  alias Gemini.Types.Content
  alias Gemini.Types.Response.{SafetyRating, CitationMetadata, GroundingAttribution}

  @derive Jason.Encoder
  typedstruct do
    field(:content, Content.t() | nil, default: nil)
    field(:finish_reason, String.t() | nil, default: nil)
    field(:safety_ratings, [SafetyRating.t()], default: [])
    field(:citation_metadata, CitationMetadata.t() | nil, default: nil)
    field(:token_count, integer() | nil, default: nil)
    field(:grounding_attributions, [GroundingAttribution.t()], default: [])
    field(:index, integer() | nil, default: nil)
  end

  @doc """
  Extract text content from this candidate.
  """
  @spec extract_text(t()) :: {:ok, String.t()} | {:error, String.t()}
  def extract_text(%__MODULE__{content: %Content{parts: parts}}) do
    text_parts =
      parts
      |> Enum.filter(&match?(%{text: text} when is_binary(text), &1))
      |> Enum.map(& &1.text)

    case text_parts do
      [] -> {:error, "No text content found"}
      texts -> {:ok, Enum.join(texts, "")}
    end
  end

  def extract_text(%__MODULE__{content: nil}) do
    {:error, "Candidate has no content"}
  end

  @doc """
  Check if this candidate was blocked by safety filters.
  """
  @spec blocked?(t()) :: boolean()
  def blocked?(%__MODULE__{finish_reason: "SAFETY"}), do: true
  def blocked?(%__MODULE__{safety_ratings: ratings}) do
    Enum.any?(ratings, & &1.blocked)
  end

  @doc """
  Check if this candidate finished successfully.
  """
  @spec completed?(t()) :: boolean()
  def completed?(%__MODULE__{finish_reason: reason}) do
    reason in ["STOP", "MAX_TOKENS", nil]
  end

  @doc """
  Get safety rating for a specific category.
  """
  @spec safety_rating(t(), String.t()) :: SafetyRating.t() | nil
  def safety_rating(%__MODULE__{safety_ratings: ratings}, category) do
    Enum.find(ratings, &(&1.category == category))
  end
end

defmodule Gemini.Types.Response.CountTokensResponse do
  @moduledoc """
  Response from token counting requests.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:total_tokens, integer(), enforce: true)
  end

  @doc """
  Create a new CountTokensResponse.
  """
  @spec new(integer()) :: t()
  def new(total_tokens) when is_integer(total_tokens) and total_tokens >= 0 do
    %__MODULE__{total_tokens: total_tokens}
  end
end

defmodule Gemini.Types.Response.PromptFeedback do
  @moduledoc """
  Feedback about the prompt, including safety ratings and block reasons.
  """

  use TypedStruct

  alias Gemini.Types.Response.SafetyRating

  @derive Jason.Encoder
  typedstruct do
    field(:block_reason, String.t() | nil, default: nil)
    field(:safety_ratings, [SafetyRating.t()], default: [])
  end

  @doc """
  Check if the prompt was blocked.
  """
  @spec blocked?(t()) :: boolean()
  def blocked?(%__MODULE__{block_reason: reason}) do
    not is_nil(reason)
  end
end

defmodule Gemini.Types.Response.UsageMetadata do
  @moduledoc """
  Token usage metadata for API requests.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:prompt_token_count, integer() | nil, default: nil)
    field(:candidates_token_count, integer() | nil, default: nil)
    field(:total_token_count, integer(), enforce: true)
    field(:cached_content_token_count, integer() | nil, default: nil)
  end

  @doc """
  Calculate the cost ratio between input and output tokens.
  """
  @spec cost_ratio(t()) :: float() | nil
  def cost_ratio(%__MODULE__{prompt_token_count: input, candidates_token_count: output})
      when is_integer(input) and is_integer(output) and output > 0 do
    input / output
  end

  def cost_ratio(%__MODULE__{}), do: nil

  @doc """
  Check if the response used cached content.
  """
  @spec used_cache?(t()) :: boolean()
  def used_cache?(%__MODULE__{cached_content_token_count: count}) do
    is_integer(count) and count > 0
  end
end

defmodule Gemini.Types.Response.SafetyRating do
  @moduledoc """
  Safety assessment for content.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:category, String.t(), enforce: true)
    field(:probability, String.t(), enforce: true)
    field(:blocked, boolean() | nil, default: nil)
  end

  @doc """
  Check if this rating indicates high risk.
  """
  @spec high_risk?(t()) :: boolean()
  def high_risk?(%__MODULE__{probability: "HIGH"}), do: true
  def high_risk?(%__MODULE__{}), do: false

  @doc """
  Check if this rating caused blocking.
  """
  @spec caused_block?(t()) :: boolean()
  def caused_block?(%__MODULE__{blocked: true}), do: true
  def caused_block?(%__MODULE__{}), do: false
end

defmodule Gemini.Types.Response.CitationMetadata do
  @moduledoc """
  Citation information for generated content.
  """

  use TypedStruct

  alias Gemini.Types.Response.CitationSource

  @derive Jason.Encoder
  typedstruct do
    field(:citation_sources, [CitationSource.t()], default: [])
  end

  @doc """
  Check if the response contains citations.
  """
  @spec has_citations?(t()) :: boolean()
  def has_citations?(%__MODULE__{citation_sources: sources}) do
    length(sources) > 0
  end

  @doc """
  Get all unique source URIs.
  """
  @spec source_uris(t()) :: [String.t()]
  def source_uris(%__MODULE__{citation_sources: sources}) do
    sources
    |> Enum.map(& &1.uri)
    |> Enum.filter(&is_binary/1)
    |> Enum.uniq()
  end
end

defmodule Gemini.Types.Response.CitationSource do
  @moduledoc """
  Individual citation source information.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:start_index, integer() | nil, default: nil)
    field(:end_index, integer() | nil, default: nil)
    field(:uri, String.t() | nil, default: nil)
    field(:license, String.t() | nil, default: nil)
  end

  @doc """
  Get the length of text covered by this citation.
  """
  @spec text_length(t()) :: integer() | nil
  def text_length(%__MODULE__{start_index: start_idx, end_index: end_idx})
      when is_integer(start_idx) and is_integer(end_idx) do
    end_idx - start_idx
  end

  def text_length(%__MODULE__{}), do: nil

  @doc """
  Check if this citation has positional information.
  """
  @spec has_position?(t()) :: boolean()
  def has_position?(%__MODULE__{start_index: start_idx, end_index: end_idx}) do
    is_integer(start_idx) and is_integer(end_idx)
  end
end

defmodule Gemini.Types.Response.GroundingAttribution do
  @moduledoc """
  Grounding attribution for generated content.
  """

  use TypedStruct

  alias Gemini.Types.Content
  alias Gemini.Types.Response.GroundingAttributionSourceId

  @derive Jason.Encoder
  typedstruct do
    field(:source_id, GroundingAttributionSourceId.t() | nil, default: nil)
    field(:content, Content.t() | nil, default: nil)
  end
end

defmodule Gemini.Types.Response.GroundingAttributionSourceId do
  @moduledoc """
  Source identifier for grounding attributions.
  """

  use TypedStruct

  alias Gemini.Types.Response.{GroundingPassageId, SemanticRetrieverChunk}

  @derive Jason.Encoder
  typedstruct do
    field(:grounding_passage, GroundingPassageId.t() | nil, default: nil)
    field(:semantic_retriever_chunk, SemanticRetrieverChunk.t() | nil, default: nil)
  end
end

defmodule Gemini.Types.Response.GroundingPassageId do
  @moduledoc """
  Identifier for a grounding passage.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:passage_id, String.t(), enforce: true)
    field(:part_index, integer(), enforce: true)
  end
end

defmodule Gemini.Types.Response.SemanticRetrieverChunk do
  @moduledoc """
  Semantic retriever chunk information.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:source, String.t(), enforce: true)
    field(:chunk, String.t(), enforce: true)
  end
end
