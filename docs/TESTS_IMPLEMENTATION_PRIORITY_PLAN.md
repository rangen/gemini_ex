# Test Implementation Priority Plan

## 🎯 Current Status: 31/113 Tests (27% Coverage)

**Foundation**: Excellent streaming and basic auth coverage from ported tests
**Gap**: Need Vertex AI auth, JWT, and multi-auth coordination
**Goal**: Focus on critical missing pieces to enable full multi-auth capability

## 📋 Implementation Phases

### **Phase 1: Critical Auth Infrastructure (12 tests) - IMMEDIATE**

#### **Priority 1A: Vertex AI Auth Strategy (6 tests)**
```bash
# Create: test/gemini/auth/vertex_strategy_test.exs
test "authenticates with access token"
test "authenticates with service account key" 
test "handles missing project_id"
test "builds correct Vertex AI headers"
test "refreshes OAuth2 tokens"
test "generates access token from service account"
```
**Why Critical**: Without these, Vertex AI auth doesn't work, breaking multi-auth capability.

#### **Priority 1B: JWT Handling (6 tests)**
```bash
# Create: test/gemini/auth/jwt_test.exs  
test "creates JWT payload with required fields"
test "signs JWT with service account key"
test "signs JWT with IAM API"
test "validates JWT payload structure"
test "loads service account key from file"
test "handles JWT signing errors"
```
**Why Critical**: JWT is required for Vertex AI service account authentication.

### **Phase 2: Core API Functionality (13 tests) - HIGH PRIORITY**

#### **Priority 2A: Content Generation API (8 tests)**
```bash
# Create: test/gemini/apis/generate_test.exs
test "generates content with text input"
test "generates content with multimodal input"
test "streams content generation"
test "handles generation errors"
test "applies generation config"
test "applies safety settings"
test "manages chat sessions"
test "sends chat messages"
```

#### **Priority 2B: Models API (5 tests)**
```bash
# Create: test/gemini/apis/models_test.exs
test "lists available models"
test "gets specific model info"
test "checks model existence"
test "filters models by capability"
test "handles pagination"
```

### **Phase 3: Multi-Auth Integration (5 tests) - HIGH PRIORITY**

#### **Priority 3A: Complete Multi-Auth Coordinator (4 tests)**
```bash
# Already created: test/gemini/auth/multi_auth_coordinator_test.exs
# Need to expand with:
test "manages concurrent auth strategies"
test "refreshes credentials independently"
test "validates auth configuration"
test "switches auth strategies per request"
```

#### **Priority 3B: Concurrent Integration Testing (1 test)**
```bash
# Create: test/integration/concurrent_auth_test.exs
test "concurrent streaming with different auths"
```

### **Phase 4: Enhanced Coverage (35 tests) - MEDIUM PRIORITY**

#### **Priority 4A: Enhanced APIs (15 tests)**
Enhanced generate, models, tokens APIs with better error handling and validation.

#### **Priority 4B: Type System (15 tests)**
Content, generation config, safety settings type validation.

#### **Priority 4C: Request/Response Types (5 tests)**
Request and response structure validation.

### **Phase 5: Comprehensive Testing (22 tests) - LOWER PRIORITY**

Error handling, edge cases, performance, and robustness testing.

## 🚀 Implementation Strategy

### **Week 1: Auth Foundation**
- [ ] Implement Vertex AI strategy tests
- [ ] Implement JWT handling tests
- [ ] Ensure all auth strategies work independently

### **Week 2: Core APIs**
- [ ] Implement generate API tests
- [ ] Implement models API tests
- [ ] Ensure basic functionality across both auth strategies

### **Week 3: Multi-Auth Integration**
- [ ] Complete multi-auth coordinator tests
- [ ] Add concurrent usage tests
- [ ] Validate the key differentiator feature

### **Week 4: Enhanced Coverage**
- [ ] Add enhanced API tests
- [ ] Add type system tests
- [ ] Improve error handling coverage

## 🎯 Success Criteria

### **Phase 1 Success**: Auth Infrastructure Complete
```elixir
# Both auth strategies work independently
{:ok, _} = Gemini.generate("Hello", auth: :gemini)
{:ok, _} = Gemini.generate("Hello", auth: :vertex_ai)
```

### **Phase 2 Success**: Core APIs Work
```elixir
# All basic operations work with both auth strategies
{:ok, models} = Gemini.list_models(auth: :gemini)
{:ok, response} = Gemini.generate("Hello", auth: :vertex_ai)
{:ok, tokens} = Gemini.count_tokens("Hello", auth: :gemini)
```

### **Phase 3 Success**: Multi-Auth Coordination
```elixir
# Concurrent usage works seamlessly
Task.async(fn -> Gemini.generate("Hello", auth: :gemini) end)
Task.async(fn -> Gemini.generate("Hello", auth: :vertex_ai) end)
Task.async(fn -> Gemini.stream_generate("Story", auth: :gemini) end)
Task.async(fn -> Gemini.stream_generate("Story", auth: :vertex_ai) end)
```

## 📊 Test Metrics Goals

### **Immediate Goals (Phase 1-3)**
- **Coverage**: 60%+ (43/113 tests)
- **Critical Path Coverage**: 100% (auth + basic APIs)
- **Multi-Auth Capability**: Fully validated

### **Medium-Term Goals (Phase 4)**  
- **Coverage**: 80%+ (78/113 tests)
- **Feature Coverage**: All major APIs tested
- **Type Safety**: Complete validation

### **Long-Term Goals (Phase 5)**
- **Coverage**: 95%+ (107/113 tests)
- **Robustness**: Comprehensive error handling
- **Performance**: Load and stress testing

## 🔧 Development Workflow

### **For Each Test Phase**:
1. **Write tests first** - Define expected behavior
2. **Implement just enough** - Make tests pass
3. **Refactor for quality** - Follow CODE_QUALITY.md
4. **Integration check** - Ensure existing tests still pass
5. **Document changes** - Update test documentation

### **Testing Strategy**:
- **Unit tests**: Test individual components in isolation
- **Integration tests**: Test component interaction
- **Property tests**: Test invariants and edge cases
- **Live API tests**: Test against real APIs (optional)

## ⚠️ Critical Dependencies

### **Blocked Tests** (need implementation first):
- Multi-auth coordinator tests → Need `multi_auth_coordinator.ex`
- Unified streaming tests → Need `unified_manager.ex` 
- API coordinator tests → Need `apis/coordinator.ex`

### **Foundation Tests** (can implement immediately):
- Vertex AI strategy tests → Use existing `vertex_strategy.ex`
- JWT tests → Use existing `jwt.ex`
- Enhanced API tests → Use existing API implementations

## 🎯 Focus Areas

### **Highest ROI Tests**:
1. **Vertex AI auth** - Unlocks half the multi-auth capability
2. **Multi-auth coordinator** - The key differentiator
3. **Concurrent usage** - Validates the architecture

### **Foundation Preservation**:
- Keep all existing streaming tests passing
- Maintain auth strategy compatibility
- Preserve excellent SSE parsing

### **Quality Standards**:
- Follow CODE_QUALITY.md for all new tests
- Use test helpers for consistency
- Mock external dependencies appropriately
- Test both success and failure cases

This plan prioritizes getting the multi-auth capability working and well-tested before expanding to comprehensive coverage.
