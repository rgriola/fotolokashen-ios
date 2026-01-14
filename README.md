# fotolokashen iOS

iOS companion app for fotolokashen - A camera-first location scouting and photo management app.

## Overview

The fotolokashen iOS app is a mobile companion to the fotolokashen web platform, designed for photographers and location scouts to capture, tag, and upload photos directly from their iPhone.

## Features

- 📷 **Camera-First Workflow** - Quick capture with automatic GPS tagging
- 🗺️ **Location Management** - Browse and manage saved locations
- 🔐 **Secure Authentication** - OAuth2 with PKCE for secure login
- 📤 **Smart Upload** - Automatic image compression and background sync
- 💾 **Offline Support** - Work offline, sync when connected
- 🎯 **EXIF Metadata** - Preserve camera settings and GPS coordinates

## Tech Stack

- **SwiftUI** - Modern declarative UI
- **Swift Concurrency** - async/await for clean async code
- **MVVM Architecture** - Clean separation of concerns
- **Core Data** - Local persistence and offline support
- **Google Maps SDK** - Interactive map views
- **KeychainAccess** - Secure token storage

## Project Structure

```
fotolokashen-ios/
├── fotolokashen/           # Main app target
│   ├── App/                # App entry point & config
│   ├── Models/             # Data models
│   ├── ViewModels/         # Business logic
│   ├── Views/              # SwiftUI views
│   ├── Services/           # API & auth services
│   ├── Utilities/          # Helpers & extensions
│   └── Resources/          # Assets & config files
├── fotolokashenTests/      # Unit tests
└── docs/                   # Documentation
```

## Getting Started

### Prerequisites

- macOS 13.0 or later
- Xcode 15.0 or later
- iOS 16.0+ deployment target
- Active fotolokashen account

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/fotolokashen-ios.git
   cd fotolokashen-ios
   ```

2. **Open in Xcode**
   ```bash
   open fotolokashen.xcodeproj
   ```

3. **Configure API Keys**
   - Copy `Config.example.plist` to `Config.plist`
   - Add your Google Maps API key
   - Configure backend URL

4. **Build and Run**
   - Select a simulator or device
   - Press ⌘+R to build and run

## Documentation

- [iOS Development Stack](docs/IOS_DEVELOPMENT_STACK.md) - Complete setup guide
- [iOS App Evaluation](docs/IOS_APP_EVALUATION.md) - Architecture analysis
- [API Documentation](docs/API.md) - Backend API reference

## Backend Integration

This app integrates with the fotolokashen backend API:
- **OAuth2 Authentication** - Secure login with PKCE
- **Photo Upload** - Signed URLs for direct ImageKit upload
- **Location Management** - CRUD operations for locations
- **User Profile** - Account settings and preferences

Backend repository: [fotolokashen](https://github.com/yourusername/fotolokashen)

## Development Status

🚧 **In Development**

- [x] Project setup and architecture
- [x] OAuth2 backend implementation
- [ ] Core services (Auth, API, Upload)
- [ ] Camera capture functionality
- [ ] Map integration
- [ ] Photo upload flow
- [ ] Offline support
- [ ] TestFlight beta

## Contributing

This is a private project. For questions or issues, contact the development team.

## License

Proprietary - All rights reserved

---

**Backend**: OAuth2 API complete on `feature/oauth2-implementation` branch  
**Status**: Ready to begin iOS development  
**Next**: Implement core services and camera capture
