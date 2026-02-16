import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    struct State: Equatable {
        var appViewState: AppViewState = .loading(.initialData)
        var currentStudyDayIndex: Int = 0
        var currentPhase: StudyPhase = .morning
        var activeWordCount: Int = 0
        var archivedWordCount: Int = 0
        var todayReviewCount: Int = 0
        var syncStatusMessage: String = "Local mode"
        var lastSyncAttemptAt: Date?
        var lastSyncSuccessAt: Date?
        var isSyncing: Bool = false
        var syncRetryCount: Int = 0
        var syncCooldownRemainingSeconds: Int = 0
        var errorMessage: String?
        var appVersion: String = "-"
        var buildNumber: String = "-"
        var bundleIdentifier: String = "-"

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

        var canRunManualSync: Bool {
            !isSyncing && syncCooldownRemainingSeconds == 0
        }

        var manualSyncButtonTitle: String {
            if isSyncing {
                return "Refreshing..."
            }
            if syncCooldownRemainingSeconds > 0 {
                return "Retry in \(syncCooldownRemainingSeconds)s"
            }
            return "Refresh Sync"
        }
    }

    enum Action {
        case onAppear
        case reload
        case runManualSync
        case clearError
    }

    @Published private(set) var state = State()

    private let repository: any AppRepository
    private let syncService: any AppSyncServiceProtocol
    private var didLoadOnAppear = false
    private var syncCooldownTask: Task<Void, Never>?
    private var syncTask: Task<Void, Never>?
    private let syncCooldownSeconds = 5
    private var cancellables: Set<AnyCancellable> = []

    init(
        repository: any AppRepository,
        syncService: any AppSyncServiceProtocol
    ) {
        self.repository = repository
        self.syncService = syncService
        state.appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        state.buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        state.bundleIdentifier = Bundle.main.bundleIdentifier ?? "-"
        bindSyncSnapshot()
    }

    deinit {
        syncCooldownTask?.cancel()
        syncTask?.cancel()
    }

    func send(_ action: Action) {
        switch action {
        case .onAppear:
            guard !didLoadOnAppear else { return }
            didLoadOnAppear = true
            loadSettings(isInitialLoad: true)

        case .reload:
            loadSettings(isInitialLoad: false)

        case .runManualSync:
            runManualSync()

        case .clearError:
            state.errorMessage = nil
        }
    }

    private func loadSettings(isInitialLoad: Bool) {
        state.appViewState = .loading(isInitialLoad ? .initialData : .syncing)
        state.errorMessage = nil

        do {
            let appState = try repository.fetchOrCreateAppState()
            let words = try repository.fetchWordItems(includeArchived: true)
            let todayEvents = try repository.fetchReviewEvents(studyDayIndex: appState.currentStudyDayIndex)

            state.currentStudyDayIndex = appState.currentStudyDayIndex
            state.currentPhase = appState.currentPhase
            state.activeWordCount = words.filter { !$0.isArchived }.count
            state.archivedWordCount = words.filter(\.isArchived).count
            state.todayReviewCount = todayEvents.count

            state.appViewState = words.isEmpty ? .empty(.noWord) : .normal
        } catch {
            state.appViewState = .error(.dataCorruption)
            state.errorMessage = error.localizedDescription
        }
    }

    private func runManualSync() {
        guard state.canRunManualSync else { return }
        state.errorMessage = nil
        startSyncCooldown(seconds: syncCooldownSeconds)

        syncTask?.cancel()
        syncTask = Task { [weak self] in
            guard let self else { return }
            _ = await self.syncService.refresh(trigger: .manual)
            self.loadSettings(isInitialLoad: false)
        }
    }

    private func startSyncCooldown(seconds: Int) {
        syncCooldownTask?.cancel()
        guard seconds > 0 else {
            state.syncCooldownRemainingSeconds = 0
            return
        }

        state.syncCooldownRemainingSeconds = seconds

        syncCooldownTask = Task { [weak self] in
            guard let self else { return }
            var remaining = seconds

            while remaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                remaining -= 1

                await MainActor.run {
                    self.state.syncCooldownRemainingSeconds = remaining
                }
            }
        }
    }

    private func bindSyncSnapshot() {
        updateSyncState(from: syncService.currentSnapshot)

        syncService.snapshotPublisher
            .sink { [weak self] snapshot in
                guard let self else { return }
                self.updateSyncState(from: snapshot)
            }
            .store(in: &cancellables)
    }

    private func updateSyncState(from snapshot: SyncSnapshot) {
        state.isSyncing = snapshot.mode == .syncing
        state.syncStatusMessage = snapshot.message
        state.lastSyncAttemptAt = snapshot.lastAttemptAt
        state.lastSyncSuccessAt = snapshot.lastSuccessAt
        state.syncRetryCount = snapshot.retryCount
    }
}
