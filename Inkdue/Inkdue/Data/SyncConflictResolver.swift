import Foundation

struct AppStateSyncRecord: Equatable {
    let currentStudyDayIndex: Int
    let currentPhase: StudyPhase
    let lastOpenedAt: Date
    let updatedAt: Date
}

struct WordSRSSyncRecord: Equatable, Identifiable {
    let wordId: UUID
    let step: Int
    let introducedDayIndex: Int
    let firstTestPlannedDayIndex: Int
    let firstTestPlannedPhase: StudyPhase
    let nextReviewDayIndex: Int
    let lastReviewedDayIndex: Int?
    let lastReviewedPhase: StudyPhase?
    let lastResult: ReviewResult?
    let recoveryDueDayIndex: Int?
    let lastAgainAt: Date?
    let updatedAt: Date

    var id: UUID { wordId }
}

struct SyncPayload: Equatable {
    let appState: AppStateSyncRecord
    let wordSRSRecords: [WordSRSSyncRecord]
}

enum SyncConflictResolver {
    private static let intervalTable = [1, 1, 2, 4, 7, 15, 30, 60]

    static func resolve(local: SyncPayload, remote: SyncPayload?) -> SyncPayload {
        guard let remote else {
            return local
        }

        let resolvedAppState = resolveAppState(local: local.appState, remote: remote.appState)

        let localByWordID = Dictionary(uniqueKeysWithValues: local.wordSRSRecords.map { ($0.wordId, $0) })
        let remoteByWordID = Dictionary(uniqueKeysWithValues: remote.wordSRSRecords.map { ($0.wordId, $0) })
        let allWordIDs = Set(localByWordID.keys).union(remoteByWordID.keys)

        let resolvedWordSRS = allWordIDs.compactMap { wordID -> WordSRSSyncRecord? in
            switch (localByWordID[wordID], remoteByWordID[wordID]) {
            case let (local?, remote?):
                return resolveWordSRS(local: local, remote: remote)
            case let (local?, nil):
                return sanitizeWordSRS(local)
            case let (nil, remote?):
                return sanitizeWordSRS(remote)
            case (nil, nil):
                return nil
            }
        }
        .sorted { lhs, rhs in
            lhs.wordId.uuidString < rhs.wordId.uuidString
        }

        return SyncPayload(
            appState: resolvedAppState,
            wordSRSRecords: resolvedWordSRS
        )
    }

    static func resolveAppState(
        local: AppStateSyncRecord,
        remote: AppStateSyncRecord
    ) -> AppStateSyncRecord {
        if local.currentStudyDayIndex != remote.currentStudyDayIndex {
            return local.currentStudyDayIndex > remote.currentStudyDayIndex ? local : remote
        }

        let localPhaseRank = phaseRank(local.currentPhase)
        let remotePhaseRank = phaseRank(remote.currentPhase)
        if localPhaseRank != remotePhaseRank {
            return localPhaseRank > remotePhaseRank ? local : remote
        }

        if local.updatedAt != remote.updatedAt {
            return local.updatedAt > remote.updatedAt ? local : remote
        }

        return local
    }

    static func resolveWordSRS(
        local: WordSRSSyncRecord,
        remote: WordSRSSyncRecord
    ) -> WordSRSSyncRecord {
        let localReviewedDay = local.lastReviewedDayIndex ?? Int.min
        let remoteReviewedDay = remote.lastReviewedDayIndex ?? Int.min

        if localReviewedDay != remoteReviewedDay {
            return sanitizeWordSRS(localReviewedDay > remoteReviewedDay ? local : remote)
        }

        if local.updatedAt != remote.updatedAt {
            return sanitizeWordSRS(local.updatedAt > remote.updatedAt ? local : remote)
        }

        return sanitizeWordSRS(local)
    }

    private static func sanitizeWordSRS(_ record: WordSRSSyncRecord) -> WordSRSSyncRecord {
        let clampedStep = WordSRS.clampStep(record.step)
        let safeIntroducedDay = max(0, record.introducedDayIndex)
        let safeFirstTestDay = max(record.firstTestPlannedDayIndex, safeIntroducedDay)
        let anchorDay = max(record.lastReviewedDayIndex ?? safeIntroducedDay, safeIntroducedDay)
        let minimumNextReviewDay = anchorDay + interval(for: clampedStep)
        let safeNextReviewDay = max(record.nextReviewDayIndex, minimumNextReviewDay)
        let safeRecoveryDay: Int? = {
            guard record.lastResult == .again else { return nil }
            return max(record.recoveryDueDayIndex ?? anchorDay + 1, anchorDay + 1)
        }()

        return WordSRSSyncRecord(
            wordId: record.wordId,
            step: clampedStep,
            introducedDayIndex: safeIntroducedDay,
            firstTestPlannedDayIndex: safeFirstTestDay,
            firstTestPlannedPhase: record.firstTestPlannedPhase,
            nextReviewDayIndex: safeNextReviewDay,
            lastReviewedDayIndex: record.lastReviewedDayIndex,
            lastReviewedPhase: record.lastReviewedPhase,
            lastResult: record.lastResult,
            recoveryDueDayIndex: safeRecoveryDay,
            lastAgainAt: record.lastAgainAt,
            updatedAt: record.updatedAt
        )
    }

    private static func interval(for step: Int) -> Int {
        let clampedStep = WordSRS.clampStep(step)
        return intervalTable[clampedStep]
    }

    private static func phaseRank(_ phase: StudyPhase) -> Int {
        switch phase {
        case .morning:
            return 0
        case .lunch:
            return 1
        case .evening:
            return 2
        }
    }
}
