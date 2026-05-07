## Fotolokashen iOS — Photo Upload Pipeline
### Updated: May 5, 2026 May 5 12:33pm EST

> **Purpose:** Document the current state of the two location-creation paths
> (Camera and Photo Library), diagnose known bugs and performance issues, and
> serve as a reusable template for photo upload pipelines in other apps.

---

### 1. Architecture Scorecard (Updated)

Since the original pipeline.md (v1.4.1), the following Phase 2a work has landed:

| Category          | Before | Now      | What changed                                                          |
| ----------------- | ------ | -------- | --------------------------------------------------------------------- |
| View Architecture | 6/10   | **7/10** | `CreateLocationView` extracted to VM; `CameraView` HUD decomposed     |
| Photo Handling    | 7/10   | **8/10** | Multi-photo camera sessions, Photo Library picker, EXIF extraction    |
| State Management  | 7/10   | **8/10** | `CreateLocationViewModel`, `CameraSessionViewModel`, `PhotoPickerVM`  |
| Service Layer     | 8/10   | **9/10** | New pipeline services: Selection, Compression, UploadQueue, Coordinator |

**What shipped since v1.4.1:**

- ✅ Multi-photo camera sessions with disk-backed captures (`CameraSessionViewModel`)
- ✅ Photo Library picker via `PHPickerViewController` (`PhotoPickerView`)
- ✅ EXIF extraction from raw `Data` and `UIImage` (`EXIFExtractor`)
- ✅ GPS spread analysis with info banner (`GPSSpreadAnalyzer`)
- ✅ Photo grid UI with per-photo stage overlays (`PhotoGridView`)
- ✅ New pipeline layer: `PhotoPipelineCoordinator` → `PhotoSelectionService` → `PhotoCompressionService` → `PhotoUploadQueue`
- ✅ Feature-flagged dual pipeline: legacy `PhotoPickerViewModel` vs new `PhotoPipelineCoordinator` via `useNewPhotoPipeline`
- ✅ Skip-recompression path for queue uploads (`uploadCompressedPhoto`)
- ✅ Session capture temp-file cleanup
- ✅ Camera HUD components extracted to `CameraHUDComponents.swift`

---

### 2. File Inventory

#### Views (UI Layer)

| File | Role |
|------|------|
| `Views/CameraView.swift` | Full-screen camera with zoom, focus, exposure, GPS badge, multi-capture, library button |
| `Views/Camera/CameraHUDComponents.swift` | Extracted HUD: focus square, exposure slider, zoom dial, GPS badge, thumbnail strip |
| `Views/CreateLocationView.swift` | Form: photos section + location info + production date + GPS + save button |
| `Views/PhotoPickerView.swift` | `PHPickerViewController` wrapper — multi-select, returns `[PipelinePhoto]` |
| `Views/PhotoGridView.swift` | Horizontal scroll strip of thumbnails with stage overlays + add/remove |
| `Views/PhotoSpreadMapView.swift` | Map showing photo GPS distribution (used in LocationDetailView) |
| `Views/CameraPreview.swift` | `AVCaptureVideoPreviewLayer` SwiftUI wrapper |

#### Services — Photo Pipeline (New, Phase 1b)

| File | Role |
|------|------|
| `Services/PhotoPipeline/PhotoPipelineCoordinator.swift` | Owns `[PipelinePhoto]`, orchestrates selection → compression → upload |
| `Services/PhotoPipeline/PhotoSelectionService.swift` | Turns raw inputs (camera, library, session) into `PipelinePhoto` with EXIF |
| `Services/PhotoPipeline/PhotoCompressionService.swift` | Actor-isolated JPEG compression with concurrent batch support |
| `Services/PhotoPipeline/PhotoUploadQueue.swift` | Bounded-concurrency upload actor with retry, cancellation, `AsyncStream` events |
| `Services/PhotoPipeline/PhotoPipelineProviding.swift` | Protocol shared by legacy VM and new coordinator |

#### Services — Photo (Legacy + Shared)

