import Foundation

enum NarrativeClientTransitionError: Error, Equatable {
    case invalidTransition(from: BookProjectState, command: NarrativeCommandType)
}

enum NarrativeStateMachine {
    static func allows(_ command: NarrativeCommandType, from state: BookProjectState) -> Bool {
        switch (state, command) {
        case (.readyForConfirmation, .confirmSetup),
             (.generatingAuditions, .generateAuditions),
             (.auditionsReady, .generateAuditions),
             (.auditionsReady, .selectAudition),
             (.auditionsReady, .generateGoldenSample),
             (.generatingGoldenSample, .generateGoldenSample),
             (.goldenSampleReview, .generateGoldenSample),
             (.goldenSampleReview, .submitArtifactFeedback),
             (.goldenSampleReview, .confirmGoldenSample),
             (.toneConfirmed, .generateOutline),
             (.outlineReview, .generateOutline),
             (.outlineReview, .reviseOutline),
             (.outlineReview, .editArtifact),
             (.outlineReview, .restoreArtifactVersion),
             (.outlineReview, .confirmOutline),
             (.writing, .generateChapter),
             (.writing, .reviseChapter),
             (.writing, .finalizeChapter),
             (.writing, .editArtifact),
             (.writing, .restoreArtifactVersion),
             (.updateAvailable, .generateChapter),
             (.updateAvailable, .reviseChapter),
             (.updateAvailable, .finalizeChapter),
             (.updateAvailable, .editArtifact),
             (.updateAvailable, .restoreArtifactVersion),
             (.updateAvailable, .adoptMemoryUpdate),
             (.updateAvailable, .ignoreMemoryUpdate):
            return true
        case (.paused, .resumeProject):
            return true
        case (_, .pauseProject):
            return [
                .notStarted,
                .checkingReadiness,
                .needsMoreMemory,
                .readyForConfirmation,
                .auditionsReady,
                .goldenSampleReview,
                .toneConfirmed,
                .outlineReview,
                .writing,
                .updateAvailable,
                .disputed,
                .suspended,
            ].contains(state)
        case (_, .archiveProject):
            return state == .writing || state == .updateAvailable || state == .paused
        default:
            return false
        }
    }

    static func require(_ command: NarrativeCommandType, from state: BookProjectState) throws {
        guard allows(command, from: state) else {
            throw NarrativeClientTransitionError.invalidTransition(from: state, command: command)
        }
    }
}
