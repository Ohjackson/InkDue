import Foundation

struct CSVImportCommitResult: Equatable {
    let addedCount: Int
    let skippedDuplicateCount: Int
    let skippedInvalidCount: Int
}

struct ConfirmCSVImportUseCase {
    private let repository: any AppRepository

    init(repository: any AppRepository) {
        self.repository = repository
    }

    func execute(preview: CSVImportPreview) throws -> CSVImportCommitResult {
        let appState = try repository.fetchOrCreateAppState()
        let currentStudyDayIndex = appState.currentStudyDayIndex

        for row in preview.importableRows {
            let wordItem = WordItem(
                term: row.term,
                meaning: row.meaning,
                example: row.example,
                exampleMeaning: row.exampleMeadning
            )
            try repository.upsertWordItem(wordItem)

            let wordSRS = WordSRS(
                wordId: wordItem.id,
                step: WordSRS.minStep,
                introducedDayIndex: currentStudyDayIndex,
                firstTestPlannedDayIndex: currentStudyDayIndex,
                firstTestPlannedPhase: .evening,
                nextReviewDayIndex: currentStudyDayIndex
            )
            try repository.upsertWordSRS(wordSRS)
        }

        return CSVImportCommitResult(
            addedCount: preview.summary.addedCount,
            skippedDuplicateCount: preview.summary.skippedDuplicateCount,
            skippedInvalidCount: preview.summary.skippedInvalidCount
        )
    }
}
