# fotolokashen iOS v1.4.1

iOS companion app for fotolokashen - A camera-first location scouting app for photographers and film crews.

## Overview

The fotolokashen iOS app allows users to quickly capture photos with GPS coordinates, automatically geocode addresses, and upload locations to the fotolokashen platform. Designed for field use by photographers, videographers, and location scouts.

## Features

### v1.4 — Social Features

- 👥 **People Search** - Discover users by username, name, or city with typeahead search
- 🤝 **Follow System** - Follow/unfollow users and view public profiles
- 📊 **Social Stats** - View follower/following counts and lists with infinite scroll
- 🗺️ **Friends' Locations** - Toggle purple markers on map to see locations from people you follow
- 📱 **Public Profiles** - View other users' profiles with banner, avatar, bio, and public locations
- 🔗 **Deep Linking** - Share locations via custom URL scheme and Universal Links
- 📐 **5-Tab Layout** - Locations | Map | Capture | People | Profile (Settings via gear icon)

### v1.3 — Location Editing & Enrichment

- ✏️ **Full Location Editing** - Edit all location fields including production notes, entry point, parking, access
- ⭐ **Personal Enrichment** - Add favorites, personal ratings (1-5 stars), tags, and captions
- 🗑️ **Photo Management** - Mark photos for deletion and remove them when saving
- 🏷️ **Type Filtering** - Filter location list by type or favorites with horizontal chips
- 🎨 **15 Location Types** - Updated to match web app (BROLL, STORY, INTERVIEW, etc.)

### v1.2 — Profile & Settings

- 👤 **Profile Editing** - Bio, city, country, language, timezone, email notifications
- 🖼️ **Avatar & Banner Upload** - Pick from library, auto-compress, secure server upload
- 🔒 **Privacy Controls** - Profile visibility, search visibility, location sharing, follow requests
- ⚙️ **Settings Integration** - Settings accessible via Profile tab gear icon

### v1.0 — Core Features

#### Camera & Capture

- 📷 **Camera-First Workflow** - Quick capture with automatic GPS tagging
- 📍 **Live GPS Tracking** - Real-time location accuracy display
- 🗺️ **Auto Geocoding** - Address lookup via Apple CLGeocoder (with Google Maps fallback)
- 📊 **Full Address Parsing** - Captures street, city, state, zipcode

#### Map & Locations

- 🗺️ **Interactive Map** - Google Maps SDK with custom markers
- 📍 **Custom Camera Markers** - Color-coded by location type (15 types)
- 🔍 **Marker Clustering** - Groups nearby locations at low zoom
- 📋 **Location List** - Searchable, sortable list view
- 🎨 **Consistent Type Colors** - Matches web app color scheme

#### Authentication & Sync

- 🔐 **OAuth2 with PKCE** - Secure in-app browser login (`ASWebAuthenticationSession`)
- 🔄 **Auto Sync** - Locations sync on app launch
- 📱 **Multi-Device Support** - Auto-logout on session invalidation
- 🔑 **Secure Storage** - Tokens stored in iOS Keychain

#### Deep Linking

- 🔗 **Custom URL Scheme** - `fotolokashen://location/123` for app-to-app sharing
- 🌐 **Universal Links** - `https://fotolokashen.com/shared/123` for web-to-app
- 🚀 **Direct Navigation** - Deep links open location detail views directly

#### Photo Upload

- 📤 **Smart Compression** - Optimizes images before upload
- 🔒 **Secure Server Upload** - Virus scanning and format validation
- ☁️ **ImageKit Integration** - Server-mediated cloud storage
- 📸 **EXIF Preservation** - Maintains camera metadata (sanitized)
- 🛡️ **Security Features** - HEIC/TIFF conversion, XSS prevention

## Tech Stack

