import Foundation
import SwiftData

@Model
final class WordItem {
    @Attribute(.unique) var id: UUID
    var term: String
    var meaning: String
    var example: String
    var exampleMeaning: String
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        term: String,
        meaning: String,
        example: String,
        exampleMeaning: String,
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.term = term
        self.meaning = meaning
        self.example = example
        self.exampleMeaning = exampleMeaning
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
