# Google Maps SDK Setup Guide

**Date**: January 16, 2026  
**SDK**: Google Maps SDK for iOS

---

## 📦 **Step 1: Add Google Maps SDK**

### **Using Swift Package Manager** (Recommended)

1. **Open Xcode**
2. **File** → **Add Package Dependencies**
3. **Enter URL**: `https://github.com/googlemaps/ios-maps-sdk`
4. **Version**: Select "Up to Next Major Version" → `8.0.0`
5. **Add to Target**: `fotolokashen`
6. **Click** "Add Package"

### **Packages to Add**:
- ✅ `GoogleMaps` (required)
- ✅ `GoogleMapsUtils` (for clustering)

---

## 🔑 **Step 2: Configure API Key**

### **Update Config.plist**

The Google Maps API key is already in your `Config.plist`:

```xml
<key>GoogleMapsAPIKey</key>
<string>YOUR_API_KEY_HERE</string>
```

### **Initialize in App**

Update `fotolokashenApp.swift`:

```swift
import SwiftUI
import GoogleMaps

@main
struct fotolokashenApp: App {
    @StateObject private var authService = AuthService()
    
    init() {
        // Initialize Google Maps
        let config = ConfigLoader.shared
        GMSServices.provideAPIKey(config.googleMapsAPIKey)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
        }
    }
}
```

---

## 🗺️ **Step 3: Create Map View**

The map view will be created in the next steps with:
- Location markers
- Clustering for nearby locations
- Tap to view details
- Current location button
- Custom marker icons by type

---

## ✅ **Verification**

After adding the SDK:
1. Build the project (⌘+B)
2. Check for any errors
3. Verify `import GoogleMaps` works
4. No red errors in console

---

## 🚨 **Common Issues**

### **"No such module 'GoogleMaps'"**
- Clean build folder (⌘+Shift+K)
- Close and reopen Xcode
- Verify package was added to target

### **API Key Issues**
- Verify key in Config.plist
- Check key has Maps SDK enabled in Google Cloud Console
- Ensure no extra spaces in key

### **Build Errors**
- Update to latest Xcode
- Check minimum iOS version (16.0+)
- Verify Swift version compatibility

---

## 📋 **Next Steps**

1. ✅ Add Google Maps SDK package
2. ✅ Update fotolokashenApp.swift with API key
3. 🔄 Create MapView component
4. 🔄 Add location markers
5. 🔄 Implement clustering
6. 🔄 Add map tab to navigation

---

**Ready to proceed with map implementation!** 🗺️✨
