//
//  AppIcons.swift
//  fotolokashen
//
//  Created by Rodolfo Cesarotti on 2/23/26.
//
//  ============================================================================
//  CENTRALIZED APP ICONS
//  ============================================================================
//
//  All SF Symbol icon names used throughout the app.
//  Using centralized constants ensures:
//  - Consistent icon usage across all views
//  - Easy updates when changing icons
//  - Single source of truth for icon names
//
//  USAGE:
//  Image(systemName: AppIcons.edit)
//  Image(systemName: AppIcons.share)
//
//  PREVIEW:
//  Run the app and look at AppIconsPreview in Xcode canvas,
//  or add AppIconsPreviewView() to any view temporarily.
//
//  ============================================================================

import SwiftUI
import UIKit

/// Centralized SF Symbol icon names for consistency across the app
enum AppIcons {
    
    // MARK: - Actions
    
    /// Edit action (square with pencil)
    static let edit = "square.and.pencil"
    
    /// Share action (arrow turning up-right)
    static let share = "arrowshape.turn.up.right"
    
    /// Delete action
    static let delete = "trash"
    
    /// Add/Create action
    static let add = "plus"
    
    /// Close/Dismiss action
    static let close = "xmark"
    
    /// Close in circle
    static let closeCircle = "xmark.circle.fill"
    
    /// Settings gear
    static let settings = "gearshape"
    
    /// Search
    static let search = "magnifyingglass"
    
    /// Filter
    static let filter = "line.3.horizontal.decrease.circle"
    
    // MARK: - Navigation
    
    /// Back chevron
    static let back = "chevron.left"
    
    /// Forward chevron
    static let forward = "chevron.right"
    
    /// Expand/collapse chevron
    static let expandCollapse = "chevron.up.chevron.down"
    
    /// Menu/more options
    static let more = "ellipsis"
    
    /// More in circle
    static let moreCircle = "ellipsis.circle"
    
    // MARK: - Tab Bar
    
    /// Locations list tab
    static let locationsList = "list.bullet"
    
    /// Map tab
    static let map = "map"
    
    /// Camera/capture tab
    static let camera = "camera"
    
    /// People/social tab
    static let people = "person.2"
    
    /// Profile tab
    static let profile = "person.crop.circle"
    
    // MARK: - Location Details
    
    /// Map pin
    static let mapPin = "mappin.circle.fill"
    
    /// Address/building
    static let building = "building.2"
    
    /// Calendar/date
    static let calendar = "calendar"
    
    /// Photo
    static let photo = "photo"
    
    /// Photos stack
    static let photoStack = "photo.stack"
    
    /// No photo available
    static let noPhoto = "photo.badge.exclamationmark"
    
    /// Bookmark/save
    static let bookmark = "bookmark"
    
    /// Bookmark filled
    static let bookmarkFilled = "bookmark.fill"
    
    /// Star/favorite
    static let star = "star"
    
    /// Star filled
    static let starFilled = "star.fill"
    
    /// Heart/like
    static let heart = "heart"
    
    /// Heart filled
    static let heartFilled = "heart.fill"
    
    // MARK: - Visibility
    
    /// Public (globe)
    static let visibilityPublic = "globe"
    
    /// Unlisted/followers only
    static let visibilityUnlisted = "person.2"
    
    /// Private (lock)
    static let visibilityPrivate = "lock.fill"
    
    /// Link
    static let link = "link"
    
    // MARK: - Status
    
    /// Checkmark/success
    static let checkmark = "checkmark"
    
    /// Checkmark in circle
    static let checkmarkCircle = "checkmark.circle.fill"
    
    /// Warning/error
    static let warning = "exclamationmark.triangle"
    
    /// Info
    static let info = "info.circle"
    
    /// Offline/no connection
    static let offline = "wifi.slash"
    
    // MARK: - Social
    
    /// Follow/add person
    static let followAdd = "person.badge.plus"
    
    /// Following/person with checkmark
    static let following = "person.badge.checkmark"
    
    /// Followers
    static let followers = "person.2.fill"
    
    // MARK: - Media
    
    /// Gallery/fullscreen
    static let fullscreen = "arrow.up.left.and.arrow.down.right"
    
    /// Copy
    static let copy = "doc.on.doc"
    
    /// Location coordinates
    static let coordinates = "location.circle"

