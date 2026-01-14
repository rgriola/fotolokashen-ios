# fotolokashen API Documentation

**Base URL**: `https://fotolokashen.com`  
**Staging URL**: `https://staging.fotolokashen.com`  
**API Version**: v1

---

## Authentication

All API requests (except OAuth endpoints) require authentication via Bearer token in the Authorization header:

```
Authorization: Bearer <access_token>
```

### OAuth2 Flow (PKCE)

#### 1. Generate PKCE Challenge

```swift
// Generate code verifier and challenge
let (verifier, challenge) = PKCEGenerator.generate()
```

#### 2. Request Authorization Code

**Endpoint**: `POST /api/auth/oauth/authorize`

**Headers**:
```
Content-Type: application/json
Cookie: auth_token=<existing_session_cookie>
```

**Request Body**:
```json
{
  "client_id": "fotolokashen-ios",
  "response_type": "code",
  "redirect_uri": "fotolokashen://oauth-callback",
  "code_challenge": "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
  "code_challenge_method": "S256",
  "scope": "read write",
  "state": "optional-csrf-token"
}
```

**Response** (200):
```json
{
  "authorization_code": "abc123...",
  "state": "optional-csrf-token"
}
```

**Error Responses**:
- `401` - User not authenticated
- `400` - Invalid client_id, redirect_uri, or scopes

---

#### 3. Exchange Code for Tokens

**Endpoint**: `POST /api/auth/oauth/token`

**Request Body**:
```json
{
  "grant_type": "authorization_code",
  "code": "abc123...",
  "code_verifier": "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk",
  "client_id": "fotolokashen-ios",
  "redirect_uri": "fotolokashen://oauth-callback"
}
```

**Response** (200):
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "def456...",
  "token_type": "Bearer",
  "expires_in": 86400,
  "scope": "read write",
  "user": {
    "id": 123,
    "email": "user@example.com",
    "username": "johndoe",
    "avatar": "https://ik.imagekit.io/..."
  }
}
```

**Error Responses**:
- `400` - Invalid code, code_verifier, or expired code
- `400` - Code already used (INVALID_GRANT)

---

#### 4. Refresh Access Token

**Endpoint**: `POST /api/auth/oauth/token`

**Request Body**:
```json
{
  "grant_type": "refresh_token",
  "refresh_token": "def456...",
  "client_id": "fotolokashen-ios"
}
```

**Response** (200):
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 86400,
  "scope": "read write"
}
```

---

#### 5. Revoke Token (Logout)

**Endpoint**: `POST /api/auth/oauth/revoke`

**Request Body**:
```json
{
  "token": "def456...",
  "client_id": "fotolokashen-ios"
}
```

**Response** (200):
```json
{
  "success": true
}
```

---

## Locations API

### List Locations

**Endpoint**: `GET /api/locations`

**Headers**:
```
Authorization: Bearer <access_token>
```

**Query Parameters**:
- `sort` - Sort field: `createdAt`, `name`, `rating` (default: `createdAt`)
- `order` - Sort order: `asc`, `desc` (default: `desc`)
- `type` - Filter by location type
- `bounds` - Viewport filter: `lat1,lng1,lat2,lng2`

**Response** (200):
```json
{
  "locations": [
    {
      "id": 456,
      "placeId": "photo-1234567890",
      "name": "Beautiful Sunset Spot",
      "address": "123 Main St, City, State",
      "lat": 37.7749,
      "lng": -122.4194,
      "type": "outdoor",
      "rating": 4.5,
      "createdAt": "2026-01-12T10:30:00Z",
      "photosCount": 5
    }
  ]
}
```

---

### Create Location

**Endpoint**: `POST /api/locations`

**Headers**:
```
Authorization: Bearer <access_token>
Content-Type: application/json
```

**Request Body**:
```json
{
  "placeId": "photo-1234567890",
  "name": "Beautiful Sunset Spot",
  "address": "123 Main St, City, State",
  "lat": 37.7749,
  "lng": -122.4194,
  "type": "outdoor",
  "notes": "Great for golden hour",
  "rating": 4.5
}
```

