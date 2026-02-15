import Foundation
import SwiftData

final class SwiftDataAppRepository: AppRepository {
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContext = ModelContext(modelContainer)
    }

    func fetchOrCreateAppState() throws -> AppState {
        if let appState = try fetchAppState() {
            return appState
        }

        let appState = AppState()
        modelContext.insert(appState)
        try modelContext.save()
        return appState
    }

    func updateAppState(_ update: (AppState) -> Void) throws {
        let appState = try fetchOrCreateAppState()
        update(appState)
        appState.updatedAt = .now
        try modelContext.save()
    }

    func fetchWordItems(includeArchived: Bool) throws -> [WordItem] {
        if includeArchived {
            let descriptor = FetchDescriptor<WordItem>(
                sortBy: [SortDescriptor(\.createdAt)]
            )
            return try modelContext.fetch(descriptor)
        }

        let descriptor = FetchDescriptor<WordItem>(
            predicate: #Predicate<WordItem> { !$0.isArchived },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchWordItem(id: UUID) throws -> WordItem? {
        var descriptor = FetchDescriptor<WordItem>(
            predicate: #Predicate<WordItem> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func upsertWordItem(_ item: WordItem) throws {
        if let storedItem = try fetchWordItem(id: item.id) {
            storedItem.term = item.term
            storedItem.meaning = item.meaning
            storedItem.example = item.example
            storedItem.exampleMeaning = item.exampleMeaning
            storedItem.isArchived = item.isArchived
            storedItem.updatedAt = .now
        } else {
            item.updatedAt = .now
            modelContext.insert(item)
        }
        try modelContext.save()
    }

    func deleteWordItem(id: UUID) throws {
        guard let item = try fetchWordItem(id: id) else {
            return
        }

        modelContext.delete(item)
        try modelContext.save()
    }

    func fetchWordSRS(wordId: UUID) throws -> WordSRS? {
        var descriptor = FetchDescriptor<WordSRS>(
            predicate: #Predicate<WordSRS> { $0.wordId == wordId }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func fetchWordSRSList() throws -> [WordSRS] {
        let descriptor = FetchDescriptor<WordSRS>(
            sortBy: [SortDescriptor(\.updatedAt)]
        )
        return try modelContext.fetch(descriptor)
    }

    func upsertWordSRS(_ srs: WordSRS) throws {
        if let storedSRS = try fetchWordSRS(wordId: srs.wordId) {
            storedSRS.step = WordSRS.clampStep(srs.step)
            storedSRS.introducedDayIndex = srs.introducedDayIndex
            storedSRS.firstTestPlannedDayIndex = srs.firstTestPlannedDayIndex
            storedSRS.firstTestPlannedPhase = srs.firstTestPlannedPhase
            storedSRS.nextReviewDayIndex = srs.nextReviewDayIndex
            storedSRS.lastReviewedDayIndex = srs.lastReviewedDayIndex
            storedSRS.lastReviewedPhase = srs.lastReviewedPhase
            storedSRS.lastResult = srs.lastResult
            storedSRS.recoveryDueDayIndex = srs.recoveryDueDayIndex
            storedSRS.lastAgainAt = srs.lastAgainAt
            storedSRS.updatedAt = .now
        } else {
            srs.step = WordSRS.clampStep(srs.step)
            srs.updatedAt = .now
            modelContext.insert(srs)
        }

        try modelContext.save()
    }

    func addReviewEvent(_ event: ReviewEvent) throws {
        modelContext.insert(event)
        try modelContext.save()
    }

    func fetchReviewEvents(studyDayIndex: Int?) throws -> [ReviewEvent] {
        if let studyDayIndex {
            let descriptor = FetchDescriptor<ReviewEvent>(
                predicate: #Predicate<ReviewEvent> { $0.studyDayIndex == studyDayIndex },
                sortBy: [SortDescriptor(\.createdAt)]
            )
            return try modelContext.fetch(descriptor)
        }

        let descriptor = FetchDescriptor<ReviewEvent>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try modelContext.fetch(descriptor)
    }

    func save() throws {
        try modelContext.save()
    }

    private func fetchAppState() throws -> AppState? {
        let singletonID = AppState.singletonID
        var descriptor = FetchDescriptor<AppState>(
            predicate: #Predicate<AppState> { $0.id == singletonID }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
