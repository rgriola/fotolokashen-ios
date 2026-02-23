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
                    iconPreview("edit", AppIcons.edit)
                    iconPreview("share", AppIcons.share)
                    iconPreview("delete", AppIcons.delete)
                    iconPreview("add", AppIcons.add)
                    iconPreview("close", AppIcons.close)
                    iconPreview("closeCircle", AppIcons.closeCircle)
                    iconPreview("settings", AppIcons.settings)
                    iconPreview("search", AppIcons.search)
                    iconPreview("filter", AppIcons.filter)
                    iconPreview("back", AppIcons.back)
                    iconPreview("forward", AppIcons.forward)
                    iconPreview("expandCollapse", AppIcons.expandCollapse)
                    iconPreview("more", AppIcons.more)
                    iconPreview("moreCircle", AppIcons.moreCircle)
                    iconPreview("locationsList", AppIcons.locationsList)
                    iconPreview("map", AppIcons.map)
                    iconPreview("camera", AppIcons.camera)
                    iconPreview("people", AppIcons.people)
                    iconPreview("profile", AppIcons.profile)
                    iconPreview("mapPin", AppIcons.mapPin)
                    iconPreview("building", AppIcons.building)
                    iconPreview("calendar", AppIcons.calendar)
                    iconPreview("photo", AppIcons.photo)
                    iconPreview("photoStack", AppIcons.photoStack)
                    iconPreview("noPhoto", AppIcons.noPhoto)
                    iconPreview("bookmark", AppIcons.bookmark)
                    iconPreview("bookmarkFilled", AppIcons.bookmarkFilled)
                    iconPreview("star", AppIcons.star)
                    iconPreview("starFilled", AppIcons.starFilled)
                    iconPreview("heart", AppIcons.heart)
                    iconPreview("heartFilled", AppIcons.heartFilled)
                    iconPreview("public", AppIcons.visibilityPublic)
                    iconPreview("unlisted", AppIcons.visibilityUnlisted)
                    iconPreview("private", AppIcons.visibilityPrivate)
                    iconPreview("link", AppIcons.link)
                    iconPreview("checkmark", AppIcons.checkmark)
                    iconPreview("checkCircle", AppIcons.checkmarkCircle)
                    iconPreview("warning", AppIcons.warning)
                    iconPreview("info", AppIcons.info)
                    iconPreview("offline", AppIcons.offline)
                    iconPreview("followAdd", AppIcons.followAdd)
                    iconPreview("following", AppIcons.following)
                    iconPreview("followers", AppIcons.followers)
                    iconPreview("fullscreen", AppIcons.fullscreen)
                    iconPreview("copy", AppIcons.copy)
                    iconPreview("coordinates", AppIcons.coordinates)
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
                .foregroundColor(.brandPurple)
            Text(name)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(height: 70)
    }
}

#Preview {
    AppIconsPreviewView()
}
