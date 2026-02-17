# fotolokashen iOS v1.1.1

iOS companion app for fotolokashen - A camera-first location scouting app for photographers and film crews.

## Overview

The fotolokashen iOS app allows users to quickly capture photos with GPS coordinates, automatically geocode addresses, and upload locations to the fotolokashen platform. Designed for field use by photographers, videographers, and location scouts.

## ✅ v1.0 Features

### Camera & Capture
- 📷 **Camera-First Workflow** - Quick capture with automatic GPS tagging
- 📍 **Live GPS Tracking** - Real-time location accuracy display
- 🗺️ **Auto Geocoding** - Address lookup via Apple CLGeocoder (with Google Maps fallback)
- 📊 **Full Address Parsing** - Captures street, city, state, zipcode

### Map & Locations
- 🗺️ **Interactive Map** - Google Maps SDK with custom markers
- 📍 **Custom Camera Markers** - Color-coded by location type (15 types)
- 🔍 **Marker Clustering** - Groups nearby locations at low zoom
- 📋 **Location List** - Searchable, sortable list view
- 🎨 **Consistent Type Colors** - Matches web app color scheme

### Authentication & Sync
- 🔐 **OAuth2 with PKCE** - Secure Safari-based login
- 🔄 **Auto Sync** - Locations sync on app launch
- 📱 **Multi-Device Support** - Auto-logout on session invalidation
- 🔑 **Secure Storage** - Tokens stored in iOS Keychain

### Photo Upload
- 📤 **Smart Compression** - Optimizes images before upload
- 🔒 **Secure Server Upload** - Virus scanning and format validation
- ☁️ **ImageKit Integration** - Server-mediated cloud storage
- 📸 **EXIF Preservation** - Maintains camera metadata (sanitized)
- 🛡️ **Security Features** - HEIC/TIFF conversion, XSS prevention

## Tech Stack

| Technology | Purpose |
|------------|---------|
| SwiftUI | Declarative UI framework |
| Swift Concurrency | async/await for networking |
| Google Maps SDK | Map display and clustering |
| Apple CLGeocoder | Address lookup (primary) |
| ImageKit | Cloud image storage |
| SwiftData | Local caching (iOS 17+) |
| Keychain | Secure token storage |

## Project Structure

```
fotolokashen-ios/
├── fotolokashen/
│   └── fotolokashen/
│       ├── fotolokashenApp.swift      # App entry point
│       ├── ContentView.swift          # Main tab view
│       ├── Views/
│       │   ├── CameraView.swift       # Camera capture
│       │   ├── CreateLocationView.swift
│       │   ├── MapView.swift          # Google Maps
│       │   ├── LocationListView.swift
│       │   ├── LocationDetailView.swift
│       │   └── LocationRow.swift
│       ├── Services/
│       │   ├── LocationStore.swift    # Shared state
│       │   ├── LocationTypeColors.swift # Centralized colors
│       │   ├── MarkerIconGenerator.swift # Custom markers
│       │   ├── SyncService.swift
│       │   └── DataManager.swift
│       └── swift-utilities/
│           ├── Models/
│           │   └── Location.swift
│           ├── APIClient.swift
│           ├── AuthService.swift
│           ├── LocationService.swift
│           ├── PhotoUploadService.swift
│           ├── CameraService.swift
│           ├── LocationManager.swift
│           └── KeychainService.swift
├── Config.plist                       # API configuration
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

| Type | Color | Icon |
|------|-------|------|
| BROLL | Blue (#3B82F6) | video |
| STORY | Green (#22C55E) | doc.text |
| INTERVIEW | Yellow (#EAB308) | mic |
| LIVE ANCHOR | Orange (#F97316) | antenna.radiowaves.left.and.right |
| REPORTER LIVE | Orange (#F97316) | person.wave.2 |
| STAKEOUT | Red (#EF4444) | eye |
| DRONE | Purple (#8B5CF6) | airplane |
| SCENE | Pink (#EC4899) | film |
| EVENT | Indigo (#6366F1) | calendar |
| BATHROOM | Cyan (#06B6D4) | toilet |
| OTHER | Gray (#6B7280) | ellipsis.circle |
| HQ | Emerald (#10B981) | building.2 |
| BUREAU | Teal (#14B8A6) | building |
| REMOTE STAFF | Sky (#0EA5E9) | person.crop.circle |
| STORAGE | Amber (#F59E0B) | archivebox |

## Backend Integration

### API Endpoints Used

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/photos/upload` | POST | Secure photo upload with virus scanning |
| `/api/auth/me` | GET | Get current user |
| `/api/auth/oauth/token` | POST | Exchange auth code for tokens |
| `/api/auth/oauth/revoke` | POST | Revoke tokens on logout |
| `/api/locations` | GET | Fetch user's locations |
| `/api/locations` | POST | Create new location |
| `/api/locations/{id}` | GET | Get location details |
| `/api/locations/{id}` | DELETE | Delete location |
| `/api/locations/{id}/photos` | POST | Associate uploaded photo with location |

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

| Feature | Description |
|---------|-------------|
| **Virus Scanning** | All uploads scanned by ClamAV before reaching CDN |
| **Format Validation** | Server validates MIME type and file extension |
| **Format Conversion** | HEIC/TIFF automatically converted to JPEG |
| **Metadata Sanitization** | EXIF strings sanitized to prevent XSS attacks |
| **Orphan Prevention** | Photos only created in DB after successful upload |

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
- ✅ OAuth2 authentication with PKCE
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

**Version**: 1.1.1  
**Last Updated**: February 17, 2026  
**Status**: ✅ Production Ready (Security Hardened)
