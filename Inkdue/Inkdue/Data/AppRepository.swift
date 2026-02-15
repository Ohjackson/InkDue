import Foundation

protocol AppRepository {
    func fetchOrCreateAppState() throws -> AppState
    func updateAppState(_ update: (AppState) -> Void) throws

    func fetchWordItems(includeArchived: Bool) throws -> [WordItem]
    func fetchWordItem(id: UUID) throws -> WordItem?
    func upsertWordItem(_ item: WordItem) throws
    func deleteWordItem(id: UUID) throws

    func fetchWordSRS(wordId: UUID) throws -> WordSRS?
    func upsertWordSRS(_ srs: WordSRS) throws

    func addReviewEvent(_ event: ReviewEvent) throws
    func fetchReviewEvents(studyDayIndex: Int?) throws -> [ReviewEvent]

    func save() throws
}
