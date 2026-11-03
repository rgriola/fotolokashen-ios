import Kingfisher
import Observation
import SwiftUI
import XCTest
@testable import fotolokashen

nonisolated final class PhotoGallerySelectionTests: XCTestCase {
    @MainActor
    func testSelectionBindingClampsReadsAndWrites() {
        var index = Int.max
        let selection = Binding(get: { index }, set: { index = $0 })
        let twoPhotoSnapshot = PhotoGallerySnapshot(
            photoIDs: [1, 2], generation: .constant(0), currentPhotoIDs: { [1, 2] },
            currentPhotoRevision: { 0 }
        )
        let twoPhotos = PhotoGallerySelection.clampedBinding(selection, snapshot: twoPhotoSnapshot)

        XCTAssertEqual(twoPhotos.wrappedValue, 1)
        twoPhotos.wrappedValue = Int.min
        XCTAssertEqual(index, 0)
        twoPhotos.wrappedValue = Int.max
        XCTAssertEqual(index, 1)

        PhotoGallerySelection.reconcile(selection, count: 0)
        XCTAssertEqual(index, 0)
        let emptySnapshot = PhotoGallerySnapshot(
            photoIDs: [], generation: .constant(0), currentPhotoIDs: { [] },
            currentPhotoRevision: { 0 }
        )
        let noPhotos = PhotoGallerySelection.clampedBinding(selection, snapshot: emptySnapshot)
        noPhotos.wrappedValue = 10
        XCTAssertEqual(index, 0)
    }

    @MainActor
    func testObsoletePhotoSetCannotChangeSelection() {
        var index = 2
        var generation = 0
        var photoIDs = [1, 2, 3]
        var isLoading = false
        var isPresented = false
        let selection = Binding(get: { index }, set: { index = $0 })
        let generationBinding = Binding(get: { generation }, set: { generation = $0 })
        let presentation = Binding(get: { isPresented }, set: { isPresented = $0 })
        let originalSnapshot = PhotoGallerySnapshot(
            photoIDs: photoIDs,
            generation: generationBinding,
            currentPhotoIDs: { photoIDs },
            currentPhotoRevision: { 0 },
            isAvailable: { !isLoading }
        )
        let original = PhotoGallerySelection.clampedBinding(selection, snapshot: originalSnapshot)

        photoIDs = [1, 2]
        XCTAssertEqual(original.wrappedValue, 1)
        photoIDs = []
        XCTAssertEqual(original.wrappedValue, 0)
        photoIDs = [4, 5, 6]
        original.wrappedValue = 1
        PhotoGallerySelection.openPhoto(
            at: 1, snapshot: originalSnapshot, selection: selection, isPresented: presentation
        )
        XCTAssertEqual(index, 2)
        XCTAssertFalse(isPresented)

        generation += 1
        let replacementSnapshot = PhotoGallerySnapshot(
            photoIDs: photoIDs,
            generation: generationBinding,
            currentPhotoIDs: { photoIDs },
            currentPhotoRevision: { 0 },
            isAvailable: { !isLoading }
        )
        let replacement = PhotoGallerySelection.clampedBinding(selection, snapshot: replacementSnapshot)
        isLoading = true
        replacement.wrappedValue = 1
        PhotoGallerySelection.openPhoto(
            at: 1, snapshot: replacementSnapshot, selection: selection, isPresented: presentation
        )
        XCTAssertEqual(index, 2)
        XCTAssertFalse(isPresented)
        isLoading = false
        PhotoGallerySelection.openPhoto(
            at: 1, snapshot: replacementSnapshot, selection: selection, isPresented: presentation
        )
        XCTAssertEqual(index, 1)
        XCTAssertTrue(isPresented)

        photoIDs = []
        generation += 1
        PhotoGallerySelection.reconcile(selection, count: 0)
        original.wrappedValue = 2
        XCTAssertEqual(index, 0)

        photoIDs = [1, 2, 3]
        generation += 1
        let reloadedSnapshot = PhotoGallerySnapshot(
            photoIDs: photoIDs, generation: generationBinding, currentPhotoIDs: { photoIDs },
            currentPhotoRevision: { 0 }
        )
        let reloaded = PhotoGallerySelection.clampedBinding(selection, snapshot: reloadedSnapshot)
        original.wrappedValue = 1
        XCTAssertEqual(index, 0)
        reloaded.wrappedValue = 2
        XCTAssertEqual(index, 2)
    }

    @MainActor
    func testPhotoRevisionRejectsCallbacksAfterPhotoSetReturns() {
        let location = Location(
            id: 1, name: "Test", address: "", latitude: 0, longitude: 0,
            type: "OTHER", createdAt: "", photosCount: 0, thumbnailUrl: nil
        )
        let viewModel = LocationDetailViewModel(location: location, mode: .owner)
        let initialPhotos = PhotoGalleryTestState().photos
        viewModel.photos = initialPhotos
        let initialRevision = viewModel.photoRevision
        var index = 2
        let selection = Binding(get: { index }, set: { index = $0 })
        let originalSnapshot = PhotoGallerySnapshot(
            photoIDs: initialPhotos.map(\.id),
            generation: .constant(0),
            currentPhotoIDs: { viewModel.photos.map(\.id) },
            currentPhotoRevision: { viewModel.photoRevision }
        )
        let original = PhotoGallerySelection.clampedBinding(selection, snapshot: originalSnapshot)
        let revisionObservation = PhotoRevisionObservation()
        withObservationTracking {
            _ = viewModel.photos
        } onChange: {
            MainActor.assumeIsolated {
                revisionObservation.revision = viewModel.photoRevision
            }
        }

        viewModel.photos.removeLast()
        XCTAssertEqual(revisionObservation.revision, initialRevision + 1)
        viewModel.photos = initialPhotos
        XCTAssertEqual(viewModel.photoRevision, initialRevision + 2)
        original.wrappedValue = 0
        XCTAssertEqual(index, 2)
        var isPresented = false
        let presentation = Binding(get: { isPresented }, set: { isPresented = $0 })
        PhotoGallerySelection.openPhoto(
            at: 0, snapshot: originalSnapshot, selection: selection, isPresented: presentation
        )
        XCTAssertFalse(isPresented)
        XCTAssertEqual(index, 2)

        let unchangedRevision = viewModel.photoRevision
        viewModel.photos = initialPhotos
        XCTAssertEqual(viewModel.photoRevision, unchangedRevision)

        viewModel.isLoadingPhotos = false
        let visibleSnapshot = PhotoGallerySnapshot(
            photoIDs: initialPhotos.map(\.id),
            generation: .constant(0),
            currentPhotoIDs: { viewModel.photos.map(\.id) },
            currentPhotoRevision: { viewModel.photoRevision },
            isAvailable: { !viewModel.isLoadingPhotos }
        )
        viewModel.isLoadingPhotos = true
        viewModel.isLoadingPhotos = false
        XCTAssertFalse(visibleSnapshot.isCurrent)
    }

    @MainActor
    func testPresentationBindingsAreScopedToTheirSession() throws {
        var currentSession: PhotoGalleryPresentationSession?
        let current = Binding(get: { currentSession }, set: { currentSession = $0 })
        let presentation = PhotoGalleryPresentationSession.presentedBinding(current)
        presentation.wrappedValue = true
        let first = try XCTUnwrap(currentSession)
        let firstBinding = first.binding(current)
        XCTAssertTrue(firstBinding.wrappedValue)
        var index = 0
        let selection = Binding(get: { index }, set: { index = $0 })
        let snapshot = PhotoGallerySnapshot(
            photoIDs: [1, 2],
            generation: .constant(0),
            currentPhotoIDs: { [1, 2] },
            currentPhotoRevision: { 0 },
            isAvailable: { firstBinding.wrappedValue }
        )
        let retainedSelection = PhotoGallerySelection.clampedBinding(selection, snapshot: snapshot)

        firstBinding.wrappedValue = false
        XCTAssertNil(currentSession)
        presentation.wrappedValue = true
        let second = try XCTUnwrap(currentSession)
        let secondBinding = second.binding(current)
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertFalse(firstBinding.wrappedValue)
        XCTAssertTrue(secondBinding.wrappedValue)
        retainedSelection.wrappedValue = 1
        XCTAssertEqual(index, 0)
        firstBinding.wrappedValue = false
        firstBinding.wrappedValue = true
        XCTAssertEqual(currentSession, second)
        secondBinding.wrappedValue = false
        XCTAssertNil(currentSession)
    }

    @MainActor
    func testInlineCallbacksCannotResumeAfterPresentation() {
        let photoIDs = [1, 2]
        var index = 0
        var generation = 0
        var isPresented = false
        let selection = Binding(get: { index }, set: { index = $0 })
        let generationBinding = Binding(get: { generation }, set: { generation = $0 })
        let presentation = Binding(get: { isPresented }, set: { isPresented = $0 })
        let originalSnapshot = PhotoGallerySnapshot(
            photoIDs: photoIDs,
            generation: generationBinding,
            currentPhotoIDs: { photoIDs },
            currentPhotoRevision: { 0 },
            isAvailable: { !isPresented }
        )
        let original = PhotoGallerySelection.clampedBinding(selection, snapshot: originalSnapshot)

        PhotoGallerySelection.openPhoto(
            at: 1, snapshot: originalSnapshot, selection: selection, isPresented: presentation
        )
        XCTAssertTrue(isPresented)
        XCTAssertEqual(index, 1)
        original.wrappedValue = 0
        XCTAssertEqual(index, 1)

        let whilePresented = PhotoGallerySnapshot(
            photoIDs: photoIDs,
            generation: generationBinding,
            currentPhotoIDs: { photoIDs },
            currentPhotoRevision: { 0 },
            isAvailable: { !isPresented }
        )
        isPresented = false
        original.wrappedValue = 0
        XCTAssertEqual(index, 1)
        XCTAssertFalse(whilePresented.isCurrent)
        PhotoGallerySelection.openPhoto(
            at: 0, snapshot: originalSnapshot, selection: selection, isPresented: presentation
        )
        XCTAssertFalse(isPresented)
        XCTAssertEqual(index, 1)

        let currentSnapshot = PhotoGallerySnapshot(
            photoIDs: photoIDs,
            generation: generationBinding,
            currentPhotoIDs: { photoIDs },
            currentPhotoRevision: { 0 },
            isAvailable: { !isPresented }
        )
        let current = PhotoGallerySelection.clampedBinding(selection, snapshot: currentSnapshot)
        current.wrappedValue = 0
        XCTAssertEqual(index, 0)
    }

    @MainActor
    func testFullScreenCallbacksCannotResumeAfterCloseAndReopen() {
        let photoIDs = [1, 2]
        var index = 0
        var generation = 0
        var isPresented = true
        let selection = Binding(get: { index }, set: { index = $0 })
        let generationBinding = Binding(get: { generation }, set: { generation = $0 })
        let presentation = Binding(get: { isPresented }, set: { isPresented = $0 })
        let originalSnapshot = PhotoGallerySnapshot(
            photoIDs: photoIDs,
            generation: generationBinding,
            currentPhotoIDs: { photoIDs },
            currentPhotoRevision: { 0 },
            isAvailable: { isPresented }
        )
        let original = PhotoGallerySelection.clampedBinding(selection, snapshot: originalSnapshot)

        PhotoGallerySelection.closeGallery(generation: generationBinding, isPresented: presentation)
        XCTAssertFalse(isPresented)
        isPresented = true
        original.wrappedValue = 1
        XCTAssertEqual(index, 0)

        let currentSnapshot = PhotoGallerySnapshot(
            photoIDs: photoIDs,
            generation: generationBinding,
            currentPhotoIDs: { photoIDs },
            currentPhotoRevision: { 0 },
            isAvailable: { isPresented }
        )
        let current = PhotoGallerySelection.clampedBinding(selection, snapshot: currentSnapshot)
        current.wrappedValue = 1
        XCTAssertEqual(index, 1)
    }

    @MainActor
    func testAccessibilityAnnouncementsAreDeduplicated() {
        var state = PhotoGalleryAccessibilityState()
        XCTAssertNil(state.observe(isEmpty: false, photoIDs: [1], isPresented: true))
        XCTAssertEqual(state.observe(isEmpty: true, photoIDs: [], isPresented: true), .noPhotos)
        XCTAssertNil(state.observe(isEmpty: true, photoIDs: [], isPresented: true))
        XCTAssertEqual(state.observe(isEmpty: false, photoIDs: [2], isPresented: true), .photosAvailable)
        XCTAssertNil(state.observe(isEmpty: false, photoIDs: [2], isPresented: true))

        var emptySession = PhotoGalleryAccessibilityState()
        XCTAssertEqual(emptySession.observe(isEmpty: true, photoIDs: [], isPresented: true), .noPhotos)
        XCTAssertNil(emptySession.observe(isEmpty: true, photoIDs: [], isPresented: true))
        XCTAssertEqual(emptySession.observe(isEmpty: false, photoIDs: [3], isPresented: true), .photosAvailable)
    }

    @MainActor
    func testAccessibilityIgnoresStaleAndDismissedCallbacks() {
        var state = PhotoGalleryAccessibilityState()
        XCTAssertNil(state.observe(isEmpty: true, photoIDs: [1], isPresented: true))
        XCTAssertNil(state.observe(isEmpty: true, photoIDs: [], isPresented: false))
        XCTAssertNil(state.lastIsEmpty)

        XCTAssertEqual(state.observe(isEmpty: true, photoIDs: [], isPresented: true), .noPhotos)
        XCTAssertNil(state.observe(isEmpty: false, photoIDs: [1], isPresented: false))
        XCTAssertNil(state.observe(isEmpty: false, photoIDs: [], isPresented: true))
        XCTAssertEqual(state.lastIsEmpty, true)
        XCTAssertEqual(state.observe(isEmpty: false, photoIDs: [1], isPresented: true), .photosAvailable)
    }

    @MainActor
    func testGallerySelectionFollowsPhotoRemoval() async throws {
        let state = PhotoGalleryTestState()
        let appeared = expectation(description: "Gallery appears")
        let initialPhotos = expectation(description: "Gallery displays the initial photo set")
        let reduced = expectation(description: "Gallery displays the reduced photo set")
        let selectedRemainingPhoto = expectation(description: "Selection moves to the remaining photo")
        let empty = expectation(description: "Gallery displays the empty state")
        let resetEmptySelection = expectation(description: "Selection resets when photos are empty")
        let reloaded = expectation(description: "Gallery reloads after becoming empty")
        let resetReloadedSelection = expectation(description: "Reloaded gallery reconciles selection")
        var observedCounts: [Int] = []
        let (window, previousWindow) = try makeVisibleWindow(
            rootView: PhotoGalleryTestView(state: state) { count in
                switch count {
                case 2:
                    observedCounts.append(count)
                    reduced.fulfill()
                case 0:
                    observedCounts.append(count)
                    empty.fulfill()
                case 1:
                    observedCounts.append(count)
                    reloaded.fulfill()
                case 3: initialPhotos.fulfill()
                default: break
                }
            }
            .onAppear { appeared.fulfill() }
        )
        defer {
            restoreWindow(window, previousWindow: previousWindow)
        }

        await fulfillment(of: [appeared, initialPhotos], timeout: 10)
        XCTAssertEqual(state.selectedIndex, 2)
        let removalWaiter = ObservationWaiter(state, \.selectedIndex, fulfilling: selectedRemainingPhoto) { $0 == 1 }
        defer { removalWaiter.cancel() }
        state.photos.removeLast()
        await fulfillment(of: [selectedRemainingPhoto, reduced], timeout: 10)
        XCTAssertEqual(state.selectedIndex, 1)

        let remainingPhoto = try XCTUnwrap(state.photos.first)
        let emptyWaiter = ObservationWaiter(state, \.selectedIndex, fulfilling: resetEmptySelection) { $0 == 0 }
        defer { emptyWaiter.cancel() }
        state.photos.removeAll()
        await fulfillment(of: [resetEmptySelection, empty], timeout: 10)
        XCTAssertEqual(state.selectedIndex, 0)

        state.selectedIndex = 9
        let reloadWaiter = ObservationWaiter(state, \.selectedIndex, fulfilling: resetReloadedSelection) { $0 == 0 }
        defer { reloadWaiter.cancel() }
        state.photos = [remainingPhoto]
        await fulfillment(of: [reloaded, resetReloadedSelection], timeout: 10)
        XCTAssertEqual(state.selectedIndex, 0)
        XCTAssertEqual(observedCounts, [2, 0, 1])
    }

    @MainActor
    func testEmptyFullScreenGalleryResetsSelection() async throws {
        let state = PhotoGalleryTestState()
        let reloadedPhoto = try XCTUnwrap(state.photos.first)
        state.photos.removeAll()
        let appeared = expectation(description: "Empty full-screen gallery appears")
        let empty = expectation(description: "Full-screen empty state is displayed")
        let resetSelection = expectation(description: "Empty full-screen selection resets")
        let reloaded = expectation(description: "Full-screen gallery reloads")
        let resetReloadedSelection = expectation(description: "Reloaded full-screen selection resets")
        let resetWaiter = ObservationWaiter(state, \.selectedIndex, fulfilling: resetSelection) { $0 == 0 }

        let (window, previousWindow) = try makeVisibleWindow(
            rootView: PhotoGalleryFullScreenTestView(state: state) { count in
                switch count {
                case 0: empty.fulfill()
                case 1: reloaded.fulfill()
                default: break
                }
            }.onAppear { appeared.fulfill() }
        )
        defer {
            resetWaiter.cancel()
            restoreWindow(window, previousWindow: previousWindow)
        }

        await fulfillment(of: [appeared, empty, resetSelection], timeout: 10)
        XCTAssertEqual(state.selectedIndex, 0)

        state.selectedIndex = 9
        let reloadWaiter = ObservationWaiter(state, \.selectedIndex, fulfilling: resetReloadedSelection) { $0 == 0 }
        defer { reloadWaiter.cancel() }
        state.photos = [reloadedPhoto]
        await fulfillment(of: [reloaded, resetReloadedSelection], timeout: 10)
        XCTAssertEqual(state.selectedIndex, 0)
    }

    @MainActor
    func testFullScreenSelectionFollowsPhotoRemoval() async throws {
        let state = PhotoGalleryTestState()
        let initialPhotos = expectation(description: "Full-screen gallery displays the initial photos")
        let reduced = expectation(description: "Full-screen gallery displays the reduced photo set")
        let selectedRemainingPhoto = expectation(description: "Full-screen selection moves to a remaining photo")
        let reloaded = expectation(description: "Full-screen gallery displays the reloaded photo set")
        let resetReloadedSelection = expectation(description: "Full-screen selection reconciles after reload")
        let (window, previousWindow) = try makeVisibleWindow(
            rootView: PhotoGalleryFullScreenTestView(state: state) { count in
                switch count {
                case 3: initialPhotos.fulfill()
                case 2: reduced.fulfill()
                case 1: reloaded.fulfill()
                default: break
                }
            }
        )
        defer { restoreWindow(window, previousWindow: previousWindow) }

        await fulfillment(of: [initialPhotos], timeout: 10)
        XCTAssertEqual(state.selectedIndex, 2)

        let removalWaiter = ObservationWaiter(state, \.selectedIndex, fulfilling: selectedRemainingPhoto) { $0 == 1 }
        defer { removalWaiter.cancel() }
        state.photos.removeLast()
        await fulfillment(of: [selectedRemainingPhoto, reduced], timeout: 10)
        XCTAssertEqual(state.selectedIndex, 1)

        let remainingPhoto = try XCTUnwrap(state.photos.first)
        state.selectedIndex = 9
        let reloadWaiter = ObservationWaiter(state, \.selectedIndex, fulfilling: resetReloadedSelection) { $0 == 0 }
        defer { reloadWaiter.cancel() }
        state.photos.removeAll()
        state.photos = [remainingPhoto]
        await fulfillment(of: [reloaded, resetReloadedSelection], timeout: 10)
        XCTAssertEqual(state.selectedIndex, 0)
    }

    @MainActor
    func testFullScreenCoverCanDismissAndReopen() async throws {
        let photos = PhotoGalleryTestState()
        let requests = PhotoGalleryPresentationTestRequests()
        let hostAppeared = expectation(description: "Gallery presentation host appears")
        let firstOpened = expectation(description: "First gallery presentation opens")
        let firstDismissed = expectation(description: "First gallery presentation completes dismissal")
        let secondOpened = expectation(description: "Second gallery presentation opens")
        let secondDismissed = expectation(description: "Second gallery presentation completes dismissal")
        var seenSessionIDs: [UUID] = []
        var dismissals = 0
        var hostHasAppeared = false
        let (window, previousWindow) = try makeVisibleWindow(
            rootView: PhotoGalleryPresentationTestView(
                photos: photos,
                requests: requests,
                onOpen: { id in
                    guard !seenSessionIDs.contains(id) else { return }
                    seenSessionIDs.append(id)
                    if seenSessionIDs.count == 1 { firstOpened.fulfill() }
                    if seenSessionIDs.count == 2 { secondOpened.fulfill() }
                },
                onDismiss: {
                    dismissals += 1
                    if dismissals == 1 { firstDismissed.fulfill() }
                    if dismissals == 2 { secondDismissed.fulfill() }
                }
            ).onAppear {
                guard !hostHasAppeared else { return }
                hostHasAppeared = true
                hostAppeared.fulfill()
            }
        )
        defer { restoreWindow(window, previousWindow: previousWindow) }

        await fulfillment(of: [hostAppeared], timeout: 10)
        requests.openCount += 1
        await fulfillment(of: [firstOpened], timeout: 10)
        requests.closeCount += 1
        await fulfillment(of: [firstDismissed], timeout: 10)
        requests.openCount += 1
        await fulfillment(of: [secondOpened], timeout: 10)
        requests.closeCount += 1
        await fulfillment(of: [secondDismissed], timeout: 10)
        XCTAssertEqual(seenSessionIDs.count, 2)
        XCTAssertEqual(dismissals, 2)
    }

    @MainActor
    private func makeVisibleWindow<Content: View>(rootView: Content) throws -> (UIWindow, UIWindow?) {
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let previousWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = UIHostingController(rootView: rootView)
        window.makeKeyAndVisible()
        return (window, previousWindow)
    }

    @MainActor
    private func restoreWindow(_ window: UIWindow, previousWindow: UIWindow?) {
        let shouldRestorePreviousWindow = window.isKeyWindow
            && previousWindow?.isHidden == false
            && previousWindow?.windowScene === window.windowScene
        window.isHidden = true
        window.rootViewController = nil
        if shouldRestorePreviousWindow {
            previousWindow?.makeKeyAndVisible()
        }
    }
}

