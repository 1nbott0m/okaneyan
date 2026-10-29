import Foundation
import CryptoKit

public enum ImportError: Error, LocalizedError {
    case empty, missingColumns, invalidRow(Int), malformedQuoting(Int), amountOutOfRange(Int), subKopeckAmount(Int), unsupportedEncoding
    case unsupportedCurrency(row: Int, value: String)
    case ambiguousAmountColumns, ambiguousCurrencyColumns, ambiguousDateColumns
    case ambiguousStatusColumns
    case ambiguousDelimiter
    case ambiguousTransactionIDColumns, ambiguousRefundReferenceColumns
    case fileTooLarge(maximumBytes: Int)
    case tooManyRows(maximumRows: Int)
    case tooManyColumns(maximumColumns: Int)
    case fieldTooLarge(maximumCharacters: Int)
    case invalidStatus(row: Int, value: String)
    case duplicateProviderTransactionID(row: Int)
    public var errorDescription: String? {
        switch self {
        case .empty: "Файл не содержит операций."
        case .missingColumns: "Не найдены обязательные столбцы: дата, описание и сумма."
        case .invalidRow(let row): "Не удалось разобрать строку \(row). Проверь формат выписки."
        case .malformedQuoting(let row): "В строке \(row) не закрыты кавычки в CSV-поле. Проверь файл выписки."
        case .amountOutOfRange(let row): "Сумма в строке \(row) превышает допустимый предел для точного учёта в копейках."
        case .subKopeckAmount(let row): "Сумма в строке \(row) содержит доли меньше копейки и не может быть точно записана."
        case .unsupportedCurrency(let row, let value): "В строке \(row) указана валюта «\(value)». MoneyWise пока принимает только операции в рублях; конвертация валют не выполняется."
        case .ambiguousAmountColumns: "В выписке несколько колонок суммы, и не удалось однозначно выбрать сумму в рублях. Загрузите рублёвую выписку или оставьте одну колонку суммы."
        case .ambiguousCurrencyColumns: "В выписке несколько колонок валюты без явной рублёвой суммы. Не удалось безопасно определить валюту операции."
        case .ambiguousDateColumns: "В выписке несколько колонок с датами, но не удалось однозначно определить дату операции."
        case .ambiguousStatusColumns: "В выписке несколько колонок статуса. Оставь один столбец, чтобы импорт не угадывал состояние операции."
        case .ambiguousDelimiter: "Не удалось однозначно определить разделитель столбцов. Сохрани выписку как CSV с одним разделителем или выбери другой файл."
        case .ambiguousTransactionIDColumns: "В выписке несколько колонок с ID операции. Убери неоднозначность перед импортом."
        case .ambiguousRefundReferenceColumns: "В выписке несколько колонок со ссылкой возврата. Убери неоднозначность перед импортом."
        case .unsupportedEncoding: "Не удалось прочитать файл как UTF-8 или Windows-1251."
        case .fileTooLarge(let maximumBytes): "Файл слишком большой. Максимальный размер выписки — \(maximumBytes / 1_048_576) МБ."
        case .tooManyRows(let maximumRows): "В выписке слишком много строк (больше \(maximumRows)). Разбейте её на несколько периодов."
        case .tooManyColumns(let maximumColumns): "В выписке слишком много столбцов (больше \(maximumColumns))."
        case .fieldTooLarge(let maximumCharacters): "В выписке найдено слишком длинное поле (больше \(maximumCharacters) символов)."
        case .invalidStatus(let row, let value): "В строке \(row) неизвестный статус операции «\(value)». Исправь выписку или убери столбец статуса."
        case .duplicateProviderTransactionID(let row): "В строке \(row) повторяется ID банковской операции. Проверь выписку: одна операция не должна встречаться несколько раз с одинаковым ID."
        }
    }
}

public struct PreparedStatementImport: Sendable {
    public let transactions: [Transaction]
    public let duplicateIndexes: Set<Int>
    public let statusUpdates: [ImportedTransactionStatusUpdate]
    public let providerConflicts: [ProviderTransactionConflict]
    public var duplicateCount: Int { duplicateIndexes.count }
}

public struct ProviderTransactionConflict: Sendable, Equatable, Identifiable {
    public var id: Int { rowIndex }
    public let rowIndex: Int
    public let providerTransactionID: String
    public let existingMerchant: String
    public let existingAmount: Money
    public let existingDate: Date
    public let existingKind: TransactionKind
    public let importedMerchant: String
    public let importedAmount: Money
    public let importedDate: Date
    public let importedKind: TransactionKind
}

public struct ImportedTransactionStatusUpdate: Sendable, Equatable {
    public enum Identity: Sendable, Equatable {
        case sourceID(String)
        case providerTransactionID(String)
    }
    public let identity: Identity
    public var sourceID: String? {
        guard case .sourceID(let value) = identity else { return nil }
        return value
    }
    public let status: TransactionStatus
    public let expectedStoredValues: ExpectedStoredTransactionValues?
    public init(sourceID: String, status: TransactionStatus,
                expectedStoredValues: ExpectedStoredTransactionValues? = nil) {
        identity = .sourceID(sourceID)
        self.status = status
        self.expectedStoredValues = expectedStoredValues
    }
    public init(providerTransactionID: String, status: TransactionStatus,
                expectedStoredValues: ExpectedStoredTransactionValues? = nil) {
        identity = .providerTransactionID(providerTransactionID)
        self.status = status
        self.expectedStoredValues = expectedStoredValues
    }
}

public struct ExpectedStoredTransactionValues: Sendable, Equatable {
    public let merchant: String
    public let amount: Money
    public let date: Date
    public let kind: TransactionKind
    public init(merchant: String, amount: Money, date: Date, kind: TransactionKind) {
        self.merchant = merchant
        self.amount = amount
        self.date = date
        self.kind = kind
    }
    public func matches(merchant: String, amount: Money, date: Date, kind: TransactionKind) -> Bool {
        self.merchant == merchant && self.amount == amount && self.date == date && self.kind == kind
    }
}

