## Plan: Fotolokashen iOS Comprehensive Review & Photo Upload Pipeline

The iOS app (v1.4.1) is architecturally sound — MVVM + shared store, OAuth2 PKCE, secure server-mediated photo pipeline, strong style guide compliance (9/10). The main gaps are: no Photo Library picker, large views needing decomposition, ~30% test coverage, weak accessibility, and a few business logic holes.

---

### Part 1: Architecture Scorecard

| Category          | Score    | Notes                                                          |
| ----------------- | -------- | -------------------------------------------------------------- |
| Security          | **9/10** | PKCE, Keychain, ClamAV, `#if DEBUG`, 401 auto-logout           |
| Style Compliance  | **9/10** | Semantic colors, AppIcons, Dynamic Type, standard spacing      |
| Service Layer     | **8/10** | Clean singletons, async/await, dual geocoding                  |
| Data Models       | **8/10** | Strong Codable, CodingKeys, lat/lng dual-format handling       |
| State Management  | **7/10** | Proper patterns used but too many `@State` vars in large views |
| View Architecture | **6/10** | 5 views over 500 lines each; needs decomposition               |
| Test Coverage     | **4/10** | 27 tests (~30%), no integration or UI tests                    |
| Accessibility     | **3/10** | Major VoiceOver gaps, photo carousels not navigable            |
| Photo Handling    | **7/10** | Secure pipeline, but camera-only (no Photo Library)            |

**What works well:**

