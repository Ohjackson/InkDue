import Foundation

enum EveningQueueSource: String, Equatable {
    case backlog
    case ready
    case new
}

struct EveningQueueItem: Equatable {
    let wordId: UUID
    let source: EveningQueueSource
}

struct BuildEveningQueueUseCase {
    private let repository: any AppRepository
    private let queueCap: Int
    private let maxNewPerStudyDay: Int

    init(
        repository: any AppRepository,
        queueCap: Int = 50,
        maxNewPerStudyDay: Int = 10
    ) {
        self.repository = repository
        self.queueCap = max(0, queueCap)
        self.maxNewPerStudyDay = max(0, maxNewPerStudyDay)
    }

    func execute(currentStudyDayIndex: Int) throws -> [EveningQueueItem] {
        guard queueCap > 0 else { return [] }

        let activeWords = try repository.fetchWordItems(includeArchived: false)
        let activeWordIDs = Set(activeWords.map(\.id))
        let wordMap = Dictionary(uniqueKeysWithValues: activeWords.map { ($0.id, $0) })

        let allSRS = try repository.fetchWordSRSList()
            .filter { activeWordIDs.contains($0.wordId) }

        let backlogQueue = allSRS
            .filter { $0.nextReviewDayIndex < currentStudyDayIndex }
            .sorted { duePriority(lhs: $0, rhs: $1, wordMap: wordMap) }
            .prefix(queueCap)
            .map { EveningQueueItem(wordId: $0.wordId, source: .backlog) }

        let remainAfterBacklog = queueCap - backlogQueue.count
        if remainAfterBacklog == 0 {
            return backlogQueue
        }

        let backlogWordIDs = Set(backlogQueue.map(\.wordId))

        let readyQueue = allSRS
            .filter { $0.nextReviewDayIndex == currentStudyDayIndex }
            .filter { !backlogWordIDs.contains($0.wordId) }
            .sorted { duePriority(lhs: $0, rhs: $1, wordMap: wordMap) }
            .prefix(remainAfterBacklog)
            .map { EveningQueueItem(wordId: $0.wordId, source: .ready) }

        let dueQueue = backlogQueue + readyQueue
        let remainAfterDue = queueCap - dueQueue.count
        if remainAfterDue == 0 {
            return dueQueue
        }

        let dueWordIDs = Set(dueQueue.map(\.wordId))
        let newLimit = min(remainAfterDue, maxNewPerStudyDay)
        if newLimit == 0 {
            return dueQueue
        }

        let newQueue = allSRS
            .filter { $0.introducedDayIndex == currentStudyDayIndex }
            .filter { $0.firstTestPlannedPhase == .evening }
            .filter { $0.lastReviewedDayIndex == nil }
            .filter { !dueWordIDs.contains($0.wordId) }
            .sorted { newPriority(lhs: $0, rhs: $1, wordMap: wordMap) }
            .prefix(newLimit)
            .map { EveningQueueItem(wordId: $0.wordId, source: .new) }

        return dueQueue + newQueue
    }

    private func duePriority(lhs: WordSRS, rhs: WordSRS, wordMap: [UUID: WordItem]) -> Bool {
        if lhs.nextReviewDayIndex != rhs.nextReviewDayIndex {
            return lhs.nextReviewDayIndex < rhs.nextReviewDayIndex
        }

        if lhs.introducedDayIndex != rhs.introducedDayIndex {
            return lhs.introducedDayIndex < rhs.introducedDayIndex
        }

        let lhsCreatedAt = wordMap[lhs.wordId]?.createdAt ?? .distantFuture
        let rhsCreatedAt = wordMap[rhs.wordId]?.createdAt ?? .distantFuture
        if lhsCreatedAt != rhsCreatedAt {
            return lhsCreatedAt < rhsCreatedAt
        }

        return lhs.wordId.uuidString < rhs.wordId.uuidString
    }

    private func newPriority(lhs: WordSRS, rhs: WordSRS, wordMap: [UUID: WordItem]) -> Bool {
        let lhsCreatedAt = wordMap[lhs.wordId]?.createdAt ?? .distantFuture
        let rhsCreatedAt = wordMap[rhs.wordId]?.createdAt ?? .distantFuture
        if lhsCreatedAt != rhsCreatedAt {
            return lhsCreatedAt < rhsCreatedAt
        }

        return lhs.wordId.uuidString < rhs.wordId.uuidString
    }
}
