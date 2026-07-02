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
    private let dexRepository: DexRepository
    private let speciesRepository: SpeciesRepository
    private let recorder: any PerceivedQualityRecorder
    private let reducer = IdentificationFlowReducer()
    private let logger = Logger(subsystem: "samayd.floradex", category: "capture-flow")

    private var identificationTask: Task<Void, Never>?
    private var undoTask: Task<Void, Never>?
    private var detailsTask: Task<Void, Never>?
    private var currentPayload: ImagePayload?

    init(
        camera: CameraSession = CameraSession(),
        orchestrator: IdentificationOrchestrator,
        detailsProvider: any SpeciesDetailsProvider,
        spriteProvider: any SpriteGenerationProvider,
        dexRepository: DexRepository,
        speciesRepository: SpeciesRepository,
        recorder: any PerceivedQualityRecorder = SignpostQualityRecorder()
    ) {
        self.camera = camera
        self.orchestrator = orchestrator
        self.detailsProvider = detailsProvider
        self.spriteProvider = spriteProvider
        self.dexRepository = dexRepository
        self.speciesRepository = speciesRepository
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

    // MARK: - Reducer plumbing

    private func begin(with image: UIImage) {
        frozenImage = image
        details = nil
        spriteImage = nil
        duplicateOfNumber = nil
        let sized = UIImage.ImageProcessing.resized(image, maxSide: 1024) ?? image
        guard let payload = sized.jpegData(compressionQuality: 0.85) else {
            logger.error("could not encode capture payload")
            return
        }
        currentPayload = ImagePayload(format: .jpeg, data: payload)
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
            currentPayload = nil
        }
    }

    private func startIdentification(_ captureID: CaptureID) {
        guard let payload = currentPayload else {
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
        identificationTask = Task { [orchestrator] in
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
    /// delay the reveal.
    private func startEnrichment(for species: Species) {
        duplicateOfNumber = dexRepository.all()
            .first { Species.normalizeLatinName($0.latinName) == species.normalizedKey }?
            .id

        detailsTask?.cancel()
        detailsTask = Task { [weak self, detailsProvider] in
            guard let content = try? await detailsProvider.details(for: species) else { return }
            await MainActor.run { [weak self] in
                self?.details = content
            }
        }
    }

    private func commitProvisional() {
        guard case .committing(_, let result) = state else { return }
        let image = frozenImage
        let content = details
        Task { [weak self] in
            guard let self else { return }
            do {
                var tags: [String] = []
                if let content {
                    let legacy = self.legacyDetails(from: content, latinName: result.species.latinName)
                    self.speciesRepository.saveSpeciesDetails(legacy)
                    tags = TagGenerator.generateTags(from: legacy)
                }
                let entry = try await self.dexRepository.addEntry(
                    latinName: result.species.latinName,
                    snapshot: image,
                    tags: tags
                )
                HeroHaptics.saveSuccess()
                self.send(.commitSucceeded(DexNumber(entry.id)))
                self.startSprite(for: result.species, entryID: entry.id)
            } catch {
                self.send(.commitFailed(String(describing: error)))
            }
        }
    }

    private func startSprite(for species: Species, entryID: Int) {
        Task { [weak self, spriteProvider] in
            do {
                let data = try await spriteProvider.sprite(for: species)
                guard let image = UIImage(data: data) else {
                    throw ProviderError.invalidResponse("sprite data was not an image")
                }
                let stored = UIImage.ImageProcessing.resized(image, maxSide: 256)?.pngData() ?? data
                try await self?.dexRepository.updateSprite(for: entryID, spriteData: stored)
                await MainActor.run { [weak self] in
                    self?.spriteImage = image
                    self?.recorder.record(.spriteShown)
                }
            } catch {
                try? await self?.dexRepository.markSpriteGenerationFailed(for: entryID)
            }
        }
    }

    private func legacyDetails(from content: SpeciesDetailsContent, latinName: String) -> SpeciesDetails {
        SpeciesDetails(
            latinName: latinName,
            commonName: content.species.commonName,
            summary: content.summary,
            sunlight: content.care.sunlight,
            water: content.care.water,
            soil: content.care.soil,
            temperature: content.care.temperature,
            bloomTime: content.care.bloomTime,
            funFacts: content.funFacts.isEmpty ? nil : content.funFacts,
            lastUpdated: content.source.generatedAt
        )
    }
}
