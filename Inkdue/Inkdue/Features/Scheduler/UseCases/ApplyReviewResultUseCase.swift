import Foundation

struct SchedulerUpdate: Equatable {
    let stepBefore: Int
    let stepAfter: Int
    let nextReviewDayIndex: Int
    let lastReviewedDayIndex: Int
    let lastReviewedPhase: StudyPhase
    let lastResult: ReviewResult
    let recoveryDueDayIndex: Int?
    let lastAgainAt: Date?
    let updatedAt: Date
}

struct ApplyReviewResultUseCase {
    private static let intervalTable = [1, 1, 2, 4, 7, 15, 30, 60]

    func execute(
        on srs: WordSRS,
        result: ReviewResult,
        currentStudyDayIndex: Int,
        currentPhase: StudyPhase,
        now: Date = .now
    ) {
        let update = makeUpdate(
            stepBefore: srs.step,
            result: result,
            currentStudyDayIndex: currentStudyDayIndex,
            currentPhase: currentPhase,
            now: now
        )

        srs.step = update.stepAfter
        srs.nextReviewDayIndex = update.nextReviewDayIndex
        srs.lastReviewedDayIndex = update.lastReviewedDayIndex
        srs.lastReviewedPhase = update.lastReviewedPhase
        srs.lastResult = update.lastResult
        srs.recoveryDueDayIndex = update.recoveryDueDayIndex
        srs.lastAgainAt = update.lastAgainAt
        srs.updatedAt = update.updatedAt
    }

    func makeUpdate(
        stepBefore: Int,
        result: ReviewResult,
        currentStudyDayIndex: Int,
        currentPhase: StudyPhase,
        now: Date = .now
    ) -> SchedulerUpdate {
        let clampedStepBefore = WordSRS.clampStep(stepBefore)
        let stepAfter = nextStep(from: clampedStepBefore, result: result)
        let nextReviewDayIndex = currentStudyDayIndex + Self.interval(for: stepAfter)

        switch result {
        case .correct:
            return SchedulerUpdate(
                stepBefore: clampedStepBefore,
                stepAfter: stepAfter,
                nextReviewDayIndex: nextReviewDayIndex,
                lastReviewedDayIndex: currentStudyDayIndex,
                lastReviewedPhase: currentPhase,
                lastResult: .correct,
                recoveryDueDayIndex: nil,
                lastAgainAt: nil,
                updatedAt: now
            )

        case .again:
            return SchedulerUpdate(
                stepBefore: clampedStepBefore,
                stepAfter: stepAfter,
                nextReviewDayIndex: nextReviewDayIndex,
                lastReviewedDayIndex: currentStudyDayIndex,
                lastReviewedPhase: currentPhase,
                lastResult: .again,
                recoveryDueDayIndex: currentStudyDayIndex + 1,
                lastAgainAt: now,
                updatedAt: now
            )
        }
    }

    static func interval(for step: Int) -> Int {
        let clampedStep = WordSRS.clampStep(step)
        return intervalTable[clampedStep]
    }

    private func nextStep(from currentStep: Int, result: ReviewResult) -> Int {
        switch result {
        case .correct:
            return min(currentStep + 1, WordSRS.maxStep)
        case .again:
            return max(currentStep - 1, WordSRS.minStep)
        }
    }
}
