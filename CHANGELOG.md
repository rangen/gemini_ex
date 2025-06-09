# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.2] - 2025-06-09

### Fixed
- **Documentation Rendering**: Fixed mermaid diagram rendering errors on hex docs by removing emoji characters from diagram labels
- **Package Links**: Removed redundant "Documentation" link in hex package configuration, keeping only "Online documentation"
- **Configuration References**: Updated TELEMETRY_IMPLEMENTATION.md to reference `:gemini_ex` instead of `:gemini` for correct application configuration

### Changed
- Improved hex docs compatibility for better rendering of documentation diagrams
- Enhanced documentation consistency across all markdown files

## [0.0.1] - 2025-06-09

### Added

#### Core Features
- **Dual Authentication System**: Support for both Gemini API keys and Vertex AI OAuth/Service Accounts
- **Advanced Streaming**: Production-grade Server-Sent Events (SSE) streaming with real-time processing
- **Comprehensive API Coverage**: Full support for Gemini API endpoints including content generation, model listing, and token counting
- **Type Safety**: Complete TypeScript-style type definitions with runtime validation
- **Error Handling**: Detailed error types with recovery suggestions and proper HTTP status code mapping
- **Built-in Telemetry**: Comprehensive observability with metrics and event tracking
- **Chat Sessions**: Multi-turn conversation management with state persistence
- **Multimodal Support**: Text, image, audio, and video content processing

#### Authentication
- Multi-strategy authentication coordinator with automatic strategy selection
- Environment variable and application configuration support
- Per-request authentication override capabilities
- Secure credential management with validation
- Support for Google Cloud Service Account JSON files
- OAuth2 Bearer token generation for Vertex AI

#### Streaming Architecture
- Unified streaming manager with state management
- Real-time SSE parsing with event dispatching
- Configurable buffer management and backpressure handling
- Stream lifecycle management (start, pause, resume, stop)
- Event subscription system with filtering capabilities
- Comprehensive error recovery and retry mechanisms

#### HTTP Client
- Dual HTTP client system (standard and streaming)
- Request/response interceptors for middleware support
- Automatic retry logic with exponential backoff
- Connection pooling and timeout management
- Request validation and response parsing
- Content-Type negotiation and encoding support

#### Type System
- Comprehensive type definitions for all API structures
- Runtime type validation with descriptive error messages
- Request and response schema validation
- Content type definitions for multimodal inputs
- Model capability and configuration types
- Error type hierarchy with actionable information

#### Configuration
- Hierarchical configuration system (runtime > environment > application)
- Environment variable detection and parsing
- Application configuration validation
- Default value management
- Configuration hot-reloading support

#### Utilities
- Content extraction helpers
- Response transformation utilities
- Validation helpers
- Debugging and logging utilities
- Performance monitoring tools

### Technical Implementation

#### Architecture
- Layered architecture with clear separation of concerns
- Behavior-driven design for pluggable components
- GenServer-based application supervision tree
- Concurrent request processing with actor model
- Event-driven streaming with backpressure management

#### Dependencies
- `req` ~> 0.4.0 for HTTP client functionality
- `jason` ~> 1.4 for JSON encoding/decoding
- `typed_struct` ~> 0.3.0 for type definitions
- `joken` ~> 2.6 for JWT handling in Vertex AI authentication
- `telemetry` ~> 1.2 for observability and metrics

#### Development Tools
- `ex_doc` for comprehensive documentation generation
- `credo` for code quality analysis
- `dialyxir` for static type analysis

### Documentation
- Complete API reference documentation
- Architecture documentation with Mermaid diagrams
- Authentication system technical specification
- Getting started guide with examples
- Advanced usage patterns and best practices
- Error handling and troubleshooting guide

### Security
- Secure credential storage and transmission
- Input validation and sanitization
- Rate limiting and throttling support
- SSL/TLS enforcement for all communications
- No sensitive data logging

### Performance
- Optimized for high-throughput scenarios
- Memory-efficient streaming implementation
- Connection reuse and pooling
- Minimal latency overhead
- Concurrent request processing

[0.0.2]: https://github.com/nshkrdotcom/gemini_ex/releases/tag/v0.0.2
[0.0.1]: https://github.com/nshkrdotcom/gemini_ex/releases/tag/v0.0.1