    static let airplane = "airplane"
    static let antennaRadiowavesLeftAndRight = "antenna.radiowaves.left.and.right"
    static let archivebox = "archivebox"
    static let arrowClockwise = "arrow.clockwise"
    static let arrowLeftAndRight = "arrow.left.and.right"
    static let arrowTriangle2CirclepathCamera = "arrow.triangle.2.circlepath.camera"
    static let arrowUpArrowDown = "arrow.up.arrow.down"
    static let arrowUpRightSquare = "arrow.up.right.square"
    static let at = "at"
    static let bellBadge = "bell.badge"
    static let bellFill = "bell.fill"
    static let boltBadgeAutomatic = "bolt.badge.automatic"
    static let boltFill = "bolt.fill"
    static let boltSlashFill = "bolt.slash.fill"
    static let book = "book"
    static let buildingFill = "building.2.fill"
    static let buildingOffice = "building"
    static let calendarBadgeClock = "calendar.badge.clock"
    static let cameraFill = "camera.fill"
    static let chevronDown = "chevron.down"
    static let chevronUp = "chevron.up"
    static let circle = "circle"
    static let clock = "clock"
    static let clockFill = "clock.fill"
    static let documentText = "doc.text"
    static let documentTextFill = "doc.text.fill"
    static let envelope = "envelope"
    static let envelopeBadge = "envelope.badge"
    static let envelopeFill = "envelope.fill"
    static let envelopeOpen = "envelope.open"
    static let error = "xmark.octagon.fill"
    static let eye = "eye"
    static let eyeSlashFill = "eye.slash.fill"
    static let film = "film"
    static let folder = "folder"
    static let gearshapeFill = "gearshape.fill"
    static let globeAmericas = "globe.americas"
    static let globeAmericasFill = "globe.americas.fill"
    static let handRaisedFill = "hand.raised.fill"
    static let infoCircleFill = "info.circle.fill"
    static let keyFill = "key.fill"
    static let locationFill = "location.fill"
    static let locationSlash = "location.slash"
    static let locationSlashFill = "location.slash.fill"
    static let lock = "lock"
    static let lockShieldFill = "lock.shield.fill"
    static let mapFill = "map.fill"
    static let mappin = "mappin"
    static let mappinAndEllipse = "mappin.and.ellipse"
    static let mappinCircle = "mappin.circle"
    static let mappinSlash = "mappin.slash"
    static let micFill = "mic.fill"
    static let noteText = "note.text"
    static let paperplaneFill = "paperplane.fill"
    static let peopleCircle = "person.2.circle"
    static let peopleSlash = "person.2.slash"
    static let personBadgeMinus = "person.badge.minus"
    static let personCircle = "person.circle"
    static let personCircleFill = "person.circle.fill"
    static let personCropCircleBadgeCheckmark = "person.crop.circle.badge.checkmark"
    static let personFill = "person.fill"
    static let personSlash = "person.slash"
    static let personWave2 = "person.wave.2"
    static let photoFill = "photo.fill"
    static let photoOnRectangle = "photo.on.rectangle"
    static let plusCircle = "plus.circle"
    static let questionmarkCircleFill = "questionmark.circle.fill"
    static let rectanglePortraitAndArrowRight = "rectangle.portrait.and.arrow.right"
    static let sunMaxFill = "sun.max.fill"
    static let sunMinFill = "sun.min.fill"
    static let tag = "tag"
    static let textformatAbc = "textformat.abc"
    static let toilet = "toilet"
    static let trashFill = "trash.fill"
    static let tray = "tray"
    static let video = "video"
    static let warningFill = "exclamationmark.triangle.fill"

    static let allSystemNames = Array(Set([
        edit, share, delete, add, close, closeCircle, settings, search, filter,
        back, forward, expandCollapse, more, moreCircle, locationsList, map,
        camera, people, profile, mapPin, building, calendar, photo, photoStack,
        noPhoto, bookmark, bookmarkFilled, star, starFilled, heart, heartFilled,
        visibilityPublic, visibilityUnlisted, visibilityPrivate, link, checkmark,
        checkmarkCircle, warning, info, offline, followAdd, following, followers,
        fullscreen, copy, coordinates, airplane, antennaRadiowavesLeftAndRight,
        archivebox, arrowClockwise, arrowLeftAndRight,
        arrowTriangle2CirclepathCamera, arrowUpArrowDown, arrowUpRightSquare, at,
        bellBadge, bellFill, boltBadgeAutomatic, boltFill, boltSlashFill, book,
        buildingFill, buildingOffice, calendarBadgeClock, cameraFill, chevronDown, chevronUp,
        circle, clock, clockFill, documentText, documentTextFill, envelope,
        envelopeBadge, envelopeFill, envelopeOpen, error, eye, eyeSlashFill, film,
        folder, gearshapeFill, globeAmericas, globeAmericasFill, handRaisedFill,
        infoCircleFill, keyFill, locationFill, locationSlash, locationSlashFill,
        lock, lockShieldFill, mapFill, mappin, mappinAndEllipse, mappinCircle,
        mappinSlash, micFill, noteText, paperplaneFill, peopleCircle, peopleSlash,
        personBadgeMinus, personCircle, personCircleFill,
        personCropCircleBadgeCheckmark, personFill, personSlash, personWave2,
        photoFill, photoOnRectangle, plusCircle, questionmarkCircleFill,
        rectanglePortraitAndArrowRight, sunMaxFill, sunMinFill, tag, textformatAbc,
        toilet, trashFill, tray, video, warningFill
    ])).sorted()

    static func uiImage(for systemName: String) -> UIImage? {
        UIImage(systemName: systemName)
    }
}

// MARK: - Preview View

/// Preview all app icons in a scrollable grid
/// Add this view temporarily to any screen to see all icons
struct AppIconsPreviewView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    ForEach(AppIcons.allSystemNames, id: \.self) { systemName in
                        iconPreview(systemName, systemName)
                    }
                }
                .padding()
            }
            .navigationTitle("App Icons")
        }
    }
    
    private func iconPreview(_ name: String, _ systemName: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemName)
                .font(.title)
                .foregroundStyle(Color.brand)
            Text(name)
                .font(.caption2)
                .foregroundStyle(Color.secondary)
                .lineLimit(1)
        }
        .frame(height: 70)
    }
}

#Preview {
    AppIconsPreviewView()
}