@Observable
@MainActor
private final class PhotoGalleryTestState {
    private let imageCachePrefix = UUID().uuidString
    private let imageData = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).pngData { context in
        UIColor.blue.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
    }
    @ObservationIgnored private var storedPhotos: [DetailPhoto] = (1...3).map({ id in
        DetailPhoto(
            id: id,
            imagekitFilePath: "/test/\(id)",
            url: "http://127.0.0.1:1/\(id)",
            thumbnailUrl: "http://127.0.0.1:1/\(id)",
            caption: nil,
            width: nil,
            height: nil,
            uploadedAt: nil,
            gpsLatitude: nil,
            gpsLongitude: nil,
            isPrimary: nil,
            fileSize: nil,
            mimeType: nil
        )
    })
    // Explicit accessors guarantee the revision is bumped before observers are notified of the change.
    var photos: [DetailPhoto] {
        get {
            access(keyPath: \.photos)
            return storedPhotos
        }
        set {
            if storedPhotos.map(\.id) != newValue.map(\.id) {
                photoRevision += 1
            }
            withMutation(keyPath: \.photos) {
                storedPhotos = newValue
            }
        }
    }
    @ObservationIgnored private(set) var photoRevision: UInt64 = 0
    var selectedIndex = 2

    func imageSource(for photo: DetailPhoto) -> Source? {
        .provider(RawImageDataProvider(data: imageData, cacheKey: "\(imageCachePrefix)-\(photo.id)"))
    }
}

