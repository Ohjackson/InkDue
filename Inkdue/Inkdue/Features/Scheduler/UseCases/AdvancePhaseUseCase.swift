import Foundation

struct PhaseTransitionResult: Equatable {
    let previousPhase: StudyPhase
    let nextPhase: StudyPhase
    let previousStudyDayIndex: Int
    let nextStudyDayIndex: Int
    let didAdvanceStudyDay: Bool
}

struct AdvancePhaseUseCase {
    func execute(
        on appState: AppState,
        completedAt now: Date = .now
    ) -> PhaseTransitionResult {
        let previousPhase = appState.currentPhase
        let previousStudyDayIndex = appState.currentStudyDayIndex

        let nextState = nextState(
            from: previousPhase,
            studyDayIndex: previousStudyDayIndex
        )

        appState.currentPhase = nextState.phase
        appState.currentStudyDayIndex = nextState.studyDayIndex
        appState.lastOpenedAt = now
        appState.updatedAt = now

        return PhaseTransitionResult(
            previousPhase: previousPhase,
            nextPhase: nextState.phase,
            previousStudyDayIndex: previousStudyDayIndex,
            nextStudyDayIndex: nextState.studyDayIndex,
            didAdvanceStudyDay: nextState.didAdvanceStudyDay
        )
    }

    func nextState(
        from phase: StudyPhase,
        studyDayIndex: Int
    ) -> (phase: StudyPhase, studyDayIndex: Int, didAdvanceStudyDay: Bool) {
        switch phase {
        case .morning:
            return (.lunch, studyDayIndex, false)
        case .lunch:
            return (.evening, studyDayIndex, false)
        case .evening:
            return (.morning, studyDayIndex + 1, true)
        }
    }
}
