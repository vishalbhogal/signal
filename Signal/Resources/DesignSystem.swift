// DesignSystem.swift
// Signal
//
//  Created by Vishal Bhogal on 27/04/26.
// Central design token file. All colors, typography, and spacing constants live here.
// Every UI file imports from this — no magic numbers or hex strings scattered in cells.
//
// Palette rationale (from mental healthcare color research):
//   • Forest green  → trust, growth, calm — primary brand voice
//   • Sage/mint     → hopeful, restorative — secondary accents
//   • Warm amber    → moderate urgency without alarm
//   • Soft coral    → high urgency, but warmer than clinical red
//   • Pastel per metric (blue/lavender/gold/rose) → visual differentiation at a glance

import UIKit
import SwiftUI

// MARK: - Signal Design Namespace

enum Signal {

    // MARK: - UIKit Colors

    enum Colors {
        // ── Brand green — single source of truth ──────────────────────────
        // UIColor(red: 0.22, green: 0.55, blue: 0.40, alpha: 1.0)
        static let brandGreen       = UIColor(red: 0.22, green: 0.55, blue: 0.40, alpha: 1.0)

        // ── App backgrounds (per spec) ────────────────────────────────────
        static let background       = UIColor(red: 0.937, green: 0.957, blue: 0.945, alpha: 1.0)
        // "This Week" metric card surfaces
        static let metricCard       = UIColor(red: 0.922, green: 0.945, blue: 0.933, alpha: 1.0)
        // Sleep chart card surface
        static let sleepCard        = UIColor(red: 0.929, green: 0.937, blue: 0.949, alpha: 1.0)
        // Generic white card surface (risk card, insights)
        static let cardSurface      = UIColor.white

        // ── Text ─────────────────────────────────────────────────────────
        static let textPrimary      = UIColor(red: 0.10, green: 0.18, blue: 0.12, alpha: 1.0)
        static let textSecondary    = UIColor(red: 0.36, green: 0.49, blue: 0.40, alpha: 1.0)

        // ── Legacy aliases (kept so nothing else breaks) ──────────────────
        static let primaryGreen     = brandGreen
        static let accentGreen      = UIColor(red: 0.32, green: 0.72, blue: 0.53, alpha: 1.0)
        static let lightGreen       = UIColor(red: 0.85, green: 0.95, blue: 0.86, alpha: 1.0)

        // ── Risk card gradients ───────────────────────────────────────────
        static let riskLowTop       = UIColor(red: 0.11, green: 0.26, blue: 0.20, alpha: 1.0)
        static let riskLowBottom    = brandGreen
        static let riskModerateTop  = UIColor(hex: "92400E")
        static let riskModerateBottom = UIColor(hex: "F59E0B")
        static let riskHighTop      = UIColor(hex: "7F1D1D")
        static let riskHighBottom   = UIColor(hex: "E76F51")

        // ── Metric icon tints (all pulled toward brandGreen for cohesion) ─
        // Icon pill bg = brandGreen.withAlphaComponent(0.15) — set in code
        static let sleepIcon        = UIColor(hex: "0369A1")
        static let stepsIcon        = UIColor(hex: "6D28D9")
        static let hrvIcon          = UIColor(hex: "B45309")
        static let workIcon         = UIColor(hex: "BE123C")

        // Legacy bubble aliases (no longer used for pill bg, kept for sparkline tint)
        static let sleepBubble      = UIColor(hex: "CDEEF7")
        static let stepsBubble      = UIColor(hex: "E5D8FC")
        static let hrvBubble        = UIColor(hex: "FEF3C7")
        static let workBubble       = UIColor(hex: "FFE4E6")

        // ── Insight accent stripes ────────────────────────────────────────
        static let insightP1        = UIColor(hex: "E76F51")
        static let insightP2        = UIColor(hex: "F59E0B")
        static let insightP3        = UIColor(hex: "0369A1")
        static let insightP4        = brandGreen
    }

    // MARK: - SwiftUI Colors (for Charts)

    enum SUI {
        static let background       = Color(hex: "EDF5EE")
        static let primaryGreen     = Color(hex: "2D6A4F")
        static let accentGreen      = Color(hex: "52B788")

        // Chart line/area colors
        static let sleepLine        = Color(hex: "0369A1")
        static let sleepArea        = Color(hex: "ADE8F4")
        static let stepsLine        = Color(hex: "6D28D9")
        static let stepsArea        = Color(hex: "DDD6FE")
        static let hrvLine          = Color(hex: "B45309")
        static let hrvArea          = Color(hex: "FDE68A")
        static let workLine         = Color(hex: "BE123C")
        static let workArea         = Color(hex: "FECDD3")
    }

    // MARK: - Typography

