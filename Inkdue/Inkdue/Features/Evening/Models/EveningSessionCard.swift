import Foundation

struct EveningSessionCard: Equatable {
    let wordId: UUID
    let term: String
    let meaning: String
    let source: EveningQueueSource
    let step: Int

    var sourceTitle: String {
        switch source {
        case .backlog:
            return "Backlog"
        case .ready:
            return "Ready"
        case .new:
            return "New"
        }
    }
}
