# Swift Utilities for fotolokashen iOS

This directory contains production-ready Swift utilities and models for the fotolokashen iOS companion app. These files are ready to be integrated into an Xcode project.

---

## 📁 Directory Structure

```
swift-utilities/
├── PKCEGenerator.swift          # OAuth2 PKCE challenge generation
├── ImageCompressor.swift         # Smart image compression
├── ConfigLoader.swift            # Config.plist loader
└── Models/
    ├── User.swift               # User model
    ├── Location.swift           # Location model
    ├── Photo.swift              # Photo model
    └── OAuthToken.swift         # OAuth token model
```

---

## 🔧 Core Utilities

### PKCEGenerator.swift

**Purpose**: Generate PKCE (Proof Key for Code Exchange) challenge for OAuth2 authorization code flow.

**Features**:
- Cryptographically secure random code verifier generation
- SHA256 code challenge generation
- Base64URL encoding (URL-safe)
- Implements RFC 7636

**Usage**:
```swift
let (verifier, challenge) = PKCEGenerator.generate()
// Store verifier securely, send challenge to authorization endpoint
```

**Dependencies**: `Foundation`, `CryptoKit`

---

### ImageCompressor.swift

**Purpose**: Smart image compression with iterative quality reduction.

**Features**:
- Two-step process: resize then compress
- Configurable target size (default: 1.5MB)
- Quality degradation with floor (prevents over-compression)
- Maintains aspect ratio
- Compression metadata tracking

**Usage**:
```swift
// Basic usage
let compressedData = ImageCompressor.compress(image)

// With custom config
let config = ImageCompressor.Config(
    targetBytes: 2_000_000,
    qualityStart: 0.95,
    qualityFloor: 0.5,
    maxDimension: 4000
)
let compressedData = ImageCompressor.compress(image, config: config)

// With metadata
if let result = ImageCompressor.compressWithMetadata(image) {
    print(result.metadata.summary)
}
```

**Dependencies**: `UIKit`

---

### ConfigLoader.swift

**Purpose**: Type-safe configuration loader for Config.plist.

**Features**:
- Singleton pattern
- Type-safe accessors for all config values
- Computed properties for URLs
- Image compression config builder
- Feature flags support

**Usage**:
```swift
let config = ConfigLoader.shared

// Access values
let backendURL = config.backendBaseURL
let googleMapsKey = config.googleMapsAPIKey
let compressionConfig = config.imageCompressionConfig

// Check feature flags
if config.enableDebugLogging {
    print("Debug mode enabled")
}

// Print all config (debugging)
config.printConfiguration()
```

**Dependencies**: `Foundation`

---

## 📦 Models

### User.swift

**Purpose**: User model matching backend API response.

**Fields**:
- Basic: `id`, `email`, `username`, `firstName`, `lastName`
- Profile: `avatar`, `bannerImage`, `city`, `country`
- Settings: `emailVerified`, `isActive`, `isAdmin`
- GPS: `gpsPermission`, `homeLocationLat`, `homeLocationLng`

**Computed Properties**:
- `fullName` - First + last name
- `displayName` - Full name or username
- `avatarURL` - Avatar URL
- `homeLocation` - Home coordinates tuple

---

### Location.swift

**Purpose**: Location model with create/update request models.

**Fields**:
- `id`, `placeId`, `name`, `address`
- `lat`, `lng` - GPS coordinates
- `type` - Location type (outdoor, indoor, studio, etc.)
- `notes`, `rating`, `photosCount`

**Computed Properties**:
- `coordinate` - CLLocationCoordinate2D
- `locationType` - LocationType enum
- `hasPhotos` - Boolean

**Related Types**:
- `LocationType` - Enum with display names and icons
- `CreateLocationRequest` - For POST requests
- `UpdateLocationRequest` - For PUT requests

---

### Photo.swift

**Purpose**: Photo model with complete upload flow models.

**Fields**:
- `id`, `imagekitFilePath`, `url`, `thumbnailUrl`
- `width`, `height`, `fileSize`, `mimeType`
- `gpsLatitude`, `gpsLongitude`
- `isPrimary`, `caption`, `uploadedAt`

**Computed Properties**:
- `photoURL`, `thumbnail` - URL objects
- `hasGPS` - Boolean
- `coordinates` - GPS tuple
- `fileSizeFormatted` - Human-readable size
- `aspectRatio` - Width/height ratio

**Related Types**:
- `RequestUploadRequest` - Request signed upload URL
- `RequestUploadResponse` - Upload credentials
- `ConfirmUploadRequest` - Confirm upload completion
- `ImageKitUploadResponse` - ImageKit response