public struct ExistingProviderTransaction: Sendable, Equatable {
    public let providerTransactionID: String
    public let sourceID: String?
    public let status: TransactionStatus
    public let merchant: String
    public let amount: Money
    public let date: Date
    public let kind: TransactionKind
    public init(providerTransactionID: String, sourceID: String?, status: TransactionStatus,
                merchant: String, amount: Money, date: Date, kind: TransactionKind) {
        self.providerTransactionID = providerTransactionID
        self.sourceID = sourceID
        self.status = status
        self.merchant = merchant
        self.amount = amount
        self.date = date
        self.kind = kind
    }
}

public struct CSVStatementImporter: Sendable {
    public static let maximumFileBytes = 20 * 1_048_576
    public static let maximumRows = 100_000
    public static let maximumColumns = 100
    public static let maximumFieldCharacters = 10_000

    private static let refundPhrases = tokenizedPhrases(["возврат", "возмещение", "refund", "reversal"])
    private static let feePhrases = tokenizedPhrases(["service charge", "плата за обслуживание"])
    private static let transferPhrases = tokenizedPhrases([
        "перевод", "перечисление", "сбп", "система быстрых платежей", "transfer"
    ])
    private static let transportPhrases = tokenizedPhrases([
        "metro", "метро", "такси", "taxi", "yandex go", "яндекс такси", "автобус", "bus",
        "трамвай", "троллейбус", "электричка", "общественный транспорт"
    ])
    private static let groceryPhrases = tokenizedPhrases([
        "пятерочка", "pyaterochka", "магнит", "вкусвилл", "vkusvill", "перекресток",
        "лента", "ашан", "auchan", "дикси", "dixy"
    ])
    private static let cafePhrases = tokenizedPhrases([
        "кафе", "ресторан", "кофе", "кофейня", "coffee", "dodo", "додо", "вкусно и точка",
        "burger king", "бургер кинг", "ростикс", "rostiks", "kfc"
    ])
    private static let subscriptionPhrases = tokenizedPhrases([
        "netflix", "ivi", "кинопоиск", "подписка", "yandex plus", "яндекс плюс",
        "spotify", "спотифай", "okko", "wink", "vk music", "vk музыка"
    ])

    public init() {}

    /// Creates stable, account-scoped source identifiers for statement rows.
    /// Re-imports from different file paths then match, while separate accounts stay distinct.
    public func assigningSourceIDs(to transactions: [Transaction], sourceNamespace: String) -> [Transaction] {
        assigningSourceIDs(to: transactions, sourceNamespace: sourceNamespace, useStatementDateIdentity: true)
    }

    private func assigningLegacySourceIDs(to transactions: [Transaction], sourceNamespace: String) -> [Transaction] {
        assigningSourceIDs(to: transactions, sourceNamespace: sourceNamespace, useStatementDateIdentity: false)
    }

    private func assigningSourceIDs(to transactions: [Transaction], sourceNamespace: String,
                                    useStatementDateIdentity: Bool) -> [Transaction] {
        let namespaceDigest = SHA256.hash(data: Data(sourceNamespace.utf8))
            .map { String(format: "%02x", $0) }.joined()
        var duplicateCounters: [String: Int] = [:]
        return transactions.map { original in
            var transaction = original
            let merchantKey = transaction.merchant
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
                .lowercased()
            let dateIdentity = useStatementDateIdentity
                ? (transaction.statementDateIdentity ?? String(transaction.date.timeIntervalSince1970))
                : String(transaction.date.timeIntervalSince1970)
            let base = "csv|\(namespaceDigest)|\(dateIdentity)|\(merchantKey)|\(transaction.amount.kopecks)|\(transaction.kind.rawValue)"
            let duplicateIndex = duplicateCounters[base, default: 0]
            duplicateCounters[base] = duplicateIndex + 1
            transaction.sourceID = "\(base)|\(duplicateIndex)"
            return transaction
        }
    }

    public func prepareImport(
        _ transactions: [Transaction],
        sourceNamespace: String?,
        existingSourceIDs: Set<String>,
        existingProviderTransactions: [ExistingProviderTransaction] = []
    ) -> PreparedStatementImport {
        let scoped = sourceNamespace.map { assigningSourceIDs(to: transactions, sourceNamespace: $0) } ?? transactions
        let legacyScoped = sourceNamespace.map {
            assigningLegacySourceIDs(to: transactions, sourceNamespace: $0)
        } ?? transactions.map { transaction -> Transaction in
            var row = transaction
            row.sourceID = legacyTimestampFingerprint(transaction.sourceID, date: transaction.date) ?? transaction.sourceID
            return row
        }
        let legacyRows = transactions.map { transaction -> Transaction in
            var row = transaction
            switch row.kind {
            case .refund, .incomingTransfer:
                row.kind = .income
                row.category = .income
                row.incomeSource = .other
            case .transfer:
                row.kind = .purchase
                row.category = .transfers
                row.incomeSource = nil
            case .fee:
                row.kind = .purchase
                row.category = .fees
                row.incomeSource = nil
            default:
                break
            }
            return row
        }
        let previousClassificationIDs: [String?]
        let previousLegacyClassificationIDs: [String?]
        if let sourceNamespace {
            let legacyIDs = assigningSourceIDs(to: legacyRows, sourceNamespace: sourceNamespace).map(\.sourceID)
            let previousDateIDs = assigningLegacySourceIDs(to: legacyRows, sourceNamespace: sourceNamespace).map(\.sourceID)
            previousClassificationIDs = transactions.indices.map { index in
                Self.hasLegacyClassification(transactions[index].kind) ? legacyIDs[index] : nil
            }
            previousLegacyClassificationIDs = transactions.indices.map { index in
                Self.hasLegacyClassification(transactions[index].kind) ? previousDateIDs[index] : nil
            }
        } else {
            previousClassificationIDs = transactions.map { transaction in
                Self.hasLegacyClassification(transaction.kind) ? previousClassificationFingerprint(transaction.sourceID, kind: transaction.kind) : nil
            }
            previousLegacyClassificationIDs = legacyScoped.map { transaction in
                Self.hasLegacyClassification(transaction.kind)
                    ? previousClassificationFingerprint(transaction.sourceID, kind: transaction.kind) : nil
            }
        }
        var accepted: [Transaction] = []
        accepted.reserveCapacity(scoped.count)
        var duplicates: Set<Int> = []
        var providerConflicts: [ProviderTransactionConflict] = []
        let providerTransactionsByID = Dictionary(grouping: existingProviderTransactions,
            by: \.providerTransactionID)

        for (index, transaction) in scoped.enumerated() {
            let scopedDuplicate = (transaction.sourceID.map(existingSourceIDs.contains) ?? false) ||
                (legacyScoped[index].sourceID.map(existingSourceIDs.contains) ?? false)
            let existingProviderMatches = transaction.providerTransactionID.flatMap {
                providerTransactionsByID[$0]
            } ?? []
            let providerDuplicate = !existingProviderMatches.isEmpty
            if existingProviderMatches.count == 1,
               let existing = existingProviderMatches.first,
               let providerID = transaction.providerTransactionID,
               existing.merchant != transaction.merchant || existing.amount != transaction.amount ||
                   existing.date != transaction.date || existing.kind != transaction.kind {
                providerConflicts.append(ProviderTransactionConflict(rowIndex: index,
                    providerTransactionID: providerID, existingMerchant: existing.merchant,
                    existingAmount: existing.amount, existingDate: existing.date, existingKind: existing.kind,
                    importedMerchant: transaction.merchant, importedAmount: transaction.amount,
                    importedDate: transaction.date, importedKind: transaction.kind))
            }
            let legacyDuplicate = sourceNamespace != nil && transactions.indices.contains(index) &&
                (transactions[index].sourceID.map(existingSourceIDs.contains) ?? false)
            let previousClassificationDuplicate = previousClassificationIDs.indices.contains(index) &&
                (previousClassificationIDs[index].map(existingSourceIDs.contains) == true ||
                 previousLegacyClassificationIDs[index].map(existingSourceIDs.contains) == true)
            if scopedDuplicate || providerDuplicate || legacyDuplicate || previousClassificationDuplicate {
                duplicates.insert(index)
            } else {
                accepted.append(transaction)
            }
        }
        return PreparedStatementImport(transactions: accepted, duplicateIndexes: duplicates,
                                       statusUpdates: [], providerConflicts: providerConflicts)
    }

