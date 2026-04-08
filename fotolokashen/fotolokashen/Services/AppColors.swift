//
//  AppColors.swift
//  fotolokashen
//
//  Centralized semantic color tokens aligned with the web app's design system.
//  See: fotolokashen/.github/copilot-instructions.md → Style Guide
//
//  USAGE:
//  .foregroundColor(.destructive)   // error/delete actions
//  .foregroundColor(.success)       // confirmations
//  .background(Color.brand)         // primary brand actions
//
//  DO NOT hardcode .red, .blue, .green for semantic intent.
//  Contextual uses (camera UI, star yellow) are exceptions — see copilot-instructions.
//

import SwiftUI

extension Color {

    // MARK: - Brand

    /// Primary brand color — web token: `primary` / `social`
    ///
    static let brand = Color(hex: "#5B4CFF")
    /// Darker brand variant for pressed/active states
    static let brandDark = Color(hex: "#4D40E6")


    // MARK: - Semantic Intent

    /// Error, delete, destructive actions — web token: `destructive`
    static let destructive = Color(.systemRed)

    /// Success, confirmation — web token: `success`
    static let success = Color(.systemGreen)

    /// Warning, caution — web token: `warning`
    static let warning = Color(.systemOrange)

    /// Social features (follow, people) — web token: `social`
    static let social = Color(hex: "#5B4CFF")

    // MARK: - Color Extension


    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

