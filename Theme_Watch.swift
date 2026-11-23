#if os(watchOS)

import SwiftUI

enum WatchTheme {
    /// Matches the iOS Theme API; the Watch keeps its original sizes.
    static func fontSize(_ size: CGFloat) -> CGFloat { size }

    // Yellow-Orange-Green palette — energetic, warm, nature-inspired
    static let primary   = Color(red: 1.00, green: 0.40, blue: 0.00)    // Vivid orange
    static let secondary = Color(red: 0.25, green: 0.75, blue: 0.35)    // Fresh green
    static let accent    = Color(red: 1.00, green: 0.82, blue: 0.00)    // Golden yellow
    static let mint      = Color(red: 0.60, green: 0.90, blue: 0.55)    // Lime green
    static let rose      = Color(red: 1.00, green: 0.45, blue: 0.10)    // Deep orange
    static let blush     = Color(red: 1.00, green: 0.96, blue: 0.80)    // Pale yellow cream
    /// Watch pages draw `paper`, so it uses the iPhone's `Theme.pageBackground` cream.
    static let paper     = Color(red: 0.99, green: 0.98, blue: 0.95)

    // Sticky-note colors — yellow, amber, lime, peach tones
    static let stickyPink   = Color(red: 1.00, green: 0.95, blue: 0.65) // Bright yellow
    static let stickyPeach  = Color(red: 1.00, green: 0.85, blue: 0.55) // Amber
    static let stickyYellow = Color(red: 0.85, green: 0.98, blue: 0.65) // Lime yellow
    static let stickyCoral  = Color(red: 1.00, green: 0.78, blue: 0.55) // Peach orange
    static let stickySage   = Color(red: 0.75, green: 0.95, blue: 0.70) // Soft sage

    // Background gradient method
    static func backgroundGradient(for scheme: ColorScheme) -> LinearGradient {
        if scheme == .dark {
            return LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.10, blue: 0.06),
                    Color(red: 0.14, green: 0.12, blue: 0.05),
                    Color(red: 0.10, green: 0.15, blue: 0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(red: 1.00, green: 0.98, blue: 0.88),
                    Color(red: 1.00, green: 0.96, blue: 0.80),
                    Color(red: 0.95, green: 0.98, blue: 0.88)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // Hero gradient — deep orange → vivid orange → golden yellow
    static let heroGradient = LinearGradient(
        colors: [
            Color(red: 0.85, green: 0.32, blue: 0.00),  // Burnt orange
            Color(red: 1.00, green: 0.55, blue: 0.05),  // Vivid orange
            Color(red: 1.00, green: 0.82, blue: 0.00)   // Golden yellow
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Surface colors match the iOS Theme exactly.
    static let surface = Color(red: 0.96, green: 0.95, blue: 0.92)
    static let cardSurface = surface
    static let background = paper
    
    // Additional Colors
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    
    // Match iOS text styling while keeping the requested black primary text.
    static let textPrimary = Color.black
    static let textSecondary = Color(red: 0.22, green: 0.21, blue: 0.20)
    static let textTertiary = textSecondary.opacity(0.78)
    
    static let ink = textPrimary
    static let muted = textSecondary

    // Watch app fonts
    static let titleFont = Font.system(.title3)
    static let headlineFont = Font.system(.headline)
    static let bodyFont = Font.system(.body)
    static let captionFont = Font.system(.caption)

    // Page background
    static let pageBackground = paper
}

// Typealias so Watch code can use "Theme"
typealias Theme = WatchTheme

#endif


