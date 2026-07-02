import SwiftUI
import FloradexKit

/// The Floradex design language, decided in the phase A lab (2026-07-02):
/// herbarium as the base, with two borrowings that earn their place.
///
/// The register rule that keeps it coherent: words are serif on paper;
/// the collection's own artifacts (sprites, dex numbers) are pixel; motion
/// is machined. The two registers never trade places: the serif never
/// renders a dex number, the pixel face never renders prose.
enum Floradex {
    /// Radius language. Cards are paper objects (16, continuous); mounted
    /// photos and sprite plates are near-square specimen mounts (3); grid
    /// tiles sit between (12). Nested corners stay concentric or square,
    /// never near-equal.
    enum Radius {
        static let card: CGFloat = 16
        static let tile: CGFloat = 12
        static let plate: CGFloat = 3
    }

    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        /// Inset of card content from the paper edge.
        static let cardPadding: CGFloat = 18
    }

    enum Motion {
        /// The signature spring: every card and stage entrance.
        static let spring = Animation.spring(response: 0.45, dampingFraction: 0.85)
        /// The stamp settle: seals and dex numbers landing, a touch of
        /// overshoot so the landing reads physical.
        static let settle = Animation.spring(response: 0.30, dampingFraction: 0.72)
        /// Press feedback; interruptible by design.
        static let press = Animation.spring(response: 0.25, dampingFraction: 0.80)
        /// The searching-lines breath while identification runs.
        static let breath = Animation.easeInOut(duration: 0.9)
        /// Reduce Motion swaps springs and moves for this quiet crossfade;
        /// a nil animation would turn transitions into single-frame cuts.
        static let reducedFade = Animation.easeInOut(duration: 0.2)
        /// Stamped things sit a hair off square.
        static let stampTilt = Angle.degrees(-1.5)
    }

    /// The shutter key's green family: hand-tuned shades of floraGreen so
    /// the most brand-carrying control retunes with the brand, not apart
    /// from it.
    enum ShutterKey {
        static let top = Color(red: 0.30, green: 0.83, blue: 0.55)
        static let bottom = Color(red: 0.12, green: 0.57, blue: 0.36)
        static let pressedTop = Color(red: 0.14, green: 0.56, blue: 0.36)
        static let pressedBottom = Color(red: 0.10, green: 0.46, blue: 0.29)
        static let inkShadow = Color(red: 0.04, green: 0.30, blue: 0.18)
        static let embossShadow = Color(red: 0.05, green: 0.33, blue: 0.20)
    }

    /// PostScript name of the bundled pixel face (Departure Mono, OFL 1.1,
    /// license ships beside the font). It has exactly one job: dex numbers.
    static let pixelFontName = "DepartureMono-Regular"
}

// MARK: - Colors

extension Color {
    private static func flora(light: Color, dark: Color) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    /// Card and label surfaces: warm paper, opaque by design. The reveal
    /// card is a physical object over the viewfinder, not a glass sheet.
    static let floraPaper = flora(
        light: Color(red: 0.984, green: 0.976, blue: 0.956),
        dark: Color(red: 0.118, green: 0.110, blue: 0.094)
    )

    /// Screen background beneath collection surfaces; one step deeper than
    /// paper so cards read as objects on a desk.
    static let floraGround = flora(
        light: Color(red: 0.965, green: 0.953, blue: 0.925),
        dark: Color(red: 0.082, green: 0.078, blue: 0.071)
    )

    /// Rules, specimen borders, and mounted-photo edges.
    static let floraHairline = flora(
        light: Color(red: 0.847, green: 0.827, blue: 0.776),
        dark: Color(white: 0.28)
    )

    /// Photo mattes: white in light, dimmed warm white in dark, like a
    /// slide mount under gallery light instead of a glowing frame.
    static let floraMatte = flora(
        light: .white,
        dark: Color(red: 0.865, green: 0.855, blue: 0.825)
    )

    /// The brand anchor (#2EB875). Held to one band per surface.
    static let floraGreen = Color(red: 0.180, green: 0.722, blue: 0.459)

    /// Ink-weight green for dex numbers and pixel artifacts on paper;
    /// brightened in dark so it stays ink, not glow.
    static let floraPixelInk = flora(
        light: Color(red: 0.125, green: 0.259, blue: 0.184),
        dark: Color(red: 0.624, green: 0.847, blue: 0.722)
    )

    /// Confidence band colors, deepened for 4.5:1 text contrast on paper
    /// and brightened for dark surfaces. Semantic: only ever confidence.
    static func floraBand(_ band: ConfidenceBand) -> Color {
        switch band {
        case .confident:
            return flora(
                light: Color(red: 0.050, green: 0.440, blue: 0.270),
                dark: Color(red: 0.450, green: 0.850, blue: 0.620)
            )
        case .likely:
            return flora(
                light: Color(red: 0.580, green: 0.400, blue: 0.000),
                dark: Color(red: 0.950, green: 0.720, blue: 0.300)
            )
        case .unsure:
            return flora(
                light: Color(red: 0.630, green: 0.190, blue: 0.160),
                dark: Color(red: 0.980, green: 0.550, blue: 0.500)
            )
        }
    }
}

// MARK: - Typography

extension Font {
    /// Card-level name display: New York, the field guide's voice.
    static let floraDisplay = Font.system(.title3, design: .serif).weight(.semibold)

    /// Entry-detail name display.
    static let floraDisplayLarge = Font.system(.title2, design: .serif).weight(.semibold)

    /// Latin binomials, always italic serif.
    static let floraLatin = Font.system(.subheadline, design: .serif).italic()
    static let floraLatinSmall = Font.system(.caption, design: .serif).italic()

    /// Dex numbers in the bundled pixel face; the single slot it earns.
    /// Sized per role so the multiple stays deliberate, scaling with
    /// Dynamic Type via the anchor style.
    static func floraNumber(_ role: FloraNumberRole) -> Font {
        .custom(Floradex.pixelFontName, size: role.size, relativeTo: role.anchor)
    }
}

enum FloraNumberRole {
    /// List rows and inline mentions.
    case row
    /// Dex grid tiles.
    case tile
    /// The commit stamp and entry-detail header.
    case stamp

    var size: CGFloat {
        switch self {
        case .row: return 13
        case .tile: return 15
        case .stamp: return 22
        }
    }

    var anchor: Font.TextStyle {
        switch self {
        case .row: return .subheadline
        case .tile: return .headline
        case .stamp: return .title2
        }
    }
}
