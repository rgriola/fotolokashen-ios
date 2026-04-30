import XCTest
import CoreLocation
@testable import fotolokashen

/// Phase 4c — Pure-logic coverage for `CreateLocationViewModel` and
/// `EditLocationViewModel`. Service-touching paths (`save()` / `loadPhotos()`)
/// are deferred until `LocationServicing` / `APIClient` mocking lands.
final class LocationViewModelTests: XCTestCase {

    // MARK: - Fixtures

    @MainActor
    private func makeCreateVM(location: CLLocation? = CLLocation(latitude: 40.7, longitude: -74.0)) -> CreateLocationViewModel {
        CreateLocationViewModel(photoLocation: location)
    }

    private func makeLocation(
        name: String = "Test Spot",
        type: String = "BROLL",
        productionDate: Date? = nil,
        notes: String? = nil,
        productionNotes: String? = nil,
        tags: [String]? = nil,
        isFavorite: Bool? = nil,
        personalRating: Double? = nil
    ) -> Location {
        var loc = Location(
            id: 1,
            name: name,
            address: "123 Main St",
            latitude: 40.7,
            longitude: -74.0,
            type: type,
            createdAt: "2026-01-01T00:00:00Z",
            photosCount: 0,
            thumbnailUrl: nil,
            productionDate: productionDate,
            productionNotes: productionNotes
        )
        loc.tags = tags
        loc.isFavorite = isFavorite
        loc.personalRating = personalRating
        loc.caption = notes
        return loc
    }

    // MARK: - CreateLocationViewModel — canSave

    @MainActor
    func testCreateCanSaveRequiresAllInputs() {
        let vm = makeCreateVM()
        XCTAssertFalse(vm.canSave(photoCount: 1), "Empty form")

        vm.locationName = "  "
        vm.locationDetails = "Some details"
        XCTAssertFalse(vm.canSave(photoCount: 1), "Whitespace-only name")

        vm.locationName = "Park"
        vm.locationDetails = "  "
        XCTAssertFalse(vm.canSave(photoCount: 1), "Whitespace-only details")

        vm.locationDetails = "Great spot"
        XCTAssertFalse(vm.canSave(photoCount: 0), "Zero photos")

        XCTAssertTrue(vm.canSave(photoCount: 1))
    }

    @MainActor
    func testCreateCanSaveRequiresPhotoLocation() {
        let vm = makeCreateVM(location: nil)
        vm.locationName = "Park"
        vm.locationDetails = "Great spot"
        XCTAssertFalse(vm.canSave(photoCount: 1), "No GPS = no save")
    }

    // MARK: - CreateLocationViewModel — enforceLimits

    @MainActor
    func testCreateEnforceLimitsTruncatesOverlongInputs() {
        let vm = makeCreateVM()
        vm.locationName = String(repeating: "x", count: CreateLocationViewModel.nameLimit + 50)
        vm.locationDetails = String(repeating: "y", count: CreateLocationViewModel.detailsLimit + 200)
        vm.enforceLimits()

        XCTAssertEqual(vm.locationName.count, CreateLocationViewModel.nameLimit)
        XCTAssertEqual(vm.locationDetails.count, CreateLocationViewModel.detailsLimit)
    }

    @MainActor
    func testCreateEnforceLimitsLeavesShortInputsAlone() {
        let vm = makeCreateVM()
        vm.locationName = "OK"
        vm.locationDetails = "Short"
        vm.enforceLimits()
        XCTAssertEqual(vm.locationName, "OK")
        XCTAssertEqual(vm.locationDetails, "Short")
    }

    // MARK: - CreateLocationViewModel — production date toggle

    @MainActor
    func testProductionDateToggleSeedsDateWhenEnabled() {
        let vm = makeCreateVM()
        XCTAssertNil(vm.productionDate)
        vm.didChangeHasProductionDate(true)
        XCTAssertNotNil(vm.productionDate, "Enabling should default to now")

        let seeded = vm.productionDate
        vm.didChangeHasProductionDate(true)
        XCTAssertEqual(vm.productionDate, seeded, "Already-seeded date should not be replaced")

        vm.didChangeHasProductionDate(false)
        XCTAssertNil(vm.productionDate, "Disabling should clear the date")
    }

    // MARK: - CreateLocationViewModel — address helpers

    @MainActor
    func testStateAbbrPassthrough() {
        let vm = makeCreateVM()
        XCTAssertEqual(vm.stateAbbr("ny"), "NY", "Two-letter state should be uppercased")
        XCTAssertEqual(vm.stateAbbr("California"), "California", "Full name preserved as-is")
        XCTAssertNil(vm.stateAbbr(nil))
        XCTAssertNil(vm.stateAbbr(""))
    }

