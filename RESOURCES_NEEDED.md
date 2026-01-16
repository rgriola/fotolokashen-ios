# Resources Needed for iOS Development

**Project**: fotolokashen iOS Companion App  
**Date**: January 15, 2026  
**Status**: Ready to Begin - Pending Resources

---

## 📋 Checklist Overview

- ✅ **Backend API**: Complete and ready
- ⏳ **Deployment**: Needs staging deployment
- ⏳ **API Keys**: Needed for iOS app
- ⏳ **Test Credentials**: Needed for development
- ⏳ **Development Environment**: Verify Xcode setup

---

## 1. Backend Deployment (Critical)

### ⏳ Deploy OAuth2 Feature Branch

**Current Status**: Code is on `feature/oauth2-implementation` branch  
**Action Required**: Deploy to staging/production

#### Steps:
```bash
# 1. Merge feature branch to main
git checkout main
git merge feature/oauth2-implementation

# 2. Deploy to Vercel (staging)
vercel --prod

# 3. Verify deployment
curl https://staging.fotolokashen.com/api/health
```

#### Database Setup:
```sql
-- Register iOS OAuth client
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

**Priority**: 🔴 **CRITICAL** - Required before iOS OAuth testing

---

## 2. API Keys & Credentials

### ⏳ Google Maps API Key (iOS)

**What I Need**:
- Google Maps API key with iOS restrictions
- Bundle identifier: `com.fotolokashen.ios`

**How to Get**:
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Enable "Maps SDK for iOS"
3. Create API key
4. Add iOS restriction with bundle ID: `com.fotolokashen.ios`

**Format**:
```
AIzaSy... (your API key)
```

**Priority**: 🟡 **HIGH** - Needed for map features (can develop camera first without this)

---

### ⏳ ImageKit Public Key

**What I Need**:
- ImageKit public key (for client-side uploads)
- ImageKit URL endpoint

**Current Values** (from backend):
- URL Endpoint: `https://ik.imagekit.io/rgriola`
- Public Key: `???` (need to confirm)

