//
//  CameraHUDComponents.swift
//  fotolokashen
//
//  Phase 2a-2: standalone HUD subviews extracted from `CameraView.swift`.
//
//  All views here are presentation-only and have no dependency on `CameraService`
//  or `CameraSessionViewModel` — callers pass bindings or callbacks.
//

import CoreLocation
import SwiftUI

// MARK: - HUD Sizing

/// Camera controls sit over the viewfinder, so like the system Camera app they stop
/// growing at `maxDynamicTypeSize`. Larger text settings get the Large Content Viewer
/// instead: long-press a control to see it enlarged.
///
/// Apply the cap to a control's label, not the control, so the Large Content Viewer
/// still sees the user's real text size.
enum CameraHUD {
    static let maxDynamicTypeSize = DynamicTypeSize.xxxLarge

    /// Scales `value` with `style`, stopping at `maxDynamicTypeSize`.
    static func scaled(_ value: CGFloat, relativeTo style: Font.TextStyle, at size: DynamicTypeSize) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(min(size, maxDynamicTypeSize)))
        return UIFontMetrics(forTextStyle: uiTextStyle(style)).scaledValue(for: value, compatibleWith: traits)
    }

    private static let uiTextStyles: [Font.TextStyle: UIFont.TextStyle] = [
        .largeTitle: .largeTitle, .title: .title1, .title2: .title2, .title3: .title3,
        .headline: .headline, .subheadline: .subheadline, .callout: .callout,
        .footnote: .footnote, .caption: .caption1, .caption2: .caption2
    ]

    private static func uiTextStyle(_ style: Font.TextStyle) -> UIFont.TextStyle {
        uiTextStyles[style] ?? .body
    }
}

// MARK: - HUD Icon Button

/// Round icon button for the camera HUD. The icon and its circle grow together.
struct CameraHUDIconButton: View {
    let systemImage: String
    let label: String
    var textStyle: Font.TextStyle = .title3
    var baseDiameter: CGFloat = 48
    var tint: Color = .white
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let diameter = max(44, CameraHUD.scaled(baseDiameter, relativeTo: textStyle, at: dynamicTypeSize))
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(textStyle))
                .dynamicTypeSize(...CameraHUD.maxDynamicTypeSize)
                .foregroundStyle(tint)
                .frame(width: diameter, height: diameter)
                .background(Color.black.opacity(0.5))
                .clipShape(Circle())
        }
        .accessibilityLabel(label)
        .accessibilityShowsLargeContentViewer {
            Label(label, systemImage: systemImage)
        }
    }
}

// MARK: - Zoom Pill

/// Round zoom readout above the shutter; tapping it opens `ZoomDialView`.
struct CameraZoomPill: View {
    let zoomLabel: String
    let isZoomed: Bool
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let diameter = max(44, CameraHUD.scaled(44, relativeTo: .footnote, at: dynamicTypeSize))
        Button(action: action) {
            Text(zoomLabel)
                .font(.system(.footnote, design: .monospaced, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .dynamicTypeSize(...CameraHUD.maxDynamicTypeSize)
                .foregroundStyle(isZoomed ? Color.yellow : Color.white)
                .frame(width: diameter, height: diameter)
                .background(Color.black.opacity(0.5))
                .clipShape(Circle())
        }
        .accessibilityLabel("Zoom")
        .accessibilityValue("\(zoomLabel) times")
        .accessibilityHint("Opens the zoom dial.")
        .accessibilityShowsLargeContentViewer {
            Text("Zoom \(zoomLabel)×")
        }
    }
}

// MARK: - Focus Square

/// Yellow focus square that animates in, like native iOS Camera.
struct FocusSquareView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 1.4
    @State private var opacity: Double = 1.0

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .stroke(Color.yellow, lineWidth: 1.5)
            .frame(width: 70, height: 70)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                guard !reduceMotion else {
                    scale = 1.0
                    opacity = 1.0
                    return
                }
                withAnimation(.easeOut(duration: 0.2)) {
                    scale = 1.0
                }
                withAnimation(.easeInOut(duration: 0.5).delay(0.3).repeatCount(2, autoreverses: true)) {
                    opacity = 0.5
                }
                withAnimation(.easeInOut(duration: 0.2).delay(1.3)) {
                    opacity = 1.0
                }
            }
    }
}

// MARK: - Exposure Slider

/// Vertical sun brightness slider that appears next to the focus point.
struct ExposureSlider: View {
    @Binding var bias: Float
    let minBias: Float
    let maxBias: Float

