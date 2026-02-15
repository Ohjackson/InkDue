import Foundation

enum PolicyInvariantChecks {
    static func runAll() {
        verifyEveningQueueCap()
        verifyAgainRecoveryRule()
        verifyStudyDayAdvanceRule()
    }

    private static func verifyEveningQueueCap() {
        let currentStudyDayIndex = 10
        let repository = InMemoryAppRepository()

        for index in 0..<80 {
            let id = UUID()
            let word = WordItem(
                id: id,
                term: "term-\(index)",
                meaning: "meaning-\(index)",
                example: "example-\(index)",
                exampleMeaning: "example-meaning-\(index)"
            )
            try? repository.upsertWordItem(word)

            let nextReview: Int
            if index < 55 {
                nextReview = currentStudyDayIndex - 1 // backlog
            } else if index < 70 {
                nextReview = currentStudyDayIndex // ready
            } else {
                nextReview = currentStudyDayIndex + 1 // not due
            }

            let srs = WordSRS(
                wordId: id,
                step: 2,
                introducedDayIndex: currentStudyDayIndex,
                firstTestPlannedDayIndex: currentStudyDayIndex,
                firstTestPlannedPhase: .evening,
                nextReviewDayIndex: nextReview,
                lastReviewedDayIndex: index < 70 ? currentStudyDayIndex - 1 : nil
            )
            try? repository.upsertWordSRS(srs)
        }

        let useCase = BuildEveningQueueUseCase(
            repository: repository,
            queueCap: 50,
            maxNewPerStudyDay: 10
        )

        guard let queue = try? useCase.execute(currentStudyDayIndex: currentStudyDayIndex) else {
            preconditionFailure("Policy check failed: evening queue build should not throw.")
        }

        precondition(queue.count == 50, "Policy check failed: evening queue must be capped at 50.")
        precondition(
            queue.allSatisfy { $0.source == .backlog },
            "Policy check failed: backlog must fill queue before ready/new."
        )
    }

    private static func verifyAgainRecoveryRule() {
        let now = Date(timeIntervalSince1970: 1_735_000_000)
        let useCase = ApplyReviewResultUseCase()
        let srs = WordSRS(
            wordId: UUID(),
            step: 3,
            introducedDayIndex: 0,
            firstTestPlannedDayIndex: 0,
            firstTestPlannedPhase: .evening,
            nextReviewDayIndex: 3
        )

        useCase.execute(
            on: srs,
            result: .again,
            currentStudyDayIndex: 7,
            currentPhase: .evening,
            now: now
        )

        precondition(srs.step == 2, "Policy check failed: Again must decrease step by 1.")
        precondition(
            srs.recoveryDueDayIndex == 8,
            "Policy check failed: Again must schedule recovery on next study day."
        )
        precondition(
            srs.recoveryDueDayIndex != 7,
            "Policy check failed: Again must not reappear immediately in same day."
        )
        precondition(
            srs.lastAgainAt == now,
            "Policy check failed: Again event timestamp should be stored."
        )
    }

    private static func verifyStudyDayAdvanceRule() {
        let useCase = AdvancePhaseUseCase()

        let morningToLunch = useCase.nextState(from: .morning, studyDayIndex: 4)
        precondition(
            morningToLunch.phase == .lunch && morningToLunch.studyDayIndex == 4 && !morningToLunch.didAdvanceStudyDay,
            "Policy check failed: Morning completion must move to lunch without day advance."
        )

        let lunchToEvening = useCase.nextState(from: .lunch, studyDayIndex: 4)
        precondition(
            lunchToEvening.phase == .evening && lunchToEvening.studyDayIndex == 4 && !lunchToEvening.didAdvanceStudyDay,
            "Policy check failed: Lunch completion must move to evening without day advance."
        )

        let eveningToMorning = useCase.nextState(from: .evening, studyDayIndex: 4)
        precondition(
            eveningToMorning.phase == .morning && eveningToMorning.studyDayIndex == 5 && eveningToMorning.didAdvanceStudyDay,
            "Policy check failed: Study day must advance only on evening completion."
        )
    }
}

private final class InMemoryAppRepository: AppRepository {
    private var appState = AppState()
    private var wordItemsByID: [UUID: WordItem] = [:]
    private var wordSRSByWordID: [UUID: WordSRS] = [:]
    private var reviewEvents: [ReviewEvent] = []

    func fetchOrCreateAppState() throws -> AppState {
        appState
    }

    func updateAppState(_ update: (AppState) -> Void) throws {
        update(appState)
    }

    func fetchWordItems(includeArchived: Bool) throws -> [WordItem] {
        let words = Array(wordItemsByID.values)
        if includeArchived {
            return words
        }
        return words.filter { !$0.isArchived }
    }

    func fetchWordItem(id: UUID) throws -> WordItem? {
        wordItemsByID[id]
    }

    func upsertWordItem(_ item: WordItem) throws {
        wordItemsByID[item.id] = item
    }

    func deleteWordItem(id: UUID) throws {
        wordItemsByID[id] = nil
        wordSRSByWordID[id] = nil
    }

    func fetchWordSRS(wordId: UUID) throws -> WordSRS? {
        wordSRSByWordID[wordId]
    }

    func fetchWordSRSList() throws -> [WordSRS] {
        Array(wordSRSByWordID.values)
    }

    func upsertWordSRS(_ srs: WordSRS) throws {
        wordSRSByWordID[srs.wordId] = srs
    }

    func addReviewEvent(_ event: ReviewEvent) throws {
        reviewEvents.append(event)
    }

    func fetchReviewEvents(studyDayIndex: Int?) throws -> [ReviewEvent] {
        guard let studyDayIndex else { return reviewEvents }
        return reviewEvents.filter { $0.studyDayIndex == studyDayIndex }
    }

    func save() throws {}
}
