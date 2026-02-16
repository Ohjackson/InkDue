import Foundation

enum RecordReviewResultError: Error, Equatable {
    case missingWordSRS(UUID)
}

struct RecordReviewResultSummary: Equatable {
    let wordId: UUID
    let result: ReviewResult
    let stepBefore: Int
    let stepAfter: Int
}

struct RecordReviewResultUseCase {
    private let repository: any AppRepository
    private let scheduler: ApplyReviewResultUseCase

    init(
        repository: any AppRepository,
        scheduler: ApplyReviewResultUseCase = ApplyReviewResultUseCase()
    ) {
        self.repository = repository
        self.scheduler = scheduler
    }

    func execute(
        wordId: UUID,
        result: ReviewResult,
        currentStudyDayIndex: Int,
        currentPhase: StudyPhase,
        now: Date = .now
    ) throws -> RecordReviewResultSummary {
        guard let srs = try repository.fetchWordSRS(wordId: wordId) else {
            throw RecordReviewResultError.missingWordSRS(wordId)
        }

        let stepBefore = srs.step
        scheduler.execute(
            on: srs,
            result: result,
            currentStudyDayIndex: currentStudyDayIndex,
            currentPhase: currentPhase,
            now: now
        )
        try repository.upsertWordSRS(srs)

        let event = ReviewEvent(
            wordId: wordId,
            studyDayIndex: currentStudyDayIndex,
            phase: currentPhase,
            result: result,
            stepBefore: stepBefore,
            stepAfter: srs.step,
            createdAt: now
        )
        try repository.addReviewEvent(event)

        return RecordReviewResultSummary(
            wordId: wordId,
            result: result,
            stepBefore: stepBefore,
            stepAfter: srs.step
        )
    }
}
