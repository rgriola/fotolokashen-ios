# iOS Development Stack & Setup Guide

**Project**: fotolokashen iOS Companion App  
**Date**: January 14, 2026  
**Status**: Planning & Setup

---

## Development Environment

### Required Software

#### 1. Xcode (Latest Stable)
- **Version**: Xcode 15.0 or later
- **Download**: Mac App Store or [developer.apple.com](https://developer.apple.com/xcode/)
- **Includes**:
  - Swift compiler
  - iOS Simulator
  - Interface Builder
  - Instruments (profiling tools)
  - Asset catalog management

#### 2. Command Line Tools
```bash
xcode-select --install
```

#### 3. CocoaPods or Swift Package Manager
**Recommended**: Swift Package Manager (SPM) - built into Xcode, no installation needed

**Alternative - CocoaPods**:
```bash
sudo gem install cocoapods
```

#### 4. Git
```bash
# Verify installation
git --version

# Configure if needed
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

---

## Project Architecture

### Technology Stack

#### Core Framework
- **SwiftUI** - Modern declarative UI framework
- **Swift 5.9+** - Programming language
- **Combine** - Reactive programming (or async/await)

#### Architecture Pattern
- **MVVM (Model-View-ViewModel)**
  - Clean separation of concerns
  - Testable business logic
  - SwiftUI-friendly

#### Concurrency
- **Swift Concurrency** (async/await)
  - Modern, built-in
  - Better than completion handlers
  - Structured concurrency

---

## Required Dependencies

### 1. Networking
**Alamofire** (Optional - URLSession is built-in)
```swift
// Swift Package Manager
.package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0")
```

**Alternative**: Use native `URLSession` with async/await
```swift
// No dependency needed - built into Swift
let (data, response) = try await URLSession.shared.data(from: url)
```

---

### 2. Google Maps SDK
**Required for map functionality**

```swift
// Swift Package Manager
.package(url: "https://github.com/googlemaps/ios-maps-sdk", from: "8.0.0")
```

**Setup**:
1. Get API key from [Google Cloud Console](https://console.cloud.google.com/)
2. Enable iOS restrictions
3. Add to `Info.plist`:
```xml
<key>GMSApiKey</key>
<string>YOUR_API_KEY_HERE</string>
```

---

### 3. Keychain Access
**KeychainAccess** - Secure token storage

```swift
// Swift Package Manager
.package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2")
```

**Usage**:
```swift
import KeychainAccess

let keychain = Keychain(service: "com.fotolokashen.ios")
keychain["access_token"] = accessToken
keychain["refresh_token"] = refreshToken
```

---

### 4. Image Handling
**Kingfisher** - Async image loading & caching

```swift
// Swift Package Manager
.package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.10.0")
```

**Features**:
- Automatic caching
- Placeholder support
- Image transformations
- SwiftUI integration

---

### 5. Core Data (Built-in)
**No dependency needed** - for local persistence

**Setup**:
1. Create Data Model (`.xcdatamodeld`)
2. Define entities: `LocationDraft`, `PhotoDraft`
3. Generate NSManagedObject subclasses

---

## Project Structure

```
fotolokashen-ios/
├── fotolokashen.xcodeproj
├── fotolokashen/
│   ├── App/
│   │   ├── fotolokashenApp.swift          # App entry point
│   │   └── Config.plist                    # Configuration
│   ├── Models/
│   │   ├── Location.swift
│   │   ├── Photo.swift
│   │   ├── User.swift
│   │   └── OAuthToken.swift
│   ├── ViewModels/
│   │   ├── AuthViewModel.swift
│   │   ├── CameraViewModel.swift
│   │   ├── LocationViewModel.swift
│   │   └── UploadViewModel.swift
│   ├── Views/
│   │   ├── Auth/
│   │   │   ├── LoginView.swift
│   │   │   └── OAuthCallbackView.swift
│   │   ├── Camera/
│   │   │   ├── CameraCaptureView.swift
│   │   │   └── PhotoPreviewView.swift
│   │   ├── Map/
│   │   │   ├── MapView.swift
│   │   │   └── LocationDetailView.swift
│   │   └── Upload/
│   │       └── UploadProgressView.swift
│   ├── Services/
│   │   ├── AuthService.swift               # OAuth2 + PKCE
│   │   ├── APIClient.swift                 # Network layer
│   │   ├── LocationService.swift
│   │   ├── PhotoService.swift
│   │   ├── UploadManager.swift
│   │   └── KeychainService.swift
│   ├── Utilities/
│   │   ├── ImageCompressor.swift
│   │   ├── PKCEGenerator.swift
│   │   ├── ConfigLoader.swift
│   │   └── Extensions/
│   ├── CoreData/
│   │   ├── fotolokashen.xcdatamodeld
│   │   ├── PersistenceController.swift
│   │   └── Entities/
│   └── Resources/
│       ├── Assets.xcassets
│       ├── Info.plist
│       └── Config.plist
└── fotolokashenTests/
    ├── AuthServiceTests.swift
    ├── ImageCompressorTests.swift
    └── MockAPIClient.swift
```

---

## Configuration File

### Config.plist
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Backend Configuration -->
    <key>backendBaseURL</key>
    <string>https://fotolokashen.com</string>
    
    <key>backendStagingURL</key>
    <string>https://staging.fotolokashen.com</string>
    
    <!-- Google Maps -->
    <key>googleMapsAPIKey</key>
    <string>AIzaSy...</string>
    
    <!-- OAuth2 Configuration -->
    <key>oauth</key>
    <dict>
        <key>clientId</key>
        <string>fotolokashen-ios</string>
        <key>redirectUri</key>
        <string>fotolokashen://oauth-callback</string>
        <key>scopes</key>
        <array>
            <string>read</string>
            <string>write</string>
        </array>
    </dict>
    
    <!-- Image Compression Settings -->
    <key>imageCompression</key>
    <dict>
        <key>maxPhotosPerLocation</key>
        <integer>20</integer>
        <key>uploadTargetBytes</key>
        <integer>1500000</integer>
        <key>compressionQualityStart</key>
        <real>0.9</real>
        <key>compressionQualityFloor</key>
        <real>0.4</real>
        <key>compressionMaxDimension</key>
        <integer>3000</integer>
    </dict>
    
    <!-- Feature Flags -->
    <key>features</key>
    <dict>
        <key>enableOfflineMode</key>
        <true/>
        <key>enableDebugLogging</key>
        <true/>
    </dict>
</dict>
</plist>
```

---

## Info.plist Permissions

### Required Permissions
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
```

---

## Key Implementation Files

### 1. AuthService.swift
```swift
import Foundation
import KeychainAccess

class AuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    private let keychain = Keychain(service: "com.fotolokashen.ios")
    private let apiClient: APIClient
    
    // PKCE properties
    private var codeVerifier: String?
    private var codeChallenge: String?
    
    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
        checkAuthStatus()
    }
    
    func startOAuthFlow() async throws {
        // Generate PKCE challenge
        let (verifier, challenge) = PKCEGenerator.generate()
        self.codeVerifier = verifier
        self.codeChallenge = challenge
        
        // Request authorization code
        let authCode = try await apiClient.requestAuthorizationCode(
            codeChallenge: challenge
        )
        
        // Exchange for tokens
        try await exchangeCodeForTokens(code: authCode)
    }
    
    private func exchangeCodeForTokens(code: String) async throws {
        guard let verifier = codeVerifier else {
            throw AuthError.missingCodeVerifier
        }
        
        let response = try await apiClient.exchangeAuthorizationCode(
            code: code,
            codeVerifier: verifier
        )
        
        // Store tokens in keychain
        keychain["access_token"] = response.accessToken
        keychain["refresh_token"] = response.refreshToken
        
        self.currentUser = response.user
        self.isAuthenticated = true
    }
    
    func refreshAccessToken() async throws {
        guard let refreshToken = keychain["refresh_token"] else {
            throw AuthError.noRefreshToken
        }
        
        let response = try await apiClient.refreshToken(refreshToken)
        keychain["access_token"] = response.accessToken
    }
    
    func logout() async {
        if let refreshToken = keychain["refresh_token"] {
            try? await apiClient.revokeToken(refreshToken)
        }
        
        keychain["access_token"] = nil
        keychain["refresh_token"] = nil
        
        self.isAuthenticated = false
        self.currentUser = nil
    }
}
```

---

### 2. PKCEGenerator.swift
```swift
import Foundation
import CryptoKit

