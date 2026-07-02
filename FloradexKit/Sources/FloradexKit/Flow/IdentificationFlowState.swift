import Foundation

public enum FlowFailure: Hashable, Sendable {
    case credentialMissing(ProviderID)
    case offline
    case noPlantDetected
    case providersUnavailable
    case commitFailed(String)
    case cancelled

    /// Failures the user can act on from within the flow (retry, retake).
    public var isRecoverable: Bool {
        switch self {
        case .credentialMissing:
            return false
        case .offline, .noPlantDetected, .providersUnavailable, .commitFailed, .cancelled:
            return true
        }
    }
}

public enum IdentificationFlowState: Hashable, Sendable {
    case idle
    /// Frame frozen, providers running; `bestSoFar` fills in as they report.
    case identifying(CaptureID, bestSoFar: IdentificationResult?)
    /// Result shown, undo window open. No dex number exists yet.
    case provisional(CaptureID, IdentificationResult)
    /// User is choosing an alternative or searching for an override.
    case correcting(CaptureID, IdentificationResult)
    /// Undo window elapsed; waiting on the store to persist and number.
    case committing(CaptureID, IdentificationResult)
    case committed(CaptureID, DexNumber)
    case failed(CaptureID, FlowFailure)
}

public enum IdentificationFlowEvent: Sendable {
    case shutterPressed(CaptureID)
    case identificationProgressed(IdentificationResult)
    case identificationFinished(FinishReason, IdentificationResult?)
    case identificationFailed(FlowFailure)
    case undoTapped
    case undoWindowElapsed
    case commitSucceeded(DexNumber)
    case commitFailed(String)
    case correctRequested
    case correctionChosen(Species)
    case correctionCancelled
    case retryRequested
    case discarded
}

public enum IdentificationFlowEffect: Hashable, Sendable {
    case recordMetric(MetricEvent)
    case startIdentification(CaptureID)
    case cancelIdentification(CaptureID)
    case startUndoWindow(CaptureID, Duration)
    case commitProvisional(CaptureID)
    case discardMedia(CaptureID)
}

public struct FlowConfiguration: Hashable, Sendable {
    public var undoWindow: Duration

    public init(undoWindow: Duration = .seconds(5)) {
        self.undoWindow = undoWindow
    }

    public static let standard = FlowConfiguration()
}
