import Foundation
import Testing
@testable import FloradexKit

@Suite struct IdentificationFlowReducerTests {
    private let reducer = IdentificationFlowReducer()
    private let captureID = CaptureID()
    private let monstera = Species(latinName: "Monstera deliciosa")
    private let pothos = Species(latinName: "Epipremnum aureum")

    private var result: IdentificationResult {
        IdentificationResult(species: monstera, confidence: 0.9, agreement: .unanimous)
    }

    /// The optimistic-UI guarantee, machine-checked: the frozen-frame metric
    /// must be recorded before identification starts.
    @Test func shutterFreezesFrameBeforeStartingIdentification() {
        let (state, effects) = reducer.reduce(.idle, .shutterPressed(captureID))

        #expect(state == .identifying(captureID, bestSoFar: nil))
        let frozen = effects.firstIndex(of: .recordMetric(.frameFrozen))
        let start = effects.firstIndex(of: .startIdentification(captureID))
        #expect(frozen != nil && start != nil)
        #expect(frozen! < start!)
    }

    @Test func firstProgressRecordsFirstReveal() {
        let identifying = IdentificationFlowState.identifying(captureID, bestSoFar: nil)
        let (state, effects) = reducer.reduce(identifying, .identificationProgressed(result))

        #expect(state == .identifying(captureID, bestSoFar: result))
        #expect(effects == [.recordMetric(.firstRevealShown)])

        let (_, secondEffects) = reducer.reduce(state, .identificationProgressed(result))
        #expect(secondEffects.isEmpty)
    }

    @Test func finishingWithResultOpensUndoWindow() {
        let identifying = IdentificationFlowState.identifying(captureID, bestSoFar: result)
        let (state, effects) = reducer.reduce(identifying, .identificationFinished(.confident, result))

        #expect(state == .provisional(captureID, result))
        #expect(effects.contains(.startUndoWindow(captureID, FlowConfiguration.standard.undoWindow)))
        #expect(effects.contains(.recordMetric(.provisionalShown)))
    }

    @Test func undoDiscardsWithoutBurningANumber() {
        let provisional = IdentificationFlowState.provisional(captureID, result)
        let (state, effects) = reducer.reduce(provisional, .undoTapped)

        #expect(state == .idle)
        #expect(effects.contains(.discardMedia(captureID)))
        #expect(effects.contains(.recordMetric(.undone)))
        // Commit is the only place numbers are assigned; no commit effect here.
        #expect(!effects.contains(.commitProvisional(captureID)))
    }

    @Test func undoWindowLapseCommits() {
        let provisional = IdentificationFlowState.provisional(captureID, result)
        let (state, effects) = reducer.reduce(provisional, .undoWindowElapsed)

        #expect(state == .committing(captureID, result))
        #expect(effects == [.commitProvisional(captureID)])

        let number = DexNumber(7)
        let (committed, commitEffects) = reducer.reduce(state, .commitSucceeded(number))
        #expect(committed == .committed(captureID, number))
        #expect(commitEffects == [.recordMetric(.committed)])
    }

    @Test func commitFailureIsRecoverable() {
        let committing = IdentificationFlowState.committing(captureID, result)
        let (state, _) = reducer.reduce(committing, .commitFailed("disk full"))

        guard case .failed(_, let failure) = state else {
            Issue.record("expected failed state, got \(state)")
            return
        }
        #expect(failure == .commitFailed("disk full"))
        #expect(failure.isRecoverable)
    }

    @Test func correctionAmendsResultAndRestartsUndoWindow() {
        let provisional = IdentificationFlowState.provisional(captureID, result)
        let (correcting, _) = reducer.reduce(provisional, .correctRequested)
        #expect(correcting == .correcting(captureID, result))

        let (state, effects) = reducer.reduce(correcting, .correctionChosen(pothos))
        guard case .provisional(_, let amended) = state else {
            Issue.record("expected provisional state after correction")
            return
        }
        #expect(amended.species == pothos)
        #expect(amended.origin == .userCorrection)
        #expect(amended.contributing == result.contributing)
        #expect(effects.contains(.recordMetric(.corrected)))
        #expect(effects.contains(.startUndoWindow(captureID, FlowConfiguration.standard.undoWindow)))
    }

    @Test func cancellingCorrectionRestoresOriginal() {
        let correcting = IdentificationFlowState.correcting(captureID, result)
        let (state, effects) = reducer.reduce(correcting, .correctionCancelled)

        #expect(state == .provisional(captureID, result))
        #expect(effects.contains(.startUndoWindow(captureID, FlowConfiguration.standard.undoWindow)))
    }

    @Test func finishingEmptyHandedFails() {
        let identifying = IdentificationFlowState.identifying(captureID, bestSoFar: nil)

        let (noPlant, _) = reducer.reduce(identifying, .identificationFinished(.noCandidates, nil))
        #expect(noPlant == .failed(captureID, .noPlantDetected))

        let (offline, _) = reducer.reduce(identifying, .identificationFinished(.queuedOffline, nil))
        #expect(offline == .failed(captureID, .offline))
    }

    @Test func recoverableFailureAllowsRetry() {
        let failed = IdentificationFlowState.failed(captureID, .offline)
        let (state, effects) = reducer.reduce(failed, .retryRequested)

        #expect(state == .identifying(captureID, bestSoFar: nil))
        #expect(effects == [.startIdentification(captureID)])
    }

    @Test func credentialFailureDoesNotRetry() {
        let failed = IdentificationFlowState.failed(captureID, .credentialMissing(.kindwise))
        let (state, effects) = reducer.reduce(failed, .retryRequested)

        #expect(state == failed)
        #expect(effects.isEmpty)
    }

    @Test func discardDuringIdentificationCancelsAndCleansUp() {
        let identifying = IdentificationFlowState.identifying(captureID, bestSoFar: nil)
        let (state, effects) = reducer.reduce(identifying, .discarded)

        #expect(state == .idle)
        #expect(effects.contains(.cancelIdentification(captureID)))
        #expect(effects.contains(.discardMedia(captureID)))
    }

    @Test func newCaptureIsValidFromRestingStates() {
        let fresh = CaptureID()
        for resting: IdentificationFlowState in [
            .idle,
            .committed(captureID, DexNumber(1)),
            .failed(captureID, .noPlantDetected),
        ] {
            let (state, _) = reducer.reduce(resting, .shutterPressed(fresh))
            #expect(state == .identifying(fresh, bestSoFar: nil))
        }
    }

    @Test func invalidEventsLeaveStateUntouched() {
        let provisional = IdentificationFlowState.provisional(captureID, result)
        for (state, event): (IdentificationFlowState, IdentificationFlowEvent) in [
            (.idle, .undoTapped),
            (.idle, .undoWindowElapsed),
            (provisional, .shutterPressed(CaptureID())),
            (provisional, .commitSucceeded(DexNumber(1))),
        ] {
            let (next, effects) = reducer.reduce(state, event)
            #expect(next == state)
            #expect(effects.isEmpty)
        }
    }
}