struct PKCEGenerator {
    static func generate() -> (verifier: String, challenge: String) {
        // Generate code verifier (43-128 characters)
        let verifier = generateCodeVerifier()
        
        // Generate code challenge (SHA256 hash of verifier)
        let challenge = generateCodeChallenge(from: verifier)
        
        return (verifier, challenge)
    }
    
    private static func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }
    
    private static func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else {
            fatalError("Failed to encode verifier")
        }
        
        let hash = SHA256.hash(data: data)
        return Data(hash).base64URLEncodedString()
    }
}

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
```

---

### 3. ImageCompressor.swift
```swift
import UIKit

struct ImageCompressor {
    struct Config {
        let targetBytes: Int
        let qualityStart: CGFloat
        let qualityFloor: CGFloat
        let maxDimension: CGFloat
        
        static let `default` = Config(
            targetBytes: 1_500_000,      // 1.5MB
            qualityStart: 0.9,
            qualityFloor: 0.4,
            maxDimension: 3000
        )
    }
    
    static func compress(_ image: UIImage, config: Config = .default) -> Data? {
        // Step 1: Resize if needed
        let resized = resize(image, maxDimension: config.maxDimension)
        
        // Step 2: Compress with quality degradation
        var quality = config.qualityStart
        var imageData = resized.jpegData(compressionQuality: quality)
        
        while let data = imageData,
              data.count > config.targetBytes,
              quality > config.qualityFloor {
            quality -= 0.1
            imageData = resized.jpegData(compressionQuality: quality)
        }
        
        return imageData
    }
    
    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        
        guard max(size.width, size.height) > maxDimension else {
            return image
        }
        
