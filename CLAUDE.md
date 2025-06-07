# CLAUDE.md - Project Context and Commands

## Project Overview
This is a production-ready Gemini Elixir library that provides authentication and API access to Google's Gemini AI models. The project supports both direct Gemini API authentication and Vertex AI authentication strategies with comprehensive streaming support.

## Key Commands
- **Run tests**: `mix test`
- **Run specific test file**: `mix test test/path/to/file_test.exs`
- **Run auth tests**: `mix test test/gemini/auth/`
- **Run live API tests**: `VERTEX_JSON_FILE=/path/to/key.json mix test test/live_api_test.exs --include live_api`
- **Check dependencies**: `mix deps.get`
- **Compile**: `mix compile`
- **Format code**: `mix format`
- **Type checking**: `mix dialyzer`

## Current Status
✅ **PRODUCTION READY - ALL SYSTEMS OPERATIONAL**: 
- ✅ Full test suite passing (133 tests, 0 failures, 8 excluded, 1 skipped)
- ✅ Live API tests verified with real credentials
- ✅ Both Gemini API and Vertex AI authentication working flawlessly
- ✅ Complete streaming infrastructure operational with ManagerV2
- ✅ Zero compilation warnings
- ✅ Dialyzer type checking passes (0 errors)
- ✅ Code quality standards fully compliant with CODE_QUALITY.md
- ✅ Streaming error handling and authentication validation working correctly

## Live API Test Results (Last Verified: Current Session)
### 🔑 Gemini API Authentication - WORKING PERFECTLY
- ✅ Text Generation: Successfully generating responses
- ✅ Model Listing: Found 50 available models
- ✅ Token Counting: Accurate token counts

### 🔑 Vertex AI Authentication - WORKING PERFECTLY  
- ✅ Service Account Auth: Loading from `/home/home/.keys/gcp-vertex-johnsmith.json`
- ✅ Project: `gen-lang-client-0083056043` auto-detected
- ✅ Text Generation: Successfully generating responses
- ✅ Model Operations: `gemini-2.0-flash` verified working

### 🌊 Streaming Functionality - FULLY OPERATIONAL
- ✅ Managed Streaming: Stream creation and subscription working perfectly
- ✅ Stream Management: Event handling and cleanup operational
- ✅ Error Handling: Proper 404 errors for invalid models, authentication validation
- ✅ Resource Management: Automatic cleanup when subscribers die
- ✅ SSE Parser: Robust parsing of Server-Sent Events with state management
- ✅ HTTP Streaming: Retry logic with exponential backoff implemented

## Architecture
- `lib/gemini.ex` - Main API with complete @spec annotations
- `lib/gemini/auth/vertex_strategy.ex` - Vertex AI authentication strategy
- `lib/gemini/auth/jwt.ex` - JWT handling for service account authentication
- `lib/gemini/auth/gemini_strategy.ex` - Direct Gemini API authentication
- `lib/gemini/client/http.ex` - Unified HTTP client using Req
- `lib/gemini/client/http_streaming.ex` - HTTP streaming client with SSE support
- `lib/gemini/streaming/manager_v2.ex` - Enhanced GenServer streaming manager
- `lib/gemini/sse/parser.ex` - Server-Sent Events parser with state management
- `lib/gemini/types/` - Complete type system with @type t specifications
- `test/gemini/auth/` - Authentication test suite
- `test/gemini/streaming/integration_test.exs` - Comprehensive streaming tests
- `test/live_api_test.exs` - Live API integration tests

## Dependencies
- **dialyxir** (~> 1.4) - Static analysis and type checking
- **JOSE** (v1.11.10) - JSON Web signatures  
- **Joken** (~> 2.6) - JWT creation and signing
- **Req** (~> 0.5) - HTTP client (replaced Finch)
- **Jason** (~> 1.4) - JSON encoding/decoding
- **typed_struct** (~> 0.3) - Structured types with enforcement

## Code Quality Improvements Completed
1. ✅ **Eliminated All Warnings**: Fixed all compilation warnings
   - Removed unused aliases in core modules
   - Fixed redefined @doc/@typedoc attributes
   - Fixed pattern matching and variable warnings
   - Fixed unused variable warning in test files (`event_count` → `_event_count`)
2. ✅ **Type Safety**: Added comprehensive @spec annotations throughout `lib/`
   - Main API functions fully annotated
   - Auth module functions with proper type specifications
   - All public functions in streaming infrastructure
3. ✅ **Dialyzer Integration**: Zero type errors, full static analysis passing
4. ✅ **Documentation**: Enhanced with proper type information per CODE_QUALITY.md
5. ✅ **Code Standards**: Full compliance with CODE_QUALITY.md standards
   - Proper @type t specifications for all structs
   - @enforce_keys for required struct fields
   - Consistent documentation and naming conventions
6. ✅ **Streaming Quality**: Robust error handling and test validation
   - Proper authentication requirement enforcement
   - 404 error handling for invalid models
   - Resource cleanup and subscriber management

## Environment Setup
```bash
export GEMINI_API_KEY="your_gemini_api_key"
export VERTEX_JSON_FILE="/path/to/service-account.json"
export VERTEX_PROJECT_ID="your-project-id"  # Optional, auto-detected from JSON
export VERTEX_LOCATION="us-central1"        # Optional, defaults to us-central1
```

## Usage Examples
```elixir
# Configure for Gemini API
Gemini.configure(:gemini, %{api_key: "your_api_key"})

# Configure for Vertex AI  
Gemini.configure(:vertex_ai, %{
  service_account_key: "/path/to/key.json",
  project_id: "your-project",
  location: "us-central1"
})

# Generate content
{:ok, response} = Gemini.generate("What is the capital of France?")
{:ok, text} = Gemini.extract_text(response)

# Streaming
{:ok, stream_id} = Gemini.start_stream("Write a short story")
:ok = Gemini.subscribe_stream(stream_id)
```

## Recent Session Work Completed
**Last Session (Current)**: Streaming Implementation & Code Quality
- ✅ **Streaming Infrastructure**: Implemented complete streaming rewrite
  - Moved REWRITE_STREAMING* files to proper lib/ structure
  - Created robust SSE parser with stateful buffer management
  - Built HTTP streaming client with retry logic and exponential backoff
  - Enhanced GenServer manager (ManagerV2) with proper resource management
- ✅ **Test Quality**: Fixed streaming test issues that were masking authentication failures
  - Created proper failing tests for authentication validation
  - Added comprehensive error scenario testing (404 for invalid models)
  - Ensured tests properly validate streaming behavior and requirements
- ✅ **Code Quality**: Full compliance with CODE_QUALITY.md standards
  - Added missing @spec annotations throughout lib/ modules
  - Fixed all compilation warnings including unused variables
  - Verified all code follows Elixir best practices and type safety
- ✅ **Type Safety**: Dialyzer passes with 0 errors and warnings

## Next Steps / Continuation
The library is now production-ready with:
- ✅ Full authentication support for both platforms
- ✅ Complete type safety and documentation
- ✅ Live API verification
- ✅ Robust streaming infrastructure with comprehensive error handling
- ✅ Full CODE_QUALITY.md compliance

**Potential future enhancements:**
- Add more streaming endpoint support
- Implement caching for access tokens
- Extend model management capabilities
- Add batch processing support