# SwiftLint Complexity Refactoring Plan

**Date**: January 16, 2026  
**Goal**: Reduce cyclomatic complexity from 21 to ≤10

---

## 📊 Current Issues

| File | Function | Line | Complexity | Target |
|------|----------|------|------------|--------|
| `APIClient.swift` | `request()` | 63 | 21 | ≤10 |
| `PhotoUploadService.swift` | `uploadToImageKit()` | 159 | 21 | ≤10 |

---

## 🔍 Problem Analysis

### Issue #1: `APIClient.request()` (Complexity: 21)

**Current Structure** (67 lines):
```
1. Build URL
2. Create request
3. Add authentication (if/guard)
4. Add body (if)
5. Add debug logging (if) × 3
6. Make request
7. Check response (guard)
8. Handle status codes (switch with nested try/catch)
   - 200-299: decode + error handling
   - 401: refresh token logic
   - 400: bad request
   - 404: not found
   - 500: server error
   - default: unknown
```

**Complexity Sources**:
- Multiple `if` statements for debug logging
- Multiple `guard` statements
- Large `switch` with nested `try/catch`
- Error handling branches

**Proposed Refactoring**:

Break into **4 smaller functions**:

```swift
// 1. Request preparation (Complexity: 3)
private func prepareRequest(
    url: URL,
    method: String,
    body: Data?,
    authenticated: Bool
) throws -> URLRequest

// 2. Authentication header (Complexity: 2)
private func addAuthenticationHeader(
    to request: inout URLRequest
) throws

// 3. Response validation (Complexity: 1)
private func validateResponse(
    _ response: URLResponse
) throws -> HTTPURLResponse

// 4. Status code handling (Complexity: 6)
private func handleStatusCode<T: Decodable>(
    _ statusCode: Int,
    data: Data
) throws -> T

// Main function (Complexity: 5)
private func request<T: Decodable, B: Encodable>(...)
```

**Benefits**:
- ✅ Main function: 21 → 5 complexity
- ✅ Each helper: ≤6 complexity
- ✅ Easier to test each piece
- ✅ Better code organization

---

### Issue #2: `PhotoUploadService.uploadToImageKit()` (Complexity: 21)

**Current Structure** (98 lines):
```
1. Debug logging (if) × 4
2. Create request
3. Clean folder path (ternary)
4. Build multipart form data (for loop)
5. Append file data
6. Perform upload
7. Validate response (guard)
8. Check status code (guard + if)
9. Debug logging (if) × 3
10. Decode response (try/catch)
11. Validate fields (guard) × 2 with debug
12. Error handling (catch specific + catch)
```

**Complexity Sources**:
- Multiple debug logging conditionals
- Nested error handling
- Multiple validation guards
- Complex multipart form building

**Proposed Refactoring**:

Break into **5 smaller functions**:

```swift
// 1. Prepare multipart body (Complexity: 3)
private func buildMultipartBody(
    imageData: Data,
    params: RequestUploadResponse,
    boundary: String
) -> Data

// 2. Add form fields (Complexity: 1)
private func appendFormFields(
    to body: inout Data,
    fields: [String: String],
    boundary: String
)

// 3. Create upload request (Complexity: 1)
private func createImageKitRequest(
    boundary: String,
    body: Data
) -> URLRequest

// 4. Validate ImageKit response (Complexity: 4)
private func validateImageKitResponse(
    statusCode: Int,
    data: Data
) throws

// 5. Parse and validate result (Complexity: 5)
private func parseImageKitResponse(
    _ data: Data
) throws -> ImageKitUploadResponse

// Main function (Complexity: 4)
private func uploadToImageKit(...)
```

**Benefits**:
- ✅ Main function: 21 → 4 complexity
- ✅ Each helper: ≤5 complexity
- ✅ Multipart logic isolated
- ✅ Easier to reuse/test

---

## 📋 Implementation Plan

### Phase 1: APIClient.swift Refactoring

**Step 1**: Create helper functions (bottom of class)
```swift
// MARK: - Private Helpers

private func prepareRequest(...) throws -> URLRequest { }
private func addAuthenticationHeader(...) throws { }
private func validateResponse(...) throws -> HTTPURLResponse { }
private func handleStatusCode<T>(...) throws -> T { }
```

**Step 2**: Refactor main `request()` function
- Replace inline logic with helper calls
- Keep debug logging minimal
- Maintain same public API

**Step 3**: Test
- Build and verify no errors
- Test authenticated requests
- Test error handling

---

### Phase 2: PhotoUploadService.swift Refactoring

