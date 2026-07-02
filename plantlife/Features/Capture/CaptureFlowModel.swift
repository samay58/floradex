import SwiftUI
import FloradexKit
import os

/// Thin bridge between the UI and FloradexKit: owns no sequencing rules
/// itself. Events go through the Kit reducer; this model executes the
/// returned effects (orchestrator runs, undo timer, commit, cleanup) and
/// exposes observable state for the capture and reveal surfaces.
@MainActor
@Observable
final class CaptureFlowModel {
    enum CameraAvailability {
        case unknown, ready, denied, unavailable
    }

    private(set) var state: IdentificationFlowState = .idle
    private(set) var cameraAvailability: CameraAvailability = .unknown
    private(set) var frozenImage: UIImage?
    private(set) var details: SpeciesDetailsContent?
    private(set) var spriteImage: UIImage?
    /// Dex number of an existing entry for the identified species, if any.
    private(set) var duplicateOfNumber: Int?
    private(set) var undoDeadline: Date?

    let camera: CameraSession

    private let orchestrator: IdentificationOrchestrator
    private let detailsProvider: any SpeciesDetailsProvider
    private let spriteProvider: any SpriteGenerationProvider
    private let store: SwiftDataDexStore
    private let media: FileMediaStore
    private let recorder: any PerceivedQualityRecorder
    private let reducer = IdentificationFlowReducer()
    private let encoder = PayloadEncoder()
    private let logger = Logger(subsystem: "samayd.floradex", category: "capture-flow")

    private var identificationTask: Task<Void, Never>?
    private var undoTask: Task<Void, Never>?
    private var detailsTask: Task<Void, Never>?

    init(
        camera: CameraSession = CameraSession(),
        orchestrator: IdentificationOrchestrator,
        detailsProvider: any SpeciesDetailsProvider,
        spriteProvider: any SpriteGenerationProvider,
        store: SwiftDataDexStore,
        media: FileMediaStore,
        recorder: any PerceivedQualityRecorder = SignpostQualityRecorder()
    ) {
        self.camera = camera
        self.orchestrator = orchestrator
        self.detailsProvider = detailsProvider
        self.spriteProvider = spriteProvider
        self.store = store
        self.media = media
        self.recorder = recorder
    }

    // MARK: - Inlets

    func startCamera() async {
        guard await CameraSession.authorize() else {
            cameraAvailability = .denied
            return
        }
        do {
            try await camera.prewarm()
            cameraAvailability = .ready
            HeroHaptics.prepare()
        } catch {
            cameraAvailability = .unavailable
        }
    }

