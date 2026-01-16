# iOS Implementation Plan - Session 1

**Date**: January 15, 2026  
**Status**: In Progress  
**Session Goal**: Create project foundation and core utilities

---

## ✅ Resources Confirmed

### Backend
- **URL**: `https://fotolokashen.com` (OAuth2 merged Jan 14)
- **OAuth Client**: `fotolokashen-ios` (needs database registration)
- **Test Account**: `baseballczar@gmail.com` / `Dakota1973$$`

### API Keys
- **Google Maps (iOS)**: `AIzaSyCmnjKXmBatWv9bU5CWYcpRINgRLzJot2E`
- **ImageKit Public**: `public_O/9pxeXVXghCIZD8o8ySi04JvK4=`
- **ImageKit Endpoint**: `https://ik.imagekit.io/rgriola`

### Development Environment
- **Xcode**: Installed ✅
- **Command Line Tools**: Installed ✅
- **Bundle ID**: `com.fotolokashen.ios`

---

## 📋 Session 1 Tasks

### Phase 1: Project Setup (30 min)
- [x] Create `.env.local` with all API keys
- [x] Create `Config.plist` with production values
- [ ] Create Xcode project structure
- [ ] Set up Swift Package Manager dependencies
- [ ] Configure Info.plist permissions

### Phase 2: Core Utilities (45 min)
- [ ] `PKCEGenerator.swift` - OAuth PKCE challenge generation
- [ ] `ImageCompressor.swift` - Smart image compression
- [ ] `ConfigLoader.swift` - Load Config.plist values
- [ ] `Extensions/` - Helper extensions (Data, String, etc.)

### Phase 3: Models (30 min)
- [ ] `User.swift` - User model
- [ ] `Location.swift` - Location model
- [ ] `Photo.swift` - Photo model
- [ ] `OAuthToken.swift` - Token model

### Phase 4: Camera Feature (60 min)
- [ ] `CameraSession.swift` - AVFoundation camera manager
- [ ] `LocationManager.swift` - CoreLocation GPS manager
- [ ] `CameraCaptureView.swift` - SwiftUI camera UI
- [ ] `PhotoPreviewView.swift` - Preview UI

### Phase 5: Testing (30 min)
- [ ] Test PKCE generation
- [ ] Test image compression
- [ ] Test camera capture
- [ ] Test GPS location

---

## 🎯 Next Session Tasks

### Phase 6: Authentication
- [ ] `AuthService.swift` - OAuth flow manager
- [ ] `KeychainService.swift` - Secure token storage
- [ ] `LoginView.swift` - Login UI
- [ ] `OAuthCallbackView.swift` - OAuth redirect handler

### Phase 7: API Integration
- [ ] `APIClient.swift` - Network layer
- [ ] `LocationService.swift` - Location API calls
- [ ] `PhotoService.swift` - Photo API calls
- [ ] `UploadManager.swift` - Upload queue manager

### Phase 8: Map Integration
- [ ] `MapView.swift` - Google Maps integration
- [ ] `LocationDetailView.swift` - Location details
- [ ] Map marker management

---

## 📁 Project Structure

