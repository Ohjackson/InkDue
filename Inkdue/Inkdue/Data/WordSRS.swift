import Foundation
import SwiftData

@Model
final class WordSRS {
    static let minStep = 0
    static let maxStep = 7

    @Attribute(.unique) var wordId: UUID
    var step: Int
    var introducedDayIndex: Int
    var firstTestPlannedDayIndex: Int
    var firstTestPlannedPhase: StudyPhase
    var nextReviewDayIndex: Int
    var lastReviewedDayIndex: Int?
    var lastReviewedPhase: StudyPhase?
    var lastResult: ReviewResult?
    var recoveryDueDayIndex: Int?
    var lastAgainAt: Date?
    var updatedAt: Date

    init(
        wordId: UUID,
        step: Int = WordSRS.minStep,
        introducedDayIndex: Int,
        firstTestPlannedDayIndex: Int? = nil,
        firstTestPlannedPhase: StudyPhase = .evening,
        nextReviewDayIndex: Int? = nil,
        lastReviewedDayIndex: Int? = nil,
        lastReviewedPhase: StudyPhase? = nil,
        lastResult: ReviewResult? = nil,
        recoveryDueDayIndex: Int? = nil,
        lastAgainAt: Date? = nil,
        updatedAt: Date = .now
    ) {
        self.wordId = wordId
        self.step = WordSRS.clampStep(step)
        self.introducedDayIndex = introducedDayIndex
        self.firstTestPlannedDayIndex = firstTestPlannedDayIndex ?? introducedDayIndex
        self.firstTestPlannedPhase = firstTestPlannedPhase
        self.nextReviewDayIndex = nextReviewDayIndex ?? introducedDayIndex + 1
        self.lastReviewedDayIndex = lastReviewedDayIndex
        self.lastReviewedPhase = lastReviewedPhase
        self.lastResult = lastResult
        self.recoveryDueDayIndex = recoveryDueDayIndex
        self.lastAgainAt = lastAgainAt
        self.updatedAt = updatedAt
    }

    static func clampStep(_ value: Int) -> Int {
        min(max(value, minStep), maxStep)
    }
}
