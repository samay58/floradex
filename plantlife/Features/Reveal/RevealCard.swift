import SwiftUI
import FloradexKit

/// The staged reveal: a digest surface, deliberately light. Name lands
/// first, then confidence, then care lines; the sprite fills its slot
/// whenever it arrives. Long-form detail lives in the entry screen, never
/// here, so the card never scrolls.
struct RevealCard: View {
    let model: CaptureFlowModel

    var body: some View {
        VStack(spacing: 14) {
            header
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 12)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: model.state)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: model.details != nil)
    }

    private var header: some View {
        HStack(spacing: 12) {
            if let image = model.frozenImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            headerText
            Spacer()
            spriteSlot
        }
    }

    @ViewBuilder
    private var headerText: some View {
        switch model.state {
        case .identifying(_, let bestSoFar):
            VStack(alignment: .leading, spacing: 4) {
                Text(bestSoFar?.species.displayName ?? "Looking closely…")
                    .font(.headline)
                    .redacted(reason: bestSoFar == nil ? .placeholder : [])
                Text(bestSoFar == nil ? "Comparing field notes" : "Getting a second opinion…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .provisional(_, let result), .correcting(_, let result), .committing(_, let result):
            VStack(alignment: .leading, spacing: 4) {
                Text(result.species.displayName)
                    .font(.headline)
                Text(result.species.latinName)
                    .font(.caption.italic())
                    .foregroundStyle(.secondary)
            }
        case .committed:
            Text("Added to your Floradex")
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
        case .failed(_, let failure):
            Text(failure.displayMessage)
                .font(.headline)
        case .idle:
            EmptyView()
        }
    }

    private var spriteSlot: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.Colors.primaryGreen.opacity(0.12))
                .frame(width: 56, height: 56)
            if let sprite = model.spriteImage {
                Image(uiImage: sprite)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(Theme.Colors.primaryGreen.opacity(0.45))
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .identifying:
            ProgressView()
                .frame(maxWidth: .infinity)
        case .provisional(_, let result):
            ProvisionalContent(model: model, result: result)
        case .correcting(_, let result):
            CorrectionContent(model: model, result: result)
        case .committing:
            Label("Saving…", systemImage: "tray.and.arrow.down")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .committed(_, let number):
            CommittedContent(model: model, number: number)
        case .failed(_, let failure):
            FailedContent(model: model, failure: failure)
        case .idle:
            EmptyView()
        }
    }
}

private struct ProvisionalContent: View {
    let model: CaptureFlowModel
    let result: IdentificationResult

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ConfidenceBadge(result: result)
                if let number = model.duplicateOfNumber {
                    Label("Already collected as #\(number)", systemImage: "square.stack")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            if result.contributingProviderCount > 1 {
                Text("\(result.agreeingProviderCount) of \(result.contributingProviderCount) sources agree")
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

private struct ConfidenceBadge: View {
    let result: IdentificationResult
    @State private var showsRawConfidence = false

    var body: some View {
        // Banded by default; the raw number is available on tap, never hidden.
        Button {
            showsRawConfidence.toggle()
        } label: {
            Label(
                showsRawConfidence ? result.confidence.formatted(.percent.precision(.fractionLength(0))) : label,
                systemImage: symbol
            )
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
        }
        .buttonStyle(.plain)
    }

    private var label: String {
        switch result.band {
        case .confident: return result.agreement == .split ? "Sources disagree" : "Confident"
        case .likely: return "Likely"
        case .unsure: return "Not sure"
        }
    }

    private var symbol: String {
        switch result.band {
        case .confident: return "checkmark.seal.fill"
        case .likely: return "leaf"
        case .unsure: return "questionmark.circle"
        }
    }

    private var color: Color {
        switch result.band {
        case .confident: return .green
        case .likely: return .orange
        case .unsure: return .red
        }
    }
}

private struct AlternativesRow: View {
    let model: CaptureFlowModel
    let result: IdentificationResult

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text(result.band == .unsure ? "Could also be:" : "Not it?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(result.alternatives, id: \.self) { alternative in
                    Button {
                        model.correct(to: alternative.species)
                    } label: {
                        Text(alternative.species.displayName)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.thinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct CareLines: View {
    let details: SpeciesDetailsContent?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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
        }
        .buttonStyle(.bordered)
    }
}

private struct CorrectionContent: View {
    let model: CaptureFlowModel
    let result: IdentificationResult
    @State private var overrideName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
            }
            HStack(spacing: 8) {
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

private struct CommittedContent: View {
    let model: CaptureFlowModel
    let number: DexNumber

    var body: some View {
        HStack {
            Label("#\(number.value)", systemImage: "sparkles")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.Colors.primaryGreen)
            Spacer()
            Button("Done") {
                model.discardTapped()
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Colors.primaryGreen)
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
