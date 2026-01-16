# fotolokashen iOS - Focused MVP Scope

**Purpose**: Quick location creation companion app for the web platform

---

## 🎯 **Core User Flow**

### **Primary Flow: Camera → Location**
1. User opens app (already logged in)
2. Tap "Create Location" button
3. **Camera opens** with GPS tracking
4. User takes photo
5. **Simple form appears**:
   - Location Name (required)
   - Location Type dropdown (required)
   - Auto-filled GPS coordinates (from photo)
6. Tap "Save"
7. Photo uploads + Location created
8. Success! → Return to map

### **Alternative Flow: Photo Library → Location**
1. User opens app
2. Tap "Create from Library"
3. **Photo picker opens**
4. User selects photo
5. **Same simple form**:
   - Location Name
   - Location Type
   - GPS from photo EXIF (if available)
   - Manual location picker if no GPS
6. Tap "Save"
7. Upload + Create
8. Success!

---

## 📱 **App Structure (Simplified)**

```
App Screens:
├── Login (OAuth) ✅ DONE
├── Map View (Main)
│   ├── Shows all user locations
│   ├── "+" FAB button → Create Location
│   └── Tap marker → View location details
└── Create Location
    ├── Camera capture OR
    ├── Photo library picker
    └── Simple form (name, type, GPS)
```

---

## 🏗️ **Implementation Order**

### **Phase 1: Foundation** ✅ COMPLETE
- Xcode project
- Authentication (OAuth2)
- Core services ready

### **Phase 2: Create Location Flow** (NEXT)
**Priority: Camera + Form**

#### **Step 1: Camera Capture View** (30 min)
- Simple camera preview
- Capture button
- GPS tracking active
- Show GPS coordinates on screen

#### **Step 2: Create Location Form** (45 min)
- Name input
- Type dropdown (from backend types)
- GPS display (lat/lng)
- Save button

#### **Step 3: Location Service** (30 min)
- Create location API call
- Upload photo
- Link photo to location
- Error handling

#### **Step 4: Photo Library Alternative** (30 min)
- Photo picker
- Extract EXIF GPS
- Same form flow

### **Phase 3: Map View** (NEXT AFTER CREATE)
**Priority: View locations**

#### **Step 1: Google Maps Integration** (45 min)
- Map view with user's current location
- Fetch user's locations from API
- Display markers

#### **Step 2: Location Details** (30 min)
- Tap marker → Show location info
- Display photo
- Show metadata

---

## 🎨 **UI/UX Design**

### **Main Screen: Map**
```
┌─────────────────────────┐
│  fotolokashen      [👤] │ ← Header with profile
├─────────────────────────┤
│                         │
│    [Google Maps View]   │ ← Full screen map
│    • Markers for locs   │
│    • User location dot  │
│                         │
│                    [+]  │ ← FAB button (bottom right)
└─────────────────────────┘
```

### **Camera Screen**
```
┌─────────────────────────┐
│  [X]           GPS: ✓   │ ← Close + GPS indicator
├─────────────────────────┤
│                         │
│   [Camera Preview]      │ ← Live camera
│                         │
│   📍 37.7749, -122.4194│ ← GPS coords
│                         │
│        [○]              │ ← Capture button
└─────────────────────────┘
```

### **Create Location Form**
```
┌─────────────────────────┐
│  Create Location   [X]  │
├─────────────────────────┤
│  [Photo Preview]        │ ← Captured/selected photo
├─────────────────────────┤
│  Location Name *        │
│  ┌───────────────────┐  │
│  │ Golden Gate Park │  │
│  └───────────────────┘  │
│                         │
│  Type *                 │
│  ┌───────────────────┐  │
│  │ Park          ▼  │  │
│  └───────────────────┘  │
│                         │
│  GPS Coordinates        │
│  📍 37.7749, -122.4194 │
│                         │
│     [Save Location]     │ ← Primary button
└─────────────────────────┘
```

---

## 🔧 **Technical Implementation**

### **Services Needed**
1. ✅ **AuthService** - Already done
2. ✅ **LocationManager** - Already done
3. ✅ **CameraService** - Already done
4. ✅ **PhotoUploadService** - Already done
5. **LocationService** - NEW (CRUD for locations)

### **Views Needed**
1. **MapView** - Google Maps with markers
2. **CameraView** - Camera capture with GPS
3. **CreateLocationView** - Form for location details
4. **PhotoPickerView** - Photo library selection

### **Models** (Already have)
- ✅ User
- ✅ Location
- ✅ Photo
- ✅ OAuthToken

---

## 📋 **Recommended Build Order**

### **TODAY (if continuing):**

**Option A: Camera-First Approach** (Recommended)
1. Build CameraView (30 min)
2. Build CreateLocationForm (45 min)
3. Build LocationService (30 min)
4. Test end-to-end: Camera → Form → Save
5. **Result**: Can create locations with camera!

**Option B: Map-First Approach**
1. Build MapView (45 min)
2. Build LocationService (30 min)
3. Test: See existing locations on map
4. **Result**: Can view locations!

---

## 🎯 **My Recommendation: Camera-First**

**Why?**
- Core value prop: "Quick location creation"
- Most unique feature vs web app
- Validates the full flow early
- Map viewing can come after

**Build Order:**
1. **CameraView** - Get photo capture working
2. **CreateLocationForm** - Simple form
3. **LocationService** - API integration
4. **Test** - Create a real location!
5. **MapView** - See your creation on map
6. **Polish** - Error handling, loading states

---

## ⏱️ **Time Estimates**

### **Minimum Viable Product**
- Camera capture: 30 min
- Create form: 45 min
- Location service: 30 min
- Map view: 45 min
- **Total**: ~2.5 hours

### **Polished Version**
- Add photo library: 30 min
- Error handling: 30 min
- Loading states: 20 min
- Polish UI: 40 min
- **Total**: +2 hours = ~4.5 hours

---

## 🚀 **Let's Start!**

**I recommend we build:**
1. **CameraView** (next)
2. **CreateLocationForm**
3. **LocationService**

This gets you to a working "create location" flow in ~2 hours.

**Sound good?** Let's build the CameraView! 📸

---

**Status**: Ready to build Camera UI  
**Next**: CameraView with live preview and capture  
**ETA**: 30 minutes
