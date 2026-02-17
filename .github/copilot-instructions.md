# Copilot Instructions for fotolokashen-ios

*Last updated: February 17, 2026*

You are assisting with the **fotolokashen iOS app** — a camera-first location scouting companion to the fotolokashen web platform.

## Tech Stack
- **Framework**: SwiftUI (iOS 16.0+), Swift 5.9+
- **Architecture**: Hybrid MVVM + Shared Store (singleton `LocationStore.shared`)
- **Auth**: OAuth2 + PKCE via Safari, JWT tokens in iOS Keychain
- **Maps**: Google Maps SDK for iOS v10.7.0, GMUClusterManager
- **Camera**: AVFoundation (AVCaptureSession, AVCapturePhotoOutput)
- **Networking**: URLSession with async/await, custom `APIClient` singleton
- **Local Storage**: SwiftData (iOS 17+ only, feature-gated)
- **Image Processing**: Custom `ImageCompressor` (JPEG resize + quality reduction)
- **Photo Storage**: ImageKit CDN via server-mediated secure upload
- **Token Storage**: KeychainAccess library (`.whenUnlocked`, not synced to iCloud)
- **Monitoring**: Sentry (planned)

## Key Principles

### 1. Security First
- **Never log tokens in release builds**: All `print()` statements with sensitive data MUST be wrapped in `#if DEBUG`
- **API keys via build configuration**: Google Maps key uses `$(GOOGLE_MAPS_API_KEY)` in Info.plist, loaded from xcconfig
- **Config.plist is gitignored**: Use `Config.example.plist` as template; never commit actual keys
- **Server-mediated uploads**: ALL photo uploads go through `/api/photos/upload` for virus scanning (ClamAV)
- **Keychain storage**: Tokens stored via KeychainAccess with `.whenUnlocked` accessibility, `.synchronizable(false)`
- **Auto-logout on 401**: `APIClient` broadcasts `authSessionInvalidated` notification → `AuthService` clears state

### 2. Type Safety & Codable
- All API models conform to `Codable`
- Use `CodingKeys` for snake_case ↔ camelCase mapping
- Use optional types (`?`) for fields that may be absent in API responses
- Match backend response shapes exactly

### 3. Async/Await
- Prefer `async/await` over completion handlers everywhere
- Use `@MainActor` for UI-bound services and view models
- Wrap in `Task {}` when calling from non-async context
- Handle cancellation appropriately

### 4. Code Style
- Follow SwiftLint configuration in `.swiftlint.yml`
- Line length: 120 char warning, 150 char error
- Function body length: 50 lines warning, 100 lines error
- Services: `XxxService.swift` naming
- Models: Singular nouns in `Models/` directory
- Views: `XxxView.swift` suffix

### 5. Debug Logging Pattern
```swift
#if DEBUG
if ConfigLoader.shared.enableDebugLogging {
    print("[ServiceName] descriptive message")
}
#endif
```
- Always use `#if DEBUG` wrapper for ANY print statement
- Use service tag prefixes: `[APIClient]`, `[AuthService]`, `[PhotoUpload]`, `[Sync]`, `[LocationStore]`
- NEVER log full tokens — use `[REDACTED]` in debug output

## Project Structure

