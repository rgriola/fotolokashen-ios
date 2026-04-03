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
    /// #5B4CFF
    static let brand = Color(red: 0.36, green: 0.30, blue: 1.0)

    /// Darker brand variant for pressed/active states
    static let brandDark = Color(red: 0.30, green: 0.25, blue: 0.90)

    // MARK: - Semantic Intent

    /// Error, delete, destructive actions — web token: `destructive`
    static let destructive = Color(.systemRed)

    /// Success, confirmation — web token: `success`
    static let success = Color(.systemGreen)

    /// Warning, caution — web token: `warning`
    static let warning = Color(.systemOrange)

    /// Social features (follow, people) — web token: `social`
    static let social = Color(red: 0.36, green: 0.30, blue: 1.0)
}
