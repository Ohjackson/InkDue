import Foundation
import Combine
import Network

enum SyncTrigger: Equatable {
    case appForeground
    case manual
    case retry
}

enum SyncMode: Equatable {
    case idle
    case syncing
    case offline
    case failed
}

struct SyncSnapshot: Equatable {
    var mode: SyncMode = .idle
    var message: String = "Local mode"
    var lastAttemptAt: Date?
    var lastSuccessAt: Date?
    var retryCount: Int = 0
}

@MainActor
protocol AppSyncServiceProtocol: AnyObject {
    var currentSnapshot: SyncSnapshot { get }
    var snapshotPublisher: AnyPublisher<SyncSnapshot, Never> { get }
    func refresh(trigger: SyncTrigger) async -> SyncSnapshot
}

@MainActor
final class AppSyncService: ObservableObject, AppSyncServiceProtocol {
    @Published private var snapshot = SyncSnapshot()

    var currentSnapshot: SyncSnapshot {
        snapshot
    }

    var snapshotPublisher: AnyPublisher<SyncSnapshot, Never> {
        $snapshot.eraseToAnyPublisher()
    }

    private let repository: any AppRepository
    private let monitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "com.coban.Inkdue.sync.monitor")
    private var isNetworkReachable = true
    private var autoRetryTask: Task<Void, Never>?
    private let maxAutoRetryCount = 3

    init(repository: any AppRepository, monitor: NWPathMonitor = NWPathMonitor()) {
        self.repository = repository
        self.monitor = monitor
        configureNetworkMonitor()
    }

    deinit {
        autoRetryTask?.cancel()
        monitor.cancel()
    }

    func refresh(trigger: SyncTrigger) async -> SyncSnapshot {
        autoRetryTask?.cancel()
        snapshot.lastAttemptAt = .now
        snapshot.mode = .syncing
        snapshot.message = "Syncing..."

        guard isNetworkReachable else {
            snapshot.mode = .offline
            snapshot.message = "Offline. Continuing with local data."
            return snapshot
        }

        do {
            try repository.save()
            snapshot.mode = .idle
            snapshot.message = messageForSuccess(trigger: trigger)
            snapshot.lastSuccessAt = .now
            snapshot.retryCount = 0
        } catch {
            snapshot.mode = .failed
            snapshot.message = "Sync failed. Continuing with local data."
            snapshot.retryCount += 1
            scheduleAutoRetryIfNeeded()
        }

        return snapshot
    }

    private func configureNetworkMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.handleNetworkPathStatus(path.status)
            }
        }
        monitor.start(queue: monitorQueue)
    }

    private func handleNetworkPathStatus(_ status: NWPath.Status) {
        let reachable = status == .satisfied
        isNetworkReachable = reachable

        if !reachable {
            autoRetryTask?.cancel()
            snapshot.mode = .offline
            snapshot.message = "Offline. Continuing with local data."
            return
        }

        guard snapshot.mode == .offline || snapshot.mode == .failed else {
            return
        }

        autoRetryTask?.cancel()
        autoRetryTask = Task { [weak self] in
            guard let self else { return }
            _ = await self.refresh(trigger: .retry)
        }
    }

    private func scheduleAutoRetryIfNeeded() {
        guard snapshot.retryCount <= maxAutoRetryCount else {
            return
        }

        let delayByAttempt = [1, 2, 4]
        let index = min(max(snapshot.retryCount - 1, 0), delayByAttempt.count - 1)
        let seconds = delayByAttempt[index]
        let delay = UInt64(seconds) * 1_000_000_000

        autoRetryTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            _ = await self.refresh(trigger: .retry)
        }
    }

    private func messageForSuccess(trigger: SyncTrigger) -> String {
        switch trigger {
        case .appForeground:
            return "Synced on app resume."
        case .manual:
            return "Manual sync completed."
        case .retry:
            return "Retry sync completed."
        }
    }
}
