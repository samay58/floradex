#if DEBUG
import SwiftUI
import FloradexKit

/// Phase A comparison harness: the provisional reveal card built three ways
/// over a simulated viewfinder, switchable live. Launch with
/// FLORADEX_DESIGN_LAB=1; FLORADEX_LAB_VARIANT preselects for screenshots.
/// Dies (or graduates to a dev tool) once a direction is chosen.
struct DesignLabView: View {
    enum Variant: String, CaseIterable, Identifiable {
        case herbarium, cartridge, instrument
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }

    @State private var variant: Variant
    private let fixture = LabFixture.make()

    init() {
        let initial = ProcessInfo.processInfo.environment["FLORADEX_LAB_VARIANT"]
            .flatMap(Variant.init(rawValue:)) ?? .herbarium
        _variant = State(initialValue: initial)
    }

    var body: some View {
        ZStack {
            backdrop
            VStack {
                Picker("Direction", selection: $variant) {
                    ForEach(Variant.allCases) { variant in
                        Text(variant.title).tag(variant)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                Spacer()
                card
                    .padding(.bottom, 44)
            }
        }
    }

    @ViewBuilder
    private var card: some View {
        switch variant {
        case .herbarium: HerbariumRevealCard(fixture: fixture)
        case .cartridge: CartridgeRevealCard(fixture: fixture)
        case .instrument: InstrumentRevealCard(fixture: fixture)
        }
    }

    /// Stands in for the live camera so the cards are judged in context.
    /// Color.clear owns the layout so the scaled image can't inflate the
    /// ZStack's proposed width.
    private var backdrop: some View {
        Color.clear
            .overlay {
                Image(uiImage: fixture.photo)
                    .resizable()
                    .scaledToFill()
            }
            .overlay(Color.black.opacity(0.25))
            .clipped()
            .ignoresSafeArea()
    }
}

/// One rich provisional-state moment, identical across all three variants so
/// only the design varies: confident majority result with alternatives, a
/// sources-agree line, both care lines, and a live undo countdown.
struct LabFixture {
    let photo: UIImage
    let sprite: UIImage
    let result: IdentificationResult
    let details: SpeciesDetailsContent
    let undoDeadline: Date

    static func make() -> LabFixture {
        let monstera = Species(
            latinName: "Monstera deliciosa",
            commonName: "Swiss cheese plant",
            family: "Araceae"
        )
        let adansonii = Species(latinName: "Monstera adansonii", commonName: "Adanson's monstera")
        let philodendron = Species(latinName: "Thaumatophyllum bipinnatifidum", commonName: "Tree philodendron")

        let result = IdentificationResult(
            species: monstera,
            confidence: 0.86,
            agreement: .majority,
            dissent: 0.21,
            alternatives: [
                IdentificationCandidate(species: adansonii, confidence: 0.42, provider: .plantNet),
                IdentificationCandidate(species: philodendron, confidence: 0.18, provider: .kindwise),
            ],
            contributing: [
                IdentificationCandidate(species: monstera, confidence: 0.91, provider: .kindwise),
                IdentificationCandidate(species: adansonii, confidence: 0.42, provider: .plantNet),
                IdentificationCandidate(species: monstera, confidence: 0.81, provider: .visionReasoner),
            ]
        )
        let details = SpeciesDetailsContent(
            species: monstera,
            care: CareProfile(
                sunlight: "Bright, indirect light",
                water: "Water when the top inch of soil is dry"
            ),
            source: ContentSource(provider: .visionReasoner, generatedAt: .now)
        )
        return LabFixture(
            photo: SampleLeaf.image(),
            sprite: LabSprite.image(),
            result: result,
            details: details,
            undoDeadline: Date().addingTimeInterval(600)
        )
    }

    /// Same strings as the live RevealCard; the lab varies design, not copy.
    var bandLabel: String {
        switch result.band {
        case .confident: return result.agreement == .split ? "Sources disagree" : "Confident"
        case .likely: return "Likely"
        case .unsure: return "Not sure"
        }
    }

    var rawConfidenceLabel: String {
        result.confidence.formatted(.percent.precision(.fractionLength(0)))
    }

    var sourcesLine: String? {
        guard result.contributingProviderCount > 1 else { return nil }
        return "\(result.agreeingProviderCount) of \(result.contributingProviderCount) sources agree"
    }

    /// Filled segments for banded meters: never a fake-precise gauge.
    var bandRank: Int {
        switch result.band {
        case .confident: return 3
        case .likely: return 2
        case .unsure: return 1
        }
    }
}

/// A deterministic 16x16 stand-in for pipeline sprites, drawn at 1 px per
/// cell so views can scale it at exact integer multiples.
enum LabSprite {
    static func image() -> UIImage {
        let rows = [
            "................",
            ".....KKKKK......",
            "...KKGGGGGKK....",
            "..KGGLLLGGGGK...",
            ".KGLLLGGGGGGGK..",
            ".KGLGGGGKKGGGK..",
            "KGGLGGK..KGGGGK.",
            "KGGGGK....KGGGK.",
            "KGGGGGKKKKGGGGK.",
            "KGGKKGGGGGGKKGK.",
            ".KGGGGGGKKGGGGK.",
            ".KDGGGGGGGGGDK..",
            "..KDDGGGGGDDK...",
            "...KKDDGDDKK....",
            ".....KKDKK......",
            ".......K........",
        ]
        let palette: [Character: UIColor] = [
            "K": UIColor(red: 0.10, green: 0.25, blue: 0.17, alpha: 1),
            "G": UIColor(red: 0.18, green: 0.72, blue: 0.46, alpha: 1),
            "L": UIColor(red: 0.56, green: 0.89, blue: 0.71, alpha: 1),
            "D": UIColor(red: 0.13, green: 0.55, blue: 0.35, alpha: 1),
        ]
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let side = CGFloat(rows.count)
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            for (y, row) in rows.enumerated() {
                for (x, cell) in row.enumerated() {
                    guard let color = palette[cell] else { continue }
                    color.setFill()
                    context.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
    }
}

// MARK: - Shared lab styling helpers

extension Color {
    /// Inline dynamic color for lab experiments; the winning direction gets
    /// real semantic tokens in Phase B.
    static func lab(_ light: Color, _ dark: Color) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    /// Band colors deepened for text contrast on warm paper, brightened for
    /// dark surfaces. Semantic (confidence), not accent decoration.
    static func labBand(_ band: ConfidenceBand) -> Color {
        switch band {
        case .confident:
            return .lab(Color(red: 0.05, green: 0.44, blue: 0.27), Color(red: 0.45, green: 0.85, blue: 0.62))
        case .likely:
            return .lab(Color(red: 0.58, green: 0.40, blue: 0.00), Color(red: 0.95, green: 0.72, blue: 0.30))
        case .unsure:
            return .lab(Color(red: 0.63, green: 0.19, blue: 0.16), Color(red: 0.98, green: 0.55, blue: 0.50))
        }
    }
}

extension Font {
    /// Departure Mono (OFL 1.1, bundled) auditioning for the dex-number slot.
    static func labPixel(_ size: CGFloat, relativeTo style: Font.TextStyle = .caption) -> Font {
        .custom("DepartureMono-Regular", size: size, relativeTo: style)
    }
}

/// Tactile press feedback shared by lab buttons.
struct LabPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

#Preview("Design lab") {
    DesignLabView()
}
#endif