```
fotolokashen-ios/
├── fotolokashen.xcodeproj          # Xcode project (to be created)
├── fotolokashen/                    # Main app target
│   ├── App/
│   │   ├── fotolokashenApp.swift   # App entry point
│   │   └── ContentView.swift       # Root view
│   ├── Models/
│   │   ├── User.swift
│   │   ├── Location.swift
│   │   ├── Photo.swift
│   │   └── OAuthToken.swift
│   ├── ViewModels/
│   │   ├── AuthViewModel.swift
│   │   ├── CameraViewModel.swift
│   │   └── LocationViewModel.swift
│   ├── Views/
│   │   ├── Auth/
│   │   │   ├── LoginView.swift
│   │   │   └── OAuthCallbackView.swift
│   │   ├── Camera/
│   │   │   ├── CameraCaptureView.swift
│   │   │   └── PhotoPreviewView.swift
│   │   └── Map/
│   │       └── MapView.swift
│   ├── Services/
│   │   ├── AuthService.swift
│   │   ├── APIClient.swift
│   │   ├── LocationService.swift
│   │   ├── PhotoService.swift
│   │   ├── UploadManager.swift
│   │   └── KeychainService.swift
│   ├── Utilities/
│   │   ├── PKCEGenerator.swift
│   │   ├── ImageCompressor.swift
│   │   ├── ConfigLoader.swift
│   │   ├── CameraSession.swift
│   │   ├── LocationManager.swift
│   │   └── Extensions/
│   │       ├── Data+Base64URL.swift
│   │       └── UIImage+Resize.swift
│   └── Resources/
│       ├── Assets.xcassets
│       ├── Info.plist
│       └── Config.plist
└── fotolokashenTests/
    ├── PKCEGeneratorTests.swift
    ├── ImageCompressorTests.swift
    └── MockAPIClient.swift
```

---

## 🔧 Dependencies (Swift Package Manager)

### Required Packages
1. **KeychainAccess** - Secure token storage
   - URL: `https://github.com/kishikawakatsumi/KeychainAccess.git`
   - Version: `4.2.2`

2. **GoogleMaps** - Map SDK
   - URL: `https://github.com/googlemaps/ios-maps-sdk`
   - Version: `8.0.0`

3. **Kingfisher** - Image loading/caching
   - URL: `https://github.com/onevcat/Kingfisher.git`
   - Version: `7.10.0`

### Optional (Can use native URLSession)
4. **Alamofire** - Networking (optional)
   - URL: `https://github.com/Alamofire/Alamofire.git`
   - Version: `5.8.0`

---

## 📝 Info.plist Permissions

```xml
<!-- Camera Access -->
<key>NSCameraUsageDescription</key>
<string>fotolokashen needs camera access to capture photos of locations.</string>

<!-- Photo Library -->
<key>NSPhotoLibraryUsageDescription</key>
<string>fotolokashen needs photo library access to save and upload photos.</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>fotolokashen needs permission to save photos to your library.</string>

<!-- Location Services -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>fotolokashen needs your location to tag photos with GPS coordinates.</string>

<!-- URL Schemes for OAuth -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>fotolokashen</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.fotolokashen.oauth</string>
    </dict>
</array>

<!-- Google Maps API Key -->
<key>GMSApiKey</key>
<string>AIzaSyCmnjKXmBatWv9bU5CWYcpRINgRLzJot2E</string>
```

---

## ⚠️ Important Notes

### OAuth Client Registration
Before OAuth will work, you need to register the iOS client in your database:

```sql
INSERT INTO "OAuthClient" (
  "clientId",
  "name",
  "redirectUris",
  "scopes",
  "createdAt"
) VALUES (
  'fotolokashen-ios',
  'fotolokashen iOS App',
  ARRAY['fotolokashen://oauth-callback'],
  ARRAY['read', 'write'],
  NOW()
);
```

Run this SQL command in your production database before testing OAuth.

---

## 🚀 Build Commands

```bash
# Open project in Xcode
open fotolokashen.xcodeproj

# Build and run
# Press ⌘ + R in Xcode

# Run tests
# Press ⌘ + U in Xcode

# Clean build folder
# Press ⌘ + Shift + K in Xcode
```

---

## 📊 Progress Tracking

### Session 1 (Today)
- [x] Environment setup
- [x] Config files created
- [ ] Xcode project created
- [ ] Core utilities implemented
- [ ] Camera feature built

### Session 2 (Next)
- [ ] Authentication flow
- [ ] API integration
- [ ] Upload manager

### Session 3 (Future)
- [ ] Map integration
- [ ] UI polish
- [ ] Testing

---

**Last Updated**: January 15, 2026 1:16 PM EST  
**Next Milestone**: Complete Phase 1-5 today
