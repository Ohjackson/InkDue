import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    struct State: Equatable {
        var appViewState: AppViewState = .loading(.initialData)
        var currentStudyDayIndex: Int = 0
        var currentPhase: StudyPhase = .morning
        var totalWordCount: Int = 0
        var morningQueueCount: Int = 0
        var morningFailedCount: Int = 0
        var eveningQueueCount: Int = 0
        var eveningNewCount: Int = 0
        var isImportSheetPresented: Bool = false
        var syncBannerContent: AppBannerContent?

        var phaseTitle: String {
            switch currentPhase {
            case .morning:
                return "Morning"
            case .lunch:
                return "Lunch"
            case .evening:
                return "Evening"
            }
        }

        var canStartMorningSession: Bool {
            currentPhase == .morning
        }

        var canStartLunchSession: Bool {
            currentPhase == .lunch
        }

        var canStartEveningSession: Bool {
            currentPhase == .evening
        }

        var canOpenWordList: Bool {
            true
        }

        var canOpenSettings: Bool {
            true
        }
    }

    enum Action {
        case onAppear
        case sceneDidBecomeActive
        case reload
        case retrySync
        case tapImport
        case dismissImport
    }

    @Published private(set) var state = State()

    private let repository: any AppRepository
    private let syncService: any AppSyncServiceProtocol
    private var didLoadOnAppear = false
    private var syncTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []

    init(
        repository: any AppRepository,
        syncService: any AppSyncServiceProtocol
    ) {
        self.repository = repository
        self.syncService = syncService
        bindSyncSnapshot()
    }

    deinit {
        syncTask?.cancel()
    }

    func send(_ action: Action) {
        switch action {
        case .onAppear:
            guard !didLoadOnAppear else { return }
            didLoadOnAppear = true
            loadHome(isInitialLoad: true)
            triggerSync(trigger: .appForeground)

        case .sceneDidBecomeActive:
            triggerSync(trigger: .appForeground)

        case .reload:
            loadHome(isInitialLoad: false)

        case .retrySync:
            triggerSync(trigger: .retry)

        case .tapImport:
            state.isImportSheetPresented = true

        case .dismissImport:
            state.isImportSheetPresented = false
            loadHome(isInitialLoad: false)
        }
    }

    func makeCSVImportViewModel() -> CSVImportViewModel {
        CSVImportViewModel(repository: repository)
    }

    func makeMorningSessionViewModel() -> MorningSessionViewModel {
        MorningSessionViewModel(repository: repository)
    }

    func makeLunchSessionViewModel() -> LunchSessionViewModel {
        LunchSessionViewModel(repository: repository)
    }

    func makeEveningSessionViewModel() -> EveningSessionViewModel {
        EveningSessionViewModel(repository: repository)
    }

    func makeWordListViewModel() -> WordListViewModel {
        WordListViewModel(repository: repository)
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            repository: repository,
            syncService: syncService
        )
    }

    private func loadHome(isInitialLoad: Bool) {
        state.appViewState = .loading(isInitialLoad ? .initialData : .syncing)

        do {
            let appState = try repository.fetchOrCreateAppState()
            let words = try repository.fetchWordItems(includeArchived: false)
            let morningQueue = try BuildMorningQueueUseCase(repository: repository)
                .execute(currentStudyDayIndex: appState.currentStudyDayIndex)
            let eveningQueue = try BuildEveningQueueUseCase(repository: repository)
                .execute(currentStudyDayIndex: appState.currentStudyDayIndex)

            state.currentStudyDayIndex = appState.currentStudyDayIndex
            state.currentPhase = appState.currentPhase
            state.totalWordCount = words.count
            state.morningQueueCount = morningQueue.count
            state.morningFailedCount = morningQueue.filter { $0.source == .failedRecovery }.count
            state.eveningQueueCount = eveningQueue.count
            state.eveningNewCount = eveningQueue.filter { $0.source == .new }.count

            guard !words.isEmpty else {
                state.appViewState = .empty(.noWord)
                return
            }

            if isCurrentPhaseQueueEmpty(
                phase: appState.currentPhase,
                morningQueueCount: morningQueue.count,
                eveningQueueCount: eveningQueue.count
            ) {
                state.appViewState = .empty(.noQueue)
            } else {
                state.appViewState = .normal
            }
        } catch {
            state.appViewState = .error(.dataCorruption)
        }
    }

    private func isCurrentPhaseQueueEmpty(
        phase: StudyPhase,
        morningQueueCount: Int,
        eveningQueueCount: Int
    ) -> Bool {
        switch phase {
        case .morning:
            return morningQueueCount == 0
        case .lunch:
            return false
        case .evening:
            return eveningQueueCount == 0
        }
    }

    private func bindSyncSnapshot() {
        state.syncBannerContent = makeSyncBannerContent(from: syncService.currentSnapshot)

        syncService.snapshotPublisher
            .sink { [weak self] snapshot in
                guard let self else { return }
                self.state.syncBannerContent = self.makeSyncBannerContent(from: snapshot)
            }
            .store(in: &cancellables)
    }

    private func triggerSync(trigger: SyncTrigger) {
        syncTask?.cancel()
        syncTask = Task { [weak self] in
            guard let self else { return }
            _ = await self.syncService.refresh(trigger: trigger)
        }
    }

    private func makeSyncBannerContent(from snapshot: SyncSnapshot) -> AppBannerContent? {
        switch snapshot.mode {
        case .idle:
            return nil

        case .syncing:
            return AppBannerContent(
                style: .info,
                title: "Syncing",
                message: "Checking updates. Local study stays available.",
                actionTitle: nil,
                isBlocking: false
            )

        case .offline:
            return AppBannerContent(
                style: .warning,
                title: "Offline mode",
                message: "Network is unavailable. Continue with local data.",
                actionTitle: "Retry",
                isBlocking: false
            )

        case .failed:
            return AppBannerContent(
                style: .warning,
                title: "Sync failed",
                message: "Local progress is safe. Retry when connection is stable.",
                actionTitle: "Retry",
                isBlocking: false
            )
        }
    }
}
