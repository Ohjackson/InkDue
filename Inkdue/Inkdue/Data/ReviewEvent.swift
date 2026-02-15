import Foundation
import SwiftData

@Model
final class ReviewEvent {
    @Attribute(.unique) var id: UUID
    var wordId: UUID
    var studyDayIndex: Int
    var phase: StudyPhase
    var result: ReviewResult
    var stepBefore: Int
    var stepAfter: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        wordId: UUID,
        studyDayIndex: Int,
        phase: StudyPhase,
        result: ReviewResult,
        stepBefore: Int,
        stepAfter: Int,
        createdAt: Date = .now
    ) {
        self.id = id
        self.wordId = wordId
        self.studyDayIndex = studyDayIndex
        self.phase = phase
        self.result = result
        self.stepBefore = WordSRS.clampStep(stepBefore)
        self.stepAfter = WordSRS.clampStep(stepAfter)
        self.createdAt = createdAt
    }
}