    public func prepareImport(
        _ transactions: [Transaction],
        sourceNamespace: String?,
        existingStatuses: [String: TransactionStatus],
        existingProviderTransactions: [ExistingProviderTransaction] = []
    ) -> PreparedStatementImport {
        let prepared = prepareImport(transactions, sourceNamespace: sourceNamespace,
                                     existingSourceIDs: Set(existingStatuses.keys),
                                     existingProviderTransactions: existingProviderTransactions)
        let scoped = sourceNamespace.map { assigningSourceIDs(to: transactions, sourceNamespace: $0) } ?? transactions
        let legacyScoped = sourceNamespace.map {
            assigningLegacySourceIDs(to: transactions, sourceNamespace: $0)
        } ?? transactions.map { transaction -> Transaction in
            var row = transaction
            row.sourceID = legacyTimestampFingerprint(transaction.sourceID, date: transaction.date) ?? transaction.sourceID
            return row
        }
        // A provider-ID match with changed transaction data needs human review. Do not
        // silently mark the stored pending row as posted while its amount/date/kind may
        // still represent only the old authorization.
        let conflictedRowIndexes = Set(prepared.providerConflicts.map(\.rowIndex))
        let sourceUpdates = scoped.enumerated().compactMap { index, row -> ImportedTransactionStatusUpdate? in
            guard !conflictedRowIndexes.contains(index) else { return nil }
            guard let sourceID = row.sourceID, row.status == .posted else { return nil }
            let previousID = Self.hasLegacyClassification(row.kind)
                ? previousClassificationFingerprint(sourceID, kind: row.kind) : nil
            let legacySourceID = legacyScoped[index].sourceID
            let previousLegacyID = Self.hasLegacyClassification(row.kind)
                ? previousClassificationFingerprint(legacySourceID, kind: row.kind) : nil
            let pendingCandidates = [sourceID, legacySourceID, previousID, previousLegacyID].compactMap { $0 }
            let storedID = pendingCandidates.first { existingStatuses[$0] == .pending }
            guard let storedID else { return nil }
            let expectedKind: TransactionKind
            if storedID == previousID || storedID == previousLegacyID {
                expectedKind = (row.kind == .transfer || row.kind == .fee) ? .purchase : .income
            } else {
                expectedKind = row.kind
            }
            let storedSnapshot = existingProviderTransactions.first { $0.sourceID == storedID }.map {
                ExpectedStoredTransactionValues(merchant: $0.merchant, amount: $0.amount,
                                                date: $0.date, kind: $0.kind)
            } ?? ExpectedStoredTransactionValues(merchant: row.merchant, amount: row.amount,
                                                  date: row.date, kind: expectedKind)
            return ImportedTransactionStatusUpdate(sourceID: storedID, status: .posted,
                                                   expectedStoredValues: storedSnapshot)
        }
        var providerIDsWithUpdate = Set<String>()
        let sourceIDsWithUpdate = Set(sourceUpdates.compactMap(\.sourceID))
        let providerTransactionsByID = Dictionary(grouping: existingProviderTransactions,
            by: \.providerTransactionID)
        let providerUpdates = scoped.enumerated().compactMap { index, row -> ImportedTransactionStatusUpdate? in
            guard !conflictedRowIndexes.contains(index) else { return nil }
            guard row.status == .posted, let providerID = row.providerTransactionID,
                  providerIDsWithUpdate.insert(providerID).inserted,
                  let matches = providerTransactionsByID[providerID], matches.count == 1,
                  let previous = matches.first, previous.status == .pending else { return nil }
            if let previousSourceID = previous.sourceID, sourceIDsWithUpdate.contains(previousSourceID) { return nil }
            return ImportedTransactionStatusUpdate(providerTransactionID: providerID, status: .posted,
                expectedStoredValues: ExpectedStoredTransactionValues(merchant: previous.merchant,
                    amount: previous.amount, date: previous.date, kind: previous.kind))
        }
        return PreparedStatementImport(transactions: prepared.transactions,
                                       duplicateIndexes: prepared.duplicateIndexes,
                                       statusUpdates: sourceUpdates + providerUpdates,
                                       providerConflicts: prepared.providerConflicts)
    }