| Technology        | Purpose                             |
| ----------------- | ----------------------------------- |
| SwiftUI           | Declarative UI framework            |
| Swift Concurrency | async/await for networking          |
| Google Maps SDK   | Map display and clustering          |
| Apple CLGeocoder  | Address lookup (primary)            |
| ImageKit          | Cloud image storage                 |
| SwiftData         | Local caching (iOS 17+)             |
| Keychain          | Secure token storage                |
| Deep Linking      | Custom URL scheme + Universal Links |

## Project Structure

```
fotolokashen-ios/
├── fotolokashen/
│   └── fotolokashen/
│       ├── fotolokashenApp.swift      # App entry point
│       ├── ContentView.swift          # 5-tab layout + navigateToMapTab notification
│       ├── Views/
│       │   ├── CameraView.swift       # Camera capture
│       │   ├── CameraPreview.swift    # AVCaptureVideoPreviewLayer wrapper
│       │   ├── CreateLocationView.swift
│       │   ├── EditLocationView.swift # Full location edit form
│       │   ├── MapView.swift          # Google Maps + friends' locations toggle
│       │   ├── LocationListView.swift # Searchable list with type filter chips
│       │   ├── LocationDetailView.swift # Unified view (owner + read-only modes)
│       │   ├── LocationRow.swift      # List row with share button
│       │   ├── LocationClusterItem.swift # GMUClusterItem + renderer
│       │   ├── ProfileView.swift      # Profile editing + avatar/banner + social stats
│       │   ├── PublicProfileView.swift # Other users' profiles (uses unified LocationDetailView)
│       │   ├── PeopleSearchView.swift # Discover/Following/Followers tabs
│       │   ├── FollowListView.swift   # Paginated followers/following list
│       │   ├── SettingsView.swift     # Privacy controls + logout
│       │   ├── LocationDetailSubviews.swift # Extracted: PhotoGallery, SectionHeader, DetailRow
│       │   └── ProfileHeaderComponents.swift # Shared: Banner, Avatar, StatItem, FormField, ImagePicker
│       ├── Services/
│       │   ├── AppColors.swift        # Centralized semantic color tokens
│       │   ├── AppIcons.swift         # Centralized SF Symbol icon names (45+ constants)
│       │   ├── LocationStore.swift    # Shared state + mapFocusLocation
│       │   ├── LocationTypeColors.swift # 15 type→color mappings
│       │   ├── MarkerIconGenerator.swift # Custom camera + social markers
│       │   ├── UserService.swift      # Profile CRUD + avatar/banner upload
│       │   ├── SyncService.swift      # Download locations + upload queued photos
│       │   ├── FollowService.swift    # Follow/unfollow, profiles, search, social locations
│       │   ├── DeepLinkManager.swift  # Deep link routing (URL scheme + Universal Links)
│       │   ├── GeocodingService.swift # Extracted: Dual geocoding (Google → Apple fallback)
│       │   ├── NetworkMonitor.swift   # NWPathMonitor connectivity
│       │   ├── PlacesService.swift    # CLGeocoder reverse geocoding
│       │   ├── GeographicClusterAlgorithm.swift # Custom clustering algorithm
│       │   ├── StaticMapHelper.swift  # Static map image generation
│       │   └── DataManager.swift      # SwiftData container (iOS 17+)
│       └── swift-utilities/
│           ├── Models/
│           │   ├── Location.swift
│           │   └── User.swift         # User + profile/privacy request types
│           ├── APIClient.swift        # GET/POST/PATCH/PUT/DELETE
│           ├── AuthService.swift
│           ├── LocationService.swift   # CRUD + updates (geocoding extracted)
│           ├── PhotoUploadService.swift
│           ├── CameraService.swift
│           ├── LocationManager.swift
│           └── KeychainService.swift
├── Config.plist                       # API configuration (gitignored)
└── docs/                              # Documentation archive
```

## Getting Started

### Prerequisites

- macOS 14.0+ (Sonoma)
- Xcode 15.0+
- iOS 16.0+ deployment target
- fotolokashen account
- Google Maps API key (Maps SDK for iOS enabled)

### Setup

