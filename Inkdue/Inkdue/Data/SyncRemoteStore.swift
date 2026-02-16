import Foundation

protocol SyncRemoteStore: AnyObject {
    func pullSnapshot() async throws -> SyncPayload?
    func pushSnapshot(_ snapshot: SyncPayload) async throws
}

actor InMemorySyncRemoteStore: SyncRemoteStore {
    private var snapshot: SyncPayload?

    func pullSnapshot() async throws -> SyncPayload? {
        snapshot
    }

    func pushSnapshot(_ snapshot: SyncPayload) async throws {
        self.snapshot = snapshot
    }
}