**How to Get**:
1. Log in to [ImageKit Dashboard](https://imagekit.io/dashboard)
2. Go to Developer Options → API Keys
3. Copy "Public Key"

**Format**:
```
public_XXXXXXXXXXXXXXXXXXXX
```

**Priority**: 🟡 **HIGH** - Needed for photo uploads

---

### ⏳ Backend Environment URLs

**What I Need**:
Confirm which environment to use for iOS development

**Options**:
- [ ] **Production**: `https://fotolokashen.com`
- [ ] **Staging**: `https://staging.fotolokashen.com` (recommended)
- [ ] **Local Development**: `http://localhost:3000`

**Recommendation**: Use staging for iOS development

**Priority**: 🔴 **CRITICAL** - Needed immediately

---

## 3. Test Credentials

### ⏳ Test User Account

**What I Need**:
A test user account for OAuth flow testing

**Required Info**:
- Email: `???`
- Password: `???`
- Username: `???`

**How to Create**:
1. Register on staging/production
2. Verify email
3. Share credentials with iOS dev team

**Priority**: 🟡 **HIGH** - Needed for OAuth testing

---

## 4. Development Environment

### ⏳ Xcode Installation

**Question**: Do you have Xcode installed?

**Required Version**: Xcode 15.0 or later

**How to Install**:
```bash
# Check if installed
xcode-select -p

# Install if needed
# Download from Mac App Store or developer.apple.com
```

**Priority**: 🔴 **CRITICAL** - Required for iOS development

---

### ⏳ Apple Developer Account

**Question**: Do you have an Apple Developer account?

**Needed For**:
- Testing on real iOS devices
- TestFlight beta distribution
- App Store submission

**Types**:
- [ ] **Free Account** - Can test on your own devices (7-day limit)
- [ ] **Paid Account** ($99/year) - Full access, TestFlight, App Store

**Priority**: 🟡 **MEDIUM** - Can develop with simulator initially

---

## 5. Project Configuration Values

### Config.plist Template

Once you provide the above resources, I'll create a `Config.plist` file with these values:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
    <!-- Backend Configuration -->
    <key>backendBaseURL</key>
    <string>https://staging.fotolokashen.com</string>
    
    <!-- Google Maps -->
    <key>googleMapsAPIKey</key>
    <string>YOUR_GOOGLE_MAPS_KEY</string>
    
    <!-- ImageKit -->
    <key>imagekitPublicKey</key>
    <string>YOUR_IMAGEKIT_PUBLIC_KEY</string>
    
    <key>imagekitUrlEndpoint</key>
    <string>https://ik.imagekit.io/rgriola</string>
    
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
</dict>
</plist>
```

---

## 6. What I Can Build Without Resources

### ✅ Can Start Immediately (No Backend Needed)

1. **Xcode Project Setup**
   - Create SwiftUI project
   - Set up folder structure
   - Configure build settings

2. **Core Utilities**
   - `PKCEGenerator.swift` - PKCE challenge generation
   - `ImageCompressor.swift` - Image compression logic
   - `ConfigLoader.swift` - Config.plist reader
   - Extensions and helpers

3. **Camera Feature**
   - `CameraCaptureView.swift` - Camera UI
   - `CameraSession.swift` - AVFoundation integration
   - `PhotoPreviewView.swift` - Preview UI
   - Location capture (CoreLocation)

4. **Core Data Models**
   - `LocationDraft` entity
   - `PhotoDraft` entity
   - Persistence layer

5. **UI Components**
   - Reusable SwiftUI components
   - Design system
   - Navigation structure

### ⏳ Needs Resources

6. **Authentication** - Needs backend URL + test credentials
7. **API Integration** - Needs backend URL + ImageKit key
8. **Map Integration** - Needs Google Maps API key
9. **Photo Upload** - Needs backend URL + ImageKit key

---

## 7. Recommended Development Approach

### Phase 1: Offline Features (Start Now)
**Duration**: 1-2 days  
**No Resources Needed**

- [x] Create Xcode project
- [ ] Implement PKCEGenerator
- [ ] Implement ImageCompressor
- [ ] Build camera capture UI
- [ ] Implement location services
- [ ] Create Core Data models

### Phase 2: Backend Integration (Needs Resources)
**Duration**: 2-3 days  
**Requires**: Backend URL, test credentials

- [ ] Implement AuthService
- [ ] Implement APIClient
- [ ] Test OAuth flow
- [ ] Implement upload manager

### Phase 3: Full Integration (Needs All Resources)
**Duration**: 3-4 days  
**Requires**: All API keys

- [ ] Integrate Google Maps
- [ ] Complete photo upload flow
- [ ] End-to-end testing
- [ ] UI polish

---

## 8. Quick Start Checklist

### Before Our Next Session, Please Provide:

#### Critical (Need ASAP):
- [ ] **Backend URL** - Which environment should iOS use?
  - Production: `https://fotolokashen.com`
  - Staging: `https://staging.fotolokashen.com`
  - Local: `http://localhost:3000`

- [ ] **OAuth Client Status** - Is `fotolokashen-ios` registered in database?
  - [ ] Yes, already registered
  - [ ] No, needs to be added (I can provide SQL)

#### High Priority (Need Soon):
- [ ] **Google Maps API Key** - For iOS app
- [ ] **ImageKit Public Key** - For photo uploads
- [ ] **Test Credentials** - Email/password for testing

#### Medium Priority (Can Wait):
- [ ] **Apple Developer Account Status** - Free or paid?
- [ ] **Preferred Testing Device** - iPhone model for testing

---

## 9. What I'll Deliver Today

### Without Any Resources, I Can:

1. ✅ **Create Xcode Project**
   - SwiftUI app template
   - Proper folder structure
   - Build configuration

2. ✅ **Implement Core Utilities**
   - PKCEGenerator (working, tested)
   - ImageCompressor (working, tested)
   - ConfigLoader (with placeholder values)

3. ✅ **Build Camera Feature**
   - Full camera capture flow
   - Image compression
   - GPS location tagging
   - Photo preview

4. ✅ **Create Config Template**
   - Config.plist with placeholders
   - Instructions for adding real values

### With Resources, I Can Also:

5. ⏳ **Implement Authentication**
   - Complete OAuth flow
   - Token management
   - Keychain storage

6. ⏳ **Build API Client**
   - Network layer
   - Bearer token auth
   - Error handling

---

## 10. Summary

### ✅ What's Ready
- Backend API is complete and production-ready
- iOS development plan is solid
- Architecture is well-designed

### ⏳ What's Needed
1. Backend deployment (staging or production)
2. OAuth client registration in database
3. Google Maps API key (iOS)
4. ImageKit public key
5. Test user credentials
6. Xcode installation confirmation

### 🚀 What I Recommend

**Start Today**:
- Create Xcode project
- Build offline features (camera, compression, Core Data)
- Create config template with placeholders

**Next Session** (once you provide resources):
- Implement OAuth flow
- Build API client
- Integrate photo uploads
- Add Google Maps

---

## Questions?

Please provide answers to these key questions:

1. **Which backend environment should iOS use?** (production/staging/local)
2. **Is the OAuth2 branch deployed yet?** (yes/no)
3. **Do you have Xcode installed?** (yes/no)
4. **Can you provide the Google Maps API key?** (yes/no/need help)
5. **Can you provide the ImageKit public key?** (yes/no/need help)

Once you answer these, I'll know exactly what to build first! 🚀

---

**Created**: January 15, 2026  
**Status**: Awaiting Resources  
**Next Step**: Your answers to the questions above