```
fotolokashen-ios/
├── .github/
│   └── copilot-instructions.md      # This file
├── Config.plist                       # API keys (gitignored)
├── Config.example.plist               # Template for Config.plist
├── CHANGELOG.md
├── README.md
├── docs/                              # Documentation
├── fotolokashen/
│   ├── Fotolokashen.xcodeproj/        # Xcode project
│   ├── fotolokashen/
│   │   ├── fotolokashenApp.swift      # App entry, Google Maps init, iOS 17 branching
│   │   ├── ContentView.swift          # Auth routing, 5-tab layout, login/logged-in views
│   │   ├── Info.plist                 # URL scheme, API key reference
│   │   ├── Views/
│   │   │   ├── CameraView.swift       # Full-screen camera with GPS overlay
│   │   │   ├── CameraPreview.swift    # AVCaptureVideoPreviewLayer wrapper
│   │   │   ├── CreateLocationView.swift # New location form
│   │   │   ├── LocationDetailView.swift # Full detail with photo gallery
│   │   │   ├── LocationListView.swift   # Searchable/sortable list
│   │   │   ├── LocationRow.swift        # List row component
│   │   │   ├── LocationClusterItem.swift # GMUClusterItem + renderer
│   │   │   ├── MapView.swift            # Google Maps with clustering
│   │   │   ├── EditLocationView.swift   # Full location edit form
│   │   │   ├── ProfileView.swift        # Profile editing with avatar/banner upload
│   │   │   └── SettingsView.swift       # Privacy controls, account info, logout
│   │   ├── Services/
│   │   │   ├── LocationStore.swift      # Singleton shared state (@MainActor), update/delete
│   │   │   ├── LocationTypeColors.swift # 15 type→color/icon mappings
│   │   │   ├── MarkerIconGenerator.swift # Custom camera-icon markers
│   │   │   ├── NetworkMonitor.swift     # NWPathMonitor connectivity
│   │   │   ├── PlacesService.swift      # CLGeocoder reverse geocoding
│   │   │   ├── SyncService.swift        # Download locations + upload queued photos
│   │   │   ├── UserService.swift        # Profile CRUD, avatar/banner upload
│   │   │   └── DataManager.swift        # SwiftData container (iOS 17+)
│   │   └── swift-utilities/
│   │       ├── APIClient.swift          # HTTP client, Bearer auth, PATCH/PUT, 401 handling
│   │       ├── AuthService.swift        # OAuth2 PKCE login/logout/refresh
│   │       ├── CameraService.swift      # AVCaptureSession management
│   │       ├── ConfigLoader.swift       # Config.plist reader
│   │       ├── ImageCompressor.swift    # JPEG resize + quality reduction
│   │       ├── KeychainService.swift    # Token storage via KeychainAccess
│   │       ├── LocationManager.swift    # CLLocationManager wrapper
│   │       ├── LocationService.swift    # CRUD + update + dual geocoding
│   │       ├── PKCEGenerator.swift      # RFC 7636 PKCE with CryptoKit
│   │       ├── PhotoUploadService.swift # Secure multipart upload
│   │       └── Models/
│   │           ├── Location.swift       # Location + API response wrappers
│   │           ├── User.swift           # User model + profile/privacy request types
│   │           ├── Photo.swift          # Photo + upload response models
│   │           ├── OAuthToken.swift     # Token models
│   │           ├── CachedLocation.swift # SwiftData @Model (iOS 17+)
│   │           ├── CachedPhoto.swift    # SwiftData @Model (iOS 17+)
│   │           └── OfflinePhoto.swift   # SwiftData @Model for upload queue
│   ├── fotolokashenTests/              # Unit tests
│   └── fotolokashenUITests/            # UI tests
```

## Common Patterns

### APIClient Usage
```swift
// GET request
let response: MyResponse = try await APIClient.shared.get("/api/endpoint", authenticated: true)

// POST request
let result: MyResult = try await APIClient.shared.post("/api/endpoint", body: requestBody)

// DELETE request
let _: EmptyResponse = try await APIClient.shared.delete("/api/locations/\(id)")
```

### Protected Service Pattern
```swift
@MainActor
class MyService: ObservableObject {
    static let shared = MyService()
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiClient = APIClient.shared
    private let config = ConfigLoader.shared
    
    func doSomething() async throws -> MyResult {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result: MyResult = try await apiClient.get("/api/something")
            return result
        } catch {
            #if DEBUG
            if config.enableDebugLogging {
                print("[MyService] Error: \(error)")
            }
            #endif
            errorMessage = error.localizedDescription
            throw error
        }
    }
}
```

### Secure Photo Upload
```swift
// All uploads go through PhotoUploadService → /api/photos/upload
// Server performs: virus scan, format validation, HEIC/TIFF→JPEG conversion
let photo = try await PhotoUploadService().uploadPhoto(
    image: uiImage,
    locationId: locationId,
    location: clLocation,
    caption: "Optional caption"
)
```

### Multipart Upload (for new upload types)
```swift
// Use the pattern from PhotoUploadService.uploadSecurely()
// 1. Get auth token from KeychainService
// 2. Build multipart/form-data with boundary
// 3. Include uploadType field ("location", "avatar", "banner")
// 4. POST to /api/photos/upload
// 5. Handle SecureUploadResponse
```

