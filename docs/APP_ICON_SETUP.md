# App Icon & Launch Screen Setup Guide

**Date**: January 16, 2026  
**Files Created**: `AppIcon.png`, `LaunchScreen.png`

---

## 📱 **App Icon Setup**

### **Step 1: Open Assets Catalog**
1. In Xcode, navigate to `fotolokashen/fotolokashen/Assets.xcassets`
2. Click on `AppIcon` in the left sidebar

### **Step 2: Add App Icon**
1. Drag `AppIcon.png` (1024x1024) from Finder
2. Drop it into the **"1024pt"** slot in the AppIcon set
3. Xcode will automatically generate all required sizes

**Alternative Method**:
1. Right-click on `AppIcon` → **Show in Finder**
2. Copy `AppIcon.png` to the opened folder
3. Rename it to match Xcode's naming convention
4. Return to Xcode and it should appear

### **Verification**:
- ✅ Icon appears in all size slots
- ✅ No yellow warnings in Assets.xcassets
- ✅ Build succeeds without errors

---

## 🚀 **Launch Screen Setup**

### **Option A: Using Storyboard (Recommended)**

1. **Create Launch Screen Storyboard** (if not exists):
   - File → New → File
   - Choose "Launch Screen" under iOS → User Interface
   - Name it `LaunchScreen.storyboard`
   - Save in `fotolokashen/fotolokashen/`

2. **Add Launch Image**:
   - Drag `LaunchScreen.png` into `Assets.xcassets`
   - Create new Image Set called `LaunchImage`
   - Add the image to "1x" slot

3. **Design Launch Screen**:
   - Open `LaunchScreen.storyboard`
   - Add an `UIImageView` to the view controller
   - Set constraints: 0 top, 0 bottom, 0 leading, 0 trailing
   - Set image to `LaunchImage`
   - Set Content Mode to "Aspect Fill"

4. **Configure in Project Settings**:
   - Select project in navigator
   - Select `fotolokashen` target
   - Go to "General" tab
   - Under "App Icons and Launch Screen"
   - Set "Launch Screen File" to `LaunchScreen`

### **Option B: Using SwiftUI (Modern)**

Create a new SwiftUI view:

```swift
// LaunchScreenView.swift
import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            // Purple gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.545, green: 0.361, blue: 0.965), // #8B5CF6
                    Color(red: 0.388, green: 0.400, blue: 0.945)  // #6366F1
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Crosshair icon
                Image(systemName: "scope")
                    .font(.system(size: 120))
                    .foregroundColor(.white)
                
                // App name
                Text("fotolokashen")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.white)
                
                // Tagline
                Text("coordinate with purpose")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}
```

Then update `fotolokashenApp.swift`:

```swift
@main
struct fotolokashenApp: App {
    @StateObject private var authService = AuthService()
    @State private var showLaunchScreen = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(authService)
                
                if showLaunchScreen {
                    LaunchScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                // Hide launch screen after 1.5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showLaunchScreen = false
                    }
                }
            }
        }
    }
}
```

---

## 🎨 **Brand Colors**

Add these to your Assets.xcassets for consistent branding:

### **Color Set: BrandPurple**
- Light Mode: `#8B5CF6` (RGB: 139, 92, 246)
- Dark Mode: `#6366F1` (RGB: 99, 102, 241)

### **Color Set: BrandPurpleDark**
- Light Mode: `#6366F1` (RGB: 99, 102, 241)
- Dark Mode: `#8B5CF6` (RGB: 139, 92, 246)

**Usage in SwiftUI**:
```swift
Color("BrandPurple")
```

---

## ✅ **Testing**

### **Test App Icon**:
1. Build and run on simulator
2. Press Home button (⌘+Shift+H)
3. Check Home screen for your icon
4. Icon should show purple gradient with white crosshair

### **Test Launch Screen**:
1. Delete app from simulator
2. Clean build folder (⌘+Shift+K)
3. Build and run
4. Launch screen should appear briefly before app loads

---

## 📋 **Required Sizes (Auto-generated from 1024x1024)**

iOS automatically generates these from your 1024x1024 icon:
- 20pt (1x, 2x, 3x) - Notifications
- 29pt (1x, 2x, 3x) - Settings
- 40pt (1x, 2x, 3x) - Spotlight
- 60pt (2x, 3x) - App Icon
- 76pt (1x, 2x) - iPad
- 83.5pt (2x) - iPad Pro
- 1024pt (1x) - App Store

---

## 🚨 **Common Issues**

### **Icon not showing**:
- Clean build folder (⌘+Shift+K)
- Delete app from simulator
- Reset simulator content and settings
- Rebuild

### **Launch screen not updating**:
- Delete app from device/simulator
- Clean build folder
- Reset simulator
- Check "Launch Screen File" in project settings

### **Yellow warnings in Assets**:
- Ensure 1024x1024 icon is exactly that size
- Check that image is PNG format
- Verify no alpha channel issues

---

## 🎯 **Next Steps**

After adding icon and launch screen:
1. ✅ Test on multiple simulators (iPhone, iPad)
2. ✅ Test on real device
3. ✅ Verify in light and dark mode
4. ✅ Check App Store Connect requirements
5. ✅ Prepare for TestFlight

---

**Files Location**:
- App Icon: `/Users/rgriola/Desktop/01_Vibecode/fotolokashen-ios/AppIcon.png`
- Launch Screen: `/Users/rgriola/Desktop/01_Vibecode/fotolokashen-ios/LaunchScreen.png`

**Brand Assets**:
- Purple Gradient: #8B5CF6 → #6366F1
- White Crosshair Icon
- Tagline: "coordinate with purpose"