| File | Role |
|------|------|
| `Services/Photo/PhotoUploadService.swift` | HTTP multipart upload to `/api/photos/upload` + associate to location |
| `Services/Photo/ImageCompressor.swift` | Iterative JPEG quality reduction to target size |
| `Services/Photo/EXIFExtractor.swift` | `ImageIO`-based EXIF extraction (GPS, camera, exposure, lens, date) |
| `Services/Photo/PhotoPipelineModels.swift` | `PipelinePhoto`, `PipelineStage`, `EXIFMetadata`, `PhotoSource` |
| `Services/Photo/SessionCapture.swift` | Disk-backed capture struct with `toPipelinePhoto()` conversion |
| `Services/Photo/GPSSpreadAnalyzer.swift` | Haversine distance spread analysis across photo GPS coordinates |

#### Services — Camera

| File | Role |
|------|------|
| `Services/Camera/CameraService.swift` | `AVCaptureSession` management, zoom, focus, exposure, photo capture |
| `Services/Camera/CameraSessionViewModel.swift` | Multi-photo session state: disk write, thumbnail gen, capture list |

#### Services — Create Location

| File | Role |
|------|------|
| `Services/CreateLocation/CreateLocationViewModel.swift` | Form state, validation, sanitization, geocoding, save + upload orchestration |

---

### 3. Path A — Camera → Form → Save

#### 3.1 End-to-End Flow

```
User taps "Capture" tab
    │
    ▼
ContentView.LoggedInView
    │ selectedTab == 2 → showingCamera = true
    │ (bounces tab back to previous)
    ▼
┌─ CameraView (fullScreenCover) ──────────────────────────────────────┐
│                                                                      │
│  CameraService: AVCaptureSession → photo capture → .capturedImage    │
│  LocationManager: tracks device GPS                                  │
│  CameraSessionViewModel: disk write → thumbnail → [SessionCapture]   │
│                                                                      │
│  User can:                                                           │
│    • Tap shutter → captures photo to temp JPEG on disk               │
│    • View thumbnail strip of captures                                │
│    • Remove individual captures                                      │
│    • Tap "Done (N)" → finishSession()                                │
│    • Tap Library button → opens PhotoPickerView as sheet             │
│                                                                      │
│  On "Done": onSessionComplete([SessionCapture]) → dismiss            │
│  On Library pick: onLibraryPhotosPicked([PipelinePhoto]) →           │
│     pendingLibraryPhotos → dismiss (hands off to Library path)       │
└──────────────────────────────────────────────────────────────────────┘
    │
    ▼ (fullScreenCover onDismiss)
ContentView: sessionCaptures != nil → present sheet
    │
    ▼
┌─ CreateLocationView (sheet) ────────────────────────────────────────┐
│                                                                      │
│  init(sessionCaptures:, photoLocation: firstCapture.location)        │
│  @StateObject photoViewModel = PhotoPickerViewModel()                │
│  @StateObject viewModel = CreateLocationViewModel(photoLocation:)    │
│                                                                      │
│  .task {                                                             │
│      1. sessionCaptures → .toPipelinePhoto() → photoVM.addPhotos()   │
│      2. EXIF extracted per photo, GPS supplemented from device       │
│      3. Compression runs in background                               │
│      4. GPS spread analyzed                                          │
│      5. Reverse geocoding runs for address display                   │
│  }                                                                   │
│                                                                      │
│  Sections: [PhotoGrid] [Location Info] [Production Date] [GPS] [Save]│
│  User fills Name + Details (required), picks Type, optional date     │
│                                                                      │
│  "Create Location" tap → viewModel.save(using: photoViewModel)       │
│    1. Sanitize name + details (strip URLs, normalize whitespace)      │
│    2. POST /api/locations with first photo → server returns Location  │
│    3. Upload remaining photos (2..N) sequentially via                 │
│       PhotoUploadService.uploadPhoto()                               │
│    4. Associate each with location via POST                          │
│       /api/locations/{id}/photos                                     │
│    5. Show success alert → dismiss → addLocation to store            │
│    6. CameraView.cleanupTempFiles()                                  │
└──────────────────────────────────────────────────────────────────────┘
```