    enum Types {
        static let display      = UIFont.systemFont(ofSize: 48, weight: .bold)
        static let largeTitle   = UIFont.systemFont(ofSize: 34, weight: .bold)
        static let title1       = UIFont.systemFont(ofSize: 24, weight: .bold)
        static let title2       = UIFont.systemFont(ofSize: 20, weight: .semibold)
        static let headline     = UIFont.systemFont(ofSize: 15, weight: .semibold)
        static let body         = UIFont.systemFont(ofSize: 14, weight: .regular)
        static let caption      = UIFont.systemFont(ofSize: 12, weight: .medium)
        static let micro        = UIFont.systemFont(ofSize: 10, weight: .regular)
    }

    // MARK: - Spacing

    enum Space {
        static let xs: CGFloat  = 4
        static let sm: CGFloat  = 8
        static let md: CGFloat  = 16
        static let lg: CGFloat  = 24
        static let xl: CGFloat  = 32
    }

    // MARK: - Card

    enum Card {
        static let radius: CGFloat      = 20
        static let shadowOpacity: Float = 0.09
        static let shadowRadius: CGFloat = 14
        static let shadowOffset         = CGSize(width: 0, height: 5)
    }
}

// MARK: - UIColor hex init

extension UIColor {
    convenience init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespaces)
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        self.init(
            red:   CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8)  & 0xFF) / 255,
            blue:  CGFloat( rgb        & 0xFF) / 255,
            alpha: 1.0
        )
    }
}

// MARK: - SwiftUI Color hex init

extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespaces)
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8)  & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255
        )
    }
}

// MARK: - UIView card styling helper

extension UIView {
    /// Apply the standard Signal card shadow. Call after setting layer.cornerRadius.
    func applyCardShadow() {
        layer.shadowColor   = UIColor.black.cgColor
        layer.shadowOpacity = Signal.Card.shadowOpacity
        layer.shadowRadius  = Signal.Card.shadowRadius
        layer.shadowOffset  = Signal.Card.shadowOffset
        layer.masksToBounds = false
    }
}

// MARK: - CAGradientLayer helper

extension CAGradientLayer {
    /// Convenience init for a top-to-bottom two-stop gradient.
    static func vertical(top: UIColor, bottom: UIColor, frame: CGRect) -> CAGradientLayer {
        let layer = CAGradientLayer()
        layer.colors     = [top.cgColor, bottom.cgColor]
        layer.startPoint = CGPoint(x: 0.5, y: 0)
        layer.endPoint   = CGPoint(x: 0.5, y: 1)
        layer.frame      = frame
        return layer
    }
}

// MARK: - Reusable diagonal card gradient

extension UIView {
    /// Replaces `existing` with a fresh diagonal gradient layer inserted at index 0
    /// of this view's layer, then returns it so the caller can store and reuse it.
    ///
    /// Call this inside `layoutSubviews` so the frame is already correct:
    ///
    ///     private var cardGradient: CAGradientLayer?
    ///     override func layoutSubviews() {
    ///         super.layoutSubviews()
    ///         cardGradient = contentView.applyDiagonalGradient(
    ///             replacing: cardGradient,
    ///             from: accentColor.withAlphaComponent(0.15),
    ///             to: .white,
    ///             cornerRadius: 16
    ///         )
    ///     }
    @discardableResult
    func applyDiagonalGradient(
        replacing existing: CAGradientLayer?,
        from topLeft: UIColor,
        to bottomRight: UIColor,
        cornerRadius: CGFloat
    ) -> CAGradientLayer {
        existing?.removeFromSuperlayer()
        let gl = CAGradientLayer()
        gl.frame        = bounds
        gl.cornerRadius = cornerRadius
        gl.colors       = [topLeft.cgColor, bottomRight.cgColor]
        gl.startPoint   = CGPoint(x: 0, y: 0)
        gl.endPoint     = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gl, at: 0)
        return gl
    }
    
    /// Configures the frosted glass background and custom active/inactive colors
    static func applyTabBarStyling(to tabBar: UITabBar) {
        let appearance = UITabBarAppearance()
        
        // 1. Frosted glass background
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
        appearance.shadowColor = .clear // Removes the harsh top border line
        
        // 2. Colors: Deep green (Active) and Slate (Inactive)
        let activeColor = UIColor(red: 30/255, green: 63/255, blue: 47/255, alpha: 1.0)
        let inactiveColor = UIColor.secondaryLabel
        
        // 3. Normal (Inactive) State
        appearance.stackedLayoutAppearance.normal.iconColor = inactiveColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: inactiveColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]
        
        // 4. Selected (Active) State
        appearance.stackedLayoutAppearance.selected.iconColor = activeColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: activeColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]
        
        // 5. Apply to the actual tab bar
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
        
        // Force the tintColor as a fallback for older components
        tabBar.tintColor = activeColor
    }
}
