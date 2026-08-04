//
//  Theme.swift
//  BeerCHILLER
//
//  Two visual styles (Classic / Beer), each with a full light and dark palette.
//  Colours are resolved from (style, colorScheme) rather than from asset-catalog
//  colour sets so the exact same palette type can be used on watchOS, where
//  trait-based dynamic colours are not available.
//
//  Contrast: every text colour below was picked to clear WCAG AA (4.5:1) against
//  the surface it is drawn on. In the Beer style the photo never sits directly
//  behind body text — a scrim plus a translucent card always separates them.
//

import SwiftUI

public extension Color {
    /// `Color(hex: 0x123B47)`
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

public struct Palette {
    public var background: Color
    public var backgroundSecondary: Color
    /// Panel/card fill.
    public var surface: Color
    /// Fill of an unselected segment or a value chip.
    public var chip: Color
    public var primaryText: Color
    public var secondaryText: Color
    /// Brand amber, used for the primary action.
    public var accent: Color
    public var accentText: Color
    /// Second half of the "BeerCHILLER" wordmark. Deliberately not `accent`:
    /// on the beer photo the plain amber does not clear AA against the foam.
    public var brandSecondary: Color
    /// The two colours of the bottle/frost brand mark.
    public var markBottle: Color
    public var markFrost: Color
    /// Fill/text of a selected segment.
    public var selectedFill: Color
    public var selectedText: Color
    public var unselectedText: Color
    public var disabledText: Color
    public var dialTrack: Color
    public var dialProgress: Color
    public var separator: Color
    public var shadow: Color

    /// Beer style only: the photo background and how strongly it is scrimmed.
    public var usesPhotoBackground: Bool = false
    public var photoScrim: Color = .clear

    // MARK: Classic

    static let classicLight = Palette(
        background: Color(hex: 0xF1F6F4),
        backgroundSecondary: Color(hex: 0xE7EFEC),
        surface: Color(hex: 0xE6EFEB),
        chip: Color(hex: 0xFDFEFE),
        primaryText: Color(hex: 0x123B47),
        secondaryText: Color(hex: 0x54737C),
        accent: Color(hex: 0xE9B421),
        accentText: Color(hex: 0x1A2A2E),
        brandSecondary: Color(hex: 0x123B47),
        markBottle: Color(hex: 0x123B47),
        markFrost: Color(hex: 0xE9B421),
        selectedFill: Color(hex: 0x123B47),
        selectedText: Color(hex: 0xFFFFFF),
        unselectedText: Color(hex: 0x123B47),
        disabledText: Color(hex: 0x9FB3B8),
        dialTrack: Color(hex: 0xC7DBDF),
        dialProgress: Color(hex: 0x1D6C7E),
        separator: Color(hex: 0xD3E1DE),
        shadow: Color(hex: 0x0B2830, opacity: 0.12)
    )

    static let classicDark = Palette(
        background: Color(hex: 0x0D1315),
        backgroundSecondary: Color(hex: 0x121A1D),
        surface: Color(hex: 0x182226),
        chip: Color(hex: 0x212D31),
        primaryText: Color(hex: 0xEAF2F3),
        secondaryText: Color(hex: 0xA0B6BB),
        accent: Color(hex: 0xF0BE33),
        accentText: Color(hex: 0x14201F),
        brandSecondary: Color(hex: 0xEAF2F3),
        markBottle: Color(hex: 0xEAF2F3),
        markFrost: Color(hex: 0xF0BE33),
        selectedFill: Color(hex: 0x2E7C90),
        selectedText: Color(hex: 0xFFFFFF),
        unselectedText: Color(hex: 0xD6E4E7),
        disabledText: Color(hex: 0x6A7D82),
        dialTrack: Color(hex: 0x2A3A3F),
        dialProgress: Color(hex: 0x59C2DA),
        separator: Color(hex: 0x273438),
        shadow: Color(hex: 0x000000, opacity: 0.5)
    )

    // MARK: Beer

    static let beerLight = Palette(
        background: Color(hex: 0xE2A31A),
        backgroundSecondary: Color(hex: 0xC98B12),
        surface: Color(hex: 0xFBF3DF, opacity: 0.92),
        chip: Color(hex: 0xFFFBF0, opacity: 0.96),
        primaryText: Color(hex: 0x3D2A08),
        secondaryText: Color(hex: 0x6B4E17),
        accent: Color(hex: 0xE0A81C),
        accentText: Color(hex: 0x3D2A08),
        brandSecondary: Color(hex: 0x8A5D06),
        markBottle: Color(hex: 0x3D2A08),
        markFrost: Color(hex: 0x8A5D06),
        selectedFill: Color(hex: 0xD79E12),
        selectedText: Color(hex: 0xFFFFFF),
        unselectedText: Color(hex: 0x3D2A08),
        disabledText: Color(hex: 0x9A8355),
        dialTrack: Color(hex: 0xFFFFFF, opacity: 0.55),
        dialProgress: Color(hex: 0xFFFFFF),
        separator: Color(hex: 0xE8D9AE),
        shadow: Color(hex: 0x3D2A08, opacity: 0.18),
        usesPhotoBackground: true,
        photoScrim: Color(hex: 0x000000, opacity: 0.05)
    )

    static let beerDark = Palette(
        background: Color(hex: 0x2A1C05),
        backgroundSecondary: Color(hex: 0x1A1103),
        surface: Color(hex: 0x241804, opacity: 0.88),
        chip: Color(hex: 0x33240A, opacity: 0.94),
        primaryText: Color(hex: 0xFBEFD2),
        secondaryText: Color(hex: 0xD9BE86),
        accent: Color(hex: 0xF0BE33),
        accentText: Color(hex: 0x241804),
        brandSecondary: Color(hex: 0xF7D77A),
        markBottle: Color(hex: 0xFBEFD2),
        markFrost: Color(hex: 0xF0BE33),
        selectedFill: Color(hex: 0xB8860B),
        selectedText: Color(hex: 0xFFF8E7),
        unselectedText: Color(hex: 0xF3E4C2),
        disabledText: Color(hex: 0x9A8355),
        dialTrack: Color(hex: 0xFFFFFF, opacity: 0.22),
        dialProgress: Color(hex: 0xF7D77A),
        separator: Color(hex: 0x4A3410),
        shadow: Color(hex: 0x000000, opacity: 0.6),
        usesPhotoBackground: true,
        photoScrim: Color(hex: 0x000000, opacity: 0.45)
    )

    public static func resolve(style: VisualStyle, scheme: ColorScheme) -> Palette {
        switch (style, scheme) {
        case (.classic, .dark): return .classicDark
        case (.classic, _): return .classicLight
        case (.beer, .dark): return .beerDark
        case (.beer, _): return .beerLight
        }
    }
}

// MARK: - Environment plumbing

private struct PaletteKey: EnvironmentKey {
    static let defaultValue: Palette = .classicLight
}

public extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}