#### 3.2 Camera Path — What Works

- Multi-photo capture with disk-backed storage (memory stays flat)
- Capture flash animation feedback
- Thumbnail strip with remove capability
- GPS badge showing lock status
- Zoom dial + pinch-to-zoom + tap-to-focus + exposure slider
- EXIF extracted from camera captures with Apple device fallback
- Session capture count badge on shutter button
- Capture button disabled during disk write

#### 3.3 Camera Path — Known Bugs & Issues

| # | Issue | Root Cause | Severity |
|---|-------|-----------|----------|
| C1 | **Slight delay between capture and thumbnail appearing** | `handleCapturedPhoto` writes JPEG to disk then renders a 150×150 thumbnail synchronously on a detached task. The `isWritingToDisk` flag correctly disables the shutter, but the user sees a ~200-400ms gap with no feedback beyond the capture flash. | Low |
| C2 | **EXIF from camera captures is mostly empty** | `CameraService` delivers a `UIImage` (not raw photo data). `EXIFExtractor.extract(from: UIImage)` converts to JPEG first, which strips most EXIF. `SessionCapture.toPipelinePhoto()` then supplements with device GPS and Apple device info, but camera-specific EXIF (ISO, shutter, aperture, lens) is lost. | Medium |
| C3 | **No front/back camera toggle** | `CameraService.setupSession()` defaults to back camera. No UI to switch. Pipeline.md v1 flagged this; still missing. | Low |
| C4 | **No flash control** | `CameraService` doesn't expose flash mode. Pipeline.md v1 flagged this; still missing. | Low |
| C5 | **Library button in CameraView opens picker but dismisses camera first** | When user picks photos from the Library button *inside* CameraView, `onLibraryPhotosPicked` fires → sets `pendingLibraryPhotos` → sets `showingCamera = false`. The camera dismisses, then `onDismiss` transfers to `libraryPhotos`, which opens CreateLocationView. This works but the UX feels like the camera "crashed" — abrupt dismissal. | Medium |

---

### 4. Path B — Photo Library → Form → Save

#### 4.1 End-to-End Flow

```
User taps "Capture" tab → CameraView opens
    │
    ▼
User taps Library button (bottom-left of camera HUD)
    │
    ▼
┌─ PhotoPickerView (sheet over CameraView) ───────────────────────────┐
│                                                                      │
│  PHPickerViewController (multi-select, images only)                  │
│  config.preferredAssetRepresentationMode = .current (preserve EXIF)  │
│  selectionLimit = 20                                                 │
│                                                                      │
│  For each result:                                                    │
│    1. Try loadDataRepresentation for JPEG/HEIC/PNG/TIFF/generic      │
│    2. Extract EXIF from raw Data (preserves GPS, camera info)        │
│    3. If JPEG: also run ImageCompressor.compress() inline            │
│    4. Fallback: loadObject(ofClass: UIImage) — EXIF may be lost      │
│    5. Build PipelinePhoto(source: .library, image:, exif:)           │
│                                                                      │
│  onPhotosPicked([PipelinePhoto]) → callback to CameraView            │
└──────────────────────────────────────────────────────────────────────┘
    │
    ▼
CameraView.onLibraryPhotosPicked
    │ pendingLibraryPhotos = photos
    │ showingCamera = false
    ▼
ContentView fullScreenCover onDismiss
    │ libraryPhotos = pendingLibraryPhotos
    ▼
┌─ CreateLocationView (sheet) ────────────────────────────────────────┐
│                                                                      │
│  init(libraryPhotos:, photoLocation: first GPS from photos)          │
│                                                                      │
│  .task {                                                             │
│      1. libraryPhotos → photoVM.addPhotos()                          │
│      2. Compress any that aren't already compressed                  │
│      3. GPS spread analysis                                          │
│      4. Reverse geocoding                                            │
│  }                                                                   │
│                                                                      │
│  Same form as Camera path from here.                                 │
│  Save flow identical: create location → upload photos sequentially.  │
└──────────────────────────────────────────────────────────────────────┘
```

