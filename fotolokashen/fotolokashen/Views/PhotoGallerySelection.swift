import SwiftUI

struct PhotoGallerySourceVersion: Equatable {
    let photoIDs: [Int]
    let revision: UInt64
}

struct PhotoGalleryPresentationSession: Identifiable, Equatable {
    let id = UUID()

    static func presentedBinding(_ current: Binding<Self?>) -> Binding<Bool> {
        Binding(
            get: { current.wrappedValue != nil },
            set: { isPresented in
                if isPresented {
                    if current.wrappedValue == nil {
                        current.wrappedValue = Self()
                    }
                } else {
                    current.wrappedValue = nil
                }
            }
        )
    }

    func binding(_ current: Binding<Self?>) -> Binding<Bool> {
        Binding(
            get: { current.wrappedValue?.id == id },
            set: { isPresented in
                if !isPresented, current.wrappedValue?.id == id {
                    current.wrappedValue = nil
                }
            }
        )
    }
}

struct PhotoGallerySnapshot {
    let photoIDs: [Int]
    private let currentPhotoIDs: () -> [Int]
    private let currentPhotoRevision: () -> UInt64
    private let capturedPhotoRevision: UInt64
    private let isAvailable: () -> Bool
    private let wasAvailableAtCapture: Bool
    private let generation: Binding<Int>
    private let capturedGeneration: Int

    init(
        photoIDs: [Int],
        generation: Binding<Int>,
        currentPhotoIDs: @escaping () -> [Int],
        currentPhotoRevision: @escaping () -> UInt64,
        isAvailable: @escaping () -> Bool = { true }
    ) {
        self.photoIDs = photoIDs
        self.generation = generation
        self.currentPhotoIDs = currentPhotoIDs
        self.currentPhotoRevision = currentPhotoRevision
        self.capturedPhotoRevision = currentPhotoRevision()
        self.isAvailable = isAvailable
        self.wasAvailableAtCapture = isAvailable()
        self.capturedGeneration = generation.wrappedValue
    }

    var isCurrent: Bool {
        generation.wrappedValue == capturedGeneration
            && wasAvailableAtCapture
            && isAvailable()
            && isPhotoSetCurrent
    }

    var isPhotoSetCurrent: Bool {
        currentPhotoRevision() == capturedPhotoRevision && currentPhotoIDs() == photoIDs
    }

    var readableCount: Int {
        min(photoIDs.count, currentPhotoIDs().count)
    }

    func invalidate() {
        generation.wrappedValue += 1
    }
}

enum PhotoGallerySelection {
    static func clampedBinding(_ selection: Binding<Int>, snapshot: PhotoGallerySnapshot) -> Binding<Int> {
        Binding(
            get: { clampedIndex(selection.wrappedValue, count: snapshot.readableCount) },
            set: { value in
                // Ignore page callbacks retained from an older photo set.
                guard snapshot.isCurrent else { return }
                let index = clampedIndex(value, count: snapshot.photoIDs.count)
                if selection.wrappedValue != index {
                    selection.wrappedValue = index
                }
            }
        )
    }

    static func openPhoto(
        at index: Int,
        snapshot: PhotoGallerySnapshot,
        selection: Binding<Int>,
        isPresented: Binding<Bool>
    ) {
        guard snapshot.isCurrent, snapshot.photoIDs.indices.contains(index) else { return }
        snapshot.invalidate()
        selection.wrappedValue = index
        isPresented.wrappedValue = true
    }

    static func closeGallery(generation: Binding<Int>, isPresented: Binding<Bool>) {
        generation.wrappedValue += 1
        isPresented.wrappedValue = false
    }

    static func reconcile(_ selection: Binding<Int>, count: Int) {
        let index = clampedIndex(selection.wrappedValue, count: count)
        if selection.wrappedValue != index {
            selection.wrappedValue = index
        }
    }

    private static func clampedIndex(_ index: Int, count: Int) -> Int {
        min(max(index, 0), max(count, 1) - 1)
    }
}

enum PhotoGalleryAvailabilityAnnouncement: Equatable {
    case photosAvailable
    case noPhotos
}

struct PhotoGalleryAccessibilityState {
    private(set) var lastIsEmpty: Bool?

    mutating func observe(
        isEmpty: Bool,
        photoIDs: [Int],
        isPresented: Bool
    ) -> PhotoGalleryAvailabilityAnnouncement? {
        guard isPresented, isEmpty == photoIDs.isEmpty else { return nil }
        let previousIsEmpty = lastIsEmpty
        lastIsEmpty = isEmpty
        guard let previousIsEmpty else { return isEmpty ? .noPhotos : nil }
        guard previousIsEmpty != isEmpty else { return nil }
        return isEmpty ? .noPhotos : .photosAvailable
    }
}
