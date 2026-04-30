# Services Layer

Layered service architecture for the fotolokashen iOS app. Reorganized in Phase 2d (April 2026) — the legacy `swift-utilities/` folder was merged into `Services/` so all non-view code lives in one place under domain-grouped subfolders.

> Xcode uses `PBXFileSystemSynchronizedRootGroup` — any `.swift` file dropped into one of these folders is automatically included in the build. No pbxproj edits needed.

## Layout

```
Services/
├── Networking/      APIClient, AuthService, KeychainService, PKCEGenerator,
│                    ConfigLoader, NetworkMonitor
├── Camera/          CameraService, CameraSessionViewModel
├── Photo/           PhotoUploadService, PhotoPipelineModels, ImageCompressor,
│                    EXIFExtractor, ImageKitURL, SessionCapture, GPSSpreadAnalyzer,
│                    PhotoPipeline/  (PhotoPipelineCoordinator + stages)
├── Locations/       LocationService, LocationGroupService, LocationManager,
│                    LocationRepository, MapNavigationCoordinator, LocationStore (facade),
│                    GeocodingService, PlacesService, GeographicClusterAlgorithm,
│                    MarkerIconGenerator, StaticMapHelper, SyncService, DataManager
├── Social/          UserService, FollowService
├── DeepLink/        DeepLinkManager
├── Errors/          ErrorPresenter, AppError
├── UI/              AppColors, AppIcons, LocationTypeColors
├── Models/          Codable models (User, Location, Photo, Social, OAuthToken,
│                    CachedLocation, CachedPhoto, OfflinePhoto)
├── LocationDetail/  LocationDetailViewModel
├── EditLocation/    EditLocationViewModel
└── CreateLocation/  CreateLocationViewModel
```

## Conventions

- **Singletons**: `XxxService.shared` for shared state; inject in constructors for testability.
- **MainActor**: All `ObservableObject` services are `@MainActor` isolated.
- **Errors**: New code presents user-facing errors via `ErrorPresenter.shared.present(...)` rather than per-service `@Published var errorMessage`.
- **Logging**: Wrap all `print()` in `#if DEBUG` and gate on `ConfigLoader.shared.enableDebugLogging`. Use `[ServiceName]` prefix.
