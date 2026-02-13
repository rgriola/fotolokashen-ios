# Changelog

All notable changes to Fotolokashen iOS are documented in this file.

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
