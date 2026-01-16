# Photo Upload Debugging Guide

**Date**: January 16, 2026  
**Issue**: Photo upload reaching confirm step but not completing  
**Status**: 🔍 DEBUGGING

---

## 🎯 Problem Summary

User sees: `[APIClient] POST https://fotolokashen.com/api/locations/43/photos/30/confirm`

This means:
- ✅ Step 1: Request upload URL - **SUCCESS** (photo ID 30 created)
- ✅ Step 2: Upload to ImageKit - **LIKELY SUCCESS** (confirm endpoint called)
- ❌ Step 3: Confirm upload - **FAILING** (something wrong with request/response)

---

## 📊 The 3-Step Upload Flow

### Step 1: Request Upload URL
```
POST /api/locations/43/photos/request-upload
```
**Returns:**
```json
{
  "photoId": 30,
  "uploadUrl": "https://upload.imagekit.io/api/v1/files/upload",
  "uploadToken": "...",
  "signature": "...",
  "expire": 1705068300,
  "fileName": "photo_1705068000.jpg",
  "folder": "users/4/photos",
  "publicKey": "public_..."
}
```
**Status**: ✅ Working (we know photo ID is 30)

---

### Step 2: Upload to ImageKit
```
POST https://upload.imagekit.io/api/v1/files/upload
Content-Type: multipart/form-data
```

**Request includes:**
- `publicKey` ✓
- `signature` ✓
- `expire` ✓
- `token` ✓
- `fileName` ✓
- `folder` ✓
- `file` (binary data) ✓

**Expected Response:**
```json
{
  "fileId": "IMAGEKIT_FILE_ID",
  "name": "photo_789.jpg",
  "url": "https://ik.imagekit.io/rgriola/production/users/4/photos/photo_789.jpg",
  "thumbnailUrl": "...",
  "width": 3000,
  "height": 2000,
  "size": 1500000
}
```

**Status**: ❓ Likely succeeding but response parsing may be failing

---

### Step 3: Confirm Upload
```
POST /api/locations/43/photos/30/confirm
```

**Request Body:**
```json
{
  "imagekitFileId": "IMAGEKIT_FILE_ID",
  "imagekitUrl": "https://ik.imagekit.io/..."
}
```

**Expected Response:**
```json
{
  "success": true,
  "photo": {
    "id": 30,
    "imagekitFilePath": "/production/users/4/photos/photo_789.jpg",
    "url": "https://ik.imagekit.io/...",
    "uploadedAt": "2026-01-16T..."
  }
}
```

**Status**: ❌ Failing (this is where we see the log message)

---

## 🔍 Potential Issues

### 1. **ImageKit Response Field Names**

The iOS app expects:
```swift
struct ImageKitUploadResponse: Codable {
    let fileId: String
    let name: String
    let url: String
    let thumbnailUrl: String
    let width: Int
    let height: Int
    let size: Int
}
```

But ImageKit might return different field names. Common variations:
- `file_id` instead of `fileId`
- `thumbnail_url` instead of `thumbnailUrl`
- Missing fields
- Extra fields that aren't in our model

**Solution**: Added debug logging to see raw response

---

### 2. **Empty or Null Values**

If ImageKit returns the response but `fileId` or `url` is empty/null:

```swift
let confirmRequest = ConfirmUploadRequest(
    imagekitFileId: imagekitResponse.fileId,  // Could be ""
    imagekitUrl: imagekitResponse.url          // Could be ""
)
```

Backend will reject with: `"Missing required fields: imagekitFileId, imagekitUrl"`

---

### 3. **Backend Validation Failing**

The backend confirm endpoint checks:
```typescript
// Verify photo hasn't already been confirmed
if (photo.imagekitFileId) {
    return apiError('Photo already confirmed', 400);
}
```

If you're retrying uploads, photo 30 might already have an `imagekitFileId` set.

---

### 4. **User ID Mismatch**

Backend checks:
```typescript
if (photo.userId !== authResult.user.id) {
    return apiError('Unauthorized', 403);
}
```

If the photo was created by a different user session, this will fail.

---

## 🛠️ Debugging Steps

### Step 1: Check ImageKit Raw Response

**Added logging in PhotoUploadService.swift:**

```swift
// DEBUG: Log raw response to see actual field names
if config.enableDebugLogging {
    if let responseString = String(data: responseData, encoding: .utf8) {
        print("[PhotoUpload] ✅ ImageKit raw response: \(responseString)")
    }
}
```

**What to look for:**
1. Run the app with debug logging enabled
2. Try uploading a photo
3. Look for: `[PhotoUpload] ✅ ImageKit raw response: {...}`
4. Check if field names match our model
5. Check if `fileId` and `url` have actual values

---

### Step 2: Check Backend Response

**Look for these backend errors in Vercel logs:**

```bash
# Photo not found
"Photo not found"

# Already confirmed
"Photo already confirmed"

# Missing fields
"Missing required fields: imagekitFileId, imagekitUrl"

# Unauthorized
"Unauthorized"
```

---

### Step 3: Check Database

**Query the photo record:**

```sql
SELECT 
    id,
    userId,
    locationId,
    imagekitFileId,
    imagekitFilePath,
    originalFilename,
    uploadedAt
FROM "Photo"
WHERE id = 30;
```

**Check:**
- Does photo ID 30 exist?
- Is `imagekitFileId` empty or already set?
- Is `userId` correct for authenticated user?

---

## 🔧 Quick Fixes

### Fix 1: Handle ImageKit Field Name Variations

Update the decoder to be more flexible:

