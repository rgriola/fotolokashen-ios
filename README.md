# fotolokashen iOS v1.6.0

iOS companion app for fotolokashen — a camera-first location scouting app for photographers and film crews.

**Production URL**: https://fotolokashen.com  
**Status**: ✅ Active Development | Build: Passing  
**Last Updated**: May 8, 2026

---

## Overview

The fotolokashen iOS app allows users to quickly capture photos with GPS coordinates, automatically geocode addresses, and upload locations to the fotolokashen platform. Designed for field use by photographers, videographers, and location scouts.

---

## Feature Summary by Version

### v1.6 — Camera & Upload Pipeline Hardening (May 2026)

- 🎞️ **EXIF Preservation** — Camera captures raw `Data` (not re-encoded `UIImage`), preserving ISO, aperture, lens, and GPS metadata through the upload pipeline
- 📷 **Flip Camera** — Front/back camera toggle button next to the shutter
- ⚡ **Flash Control** — Auto/On/Off flash toggle in top bar (Apple-style, yellow when active)
- 🔄 **Transition Overlay** — Smooth "Preparing photos…" overlay prevents abrupt Library-from-Camera dismissal
- 🚀 **Concurrent Photo Loading** — `TaskGroup`-based parallel photo loading in `PhotoPickerView` (replaces sequential I/O)
- 🛑 **Race Condition Fix** — Deferred picker dismissal + full-screen blur overlay prevents premature UI teardown
- 🐛 **Edit Details Fix** — `details` field (from Create form) now correctly round-trips to Edit view via `UpdateLocationRequest`
- 🔧 **New Pipeline Active** — `useNewPhotoPipeline = true` in `Config.plist` enables `PhotoPipelineCoordinator` + `PhotoUploadQueue` for concurrent, retry-capable uploads

### v1.5.1 (April 2026)

- 🐛 **OAuth Loop Fix** — `prefersEphemeralWebBrowserSession = true` eliminates Safari cookie contamination; unified `redirect_uri` to `fotolokashen://oauth-callback`

### v1.5.0 (April 2026)

- ⚙️ **Profile & Settings Restructure** — App Settings (Preferences + Permissions) surfaced directly on Profile tab
- 📱 **About Screen** — Dedicated `AboutView` with version, build, legal links
- 🔒 **Account & Security** — Personal Details card; Edit Profile sheet
- 📝 **Create Location Overhaul** — Required Name + Details fields with char limits; postal address format; real-time validation; URL injection prevention
- 🔐 **Auto-login after email verification** — Deep link `fotolokashen://email-verified?token=` triggers auto-login

### v1.4.1 (February 2026)

- 🔧 **Unified `LocationDetailView`** — Single view handles owner mode and read-only mode
- 🎨 **`AppIcons.swift`** — 45+ centralized SF Symbol constants
- 🗺️ **Address → Map Tab** — Tapping address navigates to in-app Map instead of Apple Maps

### v1.4.0 (February 2026)

- 👥 **People Search** — Discover/Following/Followers tabs with typeahead search
- 🤝 **Follow System** — Follow/unfollow users, public profiles, followers/following lists
- 🗺️ **Friends' Locations** — Purple markers on map for people you follow
- 🔗 **Deep Linking** — Custom URL scheme + Universal Links

### v1.3.0 (February 2026)

- ✏️ **Full Location Editing** — All fields including production notes, entry point, parking, access
- ⭐ **Personal Enrichment** — Favorites, ratings, tags, captions
- 🗑️ **Photo Deletion** — Mark for deletion on save
- 🏷️ **Type Filtering** — Horizontal filter chips on location list

### v1.2.0 (February 2026)

- 👤 **Profile & Settings** — Avatar/banner upload, privacy controls, full profile editing

### v1.0–v1.1 (January–February 2026)

- ✅ Core camera capture, GPS tagging, auto-geocoding
- ✅ OAuth2 + PKCE authentication
- ✅ Google Maps with custom markers and clustering
- ✅ Secure server-mediated photo upload (virus scan, HEIC/TIFF conversion, EXIF sanitization)

---

## Tech Stack