- OAuth2 PKCE flow via `ASWebAuthenticationSession` — textbook implementation
- `PhotoUploadService` → server-mediated uploads with virus scanning
- `LocationStore.shared` as central cache with proper `@MainActor` isolation
- `AppColors.swift` and `AppIcons.swift` centralized semantic tokens
- Social features (follow, search, friends' locations) are complete
- `ImageCompressor` with iterative quality reduction algorithm

---

### Part 2: File-by-File Issues (Comments to Add)

**Services & Utilities — business logic gaps:**

1. `fotolokashenApp.swift` — `print("[App] Scene became active...")` missing `#if DEBUG` guard
2. `LocationService.swift` — `createLocation()` doesn't support caption, tags, or UserSave fields at creation; 40+ print statements need consistency audit
3. `PhotoUploadService.swift` — `uploadSecurely()` has inconsistent response handling (tries wrapped then direct format); no EXIF metadata extraction from UIImage
4. `SyncService.swift` — `setupNetworkObserver()` posts to `Notification.Name("NetworkConnected")` but nothing subscribes to it (dead code)
5. `DeepLinkManager.swift` — doesn't handle `/{username}/locations/{id}` Universal Link format (only handles `/shared/{id}`)
6. `ConfigLoader.swift` — `fatalError()` on missing Config.plist is too aggressive for production
7. `DataManager.swift` — `fatalError()` on SwiftData init failure; no graceful degradation
8. `APIClient.swift` — Status 400 tries to decode `ErrorResponse` but silently falls back to `.unknownError`

**Views — missing features & code quality:**

9. `CreateLocationView.swift` — Missing: caption field, tags, personalRating, isFavorite, Photo Library picker option, multi-photo support
10. `CameraView.swift` — Missing: flash control toggle, front/back camera switch, "Open Library" button, multi-photo capture session
11. `LocationDetailView.swift` — 750 lines; owner-mode sections and read-only sections should be extracted into subview files
12. `PeopleSearchView.swift` — `SearchUserRow` and `UserRowView` are duplicate components; 3 tab contents should be separate files
13. `MapView.swift` — NYC hardcoded as default camera position; `LocationClusterItem` classes may be unused (direct markers used instead of `GMUClusterManager`)
14. `EditLocationView.swift` — 15+ `@State` vars should be grouped into an `EditLocationViewModel`
15. `ProfileView.swift` — 20+ `@State` vars; social stats loaded in multiple places redundantly

**Models:**

16. `Photo.swift` — Missing EXIF fields (cameraMake, cameraModel, iso, focalLength, aperture, shutterSpeed) that web captures and stores
17. `CachedLocation.swift` — Doesn't cache UserSave fields (tags, isFavorite, color) so offline mode loses per-user data

---

### Part 3: Photo Upload UI Pipeline (Reusable, Separate Plan)

**Goal:** Reusable photo selection + upload pipeline supporting both Photo Library and Camera, extractable for other apps.

**New Files:**

- `Views/PhotoPicker/PhotoPickerView.swift` — wraps `PHPickerViewController` (multi-select)
- `Views/PhotoPicker/PhotoGridView.swift` — selected photos grid with add/remove
- `Views/PhotoPicker/PhotoPickerViewModel.swift` — manages selection, EXIF extraction, compression
- `swift-utilities/EXIFExtractor.swift` — `ImageIO`-based EXIF extraction from `PHAsset`/`UIImage`
- `swift-utilities/PhotoPipelineModels.swift` — `PipelinePhoto`, `EXIFMetadata`, `PhotoSource` enum

**Modified Files:**

- `CreateLocationView.swift` — replace single camera-photo preview with `PhotoGridView` + multi-photo
- `CameraView.swift` — add "Library" button
- `PhotoUploadService.swift` — accept `EXIFMetadata` in upload calls
- `Photo.swift` — add EXIF fields

**Steps:**

**Phase 1: EXIF Foundation** (_no UI changes_)

1. Create `EXIFExtractor.swift` — extract EXIF via `CGImageSource` (ImageIO framework): GPS, camera make/model, ISO, focal length, aperture, shutter speed
2. Create `PhotoPipelineModels.swift` — `PipelinePhoto` struct (preview UIImage + compressed Data + EXIFMetadata + PhotoSource), `EXIFMetadata` struct, `PhotoSource` enum (`.camera`, `.library`)
3. Update `Photo.swift` — add optional EXIF fields matching web schema
4. Update `PhotoUploadService.uploadSecurely()` — accept `EXIFMetadata` parameter, include in upload metadata JSON

**Phase 2: Picker UI** (_parallel with Phase 1 after models defined_) 5. Create `PhotoPickerView.swift` — `PHPickerViewController` wrapper, multi-select (max 20 per `PHOTO_LIMITS`), returns `[PHPickerResult]` 6. Create `PhotoGridView.swift` — 3-column grid of selected photos, tap to remove, "+" button to add more, EXIF badge overlay 7. Create `PhotoPickerViewModel.swift` — `@MainActor ObservableObject`, manages `[PipelinePhoto]`, coordinates background EXIF extraction + compression

**Phase 3: Integration** (_depends on Phase 1 + 2_) 8. Modify `CreateLocationView.swift` — replace single photo preview with `PhotoGridView`; add "Add from Library" and "Take Photo" entry points; add caption field; optionally add tags/favorite fields 9. Add "Library" button to `CameraView.swift` — opens `PhotoPickerView` as sheet 10. Update `LocationService.createLocation()` — support multiple photos with EXIF metadata 11. Wire up GPS source: use photo EXIF GPS when available (like web does), fall back to device GPS

**Phase 4: Testing** (_depends on Phase 3_) 12. Unit tests for `EXIFExtractor` — JPEG with GPS, HEIC without GPS, corrupt image 13. Unit tests for `PhotoPickerViewModel` — add, remove, compress, extract 14. Manual test: Camera capture → create location → verify EXIF on web 15. Manual test: Photo Library → select 5 → create location → verify all uploaded with EXIF

**Reusability:** Phases 1-2 produce a self-contained module (`PhotoPicker/` + `EXIFExtractor` + `PhotoPipelineModels`). Only Phase 3 is fotolokashen-specific. Any new app can import the module and wire its own upload service.

---

### Part 4: Suggestions to Strengthen the App

**Quick Wins (< 1 day each):**

1. Consolidate `formatDate` into a shared `Date` extension — duplicated across multiple views
2. Merge `SearchUserRow` + `UserRowView` into one reusable component
3. Fix `DeepLinkManager` — add `/{username}/locations/{id}` Universal Link pattern
4. Remove orphaned `SyncService.setupNetworkObserver()` dead code
5. Add `#if DEBUG` to `fotolokashenApp.swift` print statement

**Medium Effort (1-3 days):** 6. Decompose 5 large views (>500 lines each) into subview files 7. Create `ProfileViewModel` and `EditLocationViewModel` to reduce `@State` proliferation 8. Add exponential backoff retry to `APIClient` for transient failures 9. Add local input validation before API calls (required fields, string lengths) 10. Replace `fatalError()` in `ConfigLoader`/`DataManager` with graceful error handling

**Larger Efforts (3-7 days):** 11. **Photo Library Pipeline** (Part 3 above) 12. Test coverage to 60%+ — mock `APIClient`, test all services, add basic UI tests 13. Accessibility pass — VoiceOver labels on photo carousels, form grouping, map markers 14. Complete offline mode — queue location creation (not just photos), sync conflict resolution

---

### Verification

1. Grep for `// REVIEW:` in all annotated files to confirm review comments placed
2. Build + run on simulator: Camera capture + Photo Library → create location → verify photos in `LocationDetailView`
3. EXIF verification: Create location from Library photo with GPS → check web for EXIF metadata
4. SwiftLint: `swiftlint lint` — zero warnings on new code
5. Test suite: `⌘U` — existing 27 tests pass + new `EXIFExtractor`/`PhotoPickerViewModel` tests pass
6. Regression: Existing camera-only flow still works after Photo Library addition

### Decisions

- Review comments use `// REVIEW:` prefix to distinguish from existing `// TODO:` markers
- Photo Pipeline designed as extractable module for reuse in other apps
- No backend API changes needed — iOS uses existing `/api/photos/upload` and `/api/locations/{id}/photos`
- View decomposition can happen in parallel with Photo Pipeline work
- Projects & LocationContacts remain web-only (not planned for iOS)
- Accessibility improvements are a separate work item, not blocking Photo Pipeline

### Scope Exclusions

- Video recording (photo-only for v1)
- Admin-only location types on iOS (gated by role, not implemented)
- AI features (description improvement, tag suggestions) — backend exists, iOS integration deferred
- Onboarding tours (React Joyride equivalent) — deferred to Phase 4 roadmap