    /// Rechecks a preview against identifiers read immediately before persistence.
    /// Keeps the preview-assigned IDs intact, including counters for repeated identical rows.
    public func excludingStoredDuplicates(_ transactions: [Transaction],
                                          existingSourceIDs: Set<String>,
                                          existingProviderTransactionIDs: Set<String> = []) -> [Transaction] {
        transactions.filter { transaction in
            !isStoredDuplicate(transaction, existingSourceIDs: existingSourceIDs) &&
                !(transaction.providerTransactionID.map(existingProviderTransactionIDs.contains) ?? false)
        }
    }

    private func isStoredDuplicate(_ transaction: Transaction, existingSourceIDs: Set<String>) -> Bool {
        guard let sourceID = transaction.sourceID else { return false }
        if existingSourceIDs.contains(sourceID) { return true }
        let legacyDateID = legacyTimestampFingerprint(sourceID, date: transaction.date)
        let candidates = [legacyDateID, sourceID].compactMap { $0 }
        if candidates.contains(where: existingSourceIDs.contains) { return true }
        guard Self.hasLegacyClassification(transaction.kind) else { return false }
        return candidates.compactMap { previousClassificationFingerprint($0, kind: transaction.kind) }
            .contains(where: existingSourceIDs.contains)
    }

    private func legacyTimestampFingerprint(_ sourceID: String?, date: Date) -> String? {
        guard let sourceID else { return nil }
        var components = sourceID.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard components.count >= 7, components[0] == "csv", components[1].count == 64 else { return nil }
        components[2] = String(date.timeIntervalSince1970)
        return components.joined(separator: "|")
    }

    private static func hasLegacyClassification(_ kind: TransactionKind) -> Bool {
        kind == .refund || kind == .transfer || kind == .incomingTransfer || kind == .fee
    }

    private func previousClassificationFingerprint(_ sourceID: String?, kind: TransactionKind) -> String? {
        guard let sourceID else { return nil }
        let components = sourceID.split(separator: "|", omittingEmptySubsequences: false)
        let dateIdentity = components.count > 2 ? String(components[2]) : ""
        let isLegacyTimestamp = Double(dateIdentity).map(\.isFinite) ?? false
        let isStableDateIdentity = dateIdentity.hasPrefix("wall:") ||
            (dateIdentity.hasPrefix("instant:") && UInt64(dateIdentity.dropFirst("instant:".count), radix: 16) != nil)
        guard components.count >= 7,
              components[0] == "csv",
              components[1].count == 64,
              isLegacyTimestamp || isStableDateIdentity,
              Int64(components[components.count - 3]) != nil,
              components[components.count - 2] == Substring(kind.rawValue),
              Int(components[components.count - 1]) != nil else { return nil }
        var legacy = components.map(String.init)
        legacy[legacy.count - 2] = (kind == .transfer || kind == .fee) ? "purchase" : "income"
        return legacy.joined(separator: "|")
    }

    public func parse(contentsOf url: URL, sourceNamespace: String? = nil) throws -> [Transaction] {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        if let fileSize = attributes[.size] as? NSNumber,
           fileSize.intValue > Self.maximumFileBytes {
            throw ImportError.fileTooLarge(maximumBytes: Self.maximumFileBytes)
        }
        return try parse(data: Data(contentsOf: url, options: .mappedIfSafe),
                         sourceNamespace: sourceNamespace ?? url.standardizedFileURL.path)
    }