@MainActor
private final class PhotoRevisionObservation {
    var revision: UInt64?
}

private struct PhotoGalleryTestView: View {
    @Bindable var state: PhotoGalleryTestState
    let onPhotoCountChange: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            PhotoGallerySection(
                photos: $state.photos,
                isLoading: .constant(false),
                locationType: nil,
                latitude: 0,
                longitude: 0,
                isConnected: false,
                selectedPhotoIndex: $state.selectedIndex,
                showingFullScreenGallery: .constant(false),
                currentPhotoRevision: { state.photoRevision },
                imageSource: state.imageSource
            )
        }
        .modifier(PhotoCountProbe(photoCount: state.photos.count, onPhotoCountChange: onPhotoCountChange))
    }
}

private struct PhotoGalleryFullScreenTestView: View {
    @Bindable var state: PhotoGalleryTestState
    let onPhotoCountChange: (Int) -> Void

    var body: some View {
        PhotoGalleryFullScreen(
            photos: $state.photos,
            selectedIndex: $state.selectedIndex,
            isPresented: .constant(true),
            currentPhotoRevision: { state.photoRevision },
            imageSource: state.imageSource
        )
        .modifier(PhotoCountProbe(photoCount: state.photos.count, onPhotoCountChange: onPhotoCountChange))
    }
}