---

### OAuthToken.swift

**Purpose**: OAuth token storage with expiration tracking.

**Fields**:
- `accessToken`, `refreshToken`, `tokenType`
- `expiresIn`, `scope`, `user`
- `expiresAt` - Computed expiration date

**Computed Properties**:
- `isExpired` - Boolean
- `needsRefresh` - True if expires in <5 minutes
- `timeUntilExpiration` - TimeInterval

**Related Types**:
- `TokenResponse` - Token exchange response
- `AuthorizationCodeResponse` - Authorization code
- `RefreshTokenResponse` - Refresh token response
- `RevokeTokenResponse` - Revoke response

---

## 🔐 Security Considerations

### PKCE Implementation
- Uses `SecRandomCopyBytes` for cryptographically secure random generation
- SHA256 hashing for code challenge
- Base64URL encoding (URL-safe, no padding)

### Token Storage
- **DO NOT** store tokens in UserDefaults
- **USE** Keychain for secure token storage
- Implement `KeychainService.swift` (see next session)

### Image Compression
- Configurable quality floor prevents over-compression
- Max dimension prevents excessive memory usage
- Metadata tracking for debugging

---

## 📝 Integration Checklist

### To integrate these utilities into Xcode:

1. **Create Xcode Project**
   ```bash
   # File > New > Project > iOS > App
   # Name: fotolokashen
   # Bundle ID: com.fotolokashen.ios
   # Interface: SwiftUI
   # Language: Swift
   ```

2. **Add Swift Files**
   - Drag all `.swift` files into Xcode project
   - Ensure "Copy items if needed" is checked
   - Add to target: fotolokashen

3. **Add Config.plist**
   - Drag `Config.plist` into Xcode
   - Add to target: fotolokashen
   - Ensure it's in "Copy Bundle Resources"

4. **Add Dependencies**
   - File > Add Package Dependencies
   - Add KeychainAccess, GoogleMaps, Kingfisher

5. **Update Info.plist**
   - Add camera, location, photo library permissions
   - Add URL scheme: `fotolokashen://`
   - Add Google Maps API key

---

## 🧪 Testing

### Unit Tests to Create

```swift
// PKCEGeneratorTests.swift
func testPKCEGeneration() {
    let (verifier, challenge) = PKCEGenerator.generate()
    XCTAssertGreaterThanOrEqual(verifier.count, 43)
    XCTAssertGreaterThanOrEqual(challenge.count, 43)
}

// ImageCompressorTests.swift
func testImageCompression() {
    let image = UIImage(named: "test-image")!
    let data = ImageCompressor.compress(image)
    XCTAssertNotNil(data)
    XCTAssertLessThanOrEqual(data!.count, 1_500_000)
}

// ConfigLoaderTests.swift
func testConfigLoading() {
    let config = ConfigLoader.shared
    XCTAssertFalse(config.backendBaseURL.isEmpty)
    XCTAssertFalse(config.googleMapsAPIKey.isEmpty)
}
```

---

## 📚 Next Steps

### Session 2: Authentication & API
1. Create `AuthService.swift` - OAuth flow manager
2. Create `KeychainService.swift` - Secure token storage
3. Create `APIClient.swift` - Network layer
4. Create `LocationService.swift` - Location API
5. Create `PhotoService.swift` - Photo upload API

### Session 3: UI & Camera
1. Create `CameraSession.swift` - AVFoundation manager
2. Create `LocationManager.swift` - CoreLocation manager
3. Create `CameraCaptureView.swift` - Camera UI
4. Create `PhotoPreviewView.swift` - Preview UI

### Session 4: Map & Upload
1. Create `MapView.swift` - Google Maps integration
2. Create `UploadManager.swift` - Upload queue
3. Create `LocationDetailView.swift` - Location details
4. Polish UI and test end-to-end

---

## 🔗 Resources

- [Swift Documentation](https://swift.org/documentation/)
- [OAuth 2.0 RFC](https://datatracker.ietf.org/doc/html/rfc6749)
- [PKCE RFC 7636](https://datatracker.ietf.org/doc/html/rfc7636)
- [ImageKit Upload API](https://docs.imagekit.io/api-reference/upload-file-api)
- [Google Maps iOS SDK](https://developers.google.com/maps/documentation/ios-sdk)

---

**Created**: January 15, 2026  
**Status**: Production Ready  
**Next**: Create Xcode project and integrate these utilities