1. **Clone the repository**

   ```bash
   git clone https://github.com/rgriola/fotolokashen-ios.git
   cd fotolokashen-ios
   ```

2. **Configure API Keys**

   ```bash
   cp Config.example.plist Config.plist
   ```

   Edit `Config.plist` and add:
   - `googleMapsAPIKey` - Your Google Maps API key
   - `backendBaseURL` - Backend URL (default: `https://fotolokashen.com`)

   **Important**: The Google Maps key in `Info.plist` reads from `$(GOOGLE_MAPS_API_KEY)`.
   Set this in your Xcode build settings or create a `.xcconfig` file:

   ```
   // Debug.xcconfig
   GOOGLE_MAPS_API_KEY = YOUR_KEY_HERE
   ```

3. **Open in Xcode**

   ```bash
   open fotolokashen/fotolokashen.xcodeproj
   ```

4. **Build and Run**
   - Select your target device/simulator
   - Press ⌘+R

## Configuration

### Config.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>BackendURL</key>
    <string>https://fotolokashen.com</string>

    <key>GoogleMapsAPIKey</key>
    <string>YOUR_GOOGLE_MAPS_API_KEY</string>

    <key>OAuth2ClientID</key>
    <string>fotolokashen-ios</string>

    <key>OAuth2RedirectURI</key>
    <string>fotolokashen://oauth-callback</string>

    <key>EnableDebugLogging</key>
    <true/>
</dict>
</plist>
```

## Location Types

The app supports 15 location types with consistent colors across iOS and web:

| Type          | Color             | Icon                              |
| ------------- | ----------------- | --------------------------------- |
| BROLL         | Blue (#3B82F6)    | video                             |
| STORY         | Green (#22C55E)   | doc.text                          |
| INTERVIEW     | Yellow (#EAB308)  | mic                               |
| LIVE ANCHOR   | Orange (#F97316)  | antenna.radiowaves.left.and.right |
| REPORTER LIVE | Orange (#F97316)  | person.wave.2                     |
| STAKEOUT      | Red (#EF4444)     | eye                               |
| DRONE         | Purple (#8B5CF6)  | airplane                          |
| SCENE         | Pink (#EC4899)    | film                              |
| EVENT         | Indigo (#6366F1)  | calendar                          |
| BATHROOM      | Cyan (#06B6D4)    | toilet                            |
| OTHER         | Gray (#6B7280)    | ellipsis.circle                   |
| HQ            | Emerald (#10B981) | building.2                        |
| BUREAU        | Teal (#14B8A6)    | building                          |
| REMOTE STAFF  | Sky (#0EA5E9)     | person.crop.circle                |
| STORAGE       | Amber (#F59E0B)   | archivebox                        |

## Backend Integration

### API Endpoints Used

| Endpoint                                    | Method | Purpose                                 |
| ------------------------------------------- | ------ | --------------------------------------- |
| `/api/photos/upload`                        | POST   | Secure photo upload with virus scanning |
| `/api/v1/users/me`                          | GET    | Get current user (rich profile)         |
| `/api/v1/users/me`                          | PATCH  | Update profile & privacy settings       |
| `/api/auth/avatar`                          | POST   | Upload avatar (FormData)                |
| `/api/auth/avatar`                          | DELETE | Remove avatar                           |
| `/api/auth/banner`                          | POST   | Upload banner (FormData)                |
| `/api/auth/banner`                          | DELETE | Remove banner                           |
| `/api/auth/oauth/token`                     | POST   | Exchange auth code for tokens           |
| `/api/auth/oauth/revoke`                    | POST   | Revoke tokens on logout                 |
| `/api/locations`                            | GET    | Fetch user's locations                  |
| `/api/locations`                            | POST   | Create new location                     |
| `/api/locations/{id}`                       | GET    | Get location details                    |
| `/api/locations/{id}`                       | PATCH  | Update location and UserSave fields     |
| `/api/locations/{id}`                       | DELETE | Delete location                         |
| `/api/locations/{id}/photos`                | POST   | Associate uploaded photo with location  |
| `/api/photos/{id}`                          | DELETE | Delete a photo                          |
| `/api/v1/users/{username}`                  | GET    | Fetch public profile                    |
| `/api/v1/users/{username}/follow`           | POST   | Follow user                             |
| `/api/v1/users/{username}/unfollow`         | POST   | Unfollow user                           |
| `/api/v1/users/me/follow-status/{username}` | GET    | Check follow relationship               |
| `/api/v1/users/{username}/followers`        | GET    | Paginated followers list                |
| `/api/v1/users/{username}/following`        | GET    | Paginated following list                |
| `/api/v1/users/{username}/locations`        | GET    | User's public locations                 |
| `/api/v1/locations/public`                  | GET    | All public locations (with bounds)      |
| `/api/v1/locations/friends`                 | GET    | Friends' locations (privacy-enforced)   |
| `/api/v1/search/users`                      | GET    | User search (username/bio/geo)          |
| `/api/v1/search/suggestions`                | GET    | Username autocomplete                   |

### Photo Upload Flow (v1.1+)

```
1. Capture photo with GPS
2. Compress image locally (~1.3MB)
3. Upload to /api/photos/upload
   - Server performs virus scan (ClamAV)
   - Format validation (MIME + extension)
   - HEIC/TIFF → JPEG conversion
   - Additional compression if needed
   - EXIF metadata sanitization
