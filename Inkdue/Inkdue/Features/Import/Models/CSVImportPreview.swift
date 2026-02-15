import Foundation

struct CSVImportDuplicateRow: Equatable {
    let term: String
    let meaning: String
}

struct CSVImportPreviewSummary: Equatable {
    let addedCount: Int
    let skippedDuplicateCount: Int
    let skippedInvalidCount: Int
}

struct CSVImportPreview: Equatable {
    let importableRows: [CSVImportRow]
    let duplicateRows: [CSVImportDuplicateRow]
    let invalidRows: [CSVInvalidRow]
    let ignoredColumns: [String]

    var summary: CSVImportPreviewSummary {
        CSVImportPreviewSummary(
            addedCount: importableRows.count,
            skippedDuplicateCount: duplicateRows.count,
            skippedInvalidCount: invalidRows.count
        )
    }
}