    private let sliderHeight: CGFloat = 140

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: AppIcons.sunMaxFill)
                .font(.caption2)
                .dynamicTypeSize(...CameraHUD.maxDynamicTypeSize)
                .foregroundStyle(Color.yellow.opacity(0.8))
                .accessibilityHidden(true)

            ZStack(alignment: .center) {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 4, height: sliderHeight)

                Circle()
                    .fill(Color.yellow)
                    .frame(width: 16, height: 16)
                    .offset(y: thumbOffset)
            }
            .frame(width: 44, height: sliderHeight)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let half = sliderHeight / 2
                        let clamped = min(max(value.location.y - half, -half), half)
                        let normalised = Float(-clamped / half)
                        bias = min(
                            max(normalised * practicalMaxBias, exposureRange.lowerBound),
                            exposureRange.upperBound
                        )
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Exposure")
            .accessibilityValue("\(bias.formatted(.number.precision(.fractionLength(1)))) EV")
            .accessibilityHint("Swipe up or down to adjust exposure.")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    bias = min(bias + 0.1, exposureRange.upperBound)
                case .decrement:
                    bias = max(bias - 0.1, exposureRange.lowerBound)
                @unknown default:
                    break
                }
            }

            Image(systemName: AppIcons.sunMinFill)
                .font(.caption2)
                .dynamicTypeSize(...CameraHUD.maxDynamicTypeSize)
                .foregroundStyle(Color.yellow.opacity(0.5))
                .accessibilityHidden(true)
        }
    }

    private var practicalMaxBias: Float {
        max(0, min(maxBias, 4.0))
    }

    private var exposureRange: ClosedRange<Float> {
        let lowerBound = max(minBias, -practicalMaxBias)
        let upperBound = max(lowerBound, practicalMaxBias)
        return lowerBound...upperBound
    }

    private var thumbOffset: CGFloat {
        guard practicalMaxBias > 0 else { return 0 }
        let normalised = CGFloat(bias / practicalMaxBias)
        return -normalised * (sliderHeight / 2)
    }
}

// MARK: - Zoom Dial

/// Horizontal zoom dial that expands from the zoom pill — mimics native iOS Camera.
struct ZoomDialView: View {
    @Binding var currentZoom: CGFloat
    let minZoom: CGFloat
    let maxZoom: CGFloat
    var onZoomChanged: (CGFloat) -> Void
    var onDismiss: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var presets: [CGFloat] {
        var stops: [CGFloat] = [0.5, 1.0, 2.0]
        if maxZoom >= 3.0 { stops.append(3.0) }
        if maxZoom >= 5.0 { stops.append(5.0) }
        return stops
    }

    var body: some View {
        let side = max(44, CameraHUD.scaled(44, relativeTo: .footnote, at: dynamicTypeSize))
        HStack(spacing: 0) {
            ForEach(presets, id: \.self) { preset in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        onZoomChanged(max(preset, minZoom))
                    }
                } label: {
                    Text(presetLabel(preset))
                        .font(.system(.footnote, design: .monospaced, weight: isActive(preset) ? .bold : .medium))
                        .lineLimit(1)
                        .dynamicTypeSize(...CameraHUD.maxDynamicTypeSize)
                        .foregroundStyle(isActive(preset) ? Color.yellow : Color.white)
                        .padding(.horizontal, 8)
                        .frame(minWidth: 44, minHeight: side)
                }
                .accessibilityLabel(spokenLabel(preset))
                .accessibilityAddTraits(isActive(preset) ? .isSelected : [])
                .accessibilityShowsLargeContentViewer {
                    Text("\(presetLabel(preset))×")
                }
            }

            Button {
                onDismiss()
            } label: {
                Image(systemName: AppIcons.close)
                    .font(.system(.caption2, weight: .bold))
                    .dynamicTypeSize(...CameraHUD.maxDynamicTypeSize)
                    .foregroundStyle(Color.white.opacity(0.6))
                    .frame(width: 44, height: side)
            }
            .accessibilityLabel("Close zoom controls")
            .accessibilityShowsLargeContentViewer {
                Label("Close zoom controls", systemImage: AppIcons.close)
            }
        }
        .padding(.horizontal, 4)
        .background(Color.black.opacity(0.65))
        .clipShape(Capsule())
    }

    private func presetLabel(_ value: CGFloat) -> String {
        if value < 1.0 {
            return String(format: ".%0.f", value * 10)
        }
        return String(format: "%.0f", value)
    }

    /// Spoken as "0.5 times zoom" rather than the on-screen ".5".
    private func spokenLabel(_ value: CGFloat) -> String {
        let number = Double(value).formatted(.number.precision(.fractionLength(0...1)))
        return "\(number) times zoom"
    }

    private func isActive(_ preset: CGFloat) -> Bool {
        abs(currentZoom - preset) < 0.15
    }
}

