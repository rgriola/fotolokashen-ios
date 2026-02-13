# iOS Photo Upload Security Review

**Date**: February 13, 2026  
**Status**: 🔴 **CRITICAL SECURITY GAPS IDENTIFIED**  
**Action Required**: Update to use unified secure upload endpoint

---

## Executive Summary

The iOS app currently uploads photos **directly to ImageKit CDN**, bypassing server-side security checks. This matches the pattern that was identified as a **critical security vulnerability** in the web app and subsequently fixed.

| Security Feature | Web App | iOS App |
|------------------|---------|---------|
| Virus Scanning (ClamAV) | ✅ All uploads | ❌ Bypassed |
| Server-Side Format Validation | ✅ MIME + Extension | ❌ Client-only |
| HEIC/TIFF → JPEG Conversion | ✅ Server-side | ❌ Missing |
| EXIF Metadata Sanitization | ✅ sanitizeText() | ❌ Missing |
| Orphan File Prevention | ✅ Deferred upload | ⚠️ Possible orphans |

---

## Current iOS Upload Flow (INSECURE)

```
iOS App                           Backend                        ImageKit CDN
   │                                │                                │
   │ 1. Compress locally            │                                │
   │ 2. POST /request-upload        │                                │
   │──────────────────────────────▶│                                │
   │                                │ Create pending photo record    │
   │◀──────────────────────────────│                                │
   │    { uploadToken, signature }  │                                │
   │                                │                                │
   │ 3. Direct upload to CDN ───────────────────────────────────────▶│
   │    (BYPASSES SERVER)           │                ❌ NO VIRUS SCAN │
   │◀───────────────────────────────────────────────────────────────│
   │    { fileId, url }             │                                │
   │                                │                                │
   │ 4. POST /confirm               │                                │
   │──────────────────────────────▶│                                │
   │                                │ Update photo record            │
   │◀──────────────────────────────│                                │
```

### Security Vulnerabilities

#### 1. ❌ No Virus Scanning
- **Risk**: Malicious files uploaded directly to CDN
- **Web Fix**: ClamAV scanning via `/api/photos/upload`
- **Code Location**: [PhotoUploadService.swift](../fotolokashen/fotolokashen/swift-utilities/PhotoUploadService.swift) line 86-94

#### 2. ❌ No Server-Side Format Validation
- **Risk**: Attackers can bypass client-side checks
- **Web Fix**: Server validates MIME type + file extension
- **Impact**: Arbitrary file types could be stored

#### 3. ❌ No HEIC/TIFF Conversion
- **Risk**: Incompatible formats stored on CDN
- **Web Fix**: Sharp library converts HEIC/TIFF → JPEG
- **Note**: iOS ImageCompressor only handles UIImage → JPEG

#### 4. ❌ No EXIF Metadata Sanitization
- **Risk**: XSS attacks via malicious camera metadata
- **Web Fix**: `sanitizeText()` applied to all EXIF strings
- **Example**: Camera make field could contain `<script>alert('xss')</script>`

#### 5. ⚠️ Orphan File Risk
- **Risk**: If confirm step fails, files remain on CDN without database record
- **Web Fix**: Deferred upload (only uploads when form saves)
- **Impact**: Storage bloat, potential data leakage

---

## Recommended Secure Flow

```
iOS App                           Backend                        ImageKit CDN
   │                                │                                │
   │ 1. Select/Capture photo        │                                │
   │ 2. POST /api/photos/upload     │                                │
   │    (FormData: photo, type)     │                                │
   │──────────────────────────────▶│                                │
   │                                │ ✅ Virus scan                  │
   │                                │ ✅ Format validation           │
   │                                │ ✅ HEIC/TIFF conversion        │
   │                                │ ✅ Compression                 │
   │                                │ ✅ EXIF sanitization           │
   │                                │ ✅ Upload to CDN ─────────────▶│
   │◀──────────────────────────────│◀────────────────────────────────│
   │    { url, fileId, metadata }   │                                │
   │                                │                                │
   │ 3. Save location with photoId  │                                │
   │──────────────────────────────▶│                                │
   │                                │ Associate photo with location  │
```

---

## Implementation Plan

### Phase 1: Update PhotoUploadService.swift

Replace direct ImageKit upload with secure endpoint:

```swift
// BEFORE (insecure - direct CDN upload)
let imagekitResponse = try await uploadToImageKit(
    data: compressedData,
    uploadParams: uploadResponse
)

// AFTER (secure - server-mediated upload)
let secureResponse = try await uploadSecurely(
    data: compressedData,
    locationId: locationId,
    location: location
)
```

#### New Upload Method

