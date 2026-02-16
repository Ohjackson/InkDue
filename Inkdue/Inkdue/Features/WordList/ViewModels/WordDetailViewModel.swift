import Foundation
import Combine

@MainActor
final class WordDetailViewModel: ObservableObject {
    struct State: Equatable {
        var appViewState: AppViewState = .loading(.initialData)
        var term: String = ""
        var meaning: String = ""
        var example: String = ""
        var exampleMeaning: String = ""
        var isArchived: Bool = false
        var errorMessage: String?
        var didArchiveAndClose: Bool = false
        var changeToken: Int = 0

        var canSave: Bool {
            !term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    enum Action {
        case onAppear
        case reload
        case updateTerm(String)
        case updateMeaning(String)
        case updateExample(String)
        case updateExampleMeaning(String)
        case saveChanges
        case archiveWord
        case unarchiveWord
        case clearError
    }

    @Published private(set) var state = State()

    private let repository: any AppRepository
    private let wordId: UUID
    private var didLoadOnAppear = false

    init(repository: any AppRepository, wordId: UUID) {
        self.repository = repository
        self.wordId = wordId
    }

    func send(_ action: Action) {
        switch action {
        case .onAppear:
            guard !didLoadOnAppear else { return }
            didLoadOnAppear = true
            loadWord(isInitialLoad: true)

        case .reload:
            loadWord(isInitialLoad: false)

        case let .updateTerm(value):
            state.term = value

        case let .updateMeaning(value):
            state.meaning = value

        case let .updateExample(value):
            state.example = value

        case let .updateExampleMeaning(value):
            state.exampleMeaning = value

        case .saveChanges:
            saveChanges()

        case .archiveWord:
            setArchived(true)

        case .unarchiveWord:
            setArchived(false)

        case .clearError:
            state.errorMessage = nil
        }
    }

    private func loadWord(isInitialLoad: Bool) {
        state.appViewState = .loading(isInitialLoad ? .initialData : .syncing)
        state.errorMessage = nil
        state.didArchiveAndClose = false

        do {
            guard let word = try repository.fetchWordItem(id: wordId) else {
                state.appViewState = .error(.dataCorruption)
                state.errorMessage = "Word not found."
                return
            }

            state.term = word.term
            state.meaning = word.meaning
            state.example = word.example
            state.exampleMeaning = word.exampleMeaning
            state.isArchived = word.isArchived
            state.appViewState = .normal
        } catch {
            state.appViewState = .error(.dataCorruption)
            state.errorMessage = error.localizedDescription
        }
    }

    private func saveChanges() {
        guard state.canSave else {
            state.errorMessage = "Term and meaning are required."
            return
        }

        do {
            guard let word = try repository.fetchWordItem(id: wordId) else {
                state.errorMessage = "Word not found."
                return
            }

            word.term = state.term.trimmingCharacters(in: .whitespacesAndNewlines)
            word.meaning = state.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
            word.example = state.example.trimmingCharacters(in: .whitespacesAndNewlines)
            word.exampleMeaning = state.exampleMeaning.trimmingCharacters(in: .whitespacesAndNewlines)
            word.updatedAt = .now

            try repository.upsertWordItem(word)
            state.changeToken += 1
            state.errorMessage = nil
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }

    private func setArchived(_ archived: Bool) {
        do {
            guard let word = try repository.fetchWordItem(id: wordId) else {
                state.errorMessage = "Word not found."
                return
            }

            word.isArchived = archived
            word.updatedAt = .now
            try repository.upsertWordItem(word)

            state.isArchived = archived
            state.changeToken += 1
            if archived {
                state.didArchiveAndClose = true
            }
            state.errorMessage = nil
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }
}
