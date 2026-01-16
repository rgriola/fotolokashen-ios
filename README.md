# fotolokashen iOS

iOS companion app for fotolokashen - A camera-first location scouting and photo management app.

## Overview

The fotolokashen iOS app is a mobile companion to the fotolokashen web platform, designed for photographers and location scouts to capture, tag, and upload photos directly from their iPhone.

## Features

- 📷 **Camera-First Workflow** - Quick capture with automatic GPS tagging
- 🗺️ **Location Management** - Browse and manage saved locations
- 🔐 **Secure Authentication** - OAuth2 with PKCE for secure login
- 📤 **Smart Upload** - Automatic image compression and ImageKit integration
- 🎯 **EXIF Metadata** - Preserve camera settings and GPS coordinates
- 📍 **Geocoding** - Automatic address lookup from GPS coordinates

## Tech Stack

- **SwiftUI** - Modern declarative UI
- **Swift Concurrency** - async/await for clean async code
- **MVVM Architecture** - Clean separation of concerns
- **Google Maps SDK** - Geocoding and location services
- **KeychainAccess** - Secure token storage
- **ImageKit** - Cloud-based image storage and optimization

## Project Structure

```
fotolokashen-ios/
├── fotolokashen/
│   ├── fotolokashen/
│   │   ├── App/                    # App entry point
│   │   ├── Views/                  # SwiftUI views
│   │   │   ├── CameraView.swift
│   │   │   ├── CreateLocationView.swift
│   │   │   └── LoginView.swift
│   │   └── swift-utilities/        # Core services
│   │       ├── Models/             # Data models
│   │       ├── APIClient.swift     # Network client
│   │       ├── AuthService.swift   # OAuth2 authentication
│   │       ├── LocationService.swift
│   │       ├── PhotoUploadService.swift
│   │       ├── CameraService.swift
│   │       ├── LocationManager.swift
│   │       └── KeychainService.swift
│   └── Config.plist                # API keys and configuration
└── docs/                           # Documentation
```

## Getting Started

### Prerequisites

- macOS 13.0 or later
- Xcode 15.0 or later
- iOS 16.0+ deployment target
- Active fotolokashen account
- Google Maps API key

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/rgriola/fotolokashen-ios.git
   cd fotolokashen-ios
   ```

2. **Open in Xcode**
   ```bash
   open fotolokashen/fotolokashen.xcodeproj
   ```

3. **Configure API Keys**
   - Copy `Config.example.plist` to `Config.plist`
   - Add your Google Maps API key
   - Configure backend URL (default: `https://fotolokashen.com`)

4. **Build and Run**
   - Select a simulator or device
   - Press ⌘+R to build and run

## Configuration

The app uses `Config.plist` for configuration:

```xml
<key>BackendURL</key>
<string>https://fotolokashen.com</string>

<key>GoogleMapsAPIKey</key>
<string>YOUR_API_KEY_HERE</string>

<key>OAuth2ClientID</key>
<string>fotolokashen-ios</string>

<key>OAuth2RedirectURI</key>
<string>fotolokashen://oauth-callback</string>

<key>EnableDebugLogging</key>
<true/>
```

## Backend Integration

This app integrates with the fotolokashen backend API:

### Authentication
- **OAuth2 with PKCE** - Secure authentication flow
- **Token Management** - Automatic refresh and secure storage in Keychain

### API Endpoints
- `POST /api/auth/oauth/token` - Exchange authorization code for tokens
- `POST /api/auth/oauth/revoke` - Revoke access tokens
- `POST /api/locations` - Create new location
- `POST /api/locations/{id}/photos/request-upload` - Request ImageKit upload URL
- `POST /api/locations/{id}/photos/{photoId}/confirm` - Confirm photo upload

### Photo Upload Flow
1. Compress image to optimize file size
2. Request signed upload URL from backend
3. Upload directly to ImageKit
4. Confirm upload with backend to save metadata

Backend repository: [fotolokashen](https://github.com/rgriola/fotolokashen)

## Development Status

✅ **MVP Complete - January 2026**

### Completed Features
- [x] Project setup and architecture
- [x] OAuth2 authentication with PKCE
- [x] Secure token storage (Keychain)
- [x] Camera capture functionality
- [x] GPS location tracking
- [x] Geocoding (address from coordinates)
- [x] Location creation
- [x] Photo compression
- [x] ImageKit upload integration
- [x] End-to-end photo upload flow
- [x] Debug logging system

### Recent Fixes (Jan 15, 2026)
- Fixed API field name mismatch (lat/lng → latitude/longitude)
- Added fallback address logic for geocoding failures
- Implemented response wrapper handling for backend API
- Added comprehensive debug logging
- Made photosCount optional in Location model

### Next Steps
- [ ] Location list view
- [ ] Map view integration
- [ ] Offline support with local caching
- [ ] Photo gallery view
- [ ] User profile management
- [ ] TestFlight beta testing

## Testing

The app has been tested with:
- ✅ iOS Simulator (iPhone 15 Pro)
- ✅ OAuth2 authentication flow
- ✅ Camera capture (simulator test images)
- ✅ GPS location tracking
- ✅ Location creation
- ✅ Photo upload to ImageKit
- ✅ Production backend integration

## Troubleshooting

### Common Issues

**Camera not working in simulator**
- The simulator uses test images. Camera works on real devices.

**GPS coordinates not updating**
- Simulator uses default San Francisco coordinates (37.785834, -122.406417)
- Use Xcode's location simulation for testing different locations

**Authentication failing**
- Verify `Config.plist` has correct backend URL
- Check that OAuth2 client ID matches backend configuration
- Ensure redirect URI is registered in backend

**Photo upload failing**
- Check network connectivity
- Verify ImageKit credentials in backend
- Check debug logs for specific error messages

## Documentation

- [Implementation Plan](IMPLEMENTATION_PLAN.md) - Original development plan
- [MVP Scope](MVP_SCOPE.md) - Minimum viable product definition
- [Quick Start](QUICK_START.md) - Development quick reference
- [Phase 1 Complete](PHASE_1_COMPLETE.md) - OAuth2 implementation
- [Phase 2 Complete](PHASE_2_COMPLETE.md) - Core services implementation
- [Session 1 Summary](SESSION_1_SUMMARY.md) - Initial development session

## Contributing

This is a private project. For questions or issues, contact the development team.

## License

Proprietary - All rights reserved

---

**Status**: ✅ MVP Complete - Core functionality working end-to-end  
**Last Updated**: January 15, 2026  
**Next Milestone**: Location browsing and map integration
