import Foundation

/// Pure state machine for the hero loop. The reducer owns sequencing rules
/// (optimistic response before network, undo before commit, numbers assigned
/// only at commit); the app layer executes the returned effects.
///
/// Events that are invalid in the current state return the state unchanged
/// with no effects, so the reducer is total and the UI can't wedge it.
public struct IdentificationFlowReducer: Sendable {
    public var configuration: FlowConfiguration

    public init(configuration: FlowConfiguration = .standard) {
        self.configuration = configuration
    }

    public func reduce(
        _ state: IdentificationFlowState,
        _ event: IdentificationFlowEvent
    ) -> (state: IdentificationFlowState, effects: [IdentificationFlowEffect]) {
        switch (state, event) {

        // A new capture is valid from any resting state. The frozen-frame
        // metric precedes startIdentification by design: the optimistic
        // visual response must never wait on the pipeline.
        case (.idle, .shutterPressed(let id)),
             (.committed, .shutterPressed(let id)),
             (.failed, .shutterPressed(let id)):
            return (
                .identifying(id, bestSoFar: nil),
                [.recordMetric(.frameFrozen), .startIdentification(id)]
            )

        case (.identifying(let id, let previous), .identificationProgressed(let result)):
            var effects: [IdentificationFlowEffect] = []
            if previous == nil {
                effects.append(.recordMetric(.firstRevealShown))
            }
            return (.identifying(id, bestSoFar: result), effects)

        // The orchestrator records `identificationSettled` itself; effects
        // here stay UI-perceived (what the user saw, when).
        case (.identifying(let id, _), .identificationFinished(let reason, let result)):
            if let result {
                return (
                    .provisional(id, result),
                    [
                        .recordMetric(.provisionalShown),
                        .startUndoWindow(id, configuration.undoWindow),
                    ]
                )
            }
            return (.failed(id, reason == .queuedOffline ? .offline : .noPlantDetected), [])

        case (.identifying(let id, _), .identificationFailed(let failure)):
            return (.failed(id, failure), [])

        case (.identifying(let id, _), .discarded):
            return (.idle, [.cancelIdentification(id), .discardMedia(id)])

        case (.provisional(let id, _), .undoTapped):
            return (.idle, [.recordMetric(.undone), .discardMedia(id)])

        case (.provisional(let id, let result), .undoWindowElapsed):
            return (.committing(id, result), [.commitProvisional(id)])

        case (.provisional(let id, let result), .correctRequested):
            return (.correcting(id, result), [])

        case (.correcting(let id, let result), .correctionChosen(let species)):
            // Correction restarts the undo window so the user can reconsider.
            return (
                .provisional(id, result.corrected(to: species)),
                [.recordMetric(.corrected), .startUndoWindow(id, configuration.undoWindow)]
            )

        case (.correcting(let id, let result), .correctionCancelled):
            return (.provisional(id, result), [.startUndoWindow(id, configuration.undoWindow)])

        case (.committing(let id, _), .commitSucceeded(let number)):
            return (.committed(id, number), [.recordMetric(.committed)])

        case (.committing(let id, _), .commitFailed(let message)):
            return (.failed(id, .commitFailed(message)), [])

        case (.failed(let id, let failure), .retryRequested) where failure.isRecoverable:
            return (.identifying(id, bestSoFar: nil), [.startIdentification(id)])

        case (.failed(let id, _), .discarded):
            return (.idle, [.discardMedia(id)])

        // Dismissing a committed card returns to the viewfinder; the entry
        // is already persisted, so only in-memory media is discarded.
        case (.committed(let id, _), .discarded):
            return (.idle, [.discardMedia(id)])

        default:
            return (state, [])
        }
    }
}