        let ratio = maxDimension / max(size.width, size.height)
        let newSize = CGSize(
            width: size.width * ratio,
            height: size.height * ratio
        )
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
```

---

## Development Workflow

### 1. Initial Setup
```bash
# Clone repository (when created)
git clone https://github.com/yourusername/fotolokashen-ios.git
cd fotolokashen-ios

# Open in Xcode
open fotolokashen.xcodeproj
```

### 2. Configure Project
1. Set Bundle Identifier: `com.fotolokashen.ios`
2. Set Team for code signing
3. Add Config.plist with API keys
4. Configure URL schemes in Info.plist

### 3. Add Dependencies
```swift
// In Xcode: File > Add Package Dependencies
// Add each package URL from the dependencies section above
```

### 4. Build & Run
```
⌘ + R - Build and run on simulator
⌘ + U - Run tests
⌘ + B - Build only
```

---

## Testing Strategy

### Unit Tests
- AuthService (OAuth flow, token refresh)
- ImageCompressor (compression logic)
- PKCEGenerator (challenge generation)
- API models (JSON encoding/decoding)

### Integration Tests
- Full OAuth flow with backend
- Photo upload with signed URLs
- Location creation and retrieval

### UI Tests
- Camera capture flow
- Login flow
- Photo upload progress

---

## Deployment

### TestFlight Beta
1. Archive app (Product > Archive)
2. Upload to App Store Connect
3. Add beta testers
4. Distribute via TestFlight

### App Store Release
1. Prepare app metadata
2. Create screenshots (required sizes)
3. Submit for review
4. Monitor review status

---

## Next Steps

1. **Create Xcode Project**
   - Use SwiftUI App template
   - Set up project structure

2. **Implement Core Services**
   - AuthService with OAuth2 + PKCE
   - APIClient with URLSession
   - KeychainService for token storage

3. **Build Camera Feature**
   - CameraCaptureView
   - ImageCompressor
   - Photo preview

4. **Integrate Google Maps**
   - MapView with SwiftUI
   - Location selection
   - GPS tagging

5. **Implement Upload Flow**
   - Request signed URL
   - Upload to ImageKit
   - Confirm upload

6. **Add Offline Support**
   - Core Data for drafts
   - Background sync queue
   - Conflict resolution

---

## Resources

- [Swift Documentation](https://swift.org/documentation/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [Google Maps iOS SDK](https://developers.google.com/maps/documentation/ios-sdk)
- [OAuth 2.0 RFC](https://datatracker.ietf.org/doc/html/rfc6749)
- [PKCE RFC](https://datatracker.ietf.org/doc/html/rfc7636)
- [ImageKit Upload API](https://docs.imagekit.io/api-reference/upload-file-api)

---

**Status**: Ready to begin iOS development  
**Backend**: OAuth2 API complete on `feature/oauth2-implementation` branch  
**Next**: Create Xcode project and implement core services