#### 4.2 Library Path — Known Bugs & Performance Issues

| # | Issue | Root Cause | Severity | Fix |
|---|-------|-----------|----------|-----|
| L1 | **Photo loading is slow — noticeable hang after picking** | `PhotoPickerView.Coordinator` loads each photo *sequentially* in a `for result in results` loop. Each call to `loadDataRepresentation` is an async I/O operation that may trigger iCloud download or HEIC→JPEG transcoding. For 5-10 photos, this can take 3-8 seconds with no progress indicator. The CameraView is still showing during this time, then abruptly dismisses. | **High** | Load photos concurrently with `TaskGroup`. Show a loading HUD on the picker/camera. |
| L2 | **Double compression for JPEG library photos** | `PhotoPickerView.loadData()` calls `ImageCompressor.compress(image)` inline for JPEGs at pick time. Then `PhotoPickerViewModel.addPhotos()` → `compressUncompressedPhotos()` checks `compressedData == nil` and skips — but only if the first compression succeeded. If the inline compression produced data, the photo arrives pre-compressed. However, if the image is large, the inline compression blocks the picker's Task, adding to the perceived slowness in L1. | Medium | Remove inline compression from `PhotoPickerView`. Let `PhotoPickerViewModel` handle all compression uniformly after add. |
| L3 | **Photos sometimes don't appear in the form** | Race condition: `pendingLibraryPhotos` is set and `showingCamera = false` fires, but the `fullScreenCover(onDismiss:)` callback may execute before `pendingLibraryPhotos` is fully populated if the `Task` in `PhotoPickerView.Coordinator.picker(didFinishPicking:)` is still running. The photos array arrives empty, `CreateLocationView` opens with no photos, and `canSave` is false. | **High** | The callback should only fire after all photos are loaded. Ensure the `onPhotosPicked` closure is called *after* the async loading completes (it currently is — but the `showingCamera = false` fires from within the library picker's dismiss, before `onPhotosPicked`). See fix below. |
| L4 | **GPS may be nil for library photos** | `PHPickerViewController` with `.current` representation mode returns raw image data, but HEIC photos from iCloud may arrive without GPS in the data representation. The `loadAsUIImage` fallback path calls `EXIFExtractor.extract(from: UIImage)` which round-trips through JPEG and loses GPS entirely. | Medium | For critical GPS needs, consider requesting `PHAsset` access (requires `PHPhotoLibrary` authorization) to read GPS from asset metadata directly. |
| L5 | **"Using first photo's location" spread banner shows briefly then disappears** | `analyzeSpread` runs in `.task` before `addPhotos` has finished populating `photoViewModel.photos`. When called with an empty or partial array, the spread result is nil or under threshold. | Low | Move `analyzeSpread` to run *after* `addPhotos` completes. |

#### 4.3 The L3 Race Condition — Deep Dive

The sequence that causes "photos don't show up":

```
1. User picks 5 photos in PHPicker
2. PHPicker calls picker(didFinishPicking:) → picker.dismiss(animated: true)
3. Coordinator starts Task { for result in results { await loadPhoto() } }
4. PHPicker sheet dismisses → CameraView is visible again
5. onLibraryPhotosPicked fires (but photos haven't finished loading yet)
   → In the current code, onPhotosPicked is called INSIDE the Task after
     the loop completes, so this timing should be correct...
6. BUT: the CameraView sheet's showLibraryPicker toggling and the dismiss
   animation can cause SwiftUI to evaluate bindings before the @State
   update propagates.
```

Looking at the actual code: the `picker.dismiss(animated: true)` on line 43 of `PhotoPickerView` happens *before* the `Task` that loads photos. The photos are loaded asynchronously after the picker UI is already dismissed. The callback `onPhotosPicked` correctly fires on `MainActor.run` after all photos load. So the issue is actually:

