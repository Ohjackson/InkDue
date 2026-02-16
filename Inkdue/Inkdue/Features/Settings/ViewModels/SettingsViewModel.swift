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
        var isSyncing: Bool = false
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
    private var didLoadOnAppear = false
    private var syncCooldownTask: Task<Void, Never>?
    private let syncCooldownSeconds = 5

    init(repository: any AppRepository) {
        self.repository = repository
        state.appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        state.buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        state.bundleIdentifier = Bundle.main.bundleIdentifier ?? "-"
    }

    deinit {
        syncCooldownTask?.cancel()
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
        state.isSyncing = true
        state.errorMessage = nil

        do {
            try repository.save()

            let now = Date()
            state.lastSyncAttemptAt = now
            state.syncStatusMessage = "Sync refresh requested. Continuing with local data."
            state.isSyncing = false

            startSyncCooldown(seconds: syncCooldownSeconds)
            loadSettings(isInitialLoad: false)
        } catch {
            state.isSyncing = false
            state.appViewState = .error(.sync)
            state.errorMessage = error.localizedDescription
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
}
