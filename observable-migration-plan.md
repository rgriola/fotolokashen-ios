# Plan: migrating fotolokashen-ios from ObservableObject to `@Observable`

No files were changed. I read the code directly and consulted three specialists (concurrency, testing, SwiftUI). Their input is folded into the sections below; where they disagreed, the reasoning is shown in §4.

## 0. Findings that shape the plan

**Build settings** (`fotolokashen/Fotolokashen.xcodeproj/project.pbxproj`):

| Setting | Value | Consequence |
|---|---|---|
| `IPHONEOS_DEPLOYMENT_TARGET` | **18.6** (lines 385, 447, 488, 535, 563, 589) | `@Observable`, `@Bindable` and `withObservationTracking` work without `#available`. The `Observations` async sequence needs iOS 26, so it can't be used without `#available`. |
| `SWIFT_VERSION` | 6.0 | |
| `SWIFT_STRICT_CONCURRENCY` | complete | |
| `SWIFT_APPROACHABLE_CONCURRENCY` | YES | |
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | **MainActor** for the app (394, 455); **nonisolated** for test targets (572, 598, 622, 646) | Keep an explicit `@MainActor` on every `@Observable` class. |
| `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` | YES | Files that import only Foundation need `import Observation`. |

**C-1 (the CameraService split) has already landed.** Checklist item 3.4 in `ios-27-evaluation.md` is ticked and device-tested. `CameraCaptureEngine` is a `nonisolated final class … @unchecked Sendable` that is serialized on `sessionQueue`. `CameraService` is a `@MainActor` class that holds only UI state. So the camera is no longer a blocker; it becomes a mostly mechanical phase.

**Coordination with the iOS 27 work:**
- Its concurrency phase is complete (3.6 and 4.2 ticked on Nov 2, 2026).
- H-4 and H-5 are explicitly out of that scope (line 43 and the table at lines 572–573).
- So run this on its own branch after the iOS 27 release branch is cut. Don't interleave the two.

**Combine use is much smaller than the reference count suggests:**
- Only one real hand-rolled bridge exists: `LocationStore.swift:48` and `:58-65` (H-4).
- There are **no** `debounce`, `.assign`, or `$prop.sink` calls in app code.
  - `PeopleSearchView.swift:66-79` debounces with a `Task` plus `Task.sleep` inside `onChange`. Nothing to change.
  - `MapPlaceSearchService` uses `didSet` to push the query to `MKLocalSearchCompleter`. Nothing to change.
- The only `onReceive` is `ContentView.swift:496`, a NotificationCenter publisher. It can stay as is.
- Publisher-based tests exist only in `PhotoGallerySelectionTests.swift`.
- `import Combine` appears in about 20 files. After migration nearly all of them are unused (for example `MapView.swift:5`, `LocationListView.swift:2`, `PhotoPickerViewModel.swift:2`).

## 1. Inventory

### App classes (22 classes, about 104 `@Published` properties)