// MARK: - GPS Badge

/// Top-right GPS badge — taps to expand coordinates.
struct CameraGPSBadge: View {
    let location: CLLocation?
    @Binding var showCoordinates: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCoordinates.toggle()
            }
        } label: {
            // Falls back to stacked lines when one line doesn't fit beside Close and Flash.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 4) {
                    icon
                    coordinateLines
                }
                HStack(alignment: .top, spacing: 4) {
                    icon
                    VStack(alignment: .leading, spacing: 2) {
                        coordinateLines
                    }
                }
            }
            .lineLimit(1)
            .dynamicTypeSize(...CameraHUD.maxDynamicTypeSize)
            .foregroundStyle(Color.white)
            .padding(.horizontal, showCoordinates ? 8 : 6)
            .padding(.vertical, 5)
            .frame(minWidth: 44, minHeight: 44)
            .background(location != nil ? Color.green.opacity(0.75) : Color.red.opacity(0.6))
            .cornerRadius(8)
        }
        .accessibilityLabel(location == nil ? "GPS unavailable" : "GPS available")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(location == nil
            ? "A location fix is not available."
            : showCoordinates
                ? "Double-tap to hide coordinates."
                : "Double-tap to show coordinates.")
        .accessibilityShowsLargeContentViewer {
            Label(largeContentTitle, systemImage: iconName)
        }
    }

    private var iconName: String {
        location != nil ? AppIcons.locationFill : AppIcons.locationSlashFill
    }

    private var icon: some View {
        Image(systemName: iconName)
            .font(.caption)
    }

    @ViewBuilder
    private var coordinateLines: some View {
        if showCoordinates, let loc = location {
            Text(String(format: "%.4f", loc.coordinate.latitude) + ",")
                .font(.system(.caption, design: .monospaced))
            Text(String(format: "%.4f", loc.coordinate.longitude))
                .font(.system(.caption, design: .monospaced))
            Text("±\(Int(loc.horizontalAccuracy))m")
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.7))
        }
    }

    private var largeContentTitle: String {
        guard let location else { return "GPS unavailable" }
        guard showCoordinates else { return "GPS available" }
        return String(
            format: "%.4f, %.4f ±%dm",
            location.coordinate.latitude,
            location.coordinate.longitude,
            Int(location.horizontalAccuracy)
        )
    }

    private var accessibilityValue: String {
        guard showCoordinates, let location else {
            return location == nil ? "Waiting for location" : "Coordinates hidden"
        }
        return String(
            format: "%.4f, %.4f, accuracy plus or minus %d meters",
            location.coordinate.latitude,
            location.coordinate.longitude,
            Int(location.horizontalAccuracy)
        )
    }
}

// MARK: - Permission Denied

/// Full-screen "Camera Access Required" placeholder with Open Settings CTA.
struct CameraPermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: AppIcons.cameraFill)
                .font(.system(size: 60))
                .foregroundStyle(Color.secondary)
            Text("Camera Access Required")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Enable Camera Access in Settings to Take Photos")
                .font(.body)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - Thumbnail Strip

/// Horizontal strip of session captures with delete buttons. Auto-scrolls to latest.
struct CameraThumbnailStrip: View {
    let captures: [SessionCapture]
    let onRemove: (SessionCapture) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(captures.enumerated()), id: \.element.id) { entry in
                        let (index, capture) = entry
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: capture.thumbnail)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .accessibilityLabel("Captured photo \(index + 1)")
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                                )
                            Button {
                                onRemove(capture)
                            } label: {
                                Image(systemName: AppIcons.closeCircle)
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.white)
                                    .frame(width: 24, height: 24)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("Remove photo \(index + 1)")
                            .accessibilityHint("Removes this photo from the capture session.")
                            .accessibilityShowsLargeContentViewer {
                                Label("Remove photo \(index + 1)", systemImage: AppIcons.closeCircle)
                            }
                            .offset(x: 4, y: -4)
                        }
                        .id(capture.id)
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 64)
            .padding(.bottom, 8)
            .onChange(of: captures.count) { _, _ in
                if let last = captures.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .trailing)
                    }
                }
            }
        }
    }
}
