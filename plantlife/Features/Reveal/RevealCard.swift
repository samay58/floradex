import SwiftUI
import FloradexKit

/// The staged reveal as a specimen label taking shape: name lands first in
/// serif, then the confidence seal, then care lines fill like catalog rows;
/// the sprite arrives in its plate whenever it is ready. Committing stamps
/// the dex number in the pixel face. A digest surface, deliberately light;
/// long-form detail lives in the entry screen, so the card never scrolls.
struct RevealCard: View {
    let model: CaptureFlowModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 14)
            rule
            content
                .padding(.top, 12)
        }
        .padding(Floradex.Space.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.floraPaper,
            in: RoundedRectangle(cornerRadius: Floradex.Radius.card, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Floradex.Radius.card, style: .continuous)
                .strokeBorder(Color.floraHairline, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 18, y: 8)
        .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
        .padding(.horizontal, Floradex.Space.m)
        .animation(reduceMotion ? nil : Floradex.Motion.spring, value: model.state)
        .animation(reduceMotion ? nil : Floradex.Motion.spring, value: model.details != nil)
    }

    private var rule: some View {
        Rectangle()
            .fill(Color.floraHairline)
            .frame(height: 1)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: Floradex.Space.m) {
            if let image = model.frozenImage {
                MountedPhoto(image: image)
            }
            headerText
                .frame(maxWidth: .infinity, alignment: .leading)
            SpritePlate(sprite: model.spriteImage, isSearching: model.state.isIdentifying)
        }
    }

    @ViewBuilder
    private var headerText: some View {
        switch model.state {
        case .identifying(_, let bestSoFar):
            VStack(alignment: .leading, spacing: 3) {
                Text(bestSoFar?.species.displayName ?? "Looking closely…")
                    .font(.floraDisplay)
                    .redacted(reason: bestSoFar == nil ? .placeholder : [])
                Text(bestSoFar == nil ? "Comparing field notes" : "Getting a second opinion…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .provisional(_, let result), .correcting(_, let result), .committing(_, let result):
            NameBlock(species: result.species)
        case .committed:
            Text("Added to your Floradex")
                .font(.floraDisplay)
                .fixedSize(horizontal: false, vertical: true)
        case .failed(_, let failure):
            Text(failure.displayMessage)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
        case .idle:
            EmptyView()
        }
    }

    // MARK: - Body per state

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .identifying:
            SearchingLines(reduceMotion: reduceMotion)
        case .provisional(_, let result):
            ProvisionalContent(model: model, result: result)
                .transition(bodyTransition)
        case .correcting(_, let result):
            CorrectionContent(model: model, result: result)
                .transition(bodyTransition)
        case .committing:
            Label("Saving…", systemImage: "tray.and.arrow.down")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .committed(_, let number):
            CommittedContent(model: model, number: number, reduceMotion: reduceMotion)
                .transition(bodyTransition)
        case .failed(_, let failure):
            FailedContent(model: model, failure: failure)
                .transition(bodyTransition)
        case .idle:
            EmptyView()
        }
    }

    /// Stages arrive on the signature spring and leave quietly; Reduce
    /// Motion collapses both to a crossfade.
    private var bodyTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .opacity
            )
    }
}

// MARK: - Shared pieces

private struct NameBlock: View {
    let species: Species

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(species.displayName)
                .font(.floraDisplay)
            Text(species.latinName)
                .font(.floraLatin)
                .foregroundStyle(.secondary)
        }
    }
}

/// The frozen capture as a mounted photograph: white matte, hairline edge,
/// resting shadow.
private struct MountedPhoto: View {
    let image: UIImage

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: Floradex.Radius.plate - 1))
            .padding(3)
            .background(.white, in: RoundedRectangle(cornerRadius: Floradex.Radius.plate))
            .overlay(
                RoundedRectangle(cornerRadius: Floradex.Radius.plate)
                    .strokeBorder(Color.floraHairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.10), radius: 2, y: 1)
    }
}

/// The sprite's plate: a dithered slot holding pixel art, or the leaf
/// silhouette holding its place while the pipeline works.
private struct SpritePlate: View {
    let sprite: UIImage?
    let isSearching: Bool