**Step 1**: Create helper functions (bottom of class)
```swift
// MARK: - ImageKit Upload Helpers

private func buildMultipartBody(...) -> Data { }
private func appendFormFields(...) { }
private func createImageKitRequest(...) -> URLRequest { }
private func validateImageKitResponse(...) throws { }
private func parseImageKitResponse(...) throws -> ImageKitUploadResponse { }
```

**Step 2**: Refactor main `uploadToImageKit()` function
- Extract multipart building
- Simplify error handling
- Keep debug logging in helpers

**Step 3**: Test
- Build and verify no errors
- Test photo upload
- Verify ImageKit responses

---

## 🎯 Expected Outcome

### Before
```
✗ APIClient.request()          - Complexity: 21 (ERROR)
✗ PhotoUploadService.upload()  - Complexity: 21 (ERROR)
```

### After
```
✓ APIClient.request()          - Complexity: 5  ✅
  ├─ prepareRequest()          - Complexity: 3  ✅
  ├─ addAuthentication()       - Complexity: 2  ✅
  ├─ validateResponse()        - Complexity: 1  ✅
  └─ handleStatusCode()        - Complexity: 6  ✅

✓ PhotoUpload.uploadToImageKit() - Complexity: 4  ✅
  ├─ buildMultipartBody()      - Complexity: 3  ✅
  ├─ appendFormFields()        - Complexity: 1  ✅
  ├─ createImageKitRequest()   - Complexity: 1  ✅
  ├─ validateResponse()        - Complexity: 4  ✅
  └─ parseImageKitResponse()   - Complexity: 5  ✅
```

---

## ⚠️ Risks & Considerations

### Low Risk ✅
- Functions are `private` - no API changes
- Same inputs/outputs
- Can be done incrementally
- Easy to revert if issues

### Testing Strategy
1. Run existing app - verify login works
2. Upload photo - verify ImageKit upload
3. Fetch locations - verify API calls
4. Run SwiftLint - verify complexity reduced

### Rollback Plan
- Git commit before changes
- Keep old code commented out
- Test thoroughly before deleting

---

## 📊 Success Metrics

| Metric | Before | After | Status |
|--------|--------|-------|--------|
| Total Errors | 2 | 0 | 🎯 |
| Max Complexity | 21 | 6 | ✅ |
| Functions >50 lines | 2 | 0 | ✅ |
| Code Reusability | Low | High | ✅ |
| Test Coverage | Hard | Easy | ✅ |

---

## 🚀 Timeline Estimate

| Phase | Task | Time | Difficulty |
|-------|------|------|------------|
| **Phase 1** | APIClient Refactor | 15 min | Medium |
| | Create helpers | 5 min | Easy |
| | Refactor main function | 7 min | Medium |
| | Test & verify | 3 min | Easy |
| **Phase 2** | PhotoUpload Refactor | 20 min | Medium |
| | Create helpers | 8 min | Medium |
| | Refactor main function | 8 min | Medium |
| | Test & verify | 4 min | Easy |
| **Total** | | **35 min** | |

---

## 🤔 Review Questions

Before implementing, please confirm:

1. ✅ **Approach**: Does the helper function breakdown make sense?
2. ✅ **Naming**: Are the function names clear and descriptive?
3. ✅ **Scope**: Should we tackle both files or one at a time?
4. ✅ **Testing**: Want to test after each phase or at the end?
5. ⚠️ **Alternative**: Should we disable the complexity rule instead? (Not recommended)

---

## 💡 Alternative Approaches

### Option A: Full Refactor (Recommended) ⭐
- Break into small, focused functions
- **Pros**: Clean, testable, maintainable
- **Cons**: Takes 35 minutes

### Option B: Partial Refactor
- Only extract the worst complexity branches
- **Pros**: Faster (20 minutes)
- **Cons**: Still has some complexity

### Option C: Disable Rule (Not Recommended)
- Add to `.swiftlint.yml`: `disable cyclomatic_complexity`
- **Pros**: Instant fix
- **Cons**: Technical debt accumulates

---

**Recommendation**: Proceed with **Option A** - Full Refactor

The code will be cleaner, more testable, and easier to maintain. Since both functions are private, there's zero risk of breaking external APIs.

---

**Ready to implement?** Please review and let me know if you want to:
1. ✅ Proceed with this plan as-is
2. 🔄 Adjust the breakdown (different helper functions)
3. 🎯 Focus on one file first (APIClient or PhotoUpload)
4. ❓ Ask questions about specific parts

**Next step**: I'll implement Phase 1 (APIClient) first, test it, then move to Phase 2 (PhotoUpload).
