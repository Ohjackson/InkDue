import Foundation

struct WordListItemRow: Identifiable, Equatable {
    let id: UUID
    let term: String
    let meaning: String
    let step: Int
    let nextReviewDayIndex: Int?
    let isArchived: Bool

    var subtitle: String {
        if isArchived {
            return "Archived"
        }

        if let nextReviewDayIndex {
            return "Step \(step) · Next D\(nextReviewDayIndex)"
        }

        return "Step \(step)"
    }
}