| # | Class (file:line) | Isolation | `@Published` | Owner / consumers | Special handling |
|---|---|---|---|---|---|
| 1 | `AuthService` (Services/Networking/AuthService.swift:9) | `@MainActor` | 6 | `@StateObject` at fotolokashenApp.swift:27; `.environmentObject` at :65. Read via `@EnvironmentObject` in AppRootView :79, AuthenticatedRootView :136, ContentView :10/:29, PrivacySettings :6, AccountSecurity :7/:330/:489 (re-injected at :94/:101), NotificationPreferences :6, PeopleSearch :12/:245/:344, MapView :19, Preferences :6, EditProfile :8, Profile :6 (re-injected at :67), MemberSupport :7, LocationList :8. Previews call `AuthService()` at Privacy:126, AccountSecurity:647, NotifPrefs:104, Prefs:117, EditProfile:463, Profile:231. Tests: AuthServiceTests:11, AuthServiceOAuthCallbackTests. | `init` has side effects (:70-78): `checkAuthStatus()` starts a Task, registers a NotificationCenter observer, and calls `APIClient.setTokenRefresher(self)`. Conforms to `TokenRefreshing: AnyObject`. Mark as ignored: `refreshTask` :40, `webAuthSession`, PKCE state (:27-33). |
| 2 | `NetworkMonitor` (Networking/NetworkMonitor.swift:6) | Implicit (default MainActor), no annotation | 2 | `.shared`, wrongly held as `@StateObject` at App:28. Environment consumers at App:80/:137 are **unused**. `@ObservedObject` at LocationDetailView:45. SyncService reads it imperatively. | `pathUpdateHandler` hops with `DispatchQueue.main.async` (:32-45). Imports only Foundation, so it needs `import Observation`. |
| 3 | `DeepLinkManager` (DeepLink/DeepLinkManager.swift:7) | `@MainActor` | 6 | `.shared`. `@ObservedObject` at App:83/:139, re-injected at :96/:147. Read in ContentView:30/:369 via `onChange` (:65, :95, :500). Test: DeepLinkManagerTests:7. | None. |
| 4 | `ErrorPresenter` (Errors/ErrorPresenter.swift:15) | `@MainActor` | 2 | `.shared`. `@ObservedObject` at ErrorPresenterView:59. | Ignore `bannerDismissTask` :23. |
| 5 | `CameraService` (Camera/CameraService.swift:9, NSObject) | `@MainActor` | 9 | `@StateObject` at CameraView:16. `$cameraService.currentZoom` at :208. `onChange` at :317/:330. | `init` allocates `CameraCaptureEngine` (:28), which creates an `AVCaptureSession`. Ignore `lastAppliedRevision`. |
| 6 | `CameraSessionViewModel` (Camera/CameraSessionViewModel.swift:24) | `@MainActor` | 3 | `@StateObject` at CameraView:18. | Ignore `captureFlashTask` :31. Uses `Task.detached { [weak self] }` at :62. |
| 7 | `LocationManager` (Locations/LocationManager.swift:7, NSObject) | `@MainActor` | 2 | `@StateObject` at CameraView:17. | `init` creates `CLLocationManager` and sets its delegate. Delegate methods are `nonisolated` and hop with `Task { @MainActor }` (:72-96). |
| 8 | `MapPlaceSearchService` (Locations/MapPlaceSearchService.swift:8, NSObject) | `@MainActor` | 4 | `@StateObject` at MapView:31, passed to MapPlaceSearchOverlay:7 as `@ObservedObject`, which binds `$searchService.queryFragment` at :16. | `queryFragment` has a `didSet` (:10-12). Ignore `activeSearch`. Holds an `MKLocalSearchCompleter`. |
| 9 | `LocationStore` (Locations/LocationStore.swift:42) | `@MainActor` | 0 (facade) | `.shared`. `@ObservedObject` at ContentView:368 (LoggedInView), LocationListView:9, MapView:22, ProfileView:7. `onChange` at MapView:143/:153. Test: LocationStoreTests (writes `locations`, `errorMessage`, `isLoading`). | **H-4:** Combine forwarding of the inner `objectWillChange` (:48, :58-65). |
| 10 | `LocationRepository` (Locations/LocationRepository.swift:10) | `@MainActor` | 3 | Reached only through LocationStore. | None. |
| 11 | `MapNavigationCoordinator` (Locations/MapNavigationCoordinator.swift:10) | `@MainActor` | 2 | Reached only through LocationStore. | None. |
| 12 | `LocationListViewModel` (Locations/LocationListViewModel.swift:8) | `@MainActor` | 6 (`private(set)`) | `@StateObject` at LocationListView:10. | Cheap `init`, depends on `FollowService.shared`. |
| 13 | `LocationDetailViewModel` (LocationDetail/LocationDetailViewModel.swift:12) | `@MainActor` | 6 | `@StateObject` at LocationDetailView:27, built from 3 inits (:63, :75, :110). The view is constructed in list rows and navigation destinations: LocationListView:259/:415/:417, MapView:134/:137, PublicProfileView:77, ContentView:513. Test: PhotoGallerySelectionTests:114-131. | **`willSet` on `photos` and `isLoadingPhotos` bumps the unpublished `photoRevision` (:56-69).** The revision is read lazily at LocationDetailView:142/:293 and LocationDetailSubviews:48/:323/:338-340. |
| 14 | `CreateLocationViewModel` (CreateLocation/CreateLocationViewModel.swift:22) | `@MainActor` | 11 | `@StateObject` via `StateObject(wrappedValue:)` in 4 inits (CreateLocationView:38/:51/:64/:76). | Its `init` creates `LocationService()` (:79). Writes into `photoViewModel` at :287-305. |
| 15 | `EditLocationViewModel` (EditLocation/EditLocationViewModel.swift:17) | `@MainActor` | 23 | `@StateObject` at EditLocationView:11, initialized at :21. About 18 `$viewModel.x` bindings (:86-208). | Its `init` calls `populateForm()` (:72-75). This is pure, with no I/O. |
| 16 | `PhotoPickerViewModel` (Views/PhotoPickerViewModel.swift:10) | `@MainActor` | 5 | `@StateObject` at CreateLocationView:19. `$photoViewModel.showPicker` at :118. | **Its `init` starts a Task** (`subscribeToQueueEvents()` :35). **`deinit` reads `queueEventTask`** (:38-40). Ignore `lastUploadLocationId`. |
| 17 | `FollowService` (Social/FollowService.swift:7) | `@MainActor` | 1 | `.shared`. `@ObservedObject` at PeopleSearchView:13/:50/:246/:345, MapView:23, PublicProfileView:9, FollowListView:9. | None. |
| 18 | `UserService` (Social/UserService.swift:8) | `@MainActor` | 3 | `.shared`. `@ObservedObject` at Privacy:7, NotifPrefs:7, Preferences:7, EditProfile:9 (progress shown at :191-196/:415). | None. |
| 19 | `LocationGroupService` (Locations/LocationGroupService.swift:8) | `@MainActor` | 1 | `.shared`, **held as `@StateObject` at CreateGroupSheet:20 (anti-pattern)**. Imperative use at LocationListView:384. | None. |
| 20 | `LocationService` (Locations/LocationService.swift:9) | `@MainActor` | 1 | `.shared` plus instances at SyncService:25 and CreateLocationVM:79. No view observes it. | None. |
| 21 | `PhotoUploadService` (Photo/PhotoUploadService.swift:18) | `@MainActor` | 2 | Instances at SyncService:26, LocationService:22, PhotoPickerVM:27. No view observes it. | Conforms to `PhotoUploadServicing: AnyObject, Sendable`. That still holds after migration. |
| 22 | `SyncService` (Locations/SyncService.swift:8) | `@MainActor` | 4 | `.shared`, `private let` at App:140. **Dead** `.environmentObject` at :145. No view reads its published state. | The comment at :38-40 suggests `NetworkMonitor.$isConnected.sink`. Don't do that; it goes away with this migration. |
| 23 | `DataManager` (Locations/DataManager.swift:8) | `@MainActor` | 2 | `.shared`. `@ObservedObject` at App:141. **Dead** `.environmentObject` at :146. The alert at :148-160 reads `storeRecoveryMessage`. Test: DataManagerTests:8. | `ModelContainer` and `ModelContext` are `let`s, so the macro doesn't touch them. |