**Response** (201):
```json
{
  "success": true,
  "data": {
    "id": 456,
    "placeId": "photo-1234567890",
    "name": "Beautiful Sunset Spot",
    "createdAt": "2026-01-12T10:30:00Z",
    "photosCount": 0
  }
}
```

---

### Get Location Details

**Endpoint**: `GET /api/locations/{id}`

**Response** (200):
```json
{
  "id": 456,
  "placeId": "photo-1234567890",
  "name": "Beautiful Sunset Spot",
  "address": "123 Main St, City, State",
  "lat": 37.7749,
  "lng": -122.4194,
  "type": "outdoor",
  "notes": "Great for golden hour",
  "rating": 4.5,
  "createdAt": "2026-01-12T10:30:00Z",
  "photos": []
}
```

---

### Update Location

**Endpoint**: `PUT /api/locations/{id}`

**Request Body**:
```json
{
  "name": "Updated Name",
  "notes": "Updated notes",
  "rating": 5.0
}
```

**Response** (200):
```json
{
  "success": true,
  "data": {
    "id": 456,
    "name": "Updated Name",
    "updatedAt": "2026-01-12T11:00:00Z"
  }
}
```

---

### Delete Location

**Endpoint**: `DELETE /api/locations/{id}`

**Response** (200):
```json
{
  "success": true
}
```

---

## Photos API

### Request Upload URL

**Endpoint**: `POST /api/locations/{id}/photos/request-upload`

**Headers**:
```
Authorization: Bearer <access_token>
Content-Type: application/json
```

**Request Body**:
```json
{
  "filename": "photo.jpg",
  "mimeType": "image/jpeg",
  "size": 1500000,
  "width": 3000,
  "height": 2000,
  "capturedAt": "2026-01-14T19:00:00Z",
  "gpsLatitude": 37.7749,
  "gpsLongitude": -122.4194,
  "gpsAltitude": 10.5,
  "gpsAccuracy": 5.0,
  "cameraMake": "Apple",
  "cameraModel": "iPhone 15 Pro",
  "iso": 100,
  "focalLength": "24mm",
  "aperture": "f/1.8",
  "shutterSpeed": "1/125"
}
```

**Response** (200):
```json
{
  "photoId": 789,
  "uploadUrl": "https://upload.imagekit.io/api/v1/files/upload",
  "uploadToken": "...",
  "signature": "...",
  "expire": 1705068300,
  "fileName": "photo_1705068000.jpg",
  "folder": "/development/locations/456",
  "publicKey": "public_..."
}
```

**Validation**:
- Max file size: 10MB
- Allowed types: `image/jpeg`, `image/png`, `image/heic`

---

### Upload to ImageKit

**Endpoint**: `POST https://upload.imagekit.io/api/v1/files/upload`

**Content-Type**: `multipart/form-data`

**Form Fields**:
```
publicKey: <from request-upload response>
signature: <from request-upload response>
expire: <from request-upload response>
token: <from request-upload response>
fileName: <from request-upload response>
folder: <from request-upload response>
file: <binary image data>
```

**Response** (200):
```json
{
  "fileId": "IMAGEKIT_FILE_ID",
  "name": "photo_789.jpg",
  "url": "https://ik.imagekit.io/rgriola/development/locations/456/photo_789.jpg",
  "thumbnailUrl": "...",
  "width": 3000,
  "height": 2000,
  "size": 1500000
}
```

---

### Confirm Upload

**Endpoint**: `POST /api/locations/{id}/photos/{photoId}/confirm`

**Headers**:
```
Authorization: Bearer <access_token>
Content-Type: application/json
```

**Request Body**:
```json
{
  "imagekitFileId": "IMAGEKIT_FILE_ID",
  "imagekitUrl": "https://ik.imagekit.io/..."
}
```

**Response** (200):
```json
{
  "success": true,
  "photo": {
    "id": 789,
    "imagekitFilePath": "/development/locations/456/photo_789.jpg",
    "url": "https://ik.imagekit.io/...",
    "uploadedAt": "2026-01-14T19:05:00Z"
  }
}
```

---

### List Photos

**Endpoint**: `GET /api/locations/{id}/photos`

**Query Parameters**:
- `page` - Page number (default: 1)
- `limit` - Items per page (default: 20, max: 100)

