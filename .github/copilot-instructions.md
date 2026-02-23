# Copilot Instructions for fotolokashen-ios

*Last updated: February 23, 2026*

You are assisting with the **fotolokashen iOS app** (v1.4.1) — a camera-first location scouting companion to the fotolokashen web platform.

## Tech Stack
- **Framework**: SwiftUI (iOS 16.0+), Swift 5.9+
- **Architecture**: Hybrid MVVM + Shared Store (singleton `LocationStore.shared`)
- **Auth**: OAuth2 + PKCE via Safari, JWT tokens in iOS Keychain
- **Maps**: Google Maps SDK for iOS v10.8.0, GMUClusterManager
- **Camera**: AVFoundation (AVCaptureSession, AVCapturePhotoOutput)
- **Networking**: URLSession with async/await, custom `APIClient` singleton
- **Deep Linking**: Custom URL scheme (`fotolokashen://`) + Universal Links (`applinks:fotolokashen.com`)
- **Local Storage**: SwiftData (iOS 17+ only, feature-gated)
- **Image Processing**: Custom `ImageCompressor` (JPEG resize + quality reduction)
- **Photo Storage**: ImageKit CDN via server-mediated secure upload
- **Token Storage**: KeychainAccess library (`.whenUnlocked`, not synced to iCloud)
- **UX**: The web app and iOS app should share common design patterns and user flows. iOS is optimized for on-the-go location scouting with quick references and creation. The web app remains the source of truth for all features and backend integration, with the iOS app selectively integrating features based on mobile relevance and development resources. 


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
- **Coordinate fields**: iOS models handle both `lat`/`lng` (canonical) and `latitude`/`longitude` (legacy) via custom `Codable` init — see `SocialLocationDetail` in `Social.swift`

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
│   │   │   ├── LocationDetailView.swift # UNIFIED: owner mode + read-only mode (two initializers)
│   │   │   ├── LocationListView.swift   # Searchable/sortable list with type filter chips
│   │   │   ├── LocationRow.swift        # List row component with share button
│   │   │   ├── LocationClusterItem.swift # GMUClusterItem + renderer + SocialLocationClusterItem
│   │   │   ├── MapView.swift            # Google Maps with clustering + friends' locations toggle
│   │   │   ├── EditLocationView.swift   # Full location edit form
│   │   │   ├── PublicProfileView.swift  # Public user profile (uses unified LocationDetailView)
│   │   │   ├── FollowListView.swift     # Paginated followers/following list
│   │   │   ├── PeopleSearchView.swift   # People search with Discover/Following/Followers tabs
│   │   │   ├── ProfileView.swift        # Profile editing with avatar/banner upload + social stats
│   │   │   └── SettingsView.swift       # Privacy controls, account info, logout
│   │   ├── Services/
│   │   │   ├── AppIcons.swift           # Centralized SF Symbol icon names (45+ constants)
│   │   │   ├── LocationStore.swift      # Singleton shared state (@MainActor), mapFocusLocation
│   │   │   ├── LocationTypeColors.swift # 15 type→color/icon mappings
│   │   │   ├── MarkerIconGenerator.swift # Custom camera-icon + social person-icon markers
│   │   │   ├── NetworkMonitor.swift     # NWPathMonitor connectivity
│   │   │   ├── PlacesService.swift      # CLGeocoder reverse geocoding
│   │   │   ├── SyncService.swift        # Download locations + upload queued photos
│   │   │   ├── UserService.swift        # Profile CRUD, avatar/banner upload
│   │   │   ├── FollowService.swift      # Follow/unfollow, profiles, search, social locations
│   │   │   ├── DeepLinkManager.swift    # Deep link routing (URL scheme + Universal Links)
│   │   │   ├── GeographicClusterAlgorithm.swift # Custom clustering algorithm
│   │   │   ├── StaticMapHelper.swift    # Static map image generation
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
│   │           ├── Social.swift         # PublicUser, FollowStatus, SearchUser, SocialLocation models
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

### Social Features (Follow, Profiles, Search)
```swift
// Follow/unfollow
let response = try await FollowService.shared.follow(username: "johndoe")
let response = try await FollowService.shared.unfollow(username: "johndoe")

// Check follow status
let status = try await FollowService.shared.getFollowStatus(username: "johndoe")
// status.isFollowing, status.isFollowedBy

// Public profile
let profile = try await FollowService.shared.getPublicProfile(username: "johndoe")

// Followers/following lists (paginated)
let followers = try await FollowService.shared.getFollowers(username: "johndoe", page: 1, limit: 20)
let following = try await FollowService.shared.getFollowing(username: "johndoe", page: 1, limit: 20)

// Friends' locations for map
let friendsLocations = try await FollowService.shared.getFriendsLocations(bounds: mapBounds)

// People search
let results = try await FollowService.shared.searchUsers(query: "john", type: "all")
```