```swift
/// Upload photo via secure server endpoint
private func uploadSecurely(
    data: Data,
    locationId: Int,
    location: CLLocation?
) async throws -> SecureUploadResponse {
    
    // Build multipart form data
    let boundary = "Boundary-\(UUID().uuidString)"
    var body = Data()
    
    // Add photo file
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
    body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
    body.append(data)
    body.append("\r\n".data(using: .utf8)!)
    
    // Add uploadType
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"uploadType\"\r\n\r\n".data(using: .utf8)!)
    body.append("location\r\n".data(using: .utf8)!)
    
    // Add metadata (GPS/EXIF)
    let metadata: [String: Any?] = [
        "hasGPS": location != nil,
        "lat": location?.coordinate.latitude,
        "lng": location?.coordinate.longitude,
        "altitude": location?.altitude
    ]
    let metadataJson = try JSONSerialization.data(withJSONObject: metadata)
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"metadata\"\r\n\r\n".data(using: .utf8)!)
    body.append(metadataJson)
    body.append("\r\n".data(using: .utf8)!)
    
    body.append("--\(boundary)--\r\n".data(using: .utf8)!)
    
    // Send to secure endpoint
    var request = URLRequest(url: URL(string: "\(apiBaseURL)/api/photos/upload")!)
    request.httpMethod = "POST"
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
    request.httpBody = body
    
    let (responseData, response) = try await URLSession.shared.data(for: request)
    // ... parse response
}
```

### Phase 2: Add New Response Models

```swift
/// Response from /api/photos/upload
struct SecureUploadResponse: Codable {
    let upload: UploadDetails
    let file: FileDetails
    let metadata: PhotoMetadata?
}

struct UploadDetails: Codable {
    let fileId: String
    let filePath: String
    let url: String
    let thumbnailUrl: String?
    let width: Int?
    let height: Int?
}

struct FileDetails: Codable {
    let originalFilename: String
    let size: Int
    let mimeType: String
}

struct PhotoMetadata: Codable {
    let hasGPS: Bool
    let gpsLatitude: Double?
    let gpsLongitude: Double?
    let gpsAltitude: Double?
    let cameraMake: String?
    let cameraModel: String?
    // ... other EXIF fields
}
```

### Phase 3: Deprecate Legacy Endpoints

These endpoints can be deprecated for iOS once secure upload is implemented:
- `POST /api/locations/[id]/photos/request-upload`
- `POST /api/locations/[id]/photos/[id]/confirm`

**Note**: Keep them for backwards compatibility with older app versions.

---

## Files to Modify

### iOS Project

| File | Changes |
|------|---------|
| [PhotoUploadService.swift](../fotolokashen/fotolokashen/swift-utilities/PhotoUploadService.swift) | Replace `uploadToImageKit()` with secure endpoint |
| [Photo.swift](../fotolokashen/fotolokashen/swift-utilities/Models/Photo.swift) | Add `SecureUploadResponse` models |
| [APIClient.swift](../fotolokashen/fotolokashen/swift-utilities/APIClient.swift) | Add multipart form data support if needed |

### Backend (Already Complete)

The `/api/photos/upload` endpoint already supports iOS use case:
- ✅ Accepts `uploadType: 'location'`
- ✅ Accepts `metadata` JSON with GPS data
- ✅ Returns `fileId`, `url`, `thumbnailUrl`

---

## Testing Checklist

After implementing secure upload:

- [ ] Upload standard JPEG photo → Success
- [ ] Upload HEIC photo → Converted to JPEG, uploaded
- [ ] Upload oversized photo → Compressed before upload
- [ ] Upload without GPS data → Works (metadata optional)
- [ ] Upload with GPS data → GPS preserved in response
- [ ] Virus scan test (EICAR) → Upload blocked
- [ ] Invalid file type → Upload rejected
- [ ] Authentication expired → 401 response

---

## Timeline

| Phase | Task | Estimate |
|-------|------|----------|
| 1 | Create `uploadSecurely()` method | 2-3 hours |
| 2 | Add response models | 30 min |
| 3 | Update `uploadPhoto()` to use new method | 1 hour |
| 4 | Testing across all upload scenarios | 2 hours |
| 5 | Update documentation | 30 min |
| **Total** | | **~6 hours** |

---

## References

- [UNIFIED_UPLOAD_SECURITY.md](../../fotolokashen/docs/features/UNIFIED_UPLOAD_SECURITY.md) - Web implementation
- [SECURE_PHOTO_UPLOAD_IMPLEMENTATION.md](../../fotolokashen/docs/completed-features/SECURE_PHOTO_UPLOAD_IMPLEMENTATION.md) - Security requirements
- [/api/photos/upload](../../fotolokashen/src/app/api/photos/upload/route.ts) - Secure upload endpoint