```swift
struct ImageKitUploadResponse: Codable {
    let fileId: String
    let name: String
    let url: String
    let thumbnailUrl: String?  // Make optional
    let width: Int?             // Make optional
    let height: Int?            // Make optional
    let size: Int?              // Make optional
    
    enum CodingKeys: String, CodingKey {
        case fileId
        case name
        case url
        case thumbnailUrl = "thumbnailUrl"  // or "thumbnail_url"
        case width
        case height
        case size
    }
}
```

---

### Fix 2: Add Better Error Handling

```swift
// Parse response with better error handling
let decoder = JSONDecoder()
do {
    let imagekitResponse = try decoder.decode(ImageKitUploadResponse.self, from: responseData)
    
    // Validate response has required fields
    guard !imagekitResponse.fileId.isEmpty else {
        print("[PhotoUpload] ERROR: ImageKit returned empty fileId")
        throw PhotoUploadError.imagekitUploadFailed
    }
    
    guard !imagekitResponse.url.isEmpty else {
        print("[PhotoUpload] ERROR: ImageKit returned empty URL")
        throw PhotoUploadError.imagekitUploadFailed
    }
    
    return imagekitResponse
    
} catch {
    print("[PhotoUpload] ERROR: Failed to decode ImageKit response: \(error)")
    if let responseString = String(data: responseData, encoding: .utf8) {
        print("[PhotoUpload] Raw response was: \(responseString)")
    }
    throw PhotoUploadError.imagekitUploadFailed
}
```

---

### Fix 3: Check Confirm Request

Add logging before calling confirm:

```swift
// Step 4: Confirm upload with backend
if config.enableDebugLogging {
    print("[PhotoUpload] Confirming upload...")
    print("[PhotoUpload] - Photo ID: \(uploadResponse.photoId)")
    print("[PhotoUpload] - FileId: \(imagekitResponse.fileId)")
    print("[PhotoUpload] - URL: \(imagekitResponse.url)")
}

let confirmRequest = ConfirmUploadRequest(
    imagekitFileId: imagekitResponse.fileId,
    imagekitUrl: imagekitResponse.url
)
```

---

## 📝 Testing Checklist

Run through these tests:

- [ ] Enable debug logging in app
- [ ] Capture photo with camera
- [ ] Watch console for all three steps
- [ ] Check for `[PhotoUpload] ✅ ImageKit raw response:`
- [ ] Verify `fileId` and `url` are present
- [ ] Check backend logs for confirm endpoint errors
- [ ] Query database for photo record
- [ ] Verify ImageKit dashboard shows uploaded file
- [ ] Try uploading same photo twice (test retry behavior)

---

## 🎯 Expected Console Output

**Successful upload should show:**

```
[PhotoUpload] Compressing image...
[PhotoUpload] Compressed to 850KB
[PhotoUpload] Requesting upload URL...
[PhotoUpload] Upload URL received
[PhotoUpload] Uploading to ImageKit...
[PhotoUpload] ImageKit multipart upload starting...
[PhotoUpload] Image data size: 871424 bytes
[PhotoUpload] Folder: users/4/photos
[PhotoUpload] Filename: photo_1705267890.jpg
[PhotoUpload] ImageKit response status: 200
[PhotoUpload] ✅ ImageKit raw response: {"fileId":"abc123","name":"photo_1705267890.jpg","url":"https://ik.imagekit.io/rgriola/production/users/4/photos/photo_1705267890.jpg",...}
[PhotoUpload] ImageKit upload successful!
[PhotoUpload] File ID: abc123
[PhotoUpload] URL: https://ik.imagekit.io/rgriola/production/users/4/photos/photo_1705267890.jpg
[PhotoUpload] Confirming upload...
[PhotoUpload] - Photo ID: 30
[PhotoUpload] - FileId: abc123
[PhotoUpload] - URL: https://ik.imagekit.io/rgriola/production/users/4/photos/photo_1705267890.jpg
[APIClient] POST https://fotolokashen.com/api/locations/43/photos/30/confirm
[PhotoUpload] Upload complete! Photo ID: 30
```

---

## 🚨 Common Error Messages

### "Photo already confirmed"
**Cause**: Photo record already has `imagekitFileId` set  
**Fix**: Use a fresh photo record or allow re-upload

### "Missing required fields"
**Cause**: `fileId` or `url` is empty/null from ImageKit response  
**Fix**: Check ImageKit response format, validate fields before sending

### "Unauthorized"
**Cause**: Photo belongs to different user  
**Fix**: Ensure auth token is correct, check user ID matches

### "Photo not found"
**Cause**: Photo ID doesn't exist in database  
**Fix**: Verify Step 1 completed successfully, check photo ID in logs

---

## 📚 Related Files

**iOS App:**
- `/swift-utilities/PhotoUploadService.swift` - Upload logic
- `/swift-utilities/Models/Photo.swift` - Data models
- `/swift-utilities/APIClient.swift` - Network client

**Backend:**
- `/src/app/api/locations/[id]/photos/request-upload/route.ts` - Step 1
- `/src/app/api/locations/[id]/photos/[photoId]/confirm/route.ts` - Step 3

**Documentation:**
- `/docs/API.md` - Full API specification
- `/docs/IMAGEKIT_SDK_FIX.md` - Recent ImageKit changes

---

## 💡 Next Steps

1. **Run app with debug logging**
2. **Look for the raw ImageKit response** in console
3. **Check if field names match** your model
4. **Verify fileId and url have values**
5. **Check backend logs** for specific error
6. **Query database** to see photo record state

Once you see the raw ImageKit response, we can fix any field name mismatches or validation issues.

---

**Status**: 🔍 DEBUGGING  
**Priority**: HIGH  
**Blocker**: Yes (prevents photo uploads)
