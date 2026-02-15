import Foundation

struct BuildCSVImportPreviewUseCase {
    private let parser: CSVImportParser

    init(parser: CSVImportParser = CSVImportParser()) {
        self.parser = parser
    }

    func execute(
        rawText: String,
        existingItems: [WordItem]
    ) throws -> CSVImportPreview {
        let parseResult = try parser.parse(rawText)
        var existingKeys = Set(
            existingItems.map { makeDuplicateKey(term: $0.term, meaning: $0.meaning) }
        )
        var importableRows: [CSVImportRow] = []
        var duplicateRows: [CSVImportDuplicateRow] = []

        for row in parseResult.validRows {
            let key = makeDuplicateKey(term: row.term, meaning: row.meaning)
            if existingKeys.contains(key) {
                duplicateRows.append(
                    CSVImportDuplicateRow(term: row.term, meaning: row.meaning)
                )
                continue
            }

            existingKeys.insert(key)
            importableRows.append(row)
        }

        return CSVImportPreview(
            importableRows: importableRows,
            duplicateRows: duplicateRows,
            invalidRows: parseResult.invalidRows,
            ignoredColumns: parseResult.ignoredColumns
        )
    }

    private func makeDuplicateKey(term: String, meaning: String) -> String {
        "\(normalize(term))::\(normalize(meaning))"
    }

    private func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
