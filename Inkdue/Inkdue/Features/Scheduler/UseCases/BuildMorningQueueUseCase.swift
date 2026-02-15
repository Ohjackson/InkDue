import Foundation

enum MorningQueueSource: String, Equatable {
    case failedRecovery
    case readyReview
}

struct MorningQueueItem: Equatable {
    let wordId: UUID
    let source: MorningQueueSource
}

struct BuildMorningQueueUseCase {
    private let repository: any AppRepository
    private let maxFailedChunk: Int

    init(repository: any AppRepository, maxFailedChunk: Int = 15) {
        self.repository = repository
        self.maxFailedChunk = max(0, maxFailedChunk)
    }

    func execute(currentStudyDayIndex: Int) throws -> [MorningQueueItem] {
        let activeWordIDs = Set(
            try repository.fetchWordItems(includeArchived: false).map(\.id)
        )

        let allSRS = try repository.fetchWordSRSList()
            .filter { activeWordIDs.contains($0.wordId) }

        let failedSRS = allSRS
            .filter { srs in
                guard let recoveryDueDayIndex = srs.recoveryDueDayIndex else {
                    return false
                }
                return recoveryDueDayIndex <= currentStudyDayIndex
            }
            .sorted(by: failedPriorityOrder)

        let failedQueue = failedSRS.prefix(maxFailedChunk).map {
            MorningQueueItem(wordId: $0.wordId, source: .failedRecovery)
        }

        let selectedFailedWordIDs = Set(failedQueue.map(\.wordId))

        let readyQueue = allSRS
            .filter { srs in
                srs.nextReviewDayIndex <= currentStudyDayIndex &&
                !selectedFailedWordIDs.contains(srs.wordId)
            }
            .sorted(by: readyPriorityOrder)
            .map { MorningQueueItem(wordId: $0.wordId, source: .readyReview) }

        return failedQueue + readyQueue
    }

    private func failedPriorityOrder(lhs: WordSRS, rhs: WordSRS) -> Bool {
        let lhsRecovery = lhs.recoveryDueDayIndex ?? Int.max
        let rhsRecovery = rhs.recoveryDueDayIndex ?? Int.max
        if lhsRecovery != rhsRecovery {
            return lhsRecovery < rhsRecovery
        }

        let lhsAgain = lhs.lastAgainAt ?? .distantPast
        let rhsAgain = rhs.lastAgainAt ?? .distantPast
        if lhsAgain != rhsAgain {
            return lhsAgain > rhsAgain
        }

        return lhs.wordId.uuidString < rhs.wordId.uuidString
    }

    private func readyPriorityOrder(lhs: WordSRS, rhs: WordSRS) -> Bool {
        if lhs.nextReviewDayIndex != rhs.nextReviewDayIndex {
            return lhs.nextReviewDayIndex < rhs.nextReviewDayIndex
        }

        if lhs.introducedDayIndex != rhs.introducedDayIndex {
            return lhs.introducedDayIndex < rhs.introducedDayIndex
        }

        return lhs.wordId.uuidString < rhs.wordId.uuidString
    }
}