### Test-only classes

| Class | Location | Detail |
|---|---|---|
| `PhotoGalleryTestState` | PhotoGallerySelectionTests.swift:544 | `@Published photos` with the same `willSet`/`photoRevision` pattern (:550-572). `@Published selectedIndex` (:574). |
| `PhotoGalleryPresentationTestRequests` | :621 | `@Published openCount`, `closeCount` (:622-623). |
| Test views | :582, :605, :627-628 | Use `@ObservedObject`, with bindings `$state.photos` / `$state.selectedIndex`. |
| Publisher subscriptions | :128 (`viewModel.$photos.dropFirst().sink`); :357, :366, :375, :395, :417, :449, :459 (`state.$selectedIndex.dropFirst().filter{}.prefix(1).sink` waiting on an expectation) | |

No other test file uses Combine, publishers, or `objectWillChange` (confirmed by the testing specialist).

## 2. Mechanical transformation rules

| Old | New | Notes |
|---|---|---|
| `final class X: ObservableObject` | `@Observable @MainActor final class X` | Keep or add an explicit `@MainActor` (`NetworkMonitor` doesn't have one today). NSObject subclasses are fine. |
| `@Published var p` / `@Published private(set) var p` | `var p` / `private(set) var p` | |
| Infrastructure `var` (Task handles, `Set<AnyCancellable>`, delegates, `webAuthSession`, PKCE fields, revision counters, caches, `lazy var`) | `@ObservationIgnored var …` | **Rule:** observe only what a view `body` reads. `let` properties need nothing. |
| `@StateObject private var x = T()` | `@State private var x = T()` | Only when `T.init` is cheap and has no side effects. Otherwise see §3.3. |
| `_x = StateObject(wrappedValue: T(args))` | `_x = State(initialValue: T(args))` | Evaluated eagerly on every struct init. See §3.3. |
| `@StateObject` / `@ObservedObject var x = X.shared` | `private let x = X.shared` | Tracking works through a plain `let`. |
| `@ObservedObject var x: T` (passed in) | `let x: T`, or `@Bindable var x: T` if `$x.p` is used | Only MapPlaceSearchOverlay:7 and the test views need `@Bindable`. |
| `@EnvironmentObject var x: T` | `@Environment(T.self) private var x` | Crashes if nothing is injected, the same as today. If you need `$`, write `@Bindable var x = x` inside `body`. |
| `.environmentObject(x)` | `.environment(x)` | Previews switch from `.environmentObject(AuthService())` to `.environment(AuthService())`. |
| `$x.p` on an object owned with `@State` | Unchanged | `Binding`'s dynamic member lookup works on reference key paths. |
| `onChange(of: x.p)` | Unchanged | |
| `.onReceive(NotificationCenter…publisher)` (ContentView:496) | Keep | Optional later: `.task { for await _ in NotificationCenter.default.notifications(named:) }`. |
| `x.objectWillChange.sink { … }` (forwarding) | Delete | Nested reads are tracked automatically. |
| `obj.$p.…sink` in tests | `withObservationTracking` waiter helper (§3.6) | |
| `import Combine` | Remove; add `import Observation` where SwiftUI isn't imported | Needed because of `MEMBER_IMPORT_VISIBILITY`. |

**Ordering constraint:** `@ObservedObject`, `@StateObject` and `@EnvironmentObject` only accept `ObservableObject` types. Converting a class therefore forces **all of its consumers to change in the same PR**. Old and new styles can coexist across different classes, because SwiftUI tracks `@Observable` reads in `body` no matter how the object is held. That allows one class (or cluster) per PR.

## 3. Hard cases and how to handle each

### 3.1 LocationStore facade (H-4)
- Convert `LocationRepository`, `MapNavigationCoordinator` and `LocationStore` **in one PR**.
- Delete `cancellables` (:48) and the forwarding (:58-65).
- `LocationStore` keeps no tracked state of its own. Its computed pass-throughs (`locations`, `isLoading`, `errorMessage`, `mapFocus*`) read the inner `@Observable` objects, so views are tracked through them automatically.
- **Keep the setters.** `LocationStoreTests.swift:12-13` and `testLoadingState` write through the facade.
- Add a regression test:
  - start tracking `store.locations`, mutate `repository.locations`, and assert `onChange` fired;
  - the reverse: write through the store and assert the repository changed.

### 3.2 `photoRevision` ordering in LocationDetailViewModel and the test state

**Invariant:** the revision is already bumped by the time anyone reacts to a change in `photos`. The test at :128-131 asserts exactly this.

- The concurrency specialist expects user `willSet` to run before the registrar's notification, but **was not certain**.
- So don't rely on the macro's ordering. Replace the observers with explicit accessors:
  ```
  @ObservationIgnored private var _photoStore …
  var photos { get { access(\.photos) … } set { bump revision; withMutation(\.photos) { store } } }
  ```
  Do the same for `isLoadingPhotos`.
- **Resolved disagreement:** the SwiftUI specialist wanted `photoRevision` tracked; the concurrency and testing specialists wanted it ignored. Use **`@ObservationIgnored`**:
  - It matches today's semantics, where `photoRevision` isn't `@Published`.
  - Every body-time reader also reads `photos` in the same expression (LocationDetailSubviews:48, :323), so invalidation is still guaranteed.
  - The other readers (PhotoGallerySelection.swift:73, LocationDetailSubviews:338-340) are callback-time stale guards that don't need tracking.
- Apply the same change to `PhotoGalleryTestState` (:550-572).

### 3.3 `@State` is initialized eagerly (unlike `@StateObject`'s autoclosure)

`@State`'s initial value is evaluated on every struct init and then discarded. Parent views like LoggedInView re-render on every LocationStore change, which rebuilds the content of fullScreenCover and sheet presentations.

| Site | Verdict | Strategy |
|---|---|---|
| App:27 `AuthService()` | Safe | The App struct is initialized once. Use `@State private var authService = AuthService()`. |
| App:28 `NetworkMonitor.shared` | Safe | `private let`. |
| CameraView:16 `CameraService()` | **Must fix** | Each discarded instance allocates an `AVCaptureSession`. Smallest change: `@ObservationIgnored private lazy var sessionController = CameraCaptureEngine()`, so `CameraService.init` becomes trivial and `CameraView` keeps its `$cameraService.currentZoom` binding (:208). The alternative (an optional `@State` plus `.task`) would break that binding and force a subview extraction. |
| CameraView:17 `LocationManager()` | Should fix | Make the `CLLocationManager` and its delegate setup lazy, created in `requestPermission()` or on first start. Or accept a small allocation per re-init. |
| CameraView:18 `CameraSessionViewModel()` | Probably safe | Check that `init` is trivial. |
| MapView:31 `MapPlaceSearchService()` | Moderate | Create the completer lazily on first `queryFragment` set, or use an optional `@State` plus `.task`. |
| CreateLocationView:19 `PhotoPickerViewModel()` | **Must fix** | Its `init` starts a Task. Move `subscribeToQueueEvents()` into an idempotent `start()` called from `.task`. |
| CreateLocationView ×4 and EditLocationView:21 | Acceptable | The inits are pure. Use `State(initialValue:)`. |
| LocationDetailView ×3 in list rows | Acceptable | The `init` only assigns properties (:81-90). Note as a follow-up (not in this migration): switch to `NavigationLink(value:)` plus `.navigationDestination`. |
| CreateGroupSheet:20 | Bug fix | `private let groupService = LocationGroupService.shared`. |

### 3.4 `deinit` and isolation
- `PhotoPickerViewModel.deinit` (:38-40) **will fail to compile.** `@Observable` turns `queueEventTask` into a computed property isolated to the MainActor, and the `deinit` is nonisolated.
  - Fix: mark it `@ObservationIgnored`. It stays stored, and `cancel()` is thread-safe.
  - Avoid `isolated deinit` here.
- `NetworkMonitor.deinit` is fine, because `monitor` is a `let`.

### 3.5 AVFoundation, CoreLocation, MapKit and NWPathMonitor delegates
- `CameraService`: no change to the `Task { @MainActor [weak self] }` callbacks. Mark `lastAppliedRevision` as ignored. Keep `min/maxDisplayZoom` and `minBias`/`maxBias` tracked, because views read them through `minZoom` and the related computed properties.
- `LocationManager`: keep the `nonisolated` delegate methods plus the `Task { @MainActor }` hop. Copy Sendable values into locals before hopping.
- `MapPlaceSearchService`: `didSet` on a tracked property is supported. The `@MainActor MKLocalSearchCompleterDelegate` conformance is unchanged.
- `NetworkMonitor`: preferred option is to replace `pathUpdateHandler` with a MainActor `Task` that runs `for await path in monitor` (NWPathMonitor is an AsyncSequence on iOS 17+). If you keep the handler instead:
  - Mark the closure `@Sendable` explicitly. Otherwise default MainActor isolation could infer it as MainActor and trap at runtime when it's called on `queue`.
  - Extract `status` and `type` before hopping.

### 3.6 AuthService, Keychain and the environment graph
- Only the observation mechanics change. Keychain and PKCE logic is untouched.
- PKCE fields, `webAuthSession` and `refreshTask` become `@ObservationIgnored`.
- `TokenRefreshing` conformance and `APIClient.setTokenRefresher(self)` are unchanged.
- The `init` side effects are safe because the App struct initializes once. Previews already construct `AuthService()`, so preview behavior doesn't change.
- Graph cleanup, in the same PR as AuthService:
  - Delete the unused environment declarations at App:80/:137 and the injection at :66.
  - Delete the dead `.environmentObject(syncService)` and `.environmentObject(dataManager)` at :145-146.
  - Convert the `deepLinkManager` injections at :96/:147 to `.environment`.

### 3.7 Test strategy (testing specialist)
- Add a shared `@MainActor final class ObservationWaiter<Root: Observable & AnyObject, Value>` helper. It:
  - arms `withObservationTracking`;
  - in `onChange` (a `@Sendable` closure capturing only `[weak self]`), hops with `Task { @MainActor }` so it reads the value after it's stored;
  - fulfills an `XCTestExpectation` when the predicate passes, and otherwise re-arms.
- This reproduces `dropFirst` + `filter` + `prefix(1)`. One difference: writes in the same turn are combined. That's acceptable because every test asserts the final value right afterwards.
- Rewrite :128: capture the revision synchronously in `onChange` via `MainActor.assumeIsolated`. This is valid because of the explicit setter in §3.2.
- Test views: `@Bindable var state`, `let requests`.
- Keep XCTest for the window-hosted gallery tests. New small tracking tests may use Swift Testing, as long as frameworks aren't mixed within one file.

## 4. Phased plan (each phase is one PR)

**Ordering:** start with leaf, single-owner view models; then self-contained clusters; then the shared stores; then the app-level environment graph (AuthService has the widest blast radius); cleanup last. Mixed states are safe at every step (§2).

| Phase | Scope (files) | Key points | Effort |
|---|---|---|---|
| **P0 – Prep** ✅ | New `fotolokashenTests/ObservationTestSupport.swift` (`ObservationWaiter`) + `ObservationWaiterTests.swift`; PhotoGallerySelectionTests.swift (test classes, views and `$selectedIndex` subscriptions migrated). **`import Combine` stays** until P1c because the :129 `viewModel.$photos` test still needs it. **Lint rule deferred to P8**: as a warning now it would add ~200 hits to app code. | Test classes can migrate independently because gallery views take `Binding`s. `PhotoGalleryTestState.photos` uses the explicit-accessor pattern from §3.2. **Keep the :129 publisher test until P1c.** | 0.5 d |
| **P1a – Leaf VMs** ✅ | ErrorPresenter.swift + ErrorPresenterView.swift:59; LocationListViewModel.swift + LocationListView.swift:10; CreateGroupSheet.swift:20 fix; new ErrorPresenterTests.swift | Mark `bannerDismissTask` ignored. | 0.5 d |
| **P1b – Create/Edit** ✅ | EditLocationViewModel.swift + EditLocationView.swift:11/:21; CreateLocationViewModel.swift + PhotoPickerViewModel.swift + CreateLocationView.swift:18-19/:38/:51/:64/:76 | `deinit` fix (§3.4); idempotent `start()` from `.task` (§3.3), with the queue task excluded from observation and no strong `self` capture across stream suspension; about 18 bindings unchanged. Manual create/edit location checks passed (user-reported, Nov 3, 2026). | 1 d |
| **P1c – Detail VM** ✅ | LocationDetailViewModel.swift (:55-75) + LocationDetailView.swift:27/:63/:75/:110; PhotoGallerySelectionTests.swift:114-131 | Explicit accessors plus ignored backing storage and `photoRevision` (§3.2); synchronous observation callback verifies revision is bumped before notification. Removed test-only `import Combine`. | 1 d |
| **P2 – Camera** ✅ | CameraService.swift, CameraSessionViewModel.swift, LocationManager.swift, CameraView.swift:16-18; CameraModels.swift; CameraSessionViewModelTests.swift | Migrated to Observation; lazily creates `CameraCaptureEngine` and `CLLocationManager` (§3.3); canceled setup and late location authorization no longer restart services after dismissal. Debug/Release builds, full signed tests, and Thread Sanitizer pass. Device testing exposed stale photo orientation: capture now snapshots the active camera's rotation per shutter press and applies it to the photo connection, with camera-generation validation. Physical-device smoke and orientation retest passed (user-reported, Nov 3, 2026). | 1 d |
| **P3 – Map search** ✅ | MapPlaceSearchService.swift; MapView.swift:31; Map/MapPlaceSearchOverlay.swift:7 (`@Bindable`); new MapPlaceSearchServiceTests.swift | `MKLocalSearchCompleter` is created on the first non-empty query and excluded from observation; `queryFragment` `didSet` forwarding and change notification are covered by tests. Release build and full signed tests pass. Manual map search check passed (user-reported, Nov 3, 2026). | 0.5 d |
| **P4 – Location store (H-4)** ✅ (manual checks pending) | LocationRepository.swift, MapNavigationCoordinator.swift, LocationStore.swift; ContentView.swift:368; LocationListView.swift:9; MapView.swift:22; ProfileView.swift:7; LocationStoreTests (new tracking test) | Repository and coordinator are `@Observable`; `LocationStore` is a plain facade with no Combine forwarding and keeps its setters; views hold `LocationStore.shared` as `let`. Tests cover repository→store, store→repository and coordinator→store notification. My Spots title removed; custom search field and sort menu moved into a row. Release build, full signed tests and 20-iteration store/gallery stress run pass. | 1 d |
| **P5 – Social** ✅ (manual checks pending) | FollowService.swift, UserService.swift, LocationGroupService.swift; PeopleSearchView.swift:13/:50/:246/:345; MapView.swift:23; PublicProfileView.swift:9; FollowListView.swift:9; Privacy/NotificationPreferences/Preferences/EditProfile :7/:9; SocialServiceObservationTests.swift | Services migrated to `@Observable`; singleton references in views are plain `let`. Tests verify FollowService/LocationGroupService loading and UserService loading/upload progress notifications. Accessibility review found the migration preserves all existing labels, progress, and disabled-state reads; no view behavior changes. Full signed tests and Release build pass. My Spots date sorting fix passed its device check (user-reported, Nov 3, 2026). | 0.5 d |
| **P6 – Infra services** ✅ | NetworkMonitor.swift; LocationDetailView.swift:45; DataManager.swift; SyncService.swift; LocationService.swift; PhotoUploadService.swift; fotolokashenApp.swift:28/:141; new InfrastructureObservationTests.swift | Migrate NetworkMonitor, DataManager, LocationService, and PhotoUploadService to `@Observable`; preserve ordered main-actor path updates and inject NetworkMonitor with Observation. Keep the native `storeRecoveryMessage` alert reactive using a body-time observation read. Remove the unused DataManager environment-object injection and stale SyncService Combine comment. Tests cover observation for migrated service state and recovery-message dismissal. Full signed suite (159 tests), Release build, and focused Thread Sanitizer tests pass. Airplane-mode offline UI and reconnection passed on device (user-reported, Nov 3, 2026); new-location creation remains online-only. Recovery-alert dismissal is automated-test verified, not device-verified. | 1 d |
| **P7 – Environment graph** ✅ | AuthService.swift, DeepLinkManager.swift; fotolokashenApp.swift; ContentView.swift; auth-consuming views, re-injections, and previews; AuthServiceTests.swift and DeepLinkManagerTests.swift | Both services are `@Observable @MainActor final`; AuthService is app-owned `@State`, consumers use type-based `@Environment`, and singleton deep-link references use `let`. PKCE/browser-session and in-flight/deduplication state is excluded from observation; auth, Keychain, callback, and URL-handling logic is unchanged. Drop the unused authenticated-root auth declaration and SyncService environment injection while retaining launch sync. Seven added tests cover all 12 observable properties; logout also verifies notification. Accessibility, concurrency, and auth-preservation reviews approved the approach. Debug and Release builds and full signed tests (166 unit, 7 UI) passed; root lint reports 272 violations (5 serious, pre-existing). Device smoke passed (user-reported, Nov 3, 2026). | 1 d |
| **P8 – Cleanup** ✅ | SyncService.swift; remove unused Combine imports; Services/README.md; `.swiftlint.yml`; CHANGELOG.md; `ios-27-evaluation.md`; `InfrastructureObservationTests.swift` | Migrated the final observable service to `@Observable`; removed all app-source Combine imports; added an error-level lint rule forbidding legacy wrappers; updated guidance and marked H-4/H-5 resolved. SyncService state tracking has regression coverage. Full signed suite (167 unit, 7 UI) and Debug/Release builds pass. SwiftLint reports 271 existing violations (5 serious); the new rule reports no violations. | 0.5 d |

**Post-migration SwiftLint pass (Nov 3, 2026):** The five error-level findings were addressed without changing lint rules, and safe mechanical corrections reduced the report from 271 findings to 159 warnings. The EXIF extraction refactor and unchanged update-request encoding have regression coverage. Debug/Release builds and the full signed suite (173 unit, 7 UI) pass. Manual device check passed (user-reported, Nov 3, 2026). Remaining structural and behavior-sensitive warnings are deferred for a later pass.

**Total: about 8.5 developer days**, plus device smoke time for P2 and P7. That's roughly two weeks of calendar time at one PR per day with review.

## 5. Checks for every phase

**1. Build** with zero new warnings, Debug and Release:
```
xcodebuild build -project fotolokashen/Fotolokashen.xcodeproj -scheme fotolokashen -destination 'platform=iOS Simulator,name=<device>'
```
Also run a `-configuration Release` build. Strict concurrency is `complete`, so any new isolation diagnostic blocks the PR.

**2. Tests, signed** (don't pass `CODE_SIGNING_ALLOWED=NO`):
```
xcodebuild test -project fotolokashen/Fotolokashen.xcodeproj -scheme fotolokashen -destination …
```
- Baseline per the evaluation doc: 131 unit tests and 7 UI tests.
- For P0, P1c and P4, also run the gallery and store tests repeatedly: `-only-testing:fotolokashenTests/PhotoGallerySelectionTests -test-iterations 20 -run-tests-until-failure`.
- Do one Thread Sanitizer run in P2 and P6.

**3. Lint:** `swiftlint lint --no-cache` from the repo root.

**4. Leftover search for the migrated types:**
```
grep -rnE 'ObservableObject|@Published|objectWillChange|@StateObject|@ObservedObject|@EnvironmentObject|\.\$[a-z]' fotolokashen/
```

**5. Manual smoke tests per phase:**

| Phase | What to check |
|---|---|
| P1 | Error banner auto-dismisses after 4 s and alert dismissal works. Create a location (picker sheet, upload progress, save). Edit every form field. Detail gallery: add or delete a photo while the full-screen gallery is open. |
| P2 (on device) | Permission prompt, preview, zoom dial, flash cycle, front/back switch, exposure, multi-capture, GPS badge. In one session, capture portrait → landscape-left → landscape-right → portrait; also test landscape-first and repeat with the front camera. Verify each photo's orientation in the capture strip, Photos library, and saved/uploaded location. Use `Self._printChanges()` or Instruments allocations to confirm one `AVCaptureSession` per presentation. |
| P3 | Map search suggestions, then tap to resolve. |
| P4 | Pull to refresh the list, delete a location, focus the map from the list or a deep link, read-only map focus. |
| P5 | Follow/unfollow counts update. Avatar upload progress. Privacy toggles. |
| P6 | Airplane-mode toggle updates offline UI. Sync on launch. Store-recovery alert (simulate). |
| P7 | Login, logout, session-expiry auto-logout, email verification and password reset flows (ContentView:65-102), deep links on cold and warm start, OAuth callback. |

**6. Accessibility:** this is a behavior-preserving change. Re-check VoiceOver focus and announcements on the screens driven by `onChange` (auth transitions, camera errors at CameraView:330), and on Dynamic Type in the camera HUD after P2.

## 6. Risks and rollback

| Risk | Mitigation |
|---|---|
| **Finer-grained invalidation** leaves views stale that used to refresh through unrelated `@Published` changes (computed properties reading ignored state, state read only inside closures or `Binding(get:)` such as App:150-157). | Don't over-apply `@ObservationIgnored` (§2 rule). Run the smoke list. Use `_printChanges()`. |
| `willSet`/`didSet` ordering under the macro. | Explicit accessors for `photoRevision` (§3.2). One test per migrated `didSet` (MapPlaceSearchService:11). |
| Eager `@State` init causing hidden side effects. | §3.3 table. Allocation checks in P2. |
| Missing `@Environment` injection crashes (sheets, previews). | P7 audits every presentation path. Previews switch to `.environment`. Since iOS 17, sheets inherit the environment. |
| Shared singletons leaking state between tests (`LocationStore.shared`, `DeepLinkManager.shared`). | `setUp` resets the underlying repository. |
| Collision with the iOS 27 branch. | Separate branch, started after the release cut, as the evaluation doc's H-4/H-5 entries require. |

**Rollback:** every phase is one self-contained PR that converts a class together with all its consumers. A revert therefore restores a state that compiles, because mixed old and new styles are valid. The exception is P1c, where the VM change and the :128 test change must be reverted together. Merge each PR only after a full signed test run, and keep a TestFlight build per phase from P2 onward so a device regression can be bisected to one PR.