Of course. Here is a highly detailed breakdown of Phase 2, covering the implementation of core content generation and tokenization endpoints for the Elixir Gemini adapter.

### Phase 2 Detailed Breakdown: Core Content Generation & Tokenization

**High-Level Goal:** To enable the core functionality of the Gemini API: generating text-based responses from prompts (both as a single response and as a stream) and providing a utility to count tokens before making a request. This phase involves defining a significant number of data structures that are central to the entire API.

---

### 1. Define All Related Data Structures (Structs)

This is the most critical part of this phase. A clear and accurate struct representation of the API's JSON objects is essential for a robust and user-friendly library. All structs should be defined in dedicated modules, for example, `lib/gemini/types.ex`.

**Key Documents:**
*   **Primary:** `GEMINI-API-02-GENERATING-CONTENT.md`
*   **Secondary:** `GEMINI-API-04-TOKENS.md`

#### A. Core Content & Request/Response Structs

These are the primary building blocks for sending requests and receiving responses.

*   **`Gemini.Content`**
    *   **Purpose:** Represents a single message in a conversation.
    *   **Elixir Struct:**
        ```elixir
        defstruct [:parts, :role]
        @type t :: %__MODULE__{
          parts: [Gemini.Part.t()],
          role: String.t() | nil # "user" or "model"
        }
        ```
    *   **Document Reference:** `GEMINI-API-02-GENERATING-CONTENT.md` - `contents[]` field description.

*   **`Gemini.Part`**
    *   **Purpose:** Represents a piece of a `Content` message. This is a union-type object.
    *   **Elixir Struct:** The struct will contain all possible data fields, but only one should be populated at a time.
        ```elixir
        defstruct [:text, :inline_data, :file_data, :function_call, :function_response] # ... and others
        # Note: function_call and function_response will be implemented in a later phase
        # but can be scaffolded here.
        @type t :: %__MODULE__{
          text: String.t() | nil,
          # Define Blob and FileData structs later
          inline_data: map() | nil, # Placeholder for Gemini.Blob.t()
          file_data: map() | nil,   # Placeholder for Gemini.FileData.t()
          ...
        }
        ```
    *   **Document Reference:** `GEMINI-API-02-GENERATING-CONTENT.md` - `contents[]` field, which contains `parts[]`. Also see `GEMINI-API-06-CACHING.md` for a full `Part` definition.

*   **`Gemini.GenerateContentResponse`**
    *   **Purpose:** The top-level response object for a generation request.
    *   **Elixir Struct:**
        ```elixir
        defstruct [:candidates, :prompt_feedback, :usage_metadata, :model_version]
        @type t :: %__MODULE__{
          candidates: [Gemini.Candidate.t()],
          prompt_feedback: Gemini.PromptFeedback.t() | nil,
          usage_metadata: Gemini.UsageMetadata.t() | nil,
          model_version: String.t() | nil
        }
        ```
    *   **Document Reference:** `GEMINI-API-02-GENERATING-CONTENT.md` - "GenerateContentResponse" section.

*   **`Gemini.Candidate`**
    *   **Purpose:** A single potential response from the model.
    *   **Elixir Struct:**
        ```elixir
        defstruct [:content, :finish_reason, :safety_ratings, :citation_metadata, :token_count, :index] # and others
        @type t :: %__MODULE__{
          content: Gemini.Content.t(),
          finish_reason: atom() | nil, # e.g., :STOP, :MAX_TOKENS, :SAFETY
          safety_ratings: [Gemini.SafetyRating.t()],
          citation_metadata: map() | nil, # Placeholder for Gemini.CitationMetadata.t()
          token_count: integer() | nil,
          index: integer()
        }
        ```
    *   **Document Reference:** `GEMINI-API-02-GENERATING-CONTENT.md` - "Candidate" section.

#### B. Configuration & Metadata Structs

These structs are used within the main request/response objects to control generation and provide metadata.

*   **`Gemini.GenerationConfig`**
    *   **Purpose:** Defines parameters for the generation process.
    *   **Elixir Struct:**
        ```elixir
        defstruct [
          :stop_sequences,
          :candidate_count,
          :max_output_tokens,
          :temperature,
          :top_p,
          :top_k
          # ... and many others
        ]
        @type t :: %__MODULE__{
          stop_sequences: [String.t()] | nil,
          candidate_count: integer() | nil,
          max_output_tokens: integer() | nil,
          temperature: float() | nil,
          top_p: float() | nil,
          top_k: integer() | nil
        }
        ```
    *   **Document Reference:** `GEMINI-API-02-GENERATING-CONTENT.md` - "GenerationConfig" section.

*   **`Gemini.SafetySetting` & `Gemini.SafetyRating`**
    *   **Purpose:** `SafetySetting` is for requests (what to block). `SafetyRating` is for responses (what was detected).
    *   **Elixir Structs:**
        ```elixir
        defstruct [:category, :threshold] # SafetySetting
        @type t :: %__MODULE__{category: atom(), threshold: atom()}

        defstruct [:category, :probability, :blocked] # SafetyRating
        @type t :: %__MODULE__{category: atom(), probability: atom(), blocked: boolean()}
        ```
    *   **Document Reference:** `GEMINI-API-02-GENERATING-CONTENT.md` - "SafetySetting" and "SafetyRating" sections.

*   **`Gemini.PromptFeedback`**
    *   **Purpose:** Provides feedback on the safety evaluation of the prompt itself.
    *   **Elixir Struct:**
        ```elixir
        defstruct [:block_reason, :safety_ratings]
        @type t :: %__MODULE__{
          block_reason: atom() | nil, # e.g., :SAFETY, :OTHER
          safety_ratings: [Gemini.SafetyRating.t()]
        }
        ```
    *   **Document Reference:** `GEMINI-API-02-GENERATING-CONTENT.md` - "PromptFeedback" section.