| Technology       | Purpose                             |
| ---------------- | ----------------------------------- |
| SwiftUI          | Declarative UI framework            |
| Swift Concurrency| async/await + TaskGroup for networking and I/O |
| AVFoundation     | Camera capture and raw photo data   |
| PhotosUI         | PHPickerViewController for library  |
| Google Maps SDK  | Map display and clustering          |
| Apple CLGeocoder | Address lookup (primary)            |
| ImageKit         | Cloud image storage                 |
| SwiftData        | Local caching (iOS 17+)             |
| Keychain         | Secure token storage                |
| os.Logger        | Structured logging (debug builds)   |

---

## Project Structure

```
fotolokashen-ios/
├── fotolokashen/
│   └── fotolokashen/
│       ├── fotolokashenApp.swift           # App entry point
│       ├── ContentView.swift               # 5-tab layout
│       ├── Views/
│       │   ├── CameraView.swift            # Camera: zoom, focus, exposure, flip, flash, GPS
│       │   ├── Camera/
│       │   │   └── CameraHUDComponents.swift  # Focus square, exposure slider, zoom dial, GPS badge
│       │   ├── CameraPreview.swift         # AVCaptureVideoPreviewLayer wrapper
│       │   ├── CreateLocationView.swift    # Create form: photos, location info, production date
│       │   ├── EditLocationView.swift      # Full location edit form (incl. details field fix)
│       │   ├── MapView.swift               # Google Maps + friends' locations toggle
│       │   ├── LocationListView.swift      # Searchable list with type filter chips
│       │   ├── LocationDetailView.swift    # Unified view (owner + read-only modes)
│       │   ├── LocationRow.swift           # List row with share button
│       │   ├── LocationClusterItem.swift   # GMUClusterItem + renderer
│       │   ├── ProfileView.swift           # Profile hub + App Settings (Preferences, Permissions)
│       │   ├── PublicProfileView.swift     # Other users' profiles
│       │   ├── PeopleSearchView.swift      # Discover/Following/Followers tabs
│       │   ├── FollowListView.swift        # Paginated followers/following list
│       │   ├── AboutView.swift             # App version, build, legal links
│       │   ├── AccountSecurityView.swift   # Personal details + Edit Profile
│       │   ├── PhotoPickerView.swift       # PHPicker wrapper (concurrent TaskGroup loading)
│       │   ├── PhotoPickerViewModel.swift  # Photo loading, compression, pipeline ingestion
│       │   ├── PhotoGridView.swift         # Horizontal thumbnail strip with stage overlays
│       │   ├── PhotoSpreadMapView.swift    # GPS distribution map (LocationDetailView)
│       │   ├── LocationDetailSubviews.swift # PhotoGallery, SectionHeader, DetailRow
│       │   └── ProfileHeaderComponents.swift # Banner, Avatar, StatItem, FormField, ImagePicker
│       ├── Services/
│       │   ├── AppColors.swift             # Semantic color tokens
│       │   ├── AppIcons.swift              # 45+ SF Symbol constants
│       │   ├── Networking/
│       │   │   └── DebugLog.swift          # dlog() → os.Logger routing
│       │   ├── Camera/
│       │   │   ├── CameraService.swift     # AVFoundation: capture, flip, flash, raw Data output
│       │   │   └── CameraSessionViewModel.swift  # Multi-capture session, disk writes
│       │   ├── Photo/
│       │   │   ├── PhotoPipelineCoordinator.swift  # Orchestrates selection → compress → upload
│       │   │   ├── PhotoUploadQueue.swift          # Concurrent retry-capable upload queue
│       │   │   ├── PhotoCompressionService.swift   # Batch compression
│       │   │   ├── PhotoSelectionService.swift     # Library/camera source normalization
│       │   │   ├── SessionCapture.swift            # Disk-backed photo + raw EXIF extraction
│       │   │   ├── EXIFExtractor.swift             # EXIF parsing from raw Data
│       │   │   └── GPSSpreadAnalyzer.swift         # GPS spread analysis for multi-photo
│       │   ├── Locations/
│       │   │   ├── LocationStore.swift             # Shared state + mapFocusLocation
│       │   │   ├── LocationService.swift           # CRUD + updates
│       │   │   ├── LocationRepository.swift
│       │   │   └── GeocodingService.swift          # Dual geocoding (Google → Apple fallback)
│       │   ├── CreateLocation/
│       │   │   └── CreateLocationViewModel.swift
│       │   ├── EditLocation/
│       │   │   └── EditLocationViewModel.swift     # incl. details field round-trip
│       │   ├── LocationTypeColors.swift            # 15 type→color mappings
│       │   ├── MarkerIconGenerator.swift           # Custom + social markers
│       │   ├── UserService.swift                   # Profile CRUD + avatar/banner upload
│       │   ├── SyncService.swift                   # Download + upload queued photos
│       │   ├── FollowService.swift                 # Follow/unfollow, profiles, social locations
│       │   ├── DeepLinkManager.swift               # Deep link routing
│       │   ├── NetworkMonitor.swift                # NWPathMonitor connectivity
│       │   ├── StaticMapHelper.swift               # Static map image generation
│       │   └── DataManager.swift                   # SwiftData container (iOS 17+)
│       └── Models/
│           ├── Location.swift              # Location + UserSave models + UpdateLocationRequest
│           ├── Photo.swift                 # Photo models + PipelinePhoto
│           ├── User.swift                  # User + privacy/profile request types
│           ├── Social.swift                # PublicUser, FollowStatus, MapSocialLocation, etc.
│           └── OAuthToken.swift
├── Config.plist                            # API config (gitignored)
├── CHANGELOG.md                            # Version history
├── README.md                               # This file
└── docs/
    ├── API.md                              # ⚠️ Partially stale — see notes in file
    ├── AUTHENTICATION_FLOW.md              # OAuth2 + PKCE flow details
    ├── IOS_PHOTO_UPLOAD_SECURITY_REVIEW.md # Upload security audit
    ├── PRODUCTION_DATE_API.md              # Production date field spec
    ├── APP_ICON_SETUP.md                   # App icon configuration
    └── archive/                            # Historical docs (do not delete)
```