### Deep Link Handling
```swift
// DeepLinkManager handles both URL schemes and Universal Links
// Custom scheme: fotolokashen://location/123
// Universal Link: https://fotolokashen.com/shared/123

// In fotolokashenApp.swift:
.onOpenURL { url in
    // Try deep link first; if not handled, fall back to OAuth
    if !deepLinkManager.handleURL(url) {
        if url.scheme == "fotolokashen" {
            Task {
                await authService.handleCallback(url: url)
            }
        }
    }
}
// Universal Links arrive via NSUserActivity
.onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
    guard let url = activity.webpageURL else { return }
    _ = deepLinkManager.handleURL(url)
}

// In ContentView.swift — respond to deep link navigation
.onChange(of: deepLinkManager.pendingLocationId) { _, locationId in
    guard let locationId else { return }
    Task {
        if let location = await deepLinkManager.resolveLocation(id: locationId) {
            deepLinkLocation = location
            showDeepLinkDetail = true
        }
        deepLinkManager.clearPendingNavigation()
    }
}
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

### AppIcons Usage (IMPORTANT)
```swift
// Use centralized icon constants from AppIcons.swift — do NOT hardcode SF Symbol strings
import SwiftUI

// ✅ CORRECT - Use AppIcons constants
Image(systemName: AppIcons.edit)        // "square.and.pencil"
Image(systemName: AppIcons.share)       // "arrowshape.turn.up.right"
Image(systemName: AppIcons.mapPin)      // "mappin.circle.fill"
Image(systemName: AppIcons.camera)      // "camera.fill"
Image(systemName: AppIcons.person)      // "person.fill"

// ❌ WRONG - Do not hardcode strings
Image(systemName: "square.and.pencil")  // Use AppIcons.edit instead

// Available categories in AppIcons:
// - Navigation: back, close, menu, chevronRight, chevronDown
// - Actions: add, edit, delete, share, search, filter, refresh
// - Location Types: broll, story, interview, drone, etc. (15 types)
// - Camera: camera, flash, switchCamera, gallery
// - Profile: person, followers, following, settings, logout
// - Map: map, mapPin, location, compass, directions
// - Status: checkmark, warning, error, info, star, heart
// - Content: photo, video, document, folder
```

### Unified LocationDetailView Pattern (CRITICAL)
```swift
// LocationDetailView has TWO initializers — use the correct one for the context
// DO NOT create duplicate detail views — always use the unified LocationDetailView

// Owner mode: User's own locations (Edit + Share buttons in toolbar)
LocationDetailView(location: myLocation)

// Read-only mode: Viewing another user's public location (no Edit button)
LocationDetailView(
    socialLocation: socialLocation,
    ownerUsername: "johndoe",
    ownerDisplayName: "John Doe"
)

// The view internally uses `isReadOnly` flag to control:
// - Toolbar buttons (Edit + Share for owner, Share only for read-only)
// - Edit sheet presentation
// - Delete confirmation
```

### Map Navigation from Detail View
```swift
// To navigate from a detail view to the Map tab and focus on a location:
private func showOnMap() {
    // 1. Set the location to focus on
    LocationStore.shared.mapFocusLocation = currentLocation
    
    // 2. Dismiss the current view
    dismiss()
    
    // 3. Post notification to switch to Map tab
    NotificationCenter.default.post(name: .navigateToMapTab, object: nil)
}

// MapView has an onChange handler that responds to mapFocusLocation:
.onChange(of: locationStore.mapFocusLocation) { _, location in
    guard let loc = location else { return }
    selectedLocation = loc
    focusCoordinate = CLLocationCoordinate2D(latitude: loc.lat, longitude: loc.lng)
}

// ContentView has a receiver that switches tabs:
.onReceive(NotificationCenter.default.publisher(for: .navigateToMapTab)) { _ in
    selectedTab = 1  // Map tab index
}
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
| `/api/v1/users/{username}` | GET | FollowService | Fetch public profile |
| `/api/v1/users/{username}/follow` | POST | FollowService | Follow user |
| `/api/v1/users/{username}/unfollow` | POST | FollowService | Unfollow user |
| `/api/v1/users/me/follow-status/{username}` | GET | FollowService | Check follow relationship |
| `/api/v1/users/{username}/followers` | GET | FollowService | Paginated followers list |
| `/api/v1/users/{username}/following` | GET | FollowService | Paginated following list |
| `/api/v1/users/{username}/locations` | GET | FollowService | User's public locations |
| `/api/v1/locations/public` | GET | FollowService | All public locations (with bounds) |
| `/api/v1/locations/friends` | GET | FollowService | Friends' locations (privacy-enforced) |
| `/api/v1/search/users` | GET | FollowService | User search (username/bio/geo) |
| `/api/v1/search/suggestions` | GET | FollowService | Username autocomplete |