**Response** (200):
```json
{
  "photos": [
    {
      "id": 789,
      "imagekitFilePath": "/development/locations/456/photo_789.jpg",
      "url": "https://ik.imagekit.io/...",
      "thumbnailUrl": "https://ik.imagekit.io/...?tr=w-400,h-400,c-at_max,fo-auto,q-80",
      "caption": null,
      "width": 3000,
      "height": 2000,
      "uploadedAt": "2026-01-14T19:05:00Z",
      "gpsLatitude": 37.7749,
      "gpsLongitude": -122.4194,
      "isPrimary": false,
      "fileSize": 1500000,
      "mimeType": "image/jpeg"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 156,
    "totalPages": 8
  }
}
```

**Response Headers**:
```
X-Total-Count: 156
X-Page: 1
X-Per-Page: 20
X-Total-Pages: 8
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 987
X-RateLimit-Reset: 1705068600
```

---

## Error Responses

All endpoints may return the following error responses:

### 400 Bad Request
```json
{
  "error": "Missing required parameters",
  "code": "INVALID_REQUEST"
}
```

### 401 Unauthorized
```json
{
  "error": "Authentication required",
  "code": "ERROR_401"
}
```

### 403 Forbidden
```json
{
  "error": "Insufficient permissions",
  "code": "ERROR_403"
}
```

### 404 Not Found
```json
{
  "error": "Resource not found",
  "code": "ERROR_404"
}
```

### 429 Too Many Requests
```json
{
  "error": "Rate limit exceeded",
  "code": "RATE_LIMIT_EXCEEDED"
}
```

### 500 Internal Server Error
```json
{
  "error": "Internal server error",
  "code": "SERVER_ERROR"
}
```

---

## Rate Limiting

- **Limit**: 1000 requests per 15-minute window
- **Headers**: All responses include rate limit information
  - `X-RateLimit-Limit`: Maximum requests allowed
  - `X-RateLimit-Remaining`: Requests remaining
  - `X-RateLimit-Reset`: Unix timestamp when limit resets

---

## Image Transformations

ImageKit URLs support transformation parameters:

### Thumbnail
```
?tr=w-400,h-400,c-at_max,fo-auto,q-80
```

### Parameters
- `w-{width}` - Width in pixels
- `h-{height}` - Height in pixels
- `c-at_max` - Maintain aspect ratio, fit within bounds
- `fo-auto` - Auto format (WebP for modern browsers)
- `q-{quality}` - Quality (1-100)

### Examples
```
// 400x400 thumbnail
https://ik.imagekit.io/.../photo.jpg?tr=w-400,h-400,c-at_max,fo-auto,q-80

// Full size, optimized
https://ik.imagekit.io/.../photo.jpg?tr=fo-auto,q-90

// Avatar (128x128)
https://ik.imagekit.io/.../avatar.jpg?tr=w-128,h-128,c-at_max,fo-auto,q-80
```

---

## Swift Models

### User
```swift
struct User: Codable {
    let id: Int
    let email: String
    let username: String
    let avatar: String?
}
```

### Location
```swift
struct Location: Codable {
    let id: Int
    let placeId: String
    let name: String
    let address: String?
    let lat: Double
    let lng: Double
    let type: String?
    let notes: String?
    let rating: Double?
    let createdAt: String
    let photosCount: Int
}
```

### Photo
```swift
struct Photo: Codable {
    let id: Int
    let imagekitFilePath: String
    let url: String
    let thumbnailUrl: String
    let caption: String?
    let width: Int?
    let height: Int?
    let uploadedAt: String
    let gpsLatitude: Double?
    let gpsLongitude: Double?
    let isPrimary: Bool
    let fileSize: Int?
    let mimeType: String?
}
```

---

## Testing

### Postman Collection

Import the Postman collection for easy API testing:
[Download Collection](../backend/postman/fotolokashen-api.json)

### Test Credentials

**Staging Environment**:
- Email: `test@fotolokashen.com`
- Password: `TestPassword123!`

---

**Last Updated**: January 14, 2026  
**API Version**: v1  
**Backend Repository**: [fotolokashen](https://github.com/yourusername/fotolokashen)
