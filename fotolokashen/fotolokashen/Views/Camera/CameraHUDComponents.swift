//
//  CameraHUDComponents.swift
//  fotolokashen
//
//  Phase 2a-2: standalone HUD subviews extracted from `CameraView.swift`.
//
//  All views here are presentation-only and have no dependency on `CameraService`
//  or `CameraSessionViewModel` — callers pass bindings or callbacks.
//

import SwiftUI
import CoreLocation

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
            Image(systemName: "sun.max.fill")
                .font(.system(size: 10))
                .foregroundColor(.yellow.opacity(0.8))

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

            Image(systemName: "sun.min.fill")
                .font(.system(size: 10))
                .foregroundColor(.yellow.opacity(0.5))
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

    private var presets: [CGFloat] {
        var stops: [CGFloat] = [0.5, 1.0, 2.0]
        if maxZoom >= 3.0 { stops.append(3.0) }
        if maxZoom >= 5.0 { stops.append(5.0) }
        return stops
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(presets, id: \.self) { preset in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        onZoomChanged(max(preset, minZoom))
                    }
                } label: {
                    Text(presetLabel(preset))
                        .font(.system(size: 13, weight: isActive(preset) ? .bold : .medium, design: .monospaced))
                        .foregroundColor(isActive(preset) ? .yellow : .white)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("\(presetLabel(preset))x zoom")
                .accessibilityAddTraits(isActive(preset) ? .isSelected : [])
            }

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Close zoom controls")
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
            HStack(spacing: 4) {
                Image(systemName: location != nil ? "location.fill" : "location.slash.fill")
                    .font(.system(size: 10))
                if showCoordinates, let loc = location {
                    Text(String(format: "%.4f, %.4f", loc.coordinate.latitude, loc.coordinate.longitude))
                        .font(.system(size: 10, design: .monospaced))
                    Text("±\(Int(loc.horizontalAccuracy))m")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .foregroundColor(.white)
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
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("Camera Access Required")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Please enable camera access in Settings to take photos")
                .font(.body)
                .foregroundColor(.secondary)
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
                                .aspectRatio(contentMode: .fill)
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
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            .accessibilityLabel("Remove photo \(index + 1)")
                            .accessibilityHint("Removes this photo from the capture session.")
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