    var body: some View {
        ZStack {
            DitherField()
            if let sprite {
                PixelScaledImage(image: sprite)
                    .frame(width: 48, height: 48)
                    .transition(.scale(scale: 1.12).combined(with: .opacity))
            } else {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(Color.floraGreen.opacity(0.45))
                    .opacity(isSearching ? 0.7 : 1)
            }
        }
        .frame(width: 62, height: 62)
        .background(Color.floraPaper)
        .clipShape(RoundedRectangle(cornerRadius: Floradex.Radius.plate))
        .overlay(
            RoundedRectangle(cornerRadius: Floradex.Radius.plate)
                .strokeBorder(Color.floraHairline, lineWidth: 1)
        )
    }
}

/// The permanent number, stamped: pixel face, ink green, a hair off square,
/// landing with a settle. The one place the pixel register meets the card.
private struct DexStamp: View {
    let number: DexNumber
    let reduceMotion: Bool
    @State private var landed = false

    var body: some View {
        Text("#\(number.value)")
            .font(.floraNumber(.stamp))
            .foregroundStyle(Color.floraPixelInk)
            .rotationEffect(Floradex.Motion.stampTilt)
            .scaleEffect(landed || reduceMotion ? 1 : 1.6)
            .opacity(landed || reduceMotion ? 1 : 0)
            .onAppear {
                withAnimation(reduceMotion ? nil : Floradex.Motion.settle) {
                    landed = true
                }
            }
    }
}

/// The wait is the reveal: redacted catalog rows breathing at a slow beat
/// instead of a spinner. Reduce Motion holds them steady.
private struct SearchingLines: View {
    let reduceMotion: Bool

    var body: some View {
        let rows = VStack(alignment: .leading, spacing: 6) {
            Label("Checking the field guides", systemImage: "text.book.closed")
            Label("Weighing the closest matches", systemImage: "leaf")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .redacted(reason: .placeholder)

        if reduceMotion {
            rows.opacity(0.6)
        } else {
            PhaseAnimator([0.35, 0.75]) { phase in
                rows.opacity(phase)
            } animation: { _ in
                .easeInOut(duration: 0.9)
            }
        }
    }
}

// MARK: - Provisional

private struct ProvisionalContent: View {
    let model: CaptureFlowModel
    let result: IdentificationResult

