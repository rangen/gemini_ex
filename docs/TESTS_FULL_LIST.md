# Complete Test File and Test List

## Unit Tests

### test/gemini/auth/multi_auth_coordinator_test.exs
- test "coordinates gemini auth strategy"
- test "coordinates vertex_ai auth strategy"
- test "handles invalid auth strategy"
- test "manages concurrent auth strategies"
- test "refreshes credentials independently"
- test "validates auth configuration"
- test "switches auth strategies per request"

### test/gemini/auth/gemini_strategy_test.exs
- test "authenticates with valid API key"
- test "handles missing API key"
- test "builds correct headers"
- test "returns correct base URL"
- test "builds correct path for models"
- test "handles API key refresh"

### test/gemini/auth/vertex_strategy_test.exs
- test "authenticates with access token"
- test "authenticates with service account key"
- test "authenticates with service account data"
- test "handles missing project_id"
- test "handles missing location"
- test "builds correct Vertex AI headers"
- test "returns correct Vertex AI base URL"
- test "builds correct Vertex AI path"
- test "refreshes OAuth2 tokens"
- test "generates access token from service account"

### test/gemini/auth/jwt_test.exs
- test "creates JWT payload with required fields"
- test "signs JWT with service account key"
- test "signs JWT with IAM API"
- test "validates JWT payload structure"
- test "loads service account key from file"
- test "handles JWT signing errors"
- test "extracts service account email"

### test/gemini/streaming/unified_manager_test.exs
- test "starts stream with gemini auth"
- test "starts stream with vertex_ai auth"
- test "manages concurrent streams with different auths"
- test "subscribes to stream events"
- test "unsubscribes from streams"
- test "stops active streams"
- test "handles stream errors with auth context"
- test "gets stream info with auth metadata"
- test "lists all active streams"
- test "handles subscriber process death"
- test "cleans up completed streams"

### test/gemini/streaming/manager_v2_test.exs
- test "starts streaming session"
- test "subscribes multiple processes to stream"
- test "handles streaming events"
- test "manages stream lifecycle"
- test "handles stream completion"
- test "handles stream errors"
- test "cleans up dead subscribers"
- test "stops streams when no subscribers"
- test "provides stream statistics"

### test/gemini/client/http_streaming_test.exs
- test "streams SSE events with callback"
- test "handles streaming errors"
- test "processes chunked SSE data"
- test "manages streaming timeouts"
- test "retries failed streaming requests"
- test "emits telemetry for streaming"
- test "handles connection failures"

### test/gemini/client/http_test.exs
- test "makes GET requests"
- test "makes POST requests"
- test "handles authentication headers"
- test "processes JSON responses"
- test "handles HTTP error responses"
- test "retries failed requests"
- test "emits request telemetry"

### test/gemini/sse/parser_test.exs
- test "parses complete SSE events"
- test "handles partial SSE chunks"
- test "maintains parser state across chunks"
- test "extracts event data"
- test "handles malformed SSE data"
- test "detects stream completion"
- test "finalizes remaining buffer data"

### test/gemini/apis/coordinator_test.exs
- test "routes generate requests to correct auth"
- test "routes model requests to correct auth"
- test "routes token counting to correct auth"
- test "handles auth strategy fallback"
- test "validates request routing"
- test "maintains consistent API interface"

### test/gemini/apis/generate_test.exs
- test "generates content with text input"
- test "generates content with multimodal input"
- test "streams content generation"
- test "handles generation errors"
- test "applies generation config"
- test "applies safety settings"
- test "manages chat sessions"
- test "sends chat messages"
- test "builds generate requests"

### test/gemini/apis/enhanced_generate_test.exs
- test "generates with enhanced error handling"
- test "validates request parameters"
- test "emits detailed telemetry"
- test "handles batch generation"
- test "manages generation timeouts"

### test/gemini/apis/models_test.exs
- test "lists available models"
- test "gets specific model info"
- test "checks model existence"
- test "filters models by capability"
- test "handles pagination"
- test "validates model names"

### test/gemini/apis/enhanced_models_test.exs
- test "provides rich model filtering"
- test "calculates model statistics"
- test "compares model capabilities"
- test "analyzes capacity distribution"
- test "validates model compatibility"