### Profile & Privacy Updates
```swift
// Profile update via UserService
let request = ProfileUpdateRequest(firstName: "John", bio: "Photographer")
let user = try await UserService.shared.updateProfile(request)

// Privacy update
let privacy = PrivacyUpdateRequest(profileVisibility: "followers", showInSearch: false)
let user = try await UserService.shared.updatePrivacy(privacy)

// Avatar upload (auto-compresses, multipart to /api/auth/avatar)
let avatarUrl = try await UserService.shared.uploadAvatar(image: uiImage)

// Banner upload (auto-compresses, multipart to /api/auth/banner)
let bannerUrl = try await UserService.shared.uploadBanner(image: uiImage)
```

### iOS 17+ Feature Gating
```swift
if #available(iOS 17.0, *) {
    // SwiftData features
    ContentViewiOS17()
} else {
    // Fallback without SwiftData
    ContentViewLegacy()
}
```

### Google Maps Integration
```swift
// Initialize in fotolokashenApp.init()
GMSServices.provideAPIKey(config.googleMapsAPIKey)

// ClusteredMapView is UIViewRepresentable wrapping GMSMapView
// Custom markers via MarkerIconGenerator.cameraMarker(for:)
// Clustering via GMUClusterManager with GMUNonHierarchicalDistanceBasedAlgorithm
```

### ConfigLoader Access
```swift
let config = ConfigLoader.shared
let baseURL = config.backendURL           // URL type
let apiKey = config.googleMapsAPIKey       // String
let isDebug = config.enableDebugLogging   // Bool
let maxPhotos = config.maxPhotosPerLocation // Int (20)
```

## API Endpoints Used

| Endpoint | Method | Service | Purpose |
|----------|--------|---------|---------|
| `/api/auth/oauth/token` | POST | AuthService | Token exchange & refresh |
| `/api/auth/oauth/revoke` | POST | AuthService | Logout (revoke refresh token) |
| `/api/v1/users/me` | GET | APIClient | Fetch current user (rich profile) |
| `/api/v1/users/me` | PATCH | UserService | Update profile & privacy settings |
| `/api/auth/avatar` | POST | UserService | Upload avatar (FormData) |
| `/api/auth/avatar` | DELETE | UserService | Remove avatar |
| `/api/auth/banner` | POST | UserService | Upload banner (FormData) |
| `/api/auth/banner` | DELETE | UserService | Remove banner |
| `/api/locations` | GET | LocationService | Fetch all user locations |
| `/api/locations` | POST | LocationService | Create new location |
| `/api/locations/{id}` | GET | LocationService | Fetch single location |
| `/api/locations/{id}` | PATCH | LocationService | Update location + UserSave fields |
| `/api/locations/{id}` | DELETE | LocationStore | Delete location |
| `/api/locations/{id}/photos` | GET | LocationDetailView | Fetch location photos |
| `/api/locations/{id}/photos` | POST | PhotoUploadService | Associate photo with location |
| `/api/photos/{id}` | DELETE | LocationService | Delete a photo |
| `/api/photos/upload` | POST | PhotoUploadService | Secure multipart upload |

## Dependencies (SPM)

| Package | Version | Purpose | Status |
|---------|---------|---------|--------|
| Google Maps SDK | 10.7.0 | Map display, markers | Active |
| Google Maps Utils | 7.0.0 | Marker clustering | Active |
| KeychainAccess | 4.2.2 | Secure token storage | Active |
| Kingfisher | 8.6.2 | Image caching | **Unused** — remove via Xcode |
| ImageKit iOS | 3.1.0 | CDN (legacy) | **Unused** — remove via Xcode |

## Backend API Reference

The iOS app connects to the fotolokashen web backend at `https://fotolokashen.com`.

### Authentication Flow
1. `AuthService.startLogin()` → opens Safari with OAuth2 params + PKCE challenge
2. User logs in on web → redirected back via `fotolokashen://oauth-callback?code=...`
3. `AuthService.handleCallback(url:)` → exchanges code for tokens via `/api/auth/oauth/token`
4. Tokens saved to Keychain, `isAuthenticated = true`
5. On token expiry: `refreshTokenIfNeeded()` auto-refreshes via same endpoint
6. On logout: revoke refresh token via `/api/auth/oauth/revoke`, clear Keychain

### Location Model Mapping
```
Backend (snake_case)     →  iOS (camelCase)
place_id                 →  placeId
created_at               →  createdAt
production_date          →  productionDate
user_save_id             →  userSaveId
```