    @MainActor
    func testShortZipStripsPlusFour() {
        let vm = makeCreateVM()
        XCTAssertEqual(vm.shortZip("12345-6789"), "12345")
        XCTAssertEqual(vm.shortZip("12345"), "12345")
        XCTAssertEqual(vm.shortZip("00501"), "00501")
        XCTAssertNil(vm.shortZip(nil))
        XCTAssertNil(vm.shortZip(""))
    }

    @MainActor
    func testShortZipReturnsPartialDigitsForBadInput() {
        let vm = makeCreateVM()
        XCTAssertEqual(vm.shortZip("123"), "123", "Less than 5 digits passes through verbatim")
    }

    // MARK: - EditLocationViewModel — populateForm

    @MainActor
    func testEditFormPopulatesFromLocation() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let location = makeLocation(
            name: "Bridge",
            type: "DRONE",
            productionDate: date,
            notes: nil,
            productionNotes: "Get golden hour",
            tags: ["sunset", "river"],
            isFavorite: true,
            personalRating: 4.0
        )
        let vm = EditLocationViewModel(location: location)

        XCTAssertEqual(vm.locationName, "Bridge")
        XCTAssertEqual(vm.locationType, "DRONE")
        XCTAssertEqual(vm.productionNotes, "Get golden hour")
        XCTAssertTrue(vm.hasProductionDate)
        XCTAssertEqual(vm.productionDate, date)
        XCTAssertTrue(vm.isFavorite)
        XCTAssertEqual(vm.personalRating, 4.0)
        XCTAssertEqual(vm.tagsText, "sunset, river")
    }

    @MainActor
    func testEditFormDefaultsTypeAndProductionDateAbsent() {
        var loc = makeLocation()
        loc.tags = nil
        let vm = EditLocationViewModel(location: loc)

        XCTAssertEqual(vm.locationType, "BROLL")  // value passed in
        XCTAssertFalse(vm.hasProductionDate)
        XCTAssertEqual(vm.tagsText, "")
        XCTAssertTrue(vm.parsedTags.isEmpty)
    }

    // MARK: - EditLocationViewModel — parsedTags

    @MainActor
    func testParsedTagsTrimsAndRejectsEmpties() {
        let vm = EditLocationViewModel(location: makeLocation())
        vm.tagsText = "  bridge ,  river,, sunset  ,"
        XCTAssertEqual(vm.parsedTags, ["bridge", "river", "sunset"])
    }

    // MARK: - EditLocationViewModel — canSave

    @MainActor
    func testEditCanSaveRequiresName() {
        let vm = EditLocationViewModel(location: makeLocation())
        XCTAssertTrue(vm.canSave)
        vm.locationName = ""
        XCTAssertFalse(vm.canSave)
    }

    // MARK: - EditLocationViewModel — enforceLimits

    @MainActor
    func testEditEnforceLimitsCapsAllFields() {
        let vm = EditLocationViewModel(location: makeLocation())
        let big50 = String(repeating: "a", count: 100)
        let big200 = String(repeating: "b", count: 300)
        let big500 = String(repeating: "c", count: 700)

        vm.locationName = big50
        vm.entryPoint = big200
        vm.parking = big200
        vm.access = big200
        vm.caption = big200
        vm.notes = big500
        vm.productionNotes = big500
        vm.enforceLimits()

        XCTAssertEqual(vm.locationName.count, EditLocationViewModel.nameLimit)
        XCTAssertEqual(vm.entryPoint.count, EditLocationViewModel.textLimit200)
        XCTAssertEqual(vm.parking.count, EditLocationViewModel.textLimit200)
        XCTAssertEqual(vm.access.count, EditLocationViewModel.textLimit200)
        XCTAssertEqual(vm.caption.count, EditLocationViewModel.textLimit200)
        XCTAssertEqual(vm.notes.count, EditLocationViewModel.textLimit500)
        XCTAssertEqual(vm.productionNotes.count, EditLocationViewModel.textLimit500)
    }

    // MARK: - EditLocationViewModel — photo deletion bookkeeping

    @MainActor
    func testMarkPhotoForDeletionDeduplicates() {
        let vm = EditLocationViewModel(location: makeLocation())
        vm.markPhotoForDeletion(7)
        vm.markPhotoForDeletion(8)
        vm.markPhotoForDeletion(7)  // duplicate
        XCTAssertEqual(vm.photosToDelete, [7, 8])
    }

    @MainActor
    func testUndoAllPhotoDeletionsClearsList() {
        let vm = EditLocationViewModel(location: makeLocation())
        vm.markPhotoForDeletion(1)
        vm.markPhotoForDeletion(2)
        vm.undoAllPhotoDeletions()
        XCTAssertTrue(vm.photosToDelete.isEmpty)
    }
}
