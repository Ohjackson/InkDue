import Foundation
import Combine

@MainActor
final class WordListViewModel: ObservableObject {
    struct State: Equatable {
        var appViewState: AppViewState = .loading(.initialData)
        var currentStudyDayIndex: Int = 0
        var rows: [WordListItemRow] = []
        var searchText: String = ""
        var includeArchived: Bool = false
        var errorMessage: String?

        var filteredRows: [WordListItemRow] {
            let baseRows = includeArchived ? rows : rows.filter { !$0.isArchived }
            let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !keyword.isEmpty else { return baseRows }

            return baseRows.filter { row in
                row.term.lowercased().contains(keyword) ||
                row.meaning.lowercased().contains(keyword)
            }
        }

        var hasAnyWord: Bool {
            !rows.isEmpty
        }
    }

    enum Action {
        case onAppear
        case reload
        case updateSearchText(String)
        case setIncludeArchived(Bool)
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
            loadWords(isInitialLoad: true)

        case .reload:
            loadWords(isInitialLoad: false)

        case let .updateSearchText(value):
            state.searchText = value

        case let .setIncludeArchived(value):
            state.includeArchived = value

        case .clearError:
            state.errorMessage = nil
        }
    }

    func makeWordDetailViewModel(wordId: UUID) -> WordDetailViewModel {
        WordDetailViewModel(repository: repository, wordId: wordId)
    }

    private func loadWords(isInitialLoad: Bool) {
        state.appViewState = .loading(isInitialLoad ? .initialData : .syncing)
        state.errorMessage = nil

        do {
            let appState = try repository.fetchOrCreateAppState()
            state.currentStudyDayIndex = appState.currentStudyDayIndex

            let words = try repository.fetchWordItems(includeArchived: true)
            let srsMap = Dictionary(
                uniqueKeysWithValues: try repository.fetchWordSRSList().map { ($0.wordId, $0) }
            )

            state.rows = words
                .map { word in
                    WordListItemRow(
                        id: word.id,
                        term: word.term,
                        meaning: word.meaning,
                        step: srsMap[word.id]?.step ?? 0,
                        nextReviewDayIndex: srsMap[word.id]?.nextReviewDayIndex,
                        isArchived: word.isArchived
                    )
                }
                .sorted { lhs, rhs in
                    if lhs.isArchived != rhs.isArchived {
                        return lhs.isArchived == false
                    }
                    return lhs.term.localizedCaseInsensitiveCompare(rhs.term) == .orderedAscending
                }

            state.appViewState = state.rows.isEmpty ? .empty(.noWord) : .normal
        } catch {
            state.appViewState = .error(.dataCorruption)
            state.errorMessage = error.localizedDescription
        }
    }
}
