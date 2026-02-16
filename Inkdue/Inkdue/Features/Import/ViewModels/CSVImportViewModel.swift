import Foundation
import Combine

@MainActor
final class CSVImportViewModel: ObservableObject {
    struct State: Equatable {
        var rawText: String = ""
        var isLoading: Bool = false
        var preview: CSVImportPreview?
        var lastCommitResult: CSVImportCommitResult?
        var errorMessage: String?

        var canPreview: Bool {
            !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
        }

        var canConfirm: Bool {
            guard !isLoading else { return false }
            guard let preview else { return false }
            return !preview.importableRows.isEmpty
        }
    }

    enum Action {
        case updateRawText(String)
        case buildPreview
        case confirmImport
        case clearError
    }

    @Published private(set) var state = State()

    private let repository: any AppRepository
    private let buildPreviewUseCase: BuildCSVImportPreviewUseCase

    init(
        repository: any AppRepository,
        buildPreviewUseCase: BuildCSVImportPreviewUseCase? = nil
    ) {
        self.repository = repository
        self.buildPreviewUseCase = buildPreviewUseCase ?? BuildCSVImportPreviewUseCase()
    }

    func send(_ action: Action) {
        switch action {
        case let .updateRawText(text):
            state.rawText = text
            state.preview = nil
            state.lastCommitResult = nil
            state.errorMessage = nil

        case .buildPreview:
            buildPreview()

        case .confirmImport:
            confirmImport()

        case .clearError:
            state.errorMessage = nil
        }
    }

    private func buildPreview() {
        guard state.canPreview else { return }

        state.isLoading = true
        state.errorMessage = nil
        state.lastCommitResult = nil
        defer { state.isLoading = false }

        do {
            let existingItems = try repository.fetchWordItems(includeArchived: false)
            state.preview = try buildPreviewUseCase.execute(
                rawText: state.rawText,
                existingItems: existingItems
            )
        } catch {
            state.preview = nil
            state.errorMessage = error.localizedDescription
        }
    }

    private func confirmImport() {
        guard let preview = state.preview, state.canConfirm else { return }

        state.isLoading = true
        state.errorMessage = nil
        defer { state.isLoading = false }

        do {
            let result = try ConfirmCSVImportUseCase(repository: repository).execute(preview: preview)
            state.lastCommitResult = result
            state.rawText = ""
            state.preview = nil
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }
}
