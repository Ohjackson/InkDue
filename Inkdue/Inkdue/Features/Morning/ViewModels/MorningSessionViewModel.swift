import Foundation
import Combine

@MainActor
final class MorningSessionViewModel: ObservableObject {
    struct State: Equatable {
        var appViewState: AppViewState = .loading(.initialData)
        var currentStudyDayIndex: Int = 0
        var cards: [MorningSessionCard] = []
        var currentIndex: Int = 0
        var reviewedCount: Int = 0
        var correctCount: Int = 0
        var againCount: Int = 0
        var errorMessage: String?
        var isAdvancingPhase: Bool = false
        var didCompleteSession: Bool = false

        var currentCard: MorningSessionCard? {
            guard currentIndex >= 0 && currentIndex < cards.count else {
                return nil
            }
            return cards[currentIndex]
        }

        var totalCount: Int {
            cards.count
        }

        var progressText: String {
            "\(min(currentIndex + 1, max(totalCount, 1))) / \(max(totalCount, 1))"
        }

        var isFinishedReviewing: Bool {
            currentCard == nil
        }

        var canSubmitReview: Bool {
            guard !isAdvancingPhase else { return false }
            guard appViewState == .normal else { return false }
            return currentCard != nil
        }

        var canCompleteSession: Bool {
            guard !isAdvancingPhase else { return false }
            return isFinishedReviewing
        }
    }

    enum Action {
        case onAppear
        case submitReview(ReviewResult)
        case completeSession
        case reload
        case clearError
    }

    @Published private(set) var state = State()

    private let repository: any AppRepository
    private var didLoadOnAppear = false

    init(repository: any AppRepository) {
        self.repository = repository
    }

    func send(_ action: Action) {
        switch action {
        case .onAppear:
            guard !didLoadOnAppear else { return }
            didLoadOnAppear = true
            loadQueue(isInitialLoad: true)

        case .submitReview(let result):
            submitReview(result)

        case .completeSession:
            completeSession()

        case .reload:
            loadQueue(isInitialLoad: false)

        case .clearError:
            state.errorMessage = nil
        }
    }

    private func loadQueue(isInitialLoad: Bool) {
        state.appViewState = .loading(isInitialLoad ? .initialData : .syncing)
        state.errorMessage = nil
        state.didCompleteSession = false

        do {
            let appState = try repository.fetchOrCreateAppState()
            state.currentStudyDayIndex = appState.currentStudyDayIndex

            let queueItems = try BuildMorningQueueUseCase(repository: repository)
                .execute(currentStudyDayIndex: appState.currentStudyDayIndex)

            let words = try repository.fetchWordItems(includeArchived: false)
            let wordMap = Dictionary(uniqueKeysWithValues: words.map { ($0.id, $0) })
            let srsList = try repository.fetchWordSRSList()
            let srsMap = Dictionary(uniqueKeysWithValues: srsList.map { ($0.wordId, $0) })

            let cards = queueItems.compactMap { item -> MorningSessionCard? in
                guard let word = wordMap[item.wordId], let srs = srsMap[item.wordId] else {
                    return nil
                }

                return MorningSessionCard(
                    wordId: item.wordId,
                    term: word.term,
                    meaning: word.meaning,
                    source: item.source,
                    step: srs.step
                )
            }

            state.cards = cards
            state.currentIndex = 0
            state.reviewedCount = 0
            state.correctCount = 0
            state.againCount = 0

            state.appViewState = cards.isEmpty ? .empty(.noQueue) : .normal
        } catch {
            state.cards = []
            state.currentIndex = 0
            state.appViewState = .error(.dataCorruption)
            state.errorMessage = error.localizedDescription
        }
    }

    private func submitReview(_ result: ReviewResult) {
        guard state.canSubmitReview, let card = state.currentCard else { return }

        do {
            _ = try RecordReviewResultUseCase(repository: repository).execute(
                wordId: card.wordId,
                result: result,
                currentStudyDayIndex: state.currentStudyDayIndex,
                currentPhase: .morning
            )

            state.reviewedCount += 1
            switch result {
            case .correct:
                state.correctCount += 1
            case .again:
                state.againCount += 1
            }

            state.currentIndex += 1
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }

    private func completeSession() {
        guard state.canCompleteSession else { return }
        state.isAdvancingPhase = true
        defer { state.isAdvancingPhase = false }

        do {
            let appState = try repository.fetchOrCreateAppState()
            guard appState.currentPhase == .morning else {
                state.errorMessage = "Current phase is not morning."
                return
            }

            _ = AdvancePhaseUseCase().execute(on: appState)
            try repository.save()
            state.didCompleteSession = true
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }
}