4. Server uploads to ImageKit CDN
5. Associate photo with location via /api/locations/{id}/photos
6. Location saved with photo reference
```

#### Security Features

| Feature                   | Description                                       |
| ------------------------- | ------------------------------------------------- |
| **Virus Scanning**        | All uploads scanned by ClamAV before reaching CDN |
| **Format Validation**     | Server validates MIME type and file extension     |
| **Format Conversion**     | HEIC/TIFF automatically converted to JPEG         |
| **Metadata Sanitization** | EXIF strings sanitized to prevent XSS attacks     |
| **Orphan Prevention**     | Photos only created in DB after successful upload |

## Troubleshooting

### Camera Issues

- **Simulator**: Uses test images; real camera works on devices only
- **Permissions**: Check Settings → fotolokashen → Camera

### GPS Issues

- **Simulator**: Uses simulated location (set in Xcode: Features → Location)
- **Accuracy**: Wait for accuracy < 10m for best results

### Authentication Issues

- **401 Errors**: Token expired; app will auto-logout
- **Login fails**: Verify backend URL in Config.plist
- **Browser sheet won't open**: Ensure `fotolokashen` URL scheme is registered in Info.plist

### Map Issues

- **Blank map**: Check Google Maps API key is valid
- **No markers**: Pull down to refresh locations

## Development

### Debug Logging

Enable in `Config.plist`:

```xml
<key>EnableDebugLogging</key>
<true/>
```

View logs in Xcode console with prefixes:

- `[APIClient]` - Network requests
- `[LocationService]` - Location CRUD
- `[LocationStore]` - State management
- `[CameraService]` - Camera capture
- `📍` - Geocoding operations
- `🌍` - Google Geocoding
- `🍎` - Apple Geocoding
- `💾` - Save operations

### Building for Release

1. Set `EnableDebugLogging` to `false`
2. Select "Any iOS Device" as target
3. Product → Archive
4. Distribute via TestFlight or App Store

## Version History

### v1.4.1 (February 2026)

- 🔧 **Unified LocationDetailView** — Single view handles both owner mode (Edit/Share buttons) and read-only mode (viewing others' locations)
- 🎨 **AppIcons.swift** — New centralized SF Symbol constants (45+ icons) for consistent icon usage
- 🗺️ **Address-to-Map Navigation** — Tapping address navigates to in-app Map tab instead of opening Apple Maps
- 🧹 **Code Cleanup** — Removed ~290 lines of duplicate code (`ProfileLocationDetailView`, `ProfilePhotoGalleryView`) from `PublicProfileView.swift`
- 📐 **PublicProfileView Simplified** — Now uses unified `LocationDetailView` instead of embedded duplicate views

### v1.4.0 (February 2026)

- 👥 **People Search** — New People tab with Discover, Following, and Followers sub-tabs
- 🔗 **Deep Linking** — Custom URL scheme and Universal Links support for location sharing
- 🤝 **Follow System** — Follow/unfollow users with public profile views
- 📊 **Social Stats** — Followers/following counts and lists with infinite scroll pagination
- 🗺️ **Friends' Locations** — Toggle purple markers on map to see locations from people you follow
- 🎨 **Social Markers** — Custom purple person-icon markers for friends' locations
- 📱 **5-Tab Layout Updated** — Locations | Map | Capture | People | Profile (Settings moved to Profile gear icon)

### v1.3.0 (February 2026)

- ✏️ **Full Location Editing** — Edit all fields including production notes, entry point, parking, access, indoor/outdoor
- ⭐ **Personal Enrichment** — Favorites, personal ratings (1-5 stars), tags, captions, color, visibility
- 🗑️ **Photo Deletion** — Mark photos for deletion and remove them when saving changes
- 🏷️ **Type Filtering** — Filter location list by type or favorites with horizontal scrollable chips
- 🎨 **15 Location Types** — Replaced outdated 6-type enum with actual 15 types matching web app
- 🔧 **Location Model Expanded** — Added UserSave fields directly on Location model for easier access
- 📝 **Update API** — New `PATCH /api/locations/{id}` updates both Location and UserSave in one call

### v1.2.0 (February 2026)

- ✨ **Profile & Settings** — Full profile editing with avatar/banner upload and privacy controls
- 📐 **5-Tab Layout** — Locations | Map | Capture | Profile | Settings
- 🔌 **Rich User Data** — Switched to `/api/v1/users/me` for bio, privacy settings, onboarding state
- 🔧 **APIClient PATCH/PUT** — New HTTP methods for profile and privacy updates
- 🔒 **Privacy Controls** — Profile visibility, search, location sharing, follow requests

### v1.1.1 (February 2026)

- 🔒 **Security Hardening** — All debug logging gated behind `#if DEBUG` compiler flags
- 🔑 **API Key Protection** — Hardcoded key removed from Info.plist, uses build config variable
- 🧹 **Codebase Cleanup** — Removed duplicate model files, fixed `.github` directory typo
- 📋 **Documentation** — Comprehensive rewrite of copilot-instructions.md with phased roadmap

