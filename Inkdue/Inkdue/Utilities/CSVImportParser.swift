import Foundation

struct CSVImportRow: Equatable {
    let term: String
    let meaning: String
    let example: String
    let exampleMeadning: String
}

struct CSVInvalidRow: Equatable {
    enum Reason: Equatable {
        case missingRequiredValues([String])
    }

    let lineNumber: Int
    let values: [String]
    let reason: Reason
}

struct CSVParseResult: Equatable {
    let validRows: [CSVImportRow]
    let invalidRows: [CSVInvalidRow]
    let ignoredColumns: [String]
}

enum CSVParseError: LocalizedError, Equatable {
    case emptyInput
    case missingHeader
    case missingRequiredHeaders([String])
    case unclosedQuote

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "CSV input is empty."
        case .missingHeader:
            return "CSV header is missing."
        case let .missingRequiredHeaders(headers):
            return "Missing required headers: \(headers.joined(separator: ", "))"
        case .unclosedQuote:
            return "CSV contains an unclosed quote."
        }
    }
}

struct CSVImportParser {
    private enum RequiredHeader: String, CaseIterable {
        case term
        case meaning
        case example
        case exampleMeadning = "example_meadning"

        var acceptedNames: [String] {
            switch self {
            case .exampleMeadning:
                return ["example_meadning", "example_meaning"]
            default:
                return [rawValue]
            }
        }
    }

    private let delimiter: Character

    init(delimiter: Character = ",") {
        self.delimiter = delimiter
    }

    func parse(_ rawText: String) throws -> CSVParseResult {
        let trimmedInput = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            throw CSVParseError.emptyInput
        }

        let records = try parseRecords(from: rawText)
        guard let headerRow = records.first else {
            throw CSVParseError.missingHeader
        }

        let normalizedHeaders = headerRow.map(normalizeHeader)
        guard normalizedHeaders.contains(where: { !$0.isEmpty }) else {
            throw CSVParseError.missingHeader
        }

        let headerIndexByKey = try buildHeaderIndex(from: normalizedHeaders)

        let requiredIndices = Set(headerIndexByKey.values)
        let ignoredColumns: [String] = headerRow.enumerated().compactMap { element -> String? in
            guard !requiredIndices.contains(element.offset) else { return nil }
            let trimmed = element.element.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        var validRows: [CSVImportRow] = []
        var invalidRows: [CSVInvalidRow] = []

        for (index, record) in records.dropFirst().enumerated() {
            if record.allSatisfy({ trimmedValue($0).isEmpty }) {
                continue
            }

            let term = value(in: record, at: headerIndexByKey[.term])
            let meaning = value(in: record, at: headerIndexByKey[.meaning])
            let example = value(in: record, at: headerIndexByKey[.example])
            let exampleMeadning = value(in: record, at: headerIndexByKey[.exampleMeadning])

            var missingValues: [String] = []
            if term.isEmpty { missingValues.append(RequiredHeader.term.rawValue) }
            if meaning.isEmpty { missingValues.append(RequiredHeader.meaning.rawValue) }
            if example.isEmpty { missingValues.append(RequiredHeader.example.rawValue) }
            if exampleMeadning.isEmpty { missingValues.append(RequiredHeader.exampleMeadning.rawValue) }

            if !missingValues.isEmpty {
                invalidRows.append(
                    CSVInvalidRow(
                        lineNumber: index + 2,
                        values: record.map(trimmedValue),
                        reason: .missingRequiredValues(missingValues)
                    )
                )
                continue
            }

            validRows.append(
                CSVImportRow(
                    term: term,
                    meaning: meaning,
                    example: example,
                    exampleMeadning: exampleMeadning
                )
            )
        }

        return CSVParseResult(
            validRows: validRows,
            invalidRows: invalidRows,
            ignoredColumns: ignoredColumns
        )
    }

    private func buildHeaderIndex(
        from normalizedHeaders: [String]
    ) throws -> [RequiredHeader: Int] {
        var headerIndexByKey: [RequiredHeader: Int] = [:]
        var missingHeaders: [String] = []

        for key in RequiredHeader.allCases {
            if let index = normalizedHeaders.firstIndex(where: { key.acceptedNames.contains($0) }) {
                headerIndexByKey[key] = index
            } else {
                missingHeaders.append(key.rawValue)
            }
        }

        if !missingHeaders.isEmpty {
            throw CSVParseError.missingRequiredHeaders(missingHeaders)
        }

        return headerIndexByKey
    }

    private func parseRecords(from rawText: String) throws -> [[String]] {
        var records: [[String]] = []
        var currentRecord: [String] = []
        var currentField = ""
        var isInQuotes = false

        var index = rawText.startIndex
        while index < rawText.endIndex {
            let character = rawText[index]

            if isInQuotes {
                if character == "\"" {
                    let nextIndex = rawText.index(after: index)
                    if nextIndex < rawText.endIndex, rawText[nextIndex] == "\"" {
                        currentField.append("\"")
                        index = nextIndex
                    } else {
                        isInQuotes = false
                    }
                } else {
                    currentField.append(character)
                }

                index = rawText.index(after: index)
                continue
            }

            if character == "\"" {
                isInQuotes = true
                index = rawText.index(after: index)
                continue
            }

            if character == delimiter {
                currentRecord.append(currentField)
                currentField = ""
                index = rawText.index(after: index)
                continue
            }

            if character == "\n" {
                currentRecord.append(currentField)
                records.append(currentRecord)
                currentRecord = []
                currentField = ""
                index = rawText.index(after: index)
                continue
            }

            if character == "\r" {
                currentRecord.append(currentField)
                records.append(currentRecord)
                currentRecord = []
                currentField = ""

                let nextIndex = rawText.index(after: index)
                if nextIndex < rawText.endIndex, rawText[nextIndex] == "\n" {
                    index = nextIndex
                }
                index = rawText.index(after: index)
                continue
            }

            currentField.append(character)
            index = rawText.index(after: index)
        }

        if isInQuotes {
            throw CSVParseError.unclosedQuote
        }

        if !currentField.isEmpty || !currentRecord.isEmpty {
            currentRecord.append(currentField)
            records.append(currentRecord)
        }

        return records
    }

    private func normalizeHeader(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func value(in record: [String], at index: Int?) -> String {
        guard let index, record.indices.contains(index) else {
            return ""
        }
        return trimmedValue(record[index])
    }

    private func trimmedValue(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