**The user sees the camera again (picker dismissed) → then `onPhotosPicked` fires → `pendingLibraryPhotos` set → `showingCamera = false` → camera dismisses → `onDismiss` → `libraryPhotos` set → CreateLocationView opens.** This chain works, but:

- If the user taps "Done" on the camera during the async photo loading (before `onPhotosPicked` fires), `sessionCaptures` gets set, and the session-capture sheet opens instead.
- If the photo loading takes a long time (L1), the user may interact with the camera thinking the pick failed.

**Real fix:** Don't dismiss the picker until photos are loaded. Show a loading indicator inside the picker sheet while loading is in progress.

---

### 5. Save Pipeline (Shared by Both Paths)

```
CreateLocationViewModel.save(using: photoViewModel)
    │
    ├─ 1. Sanitize inputs (strip URLs, normalize whitespace, enforce char limits)
    ├─ 2. Get first photo's UIImage
    ├─ 3. Build GeocodedAddress (from reverse geocoding or coordinate fallback)
    │
    ├─ 4. LocationService.createLocation()
    │      POST /api/locations
    │      Body: { name, type, lat, lng, geocodedAddress, photo (multipart), details, productionDate }
    │      Response: Location { id, name, ... }
    │
    ├─ 5. If photos.count > 1:
    │      uploadRemainingPhotos() — sequential loop:
    │        for each photo (index 1..N):
    │          PhotoUploadService.uploadPhoto(image:, locationId:, location:, caption:, exif:)
    │            ├─ ImageCompressor.compress(image) → JPEG Data
    │            ├─ buildUploadMetadata(location:, exif:) → metadata JSON
    │            ├─ uploadSecurely(data:, filename:, uploadType:, metadata:)
    │            │     POST /api/photos/upload (multipart: photo + uploadType + metadata)
    │            │     Server: virus scan → format validation → compression → CDN
    │            │     Response: SecureUploadResponse { fileId, url, filePath, thumbnailUrl, width, height }
    │            ├─ POST /api/locations/{id}/photos (AssociatePhotoRequest)
    │            │     Response: Photo model
    │            └─ Update uploadProgress
    │
    ├─ 6. Set createdLocation, showingSuccess = true
    └─ 7. On dismiss: locationStore.addLocation(), cleanupTempFiles()
```

### 5.1 Upload Pipeline Variants

The app has two pipeline implementations behind the `useNewPhotoPipeline` feature flag:

| | Legacy (`PhotoPickerViewModel`) | New (`PhotoPipelineCoordinator`) |
|---|---|---|
| Compression | `ImageCompressor.compress()` via detached Task | `PhotoCompressionService` actor with batch support |
| Upload | Sequential loop in `uploadAllPhotos()` | `PhotoUploadQueue` actor, 2 concurrent, auto-retry |
| Progress | Aggregate `uploadProgress` only | Per-photo `PipelineStage` state machine |
| Retry | None — failure skips photo | Automatic retry (2 attempts, exponential backoff) + manual retry |
| Cancellation | Not supported | Per-job and bulk cancel |
| Skip recompress | No — re-compresses at upload time | Yes — `uploadCompressedPhoto` sends pre-compressed bytes |

The new pipeline is **not yet the default** (`useNewPhotoPipeline = false` in Config.plist).

---

### 6. Diagnosed Issues — Priority Fix Order

#### Phase A: Fix Library Path (User-Reported Bugs)

These are the issues that make the Library path feel "slow and buggy":

**A1. Concurrent photo loading (fixes L1)**
- Change `PhotoPickerView.Coordinator` from sequential `for` loop to `TaskGroup`
- Add a loading overlay on the picker while photos load
- Expected improvement: 5-10 photos in ~1-2s instead of 3-8s