### v1.1 (February 2026)

- 🔒 **Secure Photo Upload** - Server-mediated upload with virus scanning
- 🛡️ **Format Validation** - Server-side MIME type and extension checks
- 🔄 **HEIC/TIFF Support** - Automatic conversion to JPEG
- 🧹 **EXIF Sanitization** - XSS prevention for metadata fields
- 📋 **Upload Security Documentation** - See `docs/IOS_PHOTO_UPLOAD_SECURITY_REVIEW.md`

### v1.0 (January 2026)

- ✅ OAuth2 authentication with PKCE (in-app browser via `ASWebAuthenticationSession`)
- ✅ Camera capture with GPS tracking
- ✅ Auto geocoding (Apple + Google fallback)
- ✅ Full address component capture (street, city, state, zip)
- ✅ Google Maps with custom camera markers
- ✅ Marker clustering
- ✅ Location list with search/sort
- ✅ Photo upload to ImageKit
- ✅ Multi-device session management
- ✅ Auto-sync on app launch
- ✅ Consistent type colors with web app

## Links

- **Web App**: [fotolokashen.com](https://fotolokashen.com)
- **Backend Repo**: [github.com/rgriola/fotolokashen](https://github.com/rgriola/fotolokashen)

## License

Proprietary - All rights reserved

---

**Version**: 1.4.1  
**Last Updated**: February 23, 2026  
**Status**: ✅ Production Ready