    public func parse(data: Data, sourceNamespace: String = "default",
                      timeZone: TimeZone = .current) throws -> [Transaction] {
        guard data.count <= Self.maximumFileBytes else {
            throw ImportError.fileTooLarge(maximumBytes: Self.maximumFileBytes)
        }
        guard var text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1251) else {
            throw ImportError.unsupportedEncoding
        }
        if text.first == "\u{FEFF}" { text.removeFirst() }
        let lines = try logicalRecords(in: text).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count > 1 else { throw ImportError.empty }
        guard lines.count - 1 <= Self.maximumRows else {
            throw ImportError.tooManyRows(maximumRows: Self.maximumRows)
        }
        let delimiterCandidates: [(Character, [String])] = try [",", ";", "\t"].map { candidate in
            (candidate, try splitCSV(lines[0], delimiter: candidate, row: 1))
        }
        let candidateWidths = delimiterCandidates.map { $0.1.count }
        let maximumWidth = candidateWidths.max() ?? 1
        let bestDelimiters = delimiterCandidates.filter { $0.1.count == maximumWidth }
        guard bestDelimiters.count == 1 || maximumWidth == 1 else { throw ImportError.ambiguousDelimiter }
        let (delimiter, rawHeaders) = bestDelimiters[0]
        guard rawHeaders.count <= Self.maximumColumns else {
            throw ImportError.tooManyColumns(maximumColumns: Self.maximumColumns)
        }
        let headers = rawHeaders.map { normalize($0) }
        let dateIndices = headers.indices.filter { headers[$0].contains("date") || headers[$0].contains("дата") }
        let operationDateIndices = dateIndices.filter { headers[$0].contains("operation") || headers[$0].contains("операц") }
        let nonTransactionDateMarkers = ["value date", "settlement", "валютир", "statement date", "дата выписки",
                                         "дата формирования", "report date", "дата отчета", "дата обработки", "processing date"]
        let plausibleDateIndices = dateIndices.filter { index in
            !nonTransactionDateMarkers.contains(where: headers[index].contains)
        }
        let dateIndex: Int
        if operationDateIndices.count == 1, let preferred = operationDateIndices.first {
            dateIndex = preferred
        } else if operationDateIndices.count > 1 {
            throw ImportError.ambiguousDateColumns
        } else if plausibleDateIndices.count == 1, let onlyDate = plausibleDateIndices.first {
            dateIndex = onlyDate
        } else if dateIndices.isEmpty {
            throw ImportError.missingColumns
        } else {
            throw ImportError.ambiguousDateColumns
        }
        let descriptionIndices = headers.indices.filter {
            let header = headers[$0]
            return header.contains("description") || header.contains("опис") || header.contains("merchant") || header.contains("магаз") ||
                header.contains("назначен") || header.contains("контраг") || header.contains("recipient") ||
                header.contains("sender") || header.contains("purpose") || header.contains("details")
        }
        guard let descriptionIndex = descriptionIndices.first else {
            throw ImportError.missingColumns
        }
        let operationDescriptionIndices = headers.indices.filter {
            let header = headers[$0]
            return header.contains("description") || header.contains("опис") || header.contains("назначен") ||
                header.contains("purpose") || header.contains("details")
        }
        let amountIndices = headers.indices.filter { headers[$0].contains("amount") || headers[$0].contains("сумм") }
        let explicitRubleAmountIndices = amountIndices.filter {
            headers[$0].contains("rub") || headers[$0].contains("rur") || headers[$0].contains("руб")
        }
        let debitIndices = headers.indices.filter {
            let header = headers[$0]
            return header.contains("расход") || header.contains("списан") || header == "debit" ||
                header.hasPrefix("дебет")
        }
        let creditIndices = headers.indices.filter {
            let header = headers[$0]
            return header.contains("приход") || header.contains("зачислен") || header == "credit" ||
                header == "кредит" || header.hasPrefix("кредит (")
        }
        guard debitIndices.count <= 1, creditIndices.count <= 1 else {
            throw ImportError.ambiguousAmountColumns
        }
        let debitIndex = debitIndices.first
        let creditIndex = creditIndices.first
        let amountIndex: Int?
        let amountHasExplicitRubleUnit = explicitRubleAmountIndices.count == 1
        if explicitRubleAmountIndices.count > 1 {
            throw ImportError.ambiguousAmountColumns
        } else if let explicitRubleAmountIndex = explicitRubleAmountIndices.first {
            amountIndex = explicitRubleAmountIndex
        } else if amountIndices.count == 1 {
            amountIndex = amountIndices[0]
        } else if amountIndices.count > 1 && (debitIndex != nil || creditIndex != nil) {
            amountIndex = nil
        } else if amountIndices.count > 1 {
            throw ImportError.ambiguousAmountColumns
        } else {
            amountIndex = nil
        }
        let currencyIndices = headers.indices.filter { headers[$0].contains("currency") || headers[$0].contains("валют") }
        if !amountHasExplicitRubleUnit && currencyIndices.count > 1 {
            throw ImportError.ambiguousCurrencyColumns
        }
        let currencyIndex = amountHasExplicitRubleUnit ? nil : currencyIndices.first
        let statusIndices = headers.indices.filter { headers[$0].contains("status") || headers[$0].contains("статус") }
        guard statusIndices.count <= 1 else { throw ImportError.ambiguousStatusColumns }
        let statusIndex = statusIndices.first
        let transactionIDIndices = headers.indices.filter { Self.transactionIDHeaders.contains(Self.normalizedHeaderKey(headers[$0])) }
        guard transactionIDIndices.count <= 1 else { throw ImportError.ambiguousTransactionIDColumns }
        let transactionIDIndex = transactionIDIndices.first
        let refundReferenceIndices = headers.indices.filter { Self.refundReferenceHeaders.contains(Self.normalizedHeaderKey(headers[$0])) }
        guard refundReferenceIndices.count <= 1 else { throw ImportError.ambiguousRefundReferenceColumns }
        let refundReferenceIndex = refundReferenceIndices.first
        guard amountIndex != nil || debitIndex != nil || creditIndex != nil else { throw ImportError.missingColumns }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        let localTimeZone = timeZone
        formatter.timeZone = localTimeZone
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.isLenient = false
        let formats = ["yyyy-MM-dd", "dd.MM.yyyy", "dd/MM/yyyy", "yyyy-MM-dd HH:mm:ss", "dd.MM.yyyy HH:mm:ss"]
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime]
        let fractionalISO8601Formatter = ISO8601DateFormatter()
        fractionalISO8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var result: [Transaction] = []
        var seenProviderTransactionIDs = Set<String>()
        for (offset, line) in lines.dropFirst().enumerated() {
            let fields = try splitCSV(line, delimiter: delimiter, row: offset + 2)
            guard fields.count <= Self.maximumColumns else {
                throw ImportError.tooManyColumns(maximumColumns: Self.maximumColumns)
            }
            guard fields.count <= rawHeaders.count else {
                throw ImportError.invalidRow(offset + 2)
            }
            let requiredAmountIndex = amountIndex ?? [debitIndex, creditIndex].compactMap { $0 }.min()
            let requiredIndexes = [dateIndex, descriptionIndex, requiredAmountIndex].compactMap { $0 }
            guard fields.count > (requiredIndexes.max() ?? descriptionIndex) else {
                throw ImportError.invalidRow(offset + 2)
            }
            if let currencyIndex {
                guard fields.indices.contains(currencyIndex) else { throw ImportError.invalidRow(offset + 2) }
                let rawCurrency = fields[currencyIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                guard !rawCurrency.isEmpty else { throw ImportError.invalidRow(offset + 2) }
                guard Self.isRubleCurrency(rawCurrency) else {
                    throw ImportError.unsupportedCurrency(row: offset + 2, value: rawCurrency)
                }
            }
            let rawDate = fields[dateIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            var parsedDate = iso8601Formatter.date(from: rawDate) ?? fractionalISO8601Formatter.date(from: rawDate)
            var statementDateIdentity = parsedDate.map {
                "instant:\(String($0.timeIntervalSince1970.bitPattern, radix: 16))"
            }
            if parsedDate == nil {
                for format in formats {
                    formatter.dateFormat = format
                    guard let localDate = formatter.date(from: rawDate) else { continue }
                    parsedDate = localDate
                    let components = formatter.calendar.dateComponents(in: localTimeZone, from: localDate)
                    guard let year = components.year, let month = components.month, let day = components.day,
                          let hour = components.hour, let minute = components.minute, let second = components.second else {
                        break
                    }
                    statementDateIdentity = String(format: "wall:%04d-%02d-%02dT%02d:%02d:%02d",
                        year, month, day, hour, minute, second)
                    break
                }
            }
            let decimal: Decimal?
            if let amountIndex {
                guard let amount = Self.parseAmount(fields[amountIndex]) else {
                    throw ImportError.invalidRow(offset + 2)
                }
                if debitIndex != nil || creditIndex != nil {
                    let firstDirectionIndex = [debitIndex, creditIndex].compactMap { $0 }.min()!
                    if fields.count <= firstDirectionIndex {
                        // A statement may include optional direction columns but omit
                        // the entire trailing group on rows that use the amount field.
                        decimal = amount
                    } else {
                        let debit = try Self.parseDebitCreditCell(at: debitIndex, fields: fields,
                            headerCount: rawHeaders.count, row: offset + 2, allowOmittedTrailing: false)
                        let credit = try Self.parseDebitCreditCell(at: creditIndex, fields: fields,
                            headerCount: rawHeaders.count, row: offset + 2, allowOmittedTrailing: true)
                        guard debit == 0 || credit == 0 else { throw ImportError.invalidRow(offset + 2) }
                        let directionAmount = credit != 0 ? abs(credit) : abs(debit)
                        if directionAmount != 0 {
                            // When both a signed/unsigned amount and debit-credit columns
                            // are present, use the explicit direction columns but require
                            // their magnitude to agree.
                            guard directionAmount == abs(amount) else { throw ImportError.invalidRow(offset + 2) }
                            decimal = credit != 0 ? directionAmount : -directionAmount
                        } else {
                            decimal = amount
                        }
                    }
                } else {
                    decimal = amount
                }
            } else {
                let debit = try Self.parseDebitCreditCell(at: debitIndex, fields: fields,
                    headerCount: rawHeaders.count, row: offset + 2, allowOmittedTrailing: false)
                let credit = try Self.parseDebitCreditCell(at: creditIndex, fields: fields,
                    headerCount: rawHeaders.count, row: offset + 2, allowOmittedTrailing: true)
                guard debit == 0 || credit == 0 else { throw ImportError.invalidRow(offset + 2) }
                decimal = credit != 0 ? abs(credit) : (debit != 0 ? -abs(debit) : nil)
            }
            guard let parsedDate, let decimal else {
                throw ImportError.invalidRow(offset + 2)
            }
            guard let description = descriptionIndices.lazy.compactMap({ index -> String? in
                guard fields.indices.contains(index) else { return nil }
                let value = fields[index].trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : value
            }).first else { throw ImportError.invalidRow(offset + 2) }
            let operationDescription = operationDescriptionIndices.compactMap { index -> String? in
                guard fields.indices.contains(index) else { return nil }
                let value = fields[index].trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : value
            }.joined(separator: " ")
            let classificationDescription = operationDescription.isEmpty ? description : operationDescription
            let refundOfProviderTransactionID = refundReferenceIndex
                .flatMap { fields.indices.contains($0) ? fields[$0] : nil }.flatMap(Self.nonemptyIdentifier)
            let status: TransactionStatus
            if let statusIndex {
                guard fields.indices.contains(statusIndex) else { throw ImportError.invalidRow(offset + 2) }
                let rawStatus = normalize(fields[statusIndex])
                guard let parsedStatus = Self.parseStatus(rawStatus) else {
                    throw ImportError.invalidStatus(row: offset + 2, value: rawStatus)
                }
                status = parsedStatus
            } else {
                status = .posted
            }
            let isRefund = decimal > 0 && (refundOfProviderTransactionID != nil ||
                Self.isRefundDescription(description: classificationDescription))
            let isFee = decimal < 0 && Self.isFeeDescription(classificationDescription)
            let isTransfer = Self.isTransferDescription(classificationDescription)
            let kind: TransactionKind
            if decimal == 0 { kind = .adjustment }
            else if isRefund { kind = .refund }
            else if isFee { kind = .fee }
            else if isTransfer { kind = decimal < 0 ? .transfer : .incomingTransfer }
            else { kind = decimal < 0 ? .purchase : .income }
            let category = Self.guessCategory(description: classificationDescription, kind: kind)
            let rubles = abs(decimal)
            guard Money.canRepresent(rubles: rubles) else { throw ImportError.amountOutOfRange(offset + 2) }
            guard Money.canRepresentExactlyInKopecks(rubles: rubles) else { throw ImportError.subKopeckAmount(offset + 2) }
            let amount = Money(rubles: rubles)
            let incomeSource: IncomeSource?
            if kind == .income {
                incomeSource = IncomeSource.infer(from: classificationDescription) ?? .other
            } else if kind == .incomingTransfer {
                incomeSource = IncomeSource.infer(from: classificationDescription)
            } else {
                incomeSource = nil
            }
            let providerTransactionID = transactionIDIndex.flatMap { fields.indices.contains($0) ? fields[$0] : nil }
                .flatMap(Self.nonemptyIdentifier)
            if let providerTransactionID,
               !seenProviderTransactionIDs.insert(providerTransactionID).inserted {
                throw ImportError.duplicateProviderTransactionID(row: offset + 2)
            }
            // A bank description alone cannot prove that a transfer is between the user's own accounts.
            // Keep its cash-flow direction so outgoing transfers are not silently omitted from spending.
            result.append(Transaction(date: parsedDate, merchant: description, amount: amount,
                                      kind: kind, category: category,
                                      incomeSource: incomeSource,
                                      sourceID: nil, statementDateIdentity: statementDateIdentity,
                                      status: status,
                                      providerTransactionID: providerTransactionID,
                                      refundOfProviderTransactionID: refundOfProviderTransactionID))
        }
        return assigningSourceIDs(to: result, sourceNamespace: sourceNamespace)
    }

    /// Splits physical lines into CSV records while preserving line breaks inside quoted fields.
    private func logicalRecords(in text: String) throws -> [String] {
        // CSV syntax is ASCII. Scan the String's UTF-8 view rather than
        // materializing a `Character` array for the entire statement (up to 20 MiB).
        let bytes = text.utf8
        var records: [String] = []
        var record: [UInt8] = []
        var quoted = false
        var physicalLine = 1
        var recordStartLine = 1
        var index = bytes.startIndex

        while index < bytes.endIndex {
            let byte = bytes[index]
            if byte == 34 { // quote
                let nextIndex = bytes.index(after: index)
                if quoted && nextIndex < bytes.endIndex && bytes[nextIndex] == 34 {
                    record.append(34)
                    record.append(34)
                    index = bytes.index(after: nextIndex)
                    continue
                }
                quoted.toggle()
                record.append(byte)
            } else if byte == 13 || byte == 10 { // CR, LF, or CRLF
                if quoted {
                    record.append(10)
                } else {
                    let decoded = String(decoding: record, as: UTF8.self)
                    if !decoded.trimmingCharacters(in: .whitespaces).isEmpty { records.append(decoded) }
                    record.removeAll(keepingCapacity: true)
                    recordStartLine = physicalLine + 1
                }
                let nextIndex = bytes.index(after: index)
                if byte == 13, nextIndex < bytes.endIndex, bytes[nextIndex] == 10 {
                    index = bytes.index(after: nextIndex)
                } else {
                    index = nextIndex
                }
                physicalLine += 1
                continue
            } else {
                record.append(byte)
            }
            index = bytes.index(after: index)
        }
        guard !quoted else { throw ImportError.malformedQuoting(recordStartLine) }
        let decoded = String(decoding: record, as: UTF8.self)
        if !decoded.trimmingCharacters(in: .whitespaces).isEmpty { records.append(decoded) }
        return records
    }

    private func normalize(_ value: String) -> String {
        value.lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"")))
    }

    private static let transactionIDHeaders: Set<String> = [
        "идентификатор операции", "номер операции", "id операции", "operation id",
        "transaction id", "transaction identifier", "operation identifier"
    ].map(Self.normalizedHeaderKey).reduce(into: Set<String>()) { $0.insert($1) }
    private static let refundReferenceHeaders: Set<String> = [
        "идентификатор исходной операции", "номер исходной операции", "id исходной операции",
        "original transaction id", "original operation id", "refund of transaction id",
        "refund of operation id"
    ].map(Self.normalizedHeaderKey).reduce(into: Set<String>()) { $0.insert($1) }

    private static func normalizedHeaderKey(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ru_RU"))
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private static func nonemptyIdentifier(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func parseStatus(_ raw: String) -> TransactionStatus? {
        switch raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "проведена", "проведено", "исполнена", "исполнено", "выполнена", "выполнено", "завершена", "завершено", "posted", "completed", "success", "успешно": .posted
        case "ожидает", "ожидает проведения", "в обработке", "обрабатывается", "заблокирована", "заблокировано", "pending", "processing", "hold": .pending
        default: nil
        }
    }

    private func splitCSV(_ line: String, delimiter: Character, row: Int) throws -> [String] {
        enum FieldState { case start, unquoted, quoted, afterQuote }
        var values: [String] = [], field = "", state = FieldState.start
        var fieldCharacters = 0
        var index = line.startIndex
        while index < line.endIndex {
            let character = line[index]
            let nextIndex = line.index(after: index)
            switch state {
            case .start:
                if character == "\"" {
                    state = .quoted
                } else if character == delimiter {
                    values.append(field)
                    field = ""
                    fieldCharacters = 0
                    guard values.count < Self.maximumColumns else {
                        throw ImportError.tooManyColumns(maximumColumns: Self.maximumColumns)
                    }
                } else {
                    field.append(character)
                    fieldCharacters += 1
                    if !character.isWhitespace { state = .unquoted }
                }
            case .unquoted:
                if character == delimiter {
                    values.append(field)
                    field = ""
                    fieldCharacters = 0
                    state = .start
                    guard values.count < Self.maximumColumns else {
                        throw ImportError.tooManyColumns(maximumColumns: Self.maximumColumns)
                    }
                } else if character == "\"" {
                    throw ImportError.malformedQuoting(row)
                } else {
                    field.append(character)
                    fieldCharacters += 1
                }
            case .quoted:
                if character == "\"" {
                    if nextIndex < line.endIndex && line[nextIndex] == "\"" {
                        field.append("\"")
                        fieldCharacters += 1
                        index = line.index(after: nextIndex)
                        guard fieldCharacters <= Self.maximumFieldCharacters else {
                            throw ImportError.fieldTooLarge(maximumCharacters: Self.maximumFieldCharacters)
                        }
                        continue
                    } else {
                        state = .afterQuote
                    }
                } else {
                    field.append(character)
                    fieldCharacters += 1
                }
            case .afterQuote:
                if character == delimiter {
                    values.append(field)
                    field = ""
                    fieldCharacters = 0
                    state = .start
                    guard values.count < Self.maximumColumns else {
                        throw ImportError.tooManyColumns(maximumColumns: Self.maximumColumns)
                    }
                } else if character.isWhitespace {
                    field.append(character)
                    fieldCharacters += 1
                } else {
                    throw ImportError.malformedQuoting(row)
                }
            }
            guard fieldCharacters <= Self.maximumFieldCharacters else {
                throw ImportError.fieldTooLarge(maximumCharacters: Self.maximumFieldCharacters)
            }
            index = nextIndex
        }
        if state == .quoted { throw ImportError.malformedQuoting(row) }
        values.append(field)
        return values
    }

    private static func parseAmount(_ value: String) -> Decimal? {
        var raw = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.lowercased().hasSuffix("руб.") {
            raw = String(raw.dropLast("руб.".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if raw.hasSuffix("₽") {
            raw = String(raw.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        raw = raw.replacingOccurrences(of: "−", with: "-")

        let opensParenthesis = raw.hasPrefix("(")
        let closesParenthesis = raw.hasSuffix(")")
        guard opensParenthesis == closesParenthesis else { return nil }
        let parenthesizedNegative = opensParenthesis
        if parenthesizedNegative {
            raw = String(raw.dropFirst().dropLast())
            guard !raw.hasPrefix("-") && !raw.hasPrefix("+") else { return nil }
        }

        var explicitSign: Character?
        if raw.first == "-" || raw.first == "+" {
            explicitSign = raw.removeFirst()
        }
        guard !parenthesizedNegative || explicitSign == nil else { return nil }

        let commaCount = raw.filter { $0 == "," }.count
        let dotCount = raw.filter { $0 == "." }.count
        let decimalSeparator: Character?
        var groupingSeparator: Character?
        if commaCount > 0 && dotCount > 0 {
            guard let commaIndex = raw.lastIndex(of: ","), let dotIndex = raw.lastIndex(of: ".") else { return nil }
            decimalSeparator = commaIndex > dotIndex ? "," : "."
            groupingSeparator = decimalSeparator == "," ? "." : ","
        } else if commaCount + dotCount > 1 {
            decimalSeparator = nil
            groupingSeparator = commaCount > 0 ? "," : "."
        } else if commaCount == 1 {
            decimalSeparator = ","
            groupingSeparator = nil
        } else if dotCount == 1 {
            decimalSeparator = "."
            groupingSeparator = nil
        } else {
            decimalSeparator = nil
            groupingSeparator = nil
        }

        let decimalParts: [String]
        if let decimalSeparator {
            decimalParts = raw.split(separator: decimalSeparator, omittingEmptySubsequences: false).map(String.init)
            guard decimalParts.count == 2, !decimalParts[1].isEmpty else { return nil }
        } else {
            decimalParts = [raw]
        }

        let integerPart = decimalParts[0]
        let whitespaceSeparators = integerPart.filter(\.isWhitespace)
        if let whitespaceSeparator = whitespaceSeparators.first {
            let allowedGroupingSpaces: Set<Character> = [" ", "\u{00A0}", "\u{202F}"]
            guard allowedGroupingSpaces.contains(whitespaceSeparator),
                  whitespaceSeparators.allSatisfy({ $0 == whitespaceSeparator }),
                  groupingSeparator == nil else { return nil }
            groupingSeparator = whitespaceSeparator
        }
        let apostropheSeparator: Character? = integerPart.contains("'") ? "'" : (integerPart.contains("’") ? "’" : nil)
        if let apostropheSeparator {
            guard groupingSeparator == nil else { return nil }
            groupingSeparator = apostropheSeparator
        }

        let integerGroups: [String]
        if let groupingSeparator {
            integerGroups = integerPart.split(separator: groupingSeparator, omittingEmptySubsequences: false).map(String.init)
            guard integerGroups.count > 1,
                  (1...3).contains(integerGroups[0].count),
                  integerGroups.dropFirst().allSatisfy({ $0.count == 3 && Self.isASCIIDigits($0) }) else { return nil }
        } else {
            integerGroups = [integerPart]
        }
        guard integerGroups.allSatisfy(Self.isASCIIDigits) else { return nil }
        if decimalParts.count == 2, !Self.isASCIIDigits(decimalParts[1]) { return nil }

        let normalizedInteger = integerGroups.joined()
        let normalizedFraction = decimalParts.count == 2 ? ".\(decimalParts[1])" : ""
        let sign = parenthesizedNegative || explicitSign == "-" ? "-" : ""
        let normalized = sign + normalizedInteger + normalizedFraction
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func parseDebitCreditCell(at index: Int?, fields: [String], headerCount: Int,
                                             row: Int, allowOmittedTrailing: Bool) throws -> Decimal {
        guard let index else { return 0 }
        guard fields.indices.contains(index) else {
            // Some statement exporters trim only the final empty credit cell. Preserve
            // that known shape, but never treat a missing non-trailing field as zero.
            if allowOmittedTrailing, index == headerCount - 1, fields.count == index { return 0 }
            throw ImportError.invalidRow(row)
        }
        let raw = fields[index].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return 0 }
        guard let amount = parseAmount(raw) else { throw ImportError.invalidRow(row) }
        return amount
    }

    private static func isASCIIDigits(_ value: String) -> Bool {
        !value.isEmpty && value.unicodeScalars.allSatisfy { (48...57).contains($0.value) }
    }

    private static func isRubleCurrency(_ value: String) -> Bool {
        if value.contains("₽") { return true }
        let tokens = value.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        let recognizedCodes: Set<String> = ["rub", "rur", "643", "руб", "рубль", "рубли", "рублей"]
        let compact = tokens.joined()
        return tokens.contains(where: recognizedCodes.contains) ||
            ["российскийрубль", "russianruble", "russianrouble"].contains(compact)
    }

    private static func isRefundDescription(description: String) -> Bool {
        containsAnyPhrase(in: normalizedTokens(description), phrases: refundPhrases)
    }

    private static func isFeeDescription(_ description: String) -> Bool {
        let tokens = normalizedTokens(description)
        return tokens.contains(where: { $0.hasPrefix("комисс") || $0 == "fee" || $0 == "fees" }) ||
            containsAnyPhrase(in: tokens, phrases: feePhrases)
    }

    private static func isTransferDescription(_ description: String) -> Bool {
        containsAnyPhrase(in: normalizedTokens(description), phrases: transferPhrases)
    }

    private static func guessCategory(description: String, kind: TransactionKind) -> Category {
        if kind == .adjustment { return .other }
        if kind == .income { return .income }
        if kind == .refund { return .refunds }
        if kind == .fee { return .fees }
        let tokens = normalizedTokens(description)
        if kind == .transfer || kind == .incomingTransfer || Self.containsAnyPhrase(in: tokens, phrases: transferPhrases) { return .transfers }
        if Self.containsAnyPhrase(in: tokens, phrases: transportPhrases) { return .transport }
        if Self.containsAnyPhrase(in: tokens, phrases: groceryPhrases) { return .groceries }
        if Self.containsAnyPhrase(in: tokens, phrases: cafePhrases) { return .cafe }
        if Self.containsAnyPhrase(in: tokens, phrases: subscriptionPhrases) { return .subscriptions }
        return .other
    }

    private static func normalizedTokens(_ text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ru_RU"))
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }

    private static func tokenizedPhrases(_ phrases: [String]) -> [[String]] {
        phrases.map(normalizedTokens)
    }

    private static func containsAnyPhrase(in tokens: [String], phrases: [[String]]) -> Bool {
        phrases.contains { target in
            guard !target.isEmpty, target.count <= tokens.count else { return false }
            for start in 0...(tokens.count - target.count) {
                if Array(tokens[start..<(start + target.count)]) == target { return true }
            }
            return false
        }
    }
}