### test/gemini/apis/tokens_test.exs
- test "counts tokens for text content"
- test "counts tokens for multimodal content"
- test "estimates token usage"
- test "checks content fit within limits"
- test "handles batch token counting"
- test "validates token requests"

### test/gemini/types/common/content_test.exs
- test "creates text content"
- test "creates multimodal content"
- test "validates content structure"
- test "handles content serialization"

### test/gemini/types/common/generation_config_test.exs
- test "creates default config"
- test "creates creative config"
- test "creates precise config"
- test "sets JSON response format"
- test "configures stop sequences"
- test "validates config parameters"

### test/gemini/types/common/safety_setting_test.exs
- test "creates harassment setting"
- test "creates hate speech setting"
- test "creates explicit content setting"
- test "creates dangerous content setting"
- test "provides default settings"
- test "provides permissive settings"

### test/gemini/types/request/generate_content_request_test.exs
- test "creates request from string"
- test "creates request from content list"
- test "validates required fields"
- test "applies generation config"
- test "applies safety settings"
- test "converts to JSON map"

### test/gemini/types/request/count_tokens_request_test.exs
- test "creates request for content"
- test "creates request for generate request"
- test "validates request structure"
- test "converts to JSON map"

### test/gemini/types/response/generate_content_response_test.exs
- test "extracts text from response"
- test "extracts all text from candidates"
- test "checks if response blocked"
- test "gets finish reason"
- test "extracts token usage"

### test/gemini/types/response/model_test.exs
- test "checks method support"
- test "detects streaming support"
- test "calculates capability score"
- test "determines production readiness"
- test "extracts model family"
- test "compares model capabilities"

### test/gemini/config_test.exs
- test "detects auth type from environment"
- test "gets auth configuration"
- test "validates required configuration"
- test "handles missing configuration"
- test "supports telemetry configuration"

### test/gemini/error_test.exs
- test "creates API errors"
- test "creates network errors"
- test "creates validation errors"
- test "checks error retryability"
- test "calculates retry delays"
- test "formats errors for display"
- test "adds context to errors"

### test/gemini/enhanced_error_test.exs
- test "creates comprehensive error types"
- test "provides recovery suggestions"
- test "formats errors for logging"
- test "classifies error severity"
- test "handles client vs server errors"

### test/gemini/telemetry_test.exs
- test "executes telemetry events"
- test "generates stream IDs"
- test "classifies content types"
- test "builds request metadata"
- test "calculates durations"
- test "respects telemetry configuration"

### test/gemini_test.exs
- test "generates content with default auth"
- test "generates with explicit auth strategy"
- test "streams content generation"
- test "manages chat sessions"
- test "counts tokens"
- test "lists models"
- test "checks configuration"
- test "validates health check"

## Integration Tests

### test/integration/concurrent_auth_test.exs
- test "concurrent gemini and vertex_ai requests"
- test "concurrent streaming with different auths"
- test "auth strategy isolation"
- test "concurrent chat sessions"
- test "mixed request types with different auths"

### test/integration/streaming_integration_test.exs
- test "end-to-end streaming with gemini auth"
- test "end-to-end streaming with vertex_ai auth"
- test "streaming with reconnection"
- test "streaming error recovery"
- test "streaming telemetry integration"

### test/integration/multimodal_test.exs
- test "text and image generation"
- test "multimodal with different auth strategies"
- test "file upload and processing"
- test "multimodal streaming"

### test/integration/error_handling_test.exs
- test "API error handling and recovery"
- test "network error retry logic"
- test "rate limiting handling"
- test "auth error recovery"

### test/integration/telemetry_integration_test.exs
- test "request telemetry emission"
- test "streaming telemetry emission"
- test "error telemetry emission"
- test "telemetry metadata accuracy"

## Property Tests

### test/property/content_generation_test.exs
- test "content generation invariants"
- test "request/response symmetry"
- test "auth strategy consistency"

### test/property/sse_parsing_test.exs
- test "SSE parsing with arbitrary chunks"
- test "parser state consistency"
- test "incremental parsing correctness"

### test/property/type_validation_test.exs
- test "struct validation properties"
- test "type specification compliance"
- test "serialization roundtrip properties"

## Support Files

### test/support/test_helper.exs
### test/support/mock_server.ex
### test/support/fixtures.ex
### test/support/factory.ex
### test/support/auth_helpers.ex
### test/support/streaming_helpers.ex