    var body: some View {
        VStack(alignment: .leading, spacing: Floradex.Space.m) {
            HStack(spacing: 10) {
                ConfidenceSeal(result: result)
                if result.contributingProviderCount > 1 {
                    Text("\(result.agreeingProviderCount) of \(result.contributingProviderCount) sources agree")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            if let number = model.duplicateOfNumber {
                Label("Already collected as #\(number)", systemImage: "square.stack")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if result.band == .unsure || !result.alternatives.isEmpty {
                AlternativesRow(model: model, result: result)
            }
            CareLines(details: model.details)
            HStack {
                UndoCountdownButton(model: model)
                Spacer()
            }
        }
    }
}

/// The confidence band as a stamped seal: inked outline in the band color,
/// a hair off square. Raw number on tap, never hidden.
private struct ConfidenceSeal: View {
    let result: IdentificationResult
    @State private var showsRawConfidence = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            showsRawConfidence.toggle()
        } label: {
            Text(showsRawConfidence
                 ? result.confidence.formatted(.percent.precision(.fractionLength(0)))
                 : label)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.8)
                .monospacedDigit()
                .foregroundStyle(Color.floraBand(result.band))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .overlay(
                    Capsule()
                        .strokeBorder(Color.floraBand(result.band).opacity(0.55), lineWidth: 1.25)
                )
                .rotationEffect(reduceMotion ? .zero : Floradex.Motion.stampTilt)
                .frame(minHeight: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(FloraPressStyle())
        .accessibilityLabel("Confidence: \(label)")
        .accessibilityHint("Shows the raw confidence number")
    }

    private var label: String {
        switch result.band {
        case .confident: return result.agreement == .split ? "Sources disagree" : "Confident"
        case .likely: return "Likely"
        case .unsure: return "Not sure"
        }
    }
}

private struct AlternativesRow: View {
    let model: CaptureFlowModel
    let result: IdentificationResult

    var body: some View {
        HStack(spacing: Floradex.Space.s) {
            Text(result.band == .unsure ? "Could also be:" : "Not it?")
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Floradex.Space.s) {
                    ForEach(result.alternatives, id: \.self) { alternative in
                        Button {
                            model.correct(to: alternative.species)
                        } label: {
                            Text(alternative.species.displayName)
                                .font(.floraLatinSmall)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .overlay(Capsule().strokeBorder(Color.floraHairline, lineWidth: 1))
                                .frame(minHeight: 40)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(FloraPressStyle())
                    }
                }
            }
        }
    }
}

private struct CareLines: View {
    let details: SpeciesDetailsContent?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let care = details?.care, !care.isEmpty {
                if let sunlight = care.sunlight {
                    Label(sunlight, systemImage: "sun.max")
                }
                if let water = care.water {
                    Label(water, systemImage: "drop")
                }
            } else {
                Label("Gathering field notes…", systemImage: "text.book.closed")
                    .redacted(reason: .placeholder)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

private struct UndoCountdownButton: View {
    let model: CaptureFlowModel

    var body: some View {
        Button {
            model.undoTapped()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.uturn.backward")
                Text("Undo")
                if let deadline = model.undoDeadline {
                    Text(deadline, style: .timer)
                        .monospacedDigit()
                }
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, Floradex.Space.m)
            .padding(.vertical, 7)
            .overlay(Capsule().strokeBorder(Color.floraHairline, lineWidth: 1))
            .frame(minHeight: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(FloraPressStyle())
    }
}

// MARK: - Correction

private struct CorrectionContent: View {
    let model: CaptureFlowModel
    let result: IdentificationResult
    @State private var overrideName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Floradex.Space.s) {
            HStack {
                Text("Which one is it?")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Button("Cancel") {
                    model.cancelCorrection()
                }
                .font(.caption)
            }
            ForEach(result.alternatives, id: \.self) { alternative in
                Button {
                    model.correct(to: alternative.species)
                } label: {
                    Text(alternative.species.displayName)
                        .font(.floraLatinSmall)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Floradex.Space.m)
                        .padding(.vertical, 9)
                        .overlay(
                            RoundedRectangle(cornerRadius: Floradex.Radius.plate)
                                .strokeBorder(Color.floraHairline, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(FloraPressStyle())
            }
            HStack(spacing: Floradex.Space.s) {
                TextField("Or type a species name", text: $overrideName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                Button("Use") {
                    model.correct(to: Species(latinName: trimmedOverride))
                }
                .buttonStyle(.bordered)
                .disabled(trimmedOverride.isEmpty)
            }
        }
    }

    private var trimmedOverride: String {
        overrideName.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Committed and failed

/// Number leading, action trailing: a specimen label's footer.
private struct CommittedContent: View {
    let model: CaptureFlowModel
    let number: DexNumber
    let reduceMotion: Bool

    var body: some View {
        HStack {
            DexStamp(number: number, reduceMotion: reduceMotion)
            Spacer()
            Button("Done") {
                model.discardTapped()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.floraGreen)
        }
    }
}

private struct FailedContent: View {
    let model: CaptureFlowModel
    let failure: FlowFailure

    var body: some View {
        HStack {
            if failure.isRecoverable {
                Button("Try again") {
                    model.retryTapped()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.floraGreen)
            }
            Button("Dismiss") {
                model.discardTapped()
            }
            .buttonStyle(.bordered)
            Spacer()
        }
    }
}

extension FlowFailure {
    var displayMessage: String {
        switch self {
        case .credentialMissing(let provider):
            return "Identification isn't set up: no key for \(provider.rawValue)"
        case .offline:
            return "You're offline. Try again when you're connected."
        case .noPlantDetected:
            return "No plant found. Try a closer shot?"
        case .providersUnavailable:
            return "The field guides aren't answering"
        case .commitFailed:
            return "Couldn't save this entry"
        case .cancelled:
            return "Identification stopped"
        }
    }
}

private extension IdentificationFlowState {
    var isIdentifying: Bool {
        if case .identifying = self { return true }
        return false
    }
}