*   **`Gemini.UsageMetadata`**
    *   **Purpose:** Details the token counts for a request.
    *   **Elixir Struct:**
        ```elixir
        defstruct [:prompt_token_count, :candidates_token_count, :total_token_count]
        @type t :: %__MODULE__{
          prompt_token_count: integer(),
          candidates_token_count: integer(),
          total_token_count: integer()
        }
        ```
    *   **Document Reference:** `GEMINI-API-02-GENERATING-CONTENT.md` - "UsageMetadata" section.

#### C. Handling Enums

The Gemini API uses uppercase string enums (e.g., `"STOP"`, `"HARM_CATEGORY_HARASSMENT"`). In Elixir, it's idiomatic to use atoms (e.g., `:stop`, `:harm_category_harassment`).

*   **Action:** Create a private helper function within your JSON serialization logic to convert Elixir atoms to the required uppercase snake_case or camelCase strings before sending the request, and convert them back upon receiving a response. This keeps the public-facing API clean.

---

### 2. Implement API Endpoints

These functions will be added to the `Gemini.Models` module.

#### A. `countTokens`

*   **Purpose:** Allows users to calculate the token count for a given prompt *before* sending it for generation, which is crucial for managing costs and context window limits.
*   **Elixir Function:** `Gemini.Models.count_tokens(model_name, contents)`
*   **Implementation Steps:**
    1.  Define the function signature to accept the model name and a list of `Gemini.Content` structs.
    2.  Construct the request body as a map: `%{contents: contents}`.
    3.  Use the core `Gemini.Client` to make a `POST` request to `/v1beta/{model=models/*}:countTokens`.
    4.  The response is a simple JSON object like `{"totalTokens": 10}`. Decode this and return the integer value.
    5.  Create a `Gemini.CountTokensResponse` struct for better type-hinting, containing `total_tokens` and other fields from the doc.
*   **Document Reference:** `GEMINI-API-04-TOKENS.md` - This document details the endpoint, request body, and response body.

#### B. `generateContent`

*   **Purpose:** The primary method for synchronous, non-streaming content generation.
*   **Elixir Function:** `Gemini.Models.generate_content(model_name, contents, opts \\ [])`
*   **Implementation Steps:**
    1.  Define the function to accept the model name, a list of `Gemini.Content` structs, and an optional keyword list for `generationConfig`, `safetySettings`, etc.
    2.  Build the request body map. This will be the most complex request object, combining `contents` with any provided options. For example:
        ```elixir
        body = %{contents: contents}
        body =
          if opts[:generation_config],
            do: Map.put(body, :generationConfig, opts[:generation_config]),
            else: body
        # ... and so on for other options
        ```
    3.  Use the core `Gemini.Client` to make a `POST` request to `/v1beta/{model=models/*}:generateContent`.
    4.  On a successful response, decode the JSON into a fully-populated `Gemini.GenerateContentResponse` struct, including all nested structs.
    5.  Return the struct, likely wrapped in an `{:ok, response}` tuple. Handle errors by returning `{:error, reason}`.
*   **Document Reference:** `GEMINI-API-02-GENERATING-CONTENT.md` - "Method: models.generateContent" section provides the endpoint, request, and response details.

#### C. `streamGenerateContent`

*   **Purpose:** Enables real-time, interactive experiences by receiving response chunks as they are generated.
*   **Elixir Function:** `Gemini.Models.stream_generate_content(model_name, contents, opts \\ [])`
*   **Implementation Steps:**
    1.  This is the most technically challenging part of Phase 2. The function signature is identical to `generate_content`.
    2.  The request body is also constructed identically.
    3.  The key difference is the endpoint URL. You must append `?alt=sse` to the URL to request a Server-Sent Events (SSE) stream.
    4.  Your HTTP client (`Tesla`, `Finch`, etc.) must be configured to handle a streaming response body. The function should **not** wait for the entire response.
    5.  The function should return an Elixir `Stream`. This is the idiomatic way to handle lazy, chunk-based processing.
    6.  The stream's implementation will need to:
        *   Receive raw chunks of data from the HTTP connection.
        *   Parse the SSE format. Each event is typically prefixed with `data: `. You need to strip this prefix.
        *   Each event's data is a JSON string representing a `GenerateContentResponse`. Decode this JSON into the corresponding struct.
        *   Yield the decoded `Gemini.GenerateContentResponse` struct for each event in the stream.
*   **Document Reference:** `GEMINI-API-02-GENERATING-CONTENT.md` - The "Method: models.streamGenerateContent" section's `curl` example is crucial as it shows the `alt=sse` parameter.

---

### 3. Testing and Documentation

*   **Testing `generate_content`:**
    *   Test a simple text-only prompt.
    *   Test a multi-turn conversation by passing a history in the `contents` list.
    *   Test that passing `generationConfig` (e.g., `temperature: 0`) and `safetySettings` works correctly.
    *   Test a prompt that you expect to be blocked and assert that the `prompt_feedback.block_reason` is set correctly.
*   **Testing `count_tokens`:**
    *   Verify the token count for a known string.
    *   Ensure it handles a list of `Content` structs correctly.
*   **Testing `stream_generate_content`:**
    *   Assert that the function returns a `Stream`.
    *   Take the first element from the stream (`Enum.take(stream, 1)`) and verify it's a valid, decoded `GenerateContentResponse` struct. This confirms the SSE parsing logic is working for at least one chunk.
*   **Documentation:** Add `@doc` and `@spec` to all public functions and module definitions. Document the purpose of each struct in `Gemini.Types`, especially explaining the union-like nature of `Gemini.Part`.