@Observable
@MainActor
private final class PhotoGalleryPresentationTestRequests {
    var openCount = 0
    var closeCount = 0
}

private struct PhotoGalleryPresentationTestView: View {
    @Bindable var photos: PhotoGalleryTestState
    let requests: PhotoGalleryPresentationTestRequests
    let onOpen: (UUID) -> Void
    let onDismiss: () -> Void
    @State private var session: PhotoGalleryPresentationSession?

    var body: some View {
        Color.clear
            .onChange(of: requests.openCount) { _, _ in
                PhotoGalleryPresentationSession.presentedBinding($session).wrappedValue = true
            }
            .fullScreenCover(item: $session, onDismiss: onDismiss) { session in
                PhotoGalleryFullScreen(
                    photos: $photos.photos,
                    selectedIndex: $photos.selectedIndex,
                    isPresented: session.binding($session),
                    currentPhotoRevision: { photos.photoRevision },
                    imageSource: photos.imageSource
                )
                .onAppear { onOpen(session.id) }
                .onChange(of: requests.closeCount) { _, _ in
                    session.binding($session).wrappedValue = false
                }
                .id(session.id)
            }
    }
}

private struct PhotoCountProbe: ViewModifier {
    let photoCount: Int
    let onPhotoCountChange: (Int) -> Void

    func body(content: Content) -> some View {
        content.background {
            Color.clear
                .onAppear { onPhotoCountChange(photoCount) }
                .id(photoCount)
        }
    }
}
