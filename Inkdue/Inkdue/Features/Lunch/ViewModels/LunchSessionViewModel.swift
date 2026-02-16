import Foundation
import Combine

@MainActor
final class LunchSessionViewModel: ObservableObject {
    struct State: Equatable {
        var appViewState: AppViewState = .loading(.initialData)
        var currentStudyDayIndex: Int = 0
        var currentPhase: StudyPhase = .morning
        var totalWordCount: Int = 0
        var projectedEveningQueueCount: Int = 0
        var projectedEveningNewCount: Int = 0
        var isImportSheetPresented: Bool = false
        var isAdvancingPhase: Bool = false
        var didCompleteSession: Bool = false
        var errorMessage: String?

        var canOpenImport: Bool {
            !isAdvancingPhase
        }

        var canCompleteSession: Bool {
            !isAdvancingPhase && currentPhase == .lunch
        }
    }

    enum Action {
        case onAppear
        case reload
        case tapImport
        case dismissImport
        case completeSession
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
            loadLunch(isInitialLoad: true)

        case .reload:
            loadLunch(isInitialLoad: false)

        case .tapImport:
            guard state.canOpenImport else { return }
            state.isImportSheetPresented = true

        case .dismissImport:
            state.isImportSheetPresented = false
            loadLunch(isInitialLoad: false)

        case .completeSession:
            completeSession()

        case .clearError:
            state.errorMessage = nil
        }
    }

    func makeCSVImportViewModel() -> CSVImportViewModel {
        CSVImportViewModel(repository: repository)
    }

    private func loadLunch(isInitialLoad: Bool) {
        state.appViewState = .loading(isInitialLoad ? .initialData : .syncing)
        state.errorMessage = nil
        state.didCompleteSession = false

        do {
            let appState = try repository.fetchOrCreateAppState()
            let words = try repository.fetchWordItems(includeArchived: false)
            let eveningQueue = try BuildEveningQueueUseCase(repository: repository)
                .execute(currentStudyDayIndex: appState.currentStudyDayIndex)

            state.currentStudyDayIndex = appState.currentStudyDayIndex
            state.currentPhase = appState.currentPhase
            state.totalWordCount = words.count
            state.projectedEveningQueueCount = eveningQueue.count
            state.projectedEveningNewCount = eveningQueue.filter { $0.source == .new }.count

            state.appViewState = words.isEmpty ? .empty(.noWord) : .normal
        } catch {
            state.appViewState = .error(.dataCorruption)
            state.errorMessage = error.localizedDescription
        }
    }

    private func completeSession() {
        guard state.canCompleteSession else { return }
        state.isAdvancingPhase = true
        defer { state.isAdvancingPhase = false }

        do {
            let appState = try repository.fetchOrCreateAppState()
            guard appState.currentPhase == .lunch else {
                state.errorMessage = "Current phase is not lunch."
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
