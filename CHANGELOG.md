# Changelog

All notable changes to Fotolokashen iOS are documented in this file.

## [1.5.1] - 2026-04-26

### 🐛 Bug Fixes

#### OAuth Login & Register Redirect Loop (AuthService.swift)

- **Fixed**: Tapping Sign In or Create Account on iOS opened the browser but caused a visual reload/loop instead of presenting the login or registration form cleanly
- **Root cause 1 — stale shared cookies**: `ASWebAuthenticationSession` was configured with `prefersEphemeralWebBrowserSession = false`, causing it to share the Safari cookie jar. If the user had a previous (potentially expired) web session from browsing `fotolokashen.com` in Safari, that stale `auth_token` cookie was injected into every OAuth browser session, creating a conflict between the web app's auth state and the OAuth flow
- **Root cause 2 — `redirect_uri` mismatch**: `exchangeCodeForTokens()` sent `https://fotolokashen.com/app/auth-callback` as the `redirect_uri` on iOS 17.4+, but `startLogin()` always registered `fotolokashen://oauth-callback` with the authorize endpoint. The OAuth server rejected the mismatch, silently failing the code exchange while leaving the browser open
- **Fix 1**: Set `prefersEphemeralWebBrowserSession = true` — every auth session now starts with a clean, isolated cookie jar with no Safari state leakage
- **Fix 2**: Removed the iOS 17.4+ `redirect_uri` branch from `exchangeCodeForTokens()` — both the authorize request and token exchange now consistently use `fotolokashen://oauth-callback`

#### UI

- Shortened splash/login subtitle from "Location Scouting Made Simple" → "Location Scouting" (`ContentView.swift`)

---

## [1.5.0] - 2026-04-19

### ✨ Profile & Settings Restructure

#### Navigation Redesign
- **App Settings** section added directly to `ProfileView` — Preferences and Permissions now visible one level up, without needing to navigate into Account & Security
- **Preferences** (language, timezone, notifications) moved from Edit Profile → Account & Security up to Profile → App Settings
- **Permissions** section added to App Settings with live on/off toggles for:
  - GPS / Location
  - Camera
  - Photo Library
  - Notifications
- **App Version** moved out of Profile into the new dedicated **About** screen

#### About Screen (`AboutView`)
- New `AboutView` accessible from Profile tab
- Displays app version, build number, legal links, and brand info
- Fixed `Color.brandPurple` usage in `foregroundStyle` for consistent theming

#### Account & Security (`AccountSecurityView`)
- **Personal Details** card with display-only fields (name, username, email, DOB)
- **Edit Profile** sheet accessible from Account & Security (name, bio, city, country, language, timezone, notifications)
- Added `state` and `dateOfBirth` to iOS `User` model and all profile forms
- Fixed Swift compiler error: renamed `DetailRow` → `ProfileDetailRow` to resolve redeclaration conflict

#### Profile Tab
- Restructured as a top-level navigation hub with clearly separated subviews
- Preferences and Permissions now surfaced at Profile level under **App Settings**

---

### 📍 Create Location — Full Form Overhaul

- **Removed** "Photos" section header (implied by context)
- **Increased** photo strip margins to `12pt` for better visual breathing room
- **Added** required **Location Name** field (50-character limit with live counter)
- **Added** required **Location Details** field (500-character limit, multiline, with live counter)
- **Postal address layout**: Street on line 1, City/State abbreviated on line 2, 5-digit ZIP only (strips +4 extension)
- **Removed** GPS accuracy row from address display
- **Renamed** "Set Production Date" → "Production Date"
- Real-time validation: Save button disabled until both required fields are non-empty after trimming
- Pre-save sanitization: trims whitespace, collapses internal spaces, removes blank lines

---

### 🔒 Security Hardening

#### URL Injection Prevention
- Added `stripURLs()` helper using `NSRegularExpression` — strips `http://`, `https://`, and `www.` patterns from user text
- Applied to **Location Name** and **Location Details** in `saveLocation()` before API submission
- Complements server-side `sanitizeUserInput()` as defense-in-depth

#### Authentication Flow
- Fixed: Registration browser dismissed automatically on successful auto-login after email verification
- Added auto-login trigger after email verification deep link — skips manual login step
- Implemented deep link handler for `fotolokashen://email-verified?token=` scheme

---

### 🐛 Bug Fixes