---

## Getting Started

### Prerequisites

- macOS 14.0+ (Sonoma)
- Xcode 15.4+
- iOS 16.0+ deployment target
- fotolokashen account
- Google Maps API key (Maps SDK for iOS enabled)

### Setup

1. **Clone the repository**

   ```bash
   git clone https://github.com/rgriola/fotolokashen-ios.git
   ```

2. **Configure API Keys**

   ```bash
   cp Config.example.plist fotolokashen/fotolokashen/Config.plist
   ```

   Edit `Config.plist`:
   - `BackendURL` — `https://fotolokashen.com`
   - `GoogleMapsAPIKey` — Your Google Maps API key
   - `OAuth2ClientID` — `fotolokashen-ios`
   - `OAuth2RedirectURI` — `fotolokashen://oauth-callback`
   - `EnableDebugLogging` — `true` for development, `false` for release
   - `useNewPhotoPipeline` — `true` (new pipeline active as of v1.6)

3. **Open in Xcode**

   ```bash
   open fotolokashen/fotolokashen.xcodeproj
   ```

4. **Build and Run** — ⌘+R

---

## Photo Upload Pipeline (v1.6)

```
Camera Path:
  AVFoundation raw Data → CameraSessionViewModel → disk temp file
  → SessionCapture (EXIF from raw Data) → PhotoPipelineCoordinator
  → PhotoCompressionService → PhotoUploadQueue → /api/photos/upload

Library Path:
  PHPickerViewController → TaskGroup parallel load → PipelinePhoto[]
  → PhotoPickerViewModel → PhotoPipelineCoordinator
  → PhotoCompressionService → PhotoUploadQueue → /api/photos/upload

Server:
  /api/photos/upload → ClamAV scan → Sharp HEIC/TIFF→JPEG → ImageKit CDN
  → /api/locations/{id}/photos (associate)
```

**Feature flag**: `Config.plist → useNewPhotoPipeline = true` activates `PhotoPipelineCoordinator`. Legacy `PhotoPickerViewModel` path remains for rollback.

---

## Location Types

15 types matching the web app:

| Type          | Color             |
| ------------- | ----------------- |
| BROLL         | Blue (#3B82F6)    |
| STORY         | Green (#22C55E)   |
| INTERVIEW     | Yellow (#EAB308)  |
| LIVE ANCHOR   | Orange (#F97316)  |
| REPORTER LIVE | Orange (#F97316)  |
| STAKEOUT      | Red (#EF4444)     |
| DRONE         | Purple (#8B5CF6)  |
| SCENE         | Pink (#EC4899)    |
| EVENT         | Indigo (#6366F1)  |
| BATHROOM      | Cyan (#06B6D4)    |
| OTHER         | Gray (#6B7280)    |
| HQ            | Emerald (#10B981) |
| BUREAU        | Teal (#14B8A6)    |
| REMOTE STAFF  | Sky (#0EA5E9)     |
| STORAGE       | Amber (#F59E0B)   |

---

## API Endpoints

See [docs/API.md](./docs/API.md) for full reference.

> ⚠️ **Note**: `docs/API.md` documents the legacy request/upload/confirm flow. The active upload flow uses `POST /api/photos/upload` (server-mediated). The `PUT /api/locations/{id}` shown in API.md is now `PATCH`. Full updated endpoint table is in the README backend table below.

| Endpoint | Method | Purpose |
|---|---|---|
| `/api/auth/oauth/token` | POST | Exchange code for tokens |
| `/api/auth/oauth/revoke` | POST | Revoke tokens on logout |
| `/api/auth/delete-account` | DELETE | Delete account |
| `/api/photos/upload` | POST | Secure photo upload |
| `/api/v1/users/me` | GET/PATCH | Current user profile |
| `/api/auth/avatar` | POST/DELETE | Avatar upload/delete |
| `/api/auth/banner` | POST/DELETE | Banner upload/delete |
| `/api/locations` | GET/POST | List / create locations |
| `/api/locations/{id}` | GET/PATCH/DELETE | Location detail/update/delete |
| `/api/locations/{id}/photos` | GET | List photos for location |
| `/api/photos/{id}` | DELETE | Delete a photo |
| `/api/v1/users/{username}` | GET | Public profile |
| `/api/v1/users/{username}/follow` | POST | Follow user |
| `/api/v1/users/{username}/unfollow` | POST | Unfollow user |
| `/api/v1/users/{username}/followers` | GET | Paginated followers |
| `/api/v1/users/{username}/following` | GET | Paginated following |
| `/api/v1/users/{username}/locations` | GET | User's public locations |
| `/api/v1/locations/public` | GET | All public locations (bounds) |
| `/api/v1/locations/friends` | GET | Friends' locations |
| `/api/v1/search/users` | GET | User search |
| `/api/v1/search/suggestions` | GET | Username autocomplete |

---

## Debug Logging

Enable in `Config.plist`:

```xml
<key>EnableDebugLogging</key>
<true/>
```

Logs route through `os.Logger` in debug builds (filterable in Console.app and Instruments).

Log prefixes:
- `[APIClient]` — Network requests
- `[LocationService]` — Location CRUD
- `[LocationStore]` — State management
- `[CameraService]` — Camera capture
- `[PhotoUploadQueue]` — Upload pipeline
- `📍` — Geocoding
- `🍎` — Apple Geocoding
- `💾` — Save operations

---

## Known Issues / Next Steps

- [ ] **Device testing**: Camera flip/flash and `PhotoUploadQueue` retry logic need on-device validation
- [ ] **Back-end EXIF sync**: Verify `exiftool` server jobs are picking up raw JPEG EXIF from new pipeline
- [ ] **Monitor** `PhotoUploadQueue` error rates in production for edge case retry behavior
- [ ] **Future**: Consolidate `CameraView` HUD layout if more controls (e.g., exposure lock) are added

---

## Links

- **Web App**: [fotolokashen.com](https://fotolokashen.com)
- **Backend Repo**: [github.com/rgriola/fotolokashen](https://github.com/rgriola/fotolokashen)

---

**Version**: 1.6.0  
**Last Updated**: May 8, 2026  
**Status**: ✅ Build Passing | 🔧 Active Development