**A2. Remove inline compression from picker (fixes L2)**
- Delete the `ImageCompressor.compress(image)` call on line 123 of `PhotoPickerView.swift`
- Let `PhotoPickerViewModel.compressUncompressedPhotos()` handle compression uniformly
- Eliminates redundant work and reduces picker-dismiss latency

**A3. Fix photo delivery timing (fixes L3)**
- Keep the `PhotoPickerView` sheet visible until all photos are loaded
- Add a `@State var isLoading = false` to `PhotoPickerView`
- Show a `ProgressView` overlay while loading
- Only call `onPhotosPicked` after all photos are ready, then dismiss the sheet

**A4. Move spread analysis after photo population (fixes L5)**
- In `CreateLocationView.task`, call `viewModel.analyzeSpread(photos:)` *after*
  confirming `photoViewModel.photos` is populated

#### Phase B: Improve Camera Path

**B1. Capture raw photo data for EXIF (fixes C2)**
- Modify `CameraService.capturePhoto()` to return `Data` (via `AVCapturePhoto.fileDataRepresentation()`) instead of `UIImage`
- Store raw JPEG data in `SessionCapture` and extract EXIF from it
- This gives full camera EXIF (ISO, shutter speed, aperture, lens) on camera captures

**B2. Smooth Library-from-Camera transition (fixes C5)**
- Instead of dismissing the camera and re-presenting CreateLocationView:
  Option A: Present CreateLocationView as a sheet *over* the camera (don't dismiss camera)
  Option B: Add a transition animation / loading state so the camera doesn't appear to crash

**B3. Add front/back camera toggle (fixes C3)**
- Add a flip-camera button to `CameraView` HUD
- Wire to `CameraService.switchCamera()`

**B4. Add flash control (fixes C4)**
- Add a flash mode button (auto/on/off) to `CameraView` HUD
- Wire to `CameraService.setFlashMode()`

#### Phase C: Pipeline Improvements

**C1. Enable new pipeline as default**
- Set `useNewPhotoPipeline = true` in Config.plist
- Test concurrent uploads, retry logic, per-photo stage display
- The new pipeline is fully implemented but not battle-tested

**C2. Add caption + tags at create time**
- `CreateLocationRequest` and POST `/api/locations` need schema update
- Or implement as CREATE → PATCH chain client-side

---

### 7. Reusable Photo Upload Template

> **This section is app-agnostic.** Extract these components to reuse the photo
> upload pipeline in any iOS app.

#### 7.1 Portable Components (No App-Specific Dependencies)

| Component | What it does | Dependencies |
|-----------|-------------|-------------|
| `PhotoPipelineModels.swift` | `PipelinePhoto`, `PipelineStage`, `EXIFMetadata`, `PhotoSource` | Foundation, UIKit |
| `EXIFExtractor.swift` | `ImageIO`-based EXIF from Data or UIImage | ImageIO, CoreLocation |
| `PhotoPickerView.swift` | PHPicker wrapper returning `[PipelinePhoto]` | PhotosUI, above models |
| `PhotoGridView.swift` | Thumbnail strip with stage overlays | SwiftUI, above models |
| `PhotoCompressionService.swift` | Actor-isolated JPEG compression | Foundation, UIKit |
| `PhotoUploadQueue.swift` | Bounded-concurrency upload with retry | Foundation |
| `PhotoSelectionService.swift` | Turn raw inputs → PipelinePhoto | Foundation, UIKit, CoreLocation |
| `PhotoPipelineCoordinator.swift` | Orchestrates selection → compress → upload | All of the above |
| `PhotoPipelineProviding.swift` | Protocol for swappable implementations | Foundation |
| `ImageCompressor.swift` | Iterative JPEG quality reduction | UIKit |
| `SessionCapture.swift` | Disk-backed camera capture model | Foundation, UIKit, CoreLocation |
| `GPSSpreadAnalyzer.swift` | Haversine GPS spread detection | CoreLocation |

#### 7.2 App-Specific Wiring (Must Replace Per-App)

| Component | What to replace |
|-----------|----------------|
| Upload endpoint URL | `/api/photos/upload` → your endpoint |
| Auth token source | `KeychainService.shared.getAccessToken()` → your auth |
| Associate-to-entity endpoint | `/api/locations/{id}/photos` → your entity association |
| Config source | `ConfigLoader.shared` → your config |
| Error presenter | `ErrorPresenter.shared` → your error UI |
| Max photos limit | `ConfigLoader.shared.maxPhotosPerLocation` → your limit |

#### 7.3 Integration Pattern

```swift
// 1. Create your upload service conforming to PhotoUploadServicing
class MyUploadService: PhotoUploadServicing {
    func uploadCompressedPhoto(data:, filename:, locationId:, ...) async throws -> Photo {
        // POST to your endpoint
    }
}

// 2. Wire the coordinator in your view
@StateObject private var pipeline = PhotoPipelineCoordinator(
    maxPhotos: 20,
    uploadQueue: PhotoUploadQueue(uploader: MyUploadService())
)

// 3. Use PhotoGridView for display
PhotoGridView(
    photos: pipeline.photos,
    maxPhotos: pipeline.maxPhotos,
    onAddTapped: { pipeline.showPicker = true },
    onRemovePhoto: { id in pipeline.removePhoto(id: id) },
    onRetryPhoto: { id in Task { await pipeline.retryFailed(id: id) } }
)

// 4. Upload
await pipeline.uploadAllPhotos(locationId: entityId, location: gpsLocation)
```

#### 7.4 What Photo-Fixer Adds (Beyond This Template)

The `PHOTO_UPLOAD_ARCHITECTURE.md` from Photo-Fixer adds several layers that
fotolokashen does not need but a professional photo pipeline app would:

| Feature | fotolokashen | Photo-Fixer |
|---------|-------------|-------------|
| Auth | OAuth2 PKCE via web | Supabase email auth |
| Metadata editing | EXIF read-only display | Full IPTC/editorial editor |
| RAW format support | JPEG/HEIC only | CR2, CR3, ARW, NEF, DNG, etc. |
| Server processing | CDN upload + virus scan | exiftool XMP sidecars + embedded IPTC |
| End destination | ImageKit CDN | Adobe Lightroom |
| Project grouping | Location-based | Named projects with draft TTL |
| Delivery notifications | None | Email + SMS (Twilio) + Slack |
| Storage | CDN-managed | Adapter pattern (local/S3/R2/MinIO) |

The portable pipeline components (§7.1) work as the foundation for both apps.
Photo-Fixer adds `PhotoFormatResolver`, `PhotoSidecar`, metadata editor UI,
and server-side exiftool integration on top.

---

### 8. Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Pipeline document scope | Capture flow walkthrough + bug diagnosis | User reported Library path is slow/buggy; need accurate diagnosis |
| Fix priority | Library path first (Phase A) | Highest user-facing impact; Camera path is "ok but a little buggy" |
| New pipeline activation | Deferred to Phase C | Needs real-device testing before becoming default |
| Template extraction | Documented but not physically separated | Keep in same Xcode project until second app needs it |
| GPS from library photos | EXIF extraction from raw Data | PHPicker `.current` mode preserves EXIF; no `PHPhotoLibrary` auth needed |
| Save-then-upload | Sequential (legacy) or fire-and-forget (new) | Legacy blocks on all uploads; new pipeline allows dismiss after enqueue |
| Photo-Fixer reference | Informational only | No auth, Lightroom, or exiftool integration needed for fotolokashen |

### 9. Scope Exclusions

- Video recording (photo-only for v1)
- RAW format support (JPEG/HEIC only for fotolokashen)
- Lightroom integration (Photo-Fixer only)
- exiftool / XMP sidecar generation (Photo-Fixer only)
- Supabase auth (fotolokashen uses OAuth2 PKCE)
- Batch zip upload (Photo-Fixer P4)
- Projects as organizational unit (fotolokashen uses locations)
- Admin-only location types on iOS (gated by role, not implemented)
- AI features (description improvement, tag suggestions) — deferred
