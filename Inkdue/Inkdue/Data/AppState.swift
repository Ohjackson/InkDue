import Foundation
import SwiftData

@Model
final class AppState {
    static let singletonID = "singleton"

    @Attribute(.unique) var id: String
    var currentStudyDayIndex: Int
    var currentPhase: StudyPhase
    var lastOpenedAt: Date
    var updatedAt: Date

    init(
        id: String = AppState.singletonID,
        currentStudyDayIndex: Int = 0,
        currentPhase: StudyPhase = .morning,
        lastOpenedAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.currentStudyDayIndex = currentStudyDayIndex
        self.currentPhase = currentPhase
        self.lastOpenedAt = lastOpenedAt
        self.updatedAt = updatedAt
    }
}
