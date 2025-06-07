# CLAUDE.md - Project Context and Commands

## Project Overview
This is a Gemini Elixir library that provides authentication and API access to Google's Gemini AI models. The project supports both direct Gemini API authentication and Vertex AI authentication strategies.

## Key Commands
- **Run tests**: `mix test`
- **Run specific test file**: `mix test test/path/to/file_test.exs`
- **Run auth tests**: `mix test test/gemini/auth/`
- **Check dependencies**: `mix deps.get`
- **Compile**: `mix compile`
- **Format code**: `mix format`

## Current Status
✅ **ALL SYSTEMS WORKING**: 
- ✅ Vertex AI authentication fully functional (50/50 auth tests passing)
- ✅ HTTP client migrated from Finch to Req
- ✅ All critical issues resolved
- ✅ Full test suite passing (97 tests, 0 failures)

## Architecture
- `lib/gemini/auth/vertex_strategy.ex` - Main Vertex AI authentication strategy
- `lib/gemini/auth/jwt.ex` - JWT handling for service account authentication
- `lib/gemini/auth/gemini_strategy.ex` - Direct Gemini API authentication
- `lib/gemini/client/http.ex` - Unified HTTP client using Req
- `test/gemini/auth/` - Authentication test suite

## Dependencies
- JOSE (v1.11.10) - JSON Web signatures
- Joken - JWT creation and signing
- Req (~> 0.5) - HTTP client (replaced Finch)
- Jason - JSON encoding/decoding

## Completed Fixes
1. ✅ Fixed invalid test private key with valid RSA 2048-bit key
2. ✅ Fixed string interpolation error using `inspect()`
3. ✅ Migrated HTTP client from Finch to Req
4. ✅ Updated all HTTP calls to use Req API
5. ✅ Removed Finch from application supervision tree