## Dependencies (SPM)

| Package | Version | Purpose | Status |
|---------|---------|---------|--------|
| Google Maps SDK | 10.8.0 | Map display, markers | Active |
| Google Maps Utils | 7.1.0 | Marker clustering | Active |
| KeychainAccess | 4.2.2 | Secure token storage | Active |

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

### Phase 3: Social Features ✅ (v1.4.0)
- ✅ Follow/unfollow users from public profiles
- ✅ Public user profiles with avatar, banner, bio, follower/following counts, public locations grid
- ✅ Followers/following lists with infinite scroll pagination
- ✅ People search with debounced typeahead (username, name, city)
- ✅ People tab with Discover, Following, and Followers sub-tabs
- ✅ Friends' locations on map (purple markers with person icon, toggle button)
- ✅ Social location detail sheet with user info and profile navigation
- ✅ Profile social stats (followers/following counts) with tappable navigation
- ✅ 5-tab layout updated: Locations | Map | Capture | People | Profile (Settings via gear icon)

### Phase 4: Search & Onboarding
- Terms of Service acceptance (blocking modal, scroll-to-bottom requirement)
- Onboarding walkthrough (page-style SwiftUI tabs)

### Phase 5: AI & Support
- AI description improvement (improve, extract, rewrite modes)
- AI tag suggestions from production notes
- In-app member support form

## OpenGraph & Rich Link Previews

### Web App Implementation
Public location pages (`/[username]/locations/[id]`) automatically generate OpenGraph metadata for rich link previews when shared via iOS, social media, or messaging apps.

**Metadata Generation** (Next.js `generateMetadata`):
```typescript
export async function generateMetadata({ params }: PublicLocationPageProps): Promise<Metadata> {
  const ogImage = save.location.photos[0]?.imagekitFilePath
    ? getImageKitUrl(save.location.photos[0].imagekitFilePath, 'w-1200,h-630,c-at_max')
    : undefined;

  return {
    title: `${save.location.name} - ${displayName}'s Location`,
    description: save.caption || save.location.address || `View ${save.location.name}`,
    openGraph: {
      title: save.location.name,
      description: save.caption || save.location.address,
      images: ogImage ? [ogImage] : [],
    },
  };
}
```

**Generated HTML meta tags**:
```html
<meta property="og:title" content="Location Name">
<meta property="og:description" content="Location address or caption">
<meta property="og:image" content="https://ik.imagekit.io/rgriola/...?tr=w-1200,h-630,c-at_max">
<meta property="og:url" content="https://fotolokashen.com/username/locations/123">
```

### iOS Integration
iOS app shares location URLs (not plain text) to enable automatic OpenGraph fetching:

**Correct Sharing Pattern**:
```swift
// ✅ Share URL object - triggers OpenGraph preview
if let username = location.creator?.username,
   let url = URL(string: "https://fotolokashen.com/\(username)/locations/\(location.id)") {
    ShareLink(
        item: url,
        subject: Text(location.name),
        message: Text(location.address ?? "")
    )
}

// ❌ WRONG - Plain text string, no preview
ShareLink(item: "Location Name\nAddress\nhttps://...", ...)
```

### How It Works
1. **User shares location** from iOS app via ShareLink
2. **iOS/iMessage receives URL**: `https://fotolokashen.com/rodczaro/locations/107`
3. **Platform fetches page** and parses OpenGraph meta tags
4. **Rich preview displayed** with:
   - 📷 Primary photo (1200x630, optimized via ImageKit)
   - 📍 Location name (og:title)
   - 📝 Caption or address (og:description)

### URL Format
- **Public location pages**: `/{username}/locations/{locationId}`
- **No @ symbol**: URLs are `/rodczaro/locations/107`, not `/@rodczaro/...`
- **Always use creator username**: Ensures correct public profile routing

### Image Optimization
ImageKit transformations for OpenGraph images:
- **Size**: `w-1200,h-630` (og:image standard dimensions)
- **Fit**: `c-at_max` (maintain aspect ratio, fit within bounds)
- **Format**: Auto (`fo-auto` - WebP/AVIF where supported)

### Debugging Tips
- **Test URL in browser**: View page source to verify meta tags
- **iMessage cache**: Previews cached - append `?v=2` to test changes
- **Fallback behavior**: If no photo, only title/description shown
- **Private locations**: Only public locations (`visibility: "public"`) are accessible via shared URLs

## Documentation References
- **Web Backend**: `/fotolokashen/.github/copilot-instructions.md`
- **Mobile API Schemas**: `/fotolokashen/docs/api/MOBILE_API_SCHEMAS.md` (CRITICAL - canonical response structures)
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