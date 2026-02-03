# fotolokashen iOS Custom Agent Instructions

## Project Overview
This is a SwiftUI-based iOS app for location scouting with camera-first workflow, GPS tagging, and OAuth2 authentication.

## Architecture Pattern
- **Hybrid MVVM + Shared Store** architecture
- Singleton `LocationStore.shared` for shared state
- Service layer in `swift-utilities/` directory
- SwiftUI views with `@EnvironmentObject` and `@ObservedObject`

## Code Style Guidelines

### Swift Style
- Follow SwiftLint configuration in `.swiftlint.yml`
- Line length: 120 char warning, 150 char error
- Function body length: 50 lines warning, 100 lines error
- Use `@MainActor` for UI-bound services
- Prefer `async/await` over completion handlers

### Naming Conventions
- Services: `XxxService.swift` (e.g., `AuthService`, `LocationService`)
- Models: Singular nouns in `Models/` directory
- Views: `XxxView.swift` suffix
- View Models: `XxxViewModel.swift` (if needed)

### File Organization
```
fotolokashen/fotolokashen/
├── fotolokashenApp.swift (app entry point)
├── ContentView.swift (auth routing)
├── Views/ (SwiftUI views)
├── Services/ (app-level services like LocationStore)
└── swift-utilities/ (core utilities & models)
    ├── Models/
    ├── Services/
    └── Utilities/
```

## Key Patterns to Follow

### 1. Authentication
- Use `AuthService` singleton with `@EnvironmentObject`
- OAuth2 PKCE flow via Safari
- Token storage in `KeychainService`
- Auto-logout on 401 responses

### 2. Networking
- Use `APIClient` for all backend calls
- Base URL from `ConfigLoader.shared.backendBaseURL`
- Include bearer token from `KeychainService`
- Handle errors with proper user-facing messages

### 3. Location Management
- Use `LocationStore.shared` for shared state
- GPS via `LocationManager` service
- Geocoding via Google Maps API (primary) with Apple CLGeocoder fallback
- 15 location types with consistent colors via `LocationTypeColors`

### 4. Image Handling
- Compress via `ImageCompressor` before upload
- Target size: 1.5MB (configurable in Config.plist)
- Upload to ImageKit via `PhotoUploadService`
- Maintain EXIF data

### 5. Google Maps Integration
- Initialize SDK in `fotolokashenApp.init()`
- Custom markers via `MarkerIconGenerator`
- Marker clustering for performance
- Color-coded by location type

## Dependencies
- **Google Maps SDK**: For map display and clustering
- **ImageKit**: For cloud image storage
- **SwiftData**: Local caching (iOS 17+)
- **CryptoKit**: PKCE generation

## Configuration
- All config in `Config.plist` (example: `Config.example.plist`)
- Loaded via `ConfigLoader.shared`
- Never commit actual API keys

## Testing
- Write unit tests for services
- Mock network calls
- Test error handling paths
- Validate OAuth flow

## Common Tasks

### Adding a New View
1. Create file in `Views/` directory
2. Use SwiftUI declarative syntax
3. Inject dependencies via `@EnvironmentObject`
4. Handle loading/error states

### Adding a New Service
1. Create file in `swift-utilities/` directory
2. Mark with `@MainActor` if UI-bound
3. Use singleton pattern if shared state needed
4. Document public APIs

### Adding a New Model
1. Create in `swift-utilities/Models/`
2. Conform to `Codable` for JSON parsing
3. Add computed properties for derived data
4. Match backend API structure

## Error Handling
- Use `do-try-catch` for async calls
- Display user-facing error messages
- Log errors with service tags: `print("[ServiceName] error")`
- Handle network failures gracefully

## Async/Await Best Practices
- Use `async` functions for network calls
- Await on background thread, update UI on `@MainActor`
- Wrap in Task {} when calling from non-async context
- Handle cancellation appropriately

## When Making Changes
1. Run SwiftLint before committing
2. Update CHANGELOG.md for significant changes
3. Test on both iOS 17+ and legacy iOS
4. Verify Config.plist changes don't break builds