## Location Types (15)
Consistent colors across iOS and web:
- BROLL (#3B82F6), STORY (#22C55E), INTERVIEW (#EAB308)
- LIVE ANCHOR (#F97316), REPORTER LIVE (#F97316), STAKEOUT (#EF4444)
- DRONE (#8B5CF6), SCENE (#EC4899), EVENT (#6366F1)
- BATHROOM (#06B6D4), OTHER (#6B7280), HQ (#10B981)
- BUREAU (#14B8A6), REMOTE STAFF (#0EA5E9), STORAGE (#F59E0B)

## Testing
- Unit tests in `fotolokashenTests/`
- Test files: `AuthServiceTests`, `PKCEGeneratorTests`, `ImageCompressorTests`, `LocationStoreTests`
- Mock network calls for service tests
- Run: `⌘U` in Xcode
- Test on both iOS 16 and iOS 17+ simulators

## Development Workflow

### Running Locally
```bash
open fotolokashen/Fotolokashen.xcodeproj  # Open in Xcode
# Select target device/simulator → ⌘+R to build and run
```

### Configuration Setup
```bash
cp Config.example.plist Config.plist
# Edit Config.plist with your API keys
# Do NOT commit Config.plist
```

### Building for Release
1. Set `enableDebugLogging` to `false` in Config.plist
2. Select "Any iOS Device" as target
3. Product → Archive
4. Distribute via TestFlight or App Store

## Security Checklist

When adding new features, verify:
- [ ] All `print()` statements wrapped in `#if DEBUG`
- [ ] API calls use `APIClient.shared` (handles auth headers automatically)
- [ ] No API keys hardcoded in Swift files
- [ ] Photo uploads use `PhotoUploadService` (server-mediated with virus scanning)
- [ ] Tokens not logged (use `[REDACTED]` in debug output)
- [ ] New Codable models use optional types for nullable API fields
- [ ] Error messages are user-friendly (not raw error dumps)

## Planned Features (Phased Roadmap)

### Phase 1: User Profile & Settings ✅ (v1.2.0)
- ✅ Profile editing (bio, city, country, language, timezone)
- ✅ Avatar/banner upload via secure pipeline
- ✅ Privacy controls (profileVisibility, showInSearch, showLocation, showSavedLocations)
- ✅ Switch from `/api/auth/me` to `/api/v1/users/me` for richer user data
- ✅ New 5-tab layout: Locations | Map | Capture | Profile | Settings

### Phase 2: Location Editing & Enrichment ✅ (v1.3.0)
- ✅ Edit existing locations (all fields: production notes, entry point, parking, access, indoor/outdoor)
- ✅ Favorites, tags, personal ratings via EditLocationView
- ✅ Photo deletion from locations (mark + delete on save)
- ✅ Type-based filtering on location list (horizontal filter chips)
- ✅ LocationType enum updated to match 15 real types from web app
- ✅ Location model expanded with UserSave fields (color, isFavorite, tags, etc.)

### Phase 3: Social Features
- Follow/unfollow users
- Public user profiles with avatar, banner, bio, location count
- Followers/following lists
- Public & friends' locations on map (purple markers)

### Phase 4: Search & Onboarding
- People search with typeahead suggestions
- Terms of Service acceptance (blocking modal, scroll-to-bottom requirement)
- Onboarding walkthrough (page-style SwiftUI tabs)

### Phase 5: AI & Support
- AI description improvement (improve, extract, rewrite modes)
- AI tag suggestions from production notes
- In-app member support form

## Documentation References
- **Web Backend**: `/fotolokashen/.github/copilot-instructions.md`
- **Photo Upload Security**: `docs/IOS_PHOTO_UPLOAD_SECURITY_REVIEW.md`
- **Config Template**: `Config.example.plist`

## Important Notes
- **Custom OAuth2 Auth**: PKCE flow via Safari, NOT Sign in with Apple/Google
- **Session Management**: Multi-device (web + iOS) with auto-logout on invalidation
- **iOS 16 Support**: Maintained — SwiftData features gated behind `@available(iOS 17, *)`
- **Offline Mode**: SwiftData cache + photo queue (iOS 17+ only)
- **Geocoding**: Dual strategy — Google Maps API (primary) → Apple CLGeocoder (fallback)
- **No direct CDN uploads**: All uploads server-mediated through `/api/photos/upload`
- **Admin features**: Web-only, not planned for iOS