    func shutterPressed() async {
        guard canStartCapture else { return }
        HeroHaptics.shutter()
        recorder.record(.shutterPressed)
        do {
            let data = try await camera.capturePhoto()
            guard let image = UIImage(data: data) else {
                throw CameraSessionError.captureFailed("undecodable photo data")
            }
            begin(with: image)
        } catch {
            logger.error("capture failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// Photo picker and sample-image inlet; same loop, different glass.
    func imported(_ image: UIImage) {
        guard canStartCapture else { return }
        HeroHaptics.shutter()
        recorder.record(.shutterPressed)
        begin(with: image)
    }

    var canStartCapture: Bool {
        switch state {
        case .idle, .committed, .failed: return true
        default: return false
        }
    }

    // MARK: - User actions on the reveal card

    func undoTapped() {
        HeroHaptics.undo()
        send(.undoTapped)
    }

    func retryTapped() {
        send(.retryRequested)
    }

    func discardTapped() {
        send(.discarded)
    }

    func correct(to species: Species) {
        send(.correctRequested)
        send(.correctionChosen(species))
    }

    func cancelCorrection() {
        send(.correctionCancelled)
    }

    // MARK: - Reducer plumbing

    private func begin(with image: UIImage) {
        frozenImage = image
        details = nil
        spriteImage = nil
        duplicateOfNumber = nil
        send(.shutterPressed(CaptureID()))
    }

    private func send(_ event: IdentificationFlowEvent) {
        let (next, effects) = reducer.reduce(state, event)
        state = next
        for effect in effects {
            run(effect)
        }
    }

    private func run(_ effect: IdentificationFlowEffect) {
        switch effect {
        case .recordMetric(let metric):
            recorder.record(metric)

        case .startIdentification(let captureID):
            startIdentification(captureID)

        case .cancelIdentification:
            identificationTask?.cancel()
            identificationTask = nil

        case .startUndoWindow(_, let duration):
            let seconds = Double(duration.components.seconds)
                + Double(duration.components.attoseconds) / 1e18
            undoDeadline = Date().addingTimeInterval(seconds)
            undoTask?.cancel()
            undoTask = Task { [weak self] in
                try? await Task.sleep(for: duration)
                guard !Task.isCancelled else { return }
                self?.send(.undoWindowElapsed)
            }

        case .commitProvisional:
            commitProvisional()

        case .discardMedia:
            undoTask?.cancel()
            undoTask = nil
            detailsTask?.cancel()
            detailsTask = nil
            frozenImage = nil
            details = nil
            spriteImage = nil
            duplicateOfNumber = nil
            undoDeadline = nil
        }
    }

    private func startIdentification(_ captureID: CaptureID) {
        guard let image = frozenImage else {
            send(.identificationFailed(.cancelled))
            return
        }
        identificationTask?.cancel()
        let onEvent: @Sendable (OrchestratorEvent) -> Void = { [weak self] event in
            guard let self else { return }
            Task { @MainActor in
                self.handle(event)
            }
        }
        identificationTask = Task { [orchestrator, encoder] in
            guard let payload = await encoder.encode(image) else {
                onEvent(.failed(.cancelled))
                return
            }
            _ = await orchestrator.identify(payload, onEvent: onEvent)
        }
    }

    private func handle(_ event: OrchestratorEvent) {
        switch event {
        case .progressed(let result):
            HeroHaptics.revealStage()
            send(.identificationProgressed(result))

        case .finished(let reason, let result):
            send(.identificationFinished(reason, result))
            if let result {
                startEnrichment(for: result.species)
            }

        case .failed(let failure):
            send(.identificationFailed(failure))
        }
    }

    /// Details and duplicate checks run beside the undo window; neither may
    /// delay the reveal. Details persist to the species record on arrival,
    /// even when they land after commit.
    private func startEnrichment(for species: Species) {
        Task { [weak self, store] in
            let existing = await store.existingEntry(for: species)
            self?.duplicateOfNumber = existing?.number.value
        }

        detailsTask?.cancel()
        detailsTask = Task { [weak self, detailsProvider] in
            do {
                let content = try await detailsProvider.details(for: species)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.details = content
                    self.store.updateDetails(content)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.logger.error("details for \(species.latinName, privacy: .public): \(String(describing: error), privacy: .public)")
                }
            }
        }
    }

    private func commitProvisional() {
        guard case .committing(let captureID, let result) = state else { return }
        let image = frozenImage
        let tags = details.map { TagPolicy.tags(for: $0) } ?? []
        Task { [weak self] in
            guard let self else { return }
            do {
                let committed = try await self.store.commit(ProvisionalEntry(
                    captureID: captureID,
                    result: result,
                    createdAt: Date(),
                    tags: tags
                ))
                if let image, let original = await self.encoder.encodeOriginal(image) {
                    _ = try? await self.media.writeOriginalPhoto(original, for: committed.id)
                }
                HeroHaptics.saveSuccess()
                self.send(.commitSucceeded(committed.number))
                self.startSprite(for: result.species, entry: committed)
            } catch {
                self.send(.commitFailed(String(describing: error)))
            }
        }
    }

    private func startSprite(for species: Species, entry: CommittedEntry) {
        Task { [weak self, spriteProvider, media] in
            do {
                let data = try await spriteProvider.sprite(for: species)
                guard let image = UIImage(data: data) else {
                    throw ProviderError.invalidResponse("sprite data was not an image")
                }
                let stored = image.resized(maxSide: 256).pngData() ?? data
                try await media.writeSprite(stored, for: entry.id, version: 1)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    try? self.store.setSpriteVersion(1, for: entry.number)
                    // The card may already be showing a later capture; a slow
                    // sprite must not paint onto it. Persistence above stands.
                    guard case .committed(_, let number) = self.state,
                          number == entry.number else { return }
                    self.spriteImage = image
                    self.recorder.record(.spriteShown)
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.logger.error("sprite for #\(entry.number.value): \(String(describing: error), privacy: .public)")
                    try? self.store.markSpriteFailed(for: entry.number)
                }
            }
        }
    }

    /// Owns the resize-and-encode of the capture payload so a full-size
    /// photo never contends with the shutter's optimistic freeze-frame on
    /// the main actor.
    private actor PayloadEncoder {
        func encode(_ image: UIImage) -> ImagePayload? {
            guard let data = image.resized(maxSide: 1024).jpegData(compressionQuality: 0.85) else {
                return nil
            }
            return ImagePayload(format: .jpeg, data: data)
        }

        /// Full-resolution archival copy for the entry's media directory.
        func encodeOriginal(_ image: UIImage) -> Data? {
            image.jpegData(compressionQuality: 0.9)
        }
    }
}
