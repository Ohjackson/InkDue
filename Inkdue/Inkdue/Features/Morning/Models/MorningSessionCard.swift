import Foundation

struct MorningSessionCard: Equatable {
    let wordId: UUID
    let term: String
    let meaning: String
    let source: MorningQueueSource
    let step: Int

    var sourceTitle: String {
        switch source {
        case .failedRecovery:
            return "Failed recovery"
        case .readyReview:
            return "Ready review"
        }
    }
}
