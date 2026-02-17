# Changelog

All notable changes to Fotolokashen iOS are documented in this file.

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

*For historical development notes, see `/docs/archive/`*
