# Changelog

All notable changes to Fotolokashen iOS are documented in this file.

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