- Fixed `ContentView` default tab set to Map (was previously showing wrong first tab)
- Fixed `Color.brandPurple` theming in `AboutView` and `CreateLocationView` (explicit `Color.brandPurple` instead of `.brand`)
- Fixed `AboutView` compile error: `ShapeStyle` has no member `brandPurple` → corrected to `Color.brandPurple`

---

### 📁 Files Changed

- **`CreateLocationView.swift`**: Full overhaul — Form layout, Location Name/Details fields, postal address formatting, sanitization/validation, `stripURLs()` helper
- **`ProfileView.swift`**: Restructured as navigation hub; App Settings section with Preferences + Permissions
- **`AccountSecurityView.swift`**: Personal Details card, Edit Profile integration, `ProfileDetailRow` rename
- **`AboutView.swift`** (NEW): Dedicated About screen with version, build, and brand info
- **`ContentView.swift`**: Updated tab default and tab structure
- **User model**: Added `state`, `dateOfBirth` fields

---

## [1.4.1] - 2026-02-23


### 🔧 Architecture Improvements & UI Enhancements

#### Unified LocationDetailView

- **Single Source of Truth**: Consolidated `LocationDetailView` now handles both owner mode and read-only mode (viewing others' public locations)
- **Removed `ProfileLocationDetailView`**: Deleted ~150 lines of duplicate code that was embedded in `PublicProfileView.swift`
- **Removed `ProfilePhotoGalleryView`**: Deleted ~140 lines of duplicate photo gallery code from `PublicProfileView.swift`
- **Two Initializers**:
  - `init(location:)` — Owner mode with Edit/Share buttons
  - `init(socialLocation:ownerUsername:ownerDisplayName:)` — Read-only mode for viewing others' locations
- **`isReadOnly` Flag**: Internal property controls toolbar visibility and editing capabilities

#### New AppIcons.swift

- **Centralized SF Symbol Names**: New `AppIcons` enum with 45+ icon constants for consistent icon usage across the app
- **Categories**: Navigation, Actions, Location Types, Camera, Profile, Settings, Social, Map, Status, Content
- **Preview Support**: Includes `#Preview` with visual icon grid for development reference
- **Usage Pattern**: `Image(systemName: AppIcons.edit)` instead of hardcoded strings

#### Address-to-Map Navigation

- **In-App Navigation**: Tapping address in `LocationDetailView` now navigates to Map tab and centers on location (was opening Apple Maps externally)
- **Dual Mode Support**: `showOnMap()` detects owner vs read-only mode and uses the appropriate focus property
  - Owner mode: Sets `LocationStore.shared.mapFocusLocation` → shows regular `LocationDetailView`
  - Read-only mode: Sets `LocationStore.shared.mapFocusReadOnlyContext` → shows full `LocationDetailView` in read-only mode with photos, owner info, etc.
- **New `ReadOnlyLocationContext` Struct**: Holds location, photos, and owner info for map navigation from read-only views
- **New `mapFocusReadOnlyContext` Property**: Added to `LocationStore` for social/friends' location focus
- **New LocationDetailView Initializer**: `init(readOnlyContext:)` accepts `ReadOnlyLocationContext` for map navigation
- **MapView Sheet Binding**: Added `.sheet(item: $selectedReadOnlyContext)` to show full detail view when navigating from public profiles

#### Code Reduction

- **~290 lines removed** from `PublicProfileView.swift` (was ~805 lines, now ~518 lines)
- **~145 lines removed** from `MapView.swift` by removing `SocialLocationDetailSheet` (now uses unified `LocationDetailView`)
- **Eliminated duplicate code paths** for location detail and photo gallery rendering
- **Single maintenance point** for location detail UI across owner and social contexts

#### Files Changed

- **`LocationDetailView.swift`**: Added second and third initializers for read-only mode, `isReadOnly` flag, `showOnMap()` method, uses `AppIcons` constants
  - `init(socialLocation:ownerUsername:ownerDisplayName:)` — from PublicProfileView
  - `init(readOnlyContext:)` — from Map navigation (social marker tap or address tap)
- **`LocationStore.swift`**: Added `ReadOnlyLocationContext` struct and `mapFocusReadOnlyContext` property
- **`MapView.swift`**:
  - Added `createReadOnlyContext(from:)` helper to convert `MapSocialLocation` to `ReadOnlyLocationContext`
  - Social marker tap now shows full `LocationDetailView` (was `SocialLocationDetailSheet`)
  - Removed `SocialLocationDetailSheet` (~145 lines) - no longer needed
  - Removed `selectedSocialLocation` state - replaced with `selectedReadOnlyContext`
- **`PublicProfileView.swift`**: Removed embedded `ProfileLocationDetailView` and `ProfilePhotoGalleryView`, now uses unified `LocationDetailView`
- **`AppIcons.swift`** (NEW): Centralized icon constants in `Services/` directory
- **`LocationRow.swift`**: Updated to use `AppIcons.share` constant

---

## [1.4.0] - 2026-02-17

### ✨ Phase 3: Social Features

#### New Features

- **People Search**: New "People" tab with Discover, Following, and Followers sub-tabs
- **User Discovery**: Search users by username, name, or city with debounced typeahead
- **Follow/Unfollow**: Follow and unfollow users directly from public profiles
- **Public Profiles**: View other users' profiles with banner, avatar, bio, follower/following counts, and public locations grid
- **Followers/Following Lists**: Paginated lists with infinite scroll, navigable to user profiles
- **Friends' Locations on Map**: Toggle purple markers on the map to see locations saved by people you follow
- **Social Location Detail**: Tap friend's location marker to see location info and navigate to the saver's profile
- **Profile Social Stats**: Followers and following counts displayed on your own Profile tab, tappable to view lists
- **Settings via Profile**: Settings accessible via gear icon in Profile toolbar (tab slot freed for People)

#### Architecture Changes

- **New `Social.swift` models**: `PublicUser`, `FollowStatus`, `FollowResponse`, `UnfollowResponse`, `FollowListUser`, `SearchUser`, `SocialLocation`, `MapSocialLocation`, `SocialLocationUser`, pagination models
- **New `FollowService`**: Singleton service handling follow/unfollow, follow status checks, public profiles, followers/following lists, social locations (public + friends), and people search
- **New `PublicProfileView`**: Full profile view for other users with banner, avatar, bio, follow button, stats, public locations grid
- **New `FollowListView`**: Reusable paginated list for followers/following with infinite scroll
- **New `PeopleSearchView`**: Tabbed search view with Discover (search), Following, and Followers tabs
- **New `SocialLocationClusterItem`**: GMUClusterItem subclass for friends' location markers (purple)
- **New `SocialLocationDetailSheet`**: Detail sheet for tapped social location markers with user info
- **`MarkerIconGenerator.socialMarker()`**: Purple person-icon markers for friends' locations
- **`LocationClusterRenderer` updated**: Handles both user markers and social markers
- **`MapView` updated**: Friends' locations toggle, social marker support, dual sheet bindings
- **`ProfileView` updated**: Social stats bar with followers/following counts, Settings gear button
- **`ContentView` updated**: 5-tab layout now Locations | Map | Capture | People | Profile (Settings moved into Profile)
- **`MapBounds` struct**: Viewport bounds for filtering social locations by geographic area

## [1.3.0] - 2026-02-17

### ✨ Phase 2: Location Editing & Enrichment

#### New Features

- **Edit Location**: Full edit form accessible via pencil button on location detail view
- **Production details**: Edit production notes, entry point, parking, access, indoor/outdoor, permanent status
- **Personal fields**: Favorite toggle, personal rating (1-5 stars), tags (comma-separated), personal caption
- **Photo management**: Mark photos for deletion with undo support; photos deleted on save
- **Type filter**: Horizontal scrollable filter chips on location list (All, Favorites, per-type)
- **Location type update**: Replaced outdated 6-type enum with actual 15 types matching web app

#### Architecture Changes

- **`Location` model expanded**: Added `productionNotes`, `entryPoint`, `parking`, `access`, `indoorOutdoor`, `isPermanent`, `number` (street number), and UserSave fields (`color`, `isFavorite`, `personalRating`, `caption`, `tags`, `visibility`) directly on the model
- **`UpdateLocationRequest` expanded**: Now includes all PATCH-able fields (Location + UserSave) in a single request
- **`UpdateLocationResponse` model**: New response model matching `PATCH /api/locations/{id}` response shape
- **`LocationType` enum rewritten**: 15 real types (BROLL, STORY, INTERVIEW, etc.) replacing outdated generic types
- **`LocationService.updateLocation()`**: New method calling `PATCH /api/locations/{id}` for both Location and UserSave fields
- **`LocationService.deletePhoto()`**: New method calling `DELETE /api/photos/{id}`
- **`LocationStore.updateLocation()`**: Wraps service call and updates local array in-place
- **`LocationStore.deletePhoto()`**: Delete photo and refresh location data
- **`LocationsResponse.unwrappedLocations`**: Now carries UserSave fields (color, isFavorite, personalRating, caption, tags, visibility) onto Location objects
- **New `EditLocationView`**: Comprehensive edit form with all fields, tag chips, star rating, photo deletion
- **New `FilterChip` component**: Reusable chip button for type/favorite filtering
- **`LocationDetailView` updated**: Added edit button, uses `currentLocation` state for live updates after editing

## [1.2.0] - 2026-02-17

### ✨ Phase 1: User Profile & Settings

#### New Features

- **Profile tab**: View and edit profile with banner/avatar display, personal info, location, and preferences
- **Settings tab**: Privacy controls, account info, app version, and logout
- **Avatar upload**: Pick from photo library, auto-compress, upload via secure server pipeline (`POST /api/auth/avatar`)
- **Avatar delete**: Remove avatar with confirmation (`DELETE /api/auth/avatar`)
- **Banner upload**: Pick from photo library, auto-compress, upload via secure server pipeline (`POST /api/auth/banner`)
- **Banner delete**: Remove banner with confirmation (`DELETE /api/auth/banner`)
- **Profile editing**: First name, last name, bio, city, country, language, timezone, email notifications
- **Privacy controls**: Profile visibility (public/followers/private), appear in search, show location, saved locations visibility, allow follow requests
- **Change tracking**: Unsaved changes detection with Save button in nav bar
- **Image picker**: UIImagePickerController wrapper with edit support

#### Architecture Changes

- **New `UserService`**: Singleton service for profile CRUD and avatar/banner uploads with multipart form data
- **New `ProfileView`**: Full profile editing with banner+avatar header, form sections, image upload
- **New `SettingsView`**: Privacy controls, account info, logout (replaces old `BrandTabView`)
- **User model expanded**: Added `bio`, `role`, `updatedAt`, privacy fields (`profileVisibility`, `showInSearch`, `showLocation`, `showSavedLocations`, `allowFollowRequests`), onboarding fields, and `initials` computed property
- **New request/response models**: `ProfileUpdateRequest`, `PrivacyUpdateRequest`, `ImageUploadResponse`, `V1MeResponse`
- **APIClient.patch()**: New PATCH method for profile and privacy updates
- **APIClient.put()**: New PUT method for future use
- **Switched to `/api/v1/users/me`**: `getCurrentUser()` now fetches rich user data including bio, privacy settings, and onboarding state (was `/api/auth/me`)

#### Tab Bar Redesign

- Removed `BrandTabView` (Home tab) — was placeholder with app branding
- New 5-tab layout: **Locations** | **Map** | **Capture** | **Profile** | **Settings**
- Tab bar uses brand purple tint
- Logout moved from Home tab toolbar to Settings tab

## [1.1.1] - 2026-02-17

### 🔒 Security Hardening & Codebase Cleanup

#### Security Fixes

- **Debug logging gated behind `#if DEBUG`**: All `print()` statements in `APIClient.swift`, `AuthService.swift`, `PhotoUploadService.swift`, and `ConfigLoader.swift` are now wrapped in `#if DEBUG` compiler flags to prevent any logging in release builds
- **Token logging removed**: `APIClient.swift` no longer logs token prefixes — uses `[REDACTED]` placeholder instead
- **API key removed from Info.plist**: Hardcoded Google Maps API key replaced with build configuration variable `$(GOOGLE_MAPS_API_KEY)` — key should be set via `.xcconfig` file
- **Config.plist remains gitignored**: Verified `.gitignore` properly excludes `Config.plist` and `**/Config.plist`

#### Codebase Cleanup

- **Removed duplicate model files**: Deleted stale `fotolokashen/swift-utilities/Models/` directory (contained outdated copies of `User.swift`, `Location.swift`, `Photo.swift`, `OAuthToken.swift` with incorrect non-optional types). Single source of truth now at `fotolokashen/fotolokashen/swift-utilities/Models/`
- **Fixed `.github` directory**: Renamed `.gitbhub/` → `.github/` (typo fix)
- **Updated copilot-instructions.md**: Comprehensive rewrite with full architecture documentation, security checklist, API reference, development patterns, and phased roadmap

#### Dependency Notes

- **Kingfisher** and **ImageKit iOS SDK** are SPM dependencies but unused in code — to be removed via Xcode Package Dependencies UI

#### Documentation

- Updated `CHANGELOG.md` with security fixes and phased roadmap
- Updated `README.md` with current features and corrected setup instructions
- Rewrote `.github/copilot-instructions.md` with comprehensive project documentation

### Planned Phases (Feature Parity with Web App)

#### Phase 1: User Profile & Settings

- Profile editing (bio, city, country, language, timezone)
- Avatar/banner upload via secure pipeline
- Privacy controls
- Switch to richer `/api/v1/users/me` endpoint

#### Phase 2: Location Editing & Enrichment

- Edit existing locations (production notes, entry point, parking, access, indoor/outdoor)
- Favorites, tags, personal ratings, color, visibility
- Photo deletion from locations
- Type-based filtering on location list

#### Phase 3: Social Features

- Follow/unfollow users
- Public user profiles
- Followers/following lists
- Public & friends' locations on map

#### Phase 4: Search & Onboarding

- People search with typeahead suggestions
- Terms of Service acceptance (blocking modal)
- Onboarding walkthrough

#### Phase 5: AI & Support

- AI description improvement
- AI tag suggestions
- In-app member support form

---

## [1.1.0] - 2026-02-13

### 🔒 Security Enhancement - Secure Photo Upload

#### Changed

- **Photo Upload Flow**: Replaced direct-to-CDN uploads with server-mediated secure endpoint
  - All uploads now route through `/api/photos/upload` for security validation
  - Photos are associated with locations via `/api/locations/{id}/photos` endpoint
  - Removed legacy request-upload + confirm flow

#### Security Features Added

- ✅ **Virus Scanning**: ClamAV scans all uploads before reaching CDN
- ✅ **Server-Side Format Validation**: MIME type and file extension validated server-side
- ✅ **HEIC/TIFF Conversion**: Automatic conversion to web-compatible JPEG format
- ✅ **EXIF Metadata Sanitization**: All metadata strings sanitized to prevent XSS attacks
- ✅ **Orphan File Prevention**: Photos only created in database after successful upload

#### Technical Changes

- Updated `PhotoUploadService.swift` to use `/api/photos/upload` endpoint
- Added new response models: `SecureUploadResponse`, `SecureUploadDetails`, `SecureFileDetails`, `SecurePhotoMetadata`
- Added `AssociatePhotoRequest` for linking uploaded photos to locations
- Retained legacy `ImageKitUploadResponse` for backwards compatibility

#### Documentation

- Added `IOS_PHOTO_UPLOAD_SECURITY_REVIEW.md` with implementation details
- Updated upload flow diagrams in README

### Breaking Changes

- None - backwards compatible with existing functionality

---

## [1.0.0] - 2025-01-16

### 🎉 Initial Release

First production release of the Fotolokashen iOS app - a location-based photo management companion to the web application.

### Features

#### Camera & Capture

- Full-screen camera interface with device rotation support
- Photo capture with EXIF metadata extraction (GPS, timestamps)
- Location type selection (15 types with custom camera icons) 
- Name, description, and tag fields for each location 

#### Map & Locations

- Google Maps SDK integration with full gesture support
- Custom camera marker icons matching web app design
- Marker clustering for dense location areas
- Location list view with detail cards
- Tap markers to view location details 

#### Authentication & Sync

- OAuth2 + PKCE authentication via Safari
- Secure token storage in iOS Keychain
- Auto-logout when session invalidated on another device
- Automatic sync when app becomes active 

#### Geocoding

- Google Maps Geocoding API (primary)
- Apple CLGeocoder fallback (no API key required)
- Full address component extraction:
  - Street number and name
  - City, state, zip code
  - Google Place ID or Apple fallback ID 

#### Photo Upload

- ImageKit integration for cloud storage
- Server-signed upload URLs
- JPEG compression with quality optimization 
- Upload progress feedback 

### Technical Stack

- SwiftUI with iOS 17+ deployment target 
- SwiftData for local caching
- Google Maps SDK for iOS
- GMUClusterManager for marker clustering
- Async/await concurrency

### Known Limitations

- Google Maps Geocoding may return REQUEST_DENIED due to IP restrictions (Apple fallback handles this)
- Requires camera and location permissions

---

_For historical development notes, see `/docs/archive/`_
