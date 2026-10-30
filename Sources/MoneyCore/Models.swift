import Foundation

public struct Money: Codable, Hashable, Comparable, Sendable {
    public var kopecks: Int64
    public init(kopecks: Int64) { self.kopecks = kopecks }
    public init(rubles: Decimal) {
        var value = rubles * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        if rounded.isNaN {
            self.kopecks = 0
        } else if rounded >= Decimal(Int64.max) {
            self.kopecks = Int64.max
        } else if rounded <= Decimal(Int64.min) {
            self.kopecks = Int64.min
        } else {
            self.kopecks = NSDecimalNumber(decimal: rounded).int64Value
        }
    }
    public static func canRepresent(rubles: Decimal) -> Bool {
        var value = rubles * 100
        guard !value.isNaN else { return false }
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        return !rounded.isNaN && rounded <= Decimal(Int64.max) && rounded >= Decimal(Int64.min)
    }
    public static func canRepresentExactlyInKopecks(rubles: Decimal) -> Bool {
        var value = rubles * 100
        guard !value.isNaN else { return false }
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        return rounded == value && canRepresent(rubles: rubles)
    }
    public static func parseRubles(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var characters = Array(trimmed)
        var sign = ""
        if characters.first == "-" || characters.first == "+" {
            sign = String(characters.removeFirst())
        }
        guard !characters.isEmpty else { return nil }
        let decimalSeparators = characters.filter { $0 == "," || $0 == "." }
        guard decimalSeparators.count <= 1 else { return nil }
        let decimalSeparator = decimalSeparators.first
        let pieces = String(characters).split(separator: decimalSeparator ?? "\0", omittingEmptySubsequences: false)
        guard pieces.count == (decimalSeparator == nil ? 1 : 2) else { return nil }
        let integerPart = String(pieces[0])
        let fractionPart = pieces.count == 2 ? String(pieces[1]) : nil
        let groupingSpaces: Set<Character> = [" ", "\u{00A0}", "\u{202F}"]
        func isASCIIDigit(_ character: Character) -> Bool { character >= "0" && character <= "9" }
        let integerCharacters = Array(integerPart)
        let separators = integerCharacters.filter { groupingSpaces.contains($0) }
        let validSeparatorLayout: Bool
        if let separator = separators.first {
            validSeparatorLayout = !groupingSpaces.contains(integerCharacters[0]) &&
                !groupingSpaces.contains(integerCharacters[integerCharacters.count - 1]) &&
                separators.allSatisfy { $0 == separator } &&
                !zip(integerCharacters, integerCharacters.dropFirst()).contains { pair in
                    groupingSpaces.contains(pair.0) && groupingSpaces.contains(pair.1)
                }
        } else {
            validSeparatorLayout = true
        }
        guard !integerPart.isEmpty,
              validSeparatorLayout,
              integerPart.allSatisfy({ isASCIIDigit($0) || groupingSpaces.contains($0) }) else { return nil }
        let integerGroups = integerPart.split(whereSeparator: { groupingSpaces.contains($0) })
        let validGrouping = integerGroups.count == 1 ||
            (!integerGroups.isEmpty && (1...3).contains(integerGroups[0].count) &&
             integerGroups.dropFirst().allSatisfy { $0.count == 3 })
        guard !integerGroups.isEmpty, validGrouping,
              integerGroups.allSatisfy({ $0.allSatisfy(isASCIIDigit) }) else { return nil }
        if let fractionPart {
            guard !fractionPart.isEmpty, fractionPart.allSatisfy(isASCIIDigit) else { return nil }
        }
        let normalized = sign + integerGroups.joined() + (fractionPart.map { ".\($0)" } ?? "")
        guard let amount = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")),
              canRepresentExactlyInKopecks(rubles: amount) else { return nil }
        return amount
    }
    public static let zero = Money(kopecks: 0)
    /// Sums signed balances without intermediate saturation, then clamps only the final result.
    /// This keeps net account balances independent of account ordering.
    public static func sum<S: Sequence>(_ values: S) -> Money where S.Element == Money {
        var total = Decimal.zero
        for value in values {
            total += Decimal(value.kopecks)
        }
        if total >= Decimal(Int64.max) { return Money(kopecks: Int64.max) }
        if total <= Decimal(Int64.min) { return Money(kopecks: Int64.min) }
        return Money(kopecks: NSDecimalNumber(decimal: total).int64Value)
    }
    public static func < (lhs: Money, rhs: Money) -> Bool { lhs.kopecks < rhs.kopecks }
    public static func + (lhs: Money, rhs: Money) -> Money {
        let (sum, overflow) = lhs.kopecks.addingReportingOverflow(rhs.kopecks)
        guard overflow else { return Money(kopecks: sum) }
        return Money(kopecks: lhs.kopecks >= 0 ? Int64.max : Int64.min)
    }
    public static func - (lhs: Money, rhs: Money) -> Money {
        let (difference, overflow) = lhs.kopecks.subtractingReportingOverflow(rhs.kopecks)
        guard overflow else { return Money(kopecks: difference) }
        return Money(kopecks: lhs.kopecks >= 0 ? Int64.max : Int64.min)
    }
    public static prefix func - (value: Money) -> Money {
        value.kopecks == Int64.min ? Money(kopecks: Int64.max) : Money(kopecks: -value.kopecks)
    }
    public var decimalRubles: Decimal { Decimal(kopecks) / 100 }
    public var formatted: String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.numberStyle = .currency
        formatter.currencyCode = "RUB"
        return formatter.string(from: NSDecimalNumber(decimal: decimalRubles)) ?? "\(decimalRubles) ₽"
    }
}

/// Caps a planned debt installment at the last user-confirmed outstanding balance.
/// The recurring plan itself must remain open until the user confirms repayment.
public enum DebtRepaymentSchedule {
    public static func reservedInstallment(balance: Money, payment: Money) -> Money? {
        guard balance.kopecks > 0, payment.kopecks > 0 else { return nil }
        return Money(kopecks: min(balance.kopecks, payment.kopecks))
    }

    public static func matchesPlan(balance: Money, payment: Money, firstPaymentDate: Date,
                                   plan: ScheduledItem, linkedDebtCount: Int = 1) -> Bool {
        guard balance >= .zero, payment > .zero, linkedDebtCount == 1,
              firstPaymentDate.timeIntervalSince1970.isFinite,
              plan.isConfirmed, plan.kind == .debtRepayment, plan.recurrence == .monthly,
              plan.dueDate == firstPaymentDate else { return false }
        let expectedInstallment = balance == .zero ? payment : min(balance, payment)
        guard plan.amount == expectedInstallment else { return false }
        return balance == .zero ? plan.occurrencesRemaining == 0 : plan.occurrencesRemaining == nil
    }
}

public enum TransactionKind: String, Codable, CaseIterable, Sendable {
    case purchase, income, transfer, incomingTransfer, refund, fee, adjustment

    /// Unknown persisted kinds are neutral until a user or migration can classify them.
    /// Never turn an unrecognized row into a purchase that affects spending totals.
    public static func restoring(_ rawValue: String) -> TransactionKind {
        TransactionKind(rawValue: rawValue) ?? .adjustment
    }

    public var isOutflow: Bool { self == .purchase || self == .transfer || self == .fee }
    public var isInflow: Bool { self == .income || self == .incomingTransfer || self == .refund }
    public var defaultCategory: Category? {
        switch self {
        case .income: .income
        case .refund: .refunds
        case .transfer: .transfers
        case .incomingTransfer: .transfers
        case .fee: .fees
        case .purchase, .adjustment: nil
        }
    }
}

public enum TransactionStatus: String, Codable, CaseIterable, Sendable {
    case posted
    case pending

    /// Older persisted transactions did not have a status and are treated as posted.
    /// An unknown non-nil value fails closed so corrupt/newer data cannot enter finance totals.
    public static func restoring(_ rawValue: String?) -> TransactionStatus {
        guard let rawValue else { return .posted }
        return TransactionStatus(rawValue: rawValue) ?? .pending
    }

    /// Only an explicitly pending row may be promoted by a later statement import.
    /// Legacy nil status is posted, while an unknown raw value is ambiguous and must not be promoted.
    public static func canPromoteToPosted(fromStoredRawValue rawValue: String?) -> Bool {
        rawValue == TransactionStatus.pending.rawValue
    }

    public var title: String {
        switch self {
        case .posted: "Проведена"
        case .pending: "Ожидает проведения"
        }
    }
}

/// Toggles amount privacy after two distinct face-down flips within a short interval.
/// A visible face-up event must separate the two flips so repeated sensor notifications
/// cannot trigger the gesture twice.
public struct DoubleFlipPrivacyGesture: Sendable {
    private let maximumInterval: TimeInterval
    private var previousFaceDown: Bool?
    private var lastFaceDownAt: Date?

    public init(maximumInterval: TimeInterval = 3) {
        self.maximumInterval = maximumInterval.isFinite && maximumInterval > 0 ? maximumInterval : 3
    }

    public mutating func reset() {
        previousFaceDown = nil
        lastFaceDownAt = nil
    }

    /// Returns true on the second face-down transition; all other sensor events return false.
    public mutating func record(isFaceDown: Bool, at date: Date) -> Bool {
        guard let previousFaceDown else {
            self.previousFaceDown = isFaceDown
            return false
        }
        guard previousFaceDown != isFaceDown else { return false }
        self.previousFaceDown = isFaceDown
        guard isFaceDown else { return false }

        if let lastFaceDownAt,
           date >= lastFaceDownAt,
           date.timeIntervalSince(lastFaceDownAt) <= maximumInterval {
            self.lastFaceDownAt = nil
            return true
        }
        lastFaceDownAt = date
        return false
    }
}

public enum IncomeSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case parentSupport = "Поддержка от родителей"
    case other = "Другой доход"

    public var id: String { rawValue }

    public static func infer(from description: String) -> IncomeSource? {
        let tokens = description.lowercased().components(separatedBy: CharacterSet.letters.inverted)
        let mentionsParent = tokens.contains { token in
            token.hasPrefix("родител") || ["мама", "маме", "мамы", "мамой", "папа", "папе", "папы", "папой"].contains(token)
        }
        return mentionsParent ? .parentSupport : nil
    }
}

public enum Category: String, Codable, CaseIterable, Identifiable, Sendable {
    case housing, groceries, cafe, transport, health, subscriptions, shopping, entertainment
    case education, gifts, fees, transfers, refunds, income, other
    public var id: String { rawValue }
    /// Income, refunds, transfers, and bank fees have dedicated transaction kinds
    /// and must not be used to classify an ordinary purchase.
    public var supportsPurchaseClassification: Bool {
        switch self {
        case .income, .refunds, .transfers, .fees: false
        case .housing, .groceries, .cafe, .transport, .health, .subscriptions,
             .shopping, .entertainment, .education, .gifts, .other: true
        }
    }
    public var title: String {
        switch self {
        case .housing: "Жильё"; case .groceries: "Продукты"; case .cafe: "Кафе и доставка"
        case .transport: "Транспорт"; case .health: "Здоровье"; case .subscriptions: "Подписки"
        case .shopping: "Покупки"; case .entertainment: "Развлечения"; case .education: "Образование"
        case .gifts: "Подарки и помощь"; case .fees: "Комиссии"; case .transfers: "Переводы"
        case .refunds: "Возвраты"; case .income: "Доход"; case .other: "Другое"
        }
    }
}

public enum CategoryBudgetPolicy {
    public static func isValid(category: Category, limit: Money, periodStart: Date,
                               calendar: Calendar = .current) -> Bool {
        category.supportsPurchaseClassification && limit > .zero &&
            periodStart.timeIntervalSince1970.isFinite &&
            calendar.dateInterval(of: .month, for: periodStart) != nil
    }
}

public struct Transaction: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var date: Date
    public var merchant: String
    public var amount: Money
    public var kind: TransactionKind
    /// Nil decodes legacy serialized transactions as posted for backward compatibility.
    public var status: TransactionStatus?
    public var category: Category
    public var incomeSource: IncomeSource?
    public var note: String
    public var isInternalTransfer: Bool
    public var sourceID: String?
    /// Stable calendar/instant identity from a parsed statement date. Date-only and
    /// offset-free timestamps retain their original wall-clock fields across timezones.
    public var statementDateIdentity: String?
    /// Stable identifier supplied by the bank, when present in an imported statement.
    public var providerTransactionID: String?
    /// Explicit provider reference to the original operation for a refund.
    public var refundOfProviderTransactionID: String?
    /// Local transaction ID, populated only after an exact, unique, same-account match.
    public var refundOfTransactionID: UUID?
    public var isOutflow: Bool { kind.isOutflow }
    public var isPosted: Bool { status != .pending }
    public init(id: UUID = UUID(), date: Date = .now, merchant: String, amount: Money,
                kind: TransactionKind, category: Category = .other, incomeSource: IncomeSource? = nil, note: String = "",
                isInternalTransfer: Bool = false, sourceID: String? = nil,
                statementDateIdentity: String? = nil,
                status: TransactionStatus = .posted, providerTransactionID: String? = nil,
                refundOfProviderTransactionID: String? = nil, refundOfTransactionID: UUID? = nil) {
        self.id = id; self.date = date; self.merchant = merchant; self.amount = amount
        self.kind = kind; self.status = status; self.category = category; self.incomeSource = incomeSource; self.note = note
        self.isInternalTransfer = isInternalTransfer; self.sourceID = sourceID
        self.statementDateIdentity = statementDateIdentity
        self.providerTransactionID = providerTransactionID
        self.refundOfProviderTransactionID = refundOfProviderTransactionID
        self.refundOfTransactionID = refundOfTransactionID
    }
}

public struct ProviderTransactionCandidate: Sendable, Equatable {
    public let id: UUID
    public let accountID: UUID?
    public let providerTransactionID: String?
    public let kind: TransactionKind
    public let isInternalTransfer: Bool

    public init(id: UUID, accountID: UUID?, providerTransactionID: String?,
                kind: TransactionKind, isInternalTransfer: Bool) {
        self.id = id
        self.accountID = accountID
        self.providerTransactionID = providerTransactionID
        self.kind = kind
        self.isInternalTransfer = isInternalTransfer
    }
}

public enum RefundLinkResolver {
    /// Candidates must represent all existing and current-import transactions.
    /// An account-less import cannot establish a safe link across sources.
    public static func resolve(refund: Transaction, accountID: UUID?,
                               candidates: [ProviderTransactionCandidate]) -> UUID? {
        guard refund.kind == .refund, let accountID,
              let reference = refund.refundOfProviderTransactionID,
              !reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let matches = candidates.filter {
            $0.accountID == accountID && $0.providerTransactionID == reference &&
                $0.kind.isOutflow && !$0.isInternalTransfer
        }
        return matches.count == 1 ? matches[0].id : nil
    }
}

/// A confirmed internal-transfer pair must remain balanced and point in opposite directions.
/// If either operation changes amount, date, direction, or internal status, detach the pair.
public enum InternalTransferPairPolicy {
    public static func shouldDetach(original: Transaction, edited: Transaction) -> Bool {
        original.amount != edited.amount || original.date != edited.date ||
            original.kind != edited.kind || !edited.isInternalTransfer
    }
}

/// Merchant rules are learned from purchases and must not relabel refunds, income, or transfers.
public enum TransactionCategoryCorrection {
    public static func applying(_ category: Category, to transaction: Transaction) -> Transaction {
        guard transaction.kind == .purchase, category.supportsPurchaseClassification else { return transaction }
        var corrected = transaction
        corrected.category = category
        return corrected
    }
}

public struct ScheduledItem: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var amount: Money
    public var dueDate: Date
    public var isConfirmed: Bool
    public var kind: Kind
    public var recurrence: Recurrence
    public var occurrencesRemaining: Int?
    public var finalOccurrenceAmount: Money?
    public enum Kind: String, Codable, Sendable { case obligation, goalContribution, debtRepayment, subscription }
    public enum Recurrence: String, Codable, Sendable { case none, weekly, monthly, yearly }
    public init(id: UUID = UUID(), title: String, amount: Money, dueDate: Date,
                isConfirmed: Bool = true, kind: Kind = .obligation, recurrence: Recurrence = .none,
                occurrencesRemaining: Int? = nil, finalOccurrenceAmount: Money? = nil) {
        self.id = id; self.title = title; self.amount = amount; self.dueDate = dueDate
        self.isConfirmed = isConfirmed; self.kind = kind; self.recurrence = recurrence
        self.occurrencesRemaining = occurrencesRemaining; self.finalOccurrenceAmount = finalOccurrenceAmount
    }
}

/// One concrete occurrence of a scheduled item, with any confirmed partial payment deducted.
public struct PlannedOccurrence: Identifiable, Hashable, Sendable {
    public let id: String
    public let planID: UUID
    public let title: String
    public let amount: Money
    public let date: Date

    public init(planID: UUID, title: String, amount: Money, date: Date) {
        self.planID = planID
        self.title = title
        self.amount = amount
        self.date = date
        id = "\(planID.uuidString)-\(date.timeIntervalSince1970)"
    }
}

/// Shared calendar rules for planned-payment projections and local reminders.
public enum ScheduledRecurrence {
    /// Finds the first scheduled occurrence on or after a calendar day without replaying
    /// every past weekly/monthly/yearly recurrence. Finite plans respect their remaining count.
    public static func firstOccurrence(onOrAfter target: Date, of item: ScheduledItem,
                                       calendar: Calendar = .current) -> Date? {
        let anchor = item.dueDate
        let anchorDay = calendar.startOfDay(for: anchor)
        let targetDay = calendar.startOfDay(for: target)
        guard anchor.timeIntervalSince1970.isFinite, target.timeIntervalSince1970.isFinite else { return nil }
        if anchorDay >= targetDay {
            return occurrenceIndex(anchor, of: item, calendar: calendar) == nil ? nil : anchor
        }
        let anchorParts = calendar.dateComponents([.era, .year, .month, .day], from: anchor)
        let targetParts = calendar.dateComponents([.era, .year, .month, .day], from: targetDay)
        guard anchorParts.era == targetParts.era,
              let anchorYear = anchorParts.year, let targetYear = targetParts.year,
              let anchorMonth = anchorParts.month, let targetMonth = targetParts.month,
              let anchorDate = anchorParts.day else { return nil }

        let candidate: Date?
        switch item.recurrence {
        case .none:
            candidate = nil
        case .weekly:
            guard let elapsedDays = calendar.dateComponents([.day], from: anchorDay, to: targetDay).day else { return nil }
            let weeks = max(0, (elapsedDays + 6) / 7)
            var next = calendar.date(byAdding: .weekOfYear, value: weeks, to: anchor)
            if let value = next, calendar.startOfDay(for: value) < targetDay {
                next = calendar.date(byAdding: .weekOfYear, value: 1, to: value)
            }
            candidate = next
        case .monthly:
            let elapsedMonths = (targetYear - anchorYear) * 12 + targetMonth - anchorMonth
            var months = max(0, elapsedMonths)
            var next = anchoredMonthlyDate(anchor: anchor, monthOffset: months, day: anchorDate, calendar: calendar)
            if let value = next, calendar.startOfDay(for: value) < targetDay {
                months += 1
                next = anchoredMonthlyDate(anchor: anchor, monthOffset: months, day: anchorDate, calendar: calendar)
            }
            candidate = next
        case .yearly:
            var years = max(0, targetYear - anchorYear)
            var next = anchoredYearlyDate(anchor: anchor, yearOffset: years, day: anchorDate, calendar: calendar)
            if let value = next, calendar.startOfDay(for: value) < targetDay {
                years += 1
                next = anchoredYearlyDate(anchor: anchor, yearOffset: years, day: anchorDate, calendar: calendar)
            }
            candidate = next
        }
        guard let candidate,
              occurrenceIndex(candidate, of: item, calendar: calendar) != nil else { return nil }
        return candidate
    }

    private static func anchoredMonthlyDate(anchor: Date, monthOffset: Int, day: Int,
                                            calendar: Calendar) -> Date? {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.era, .year, .month], from: anchor)),
              let targetMonth = calendar.date(byAdding: .month, value: monthOffset, to: monthStart),
              let days = calendar.range(of: .day, in: .month, for: targetMonth) else { return nil }
        var components = calendar.dateComponents([.era, .year, .month], from: targetMonth)
        components.day = min(day, days.count)
        components.hour = calendar.component(.hour, from: anchor)
        components.minute = calendar.component(.minute, from: anchor)
        components.second = calendar.component(.second, from: anchor)
        return calendar.date(from: components)
    }

    private static func anchoredYearlyDate(anchor: Date, yearOffset: Int, day: Int,
                                           calendar: Calendar) -> Date? {
        guard let targetYearDate = calendar.date(byAdding: .year, value: yearOffset, to: anchor),
              let monthStart = calendar.date(from: calendar.dateComponents([.era, .year, .month], from: targetYearDate)),
              let days = calendar.range(of: .day, in: .month, for: monthStart) else { return nil }
        var components = calendar.dateComponents([.era, .year, .month], from: targetYearDate)
        components.day = min(day, days.count)
        components.hour = calendar.component(.hour, from: anchor)
        components.minute = calendar.component(.minute, from: anchor)
        components.second = calendar.component(.second, from: anchor)
        return calendar.date(from: components)
    }

    public static func occurrenceIndex(_ candidate: Date, of item: ScheduledItem,
                                       calendar: Calendar = .current) -> Int? {
        let candidateDay = calendar.startOfDay(for: candidate)
        let anchorDay = calendar.startOfDay(for: item.dueDate)
        guard candidateDay >= anchorDay else { return nil }
        let anchor = calendar.dateComponents([.era, .year, .month, .day], from: anchorDay)
        let date = calendar.dateComponents([.era, .year, .month, .day], from: candidateDay)
        guard anchor.era == date.era,
              let anchorYear = anchor.year, let year = date.year,
              let anchorMonth = anchor.month, let month = date.month,
              let anchorDate = anchor.day, let day = date.day else { return nil }

        let occurrenceIndex: Int
        switch item.recurrence {
        case .none:
            guard candidateDay == anchorDay else { return nil }
            occurrenceIndex = 0
        case .weekly:
            guard let days = calendar.dateComponents([.day], from: anchorDay, to: candidateDay).day,
                  days >= 0, days.isMultiple(of: 7) else { return nil }
            occurrenceIndex = days / 7
        case .monthly:
            let months = (year - anchorYear) * 12 + month - anchorMonth
            guard months >= 0,
                  let monthStart = calendar.date(from: DateComponents(era: date.era, year: year, month: month)),
                  let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart),
                  day == min(anchorDate, daysInMonth.count) else { return nil }
            occurrenceIndex = months
        case .yearly:
            let years = year - anchorYear
            guard years >= 0, month == anchorMonth,
                  let monthStart = calendar.date(from: DateComponents(era: date.era, year: year, month: month)),
                  let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart),
                  day == min(anchorDate, daysInMonth.count) else { return nil }
            occurrenceIndex = years
        }
        guard let remaining = item.occurrencesRemaining else { return occurrenceIndex }
        return remaining > 0 && occurrenceIndex < remaining ? occurrenceIndex : nil
    }

    public static func isOccurrence(_ candidate: Date, of item: ScheduledItem,
                                    calendar: Calendar = .current) -> Bool {
        occurrenceIndex(candidate, of: item, calendar: calendar) != nil
    }

    public static func amount(for candidate: Date, of item: ScheduledItem,
                              calendar: Calendar = .current) -> Money? {
        guard let index = occurrenceIndex(candidate, of: item, calendar: calendar) else { return nil }
        let regularAmount = max(.zero, item.amount)
        if let remaining = item.occurrencesRemaining, remaining > 0,
           index == remaining - 1, let finalAmount = item.finalOccurrenceAmount {
            return min(regularAmount, max(.zero, finalAmount))
        }
        return regularAmount
    }

    public static func nextDate(after date: Date, anchoredAt anchor: Date,
                                recurrence: ScheduledItem.Recurrence,
                                calendar: Calendar = .current) -> Date? {
        switch recurrence {
        case .none:
            return nil
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .monthly:
            guard let firstOfMonth = calendar.date(from: calendar.dateComponents([.era, .year, .month], from: date)),
                  let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstOfMonth),
                  let days = calendar.range(of: .day, in: .month, for: nextMonth) else { return nil }
            var components = calendar.dateComponents([.era, .year, .month], from: nextMonth)
            components.day = min(calendar.component(.day, from: anchor), days.count)
            components.hour = calendar.component(.hour, from: date)
            components.minute = calendar.component(.minute, from: date)
            components.second = calendar.component(.second, from: date)
            return calendar.date(from: components)
        case .yearly:
            guard let targetYear = calendar.date(byAdding: .year, value: 1, to: date) else { return nil }
            let era = calendar.component(.era, from: targetYear)
            let year = calendar.component(.year, from: targetYear)
            let anchorMonth = calendar.component(.month, from: anchor)
            let anchorDay = calendar.component(.day, from: anchor)
            guard let firstOfMonth = calendar.date(from: DateComponents(era: era, year: year,
                                                                        month: anchorMonth, day: 1)),
                  let days = calendar.range(of: .day, in: .month, for: firstOfMonth) else { return nil }
            var components = calendar.dateComponents([.era, .year], from: targetYear)
            components.month = anchorMonth
            components.day = min(anchorDay, days.count)
            components.hour = calendar.component(.hour, from: date)
            components.minute = calendar.component(.minute, from: date)
            components.second = calendar.component(.second, from: date)
            return calendar.date(from: components)
        }
    }
}

public struct GoalReserveAllocation: Codable, Sendable, Equatable {
    public let goalID: UUID
    public let amount: Money
    public init(goalID: UUID, amount: Money) { self.goalID = goalID; self.amount = amount }
}

public struct NamedReserveAllocation: Codable, Sendable, Equatable {
    public let amount: Money
    public let goalID: UUID?
    public let scheduledItemID: UUID?
    public let occurrenceDate: Date?

    public init(amount: Money, goalID: UUID? = nil, scheduledItemID: UUID? = nil,
                occurrenceDate: Date? = nil) {
        self.amount = amount
        self.goalID = goalID
        self.scheduledItemID = scheduledItemID
        self.occurrenceDate = occurrenceDate
    }
}

public struct ProtectedReserveTotals: Sendable, Equatable {
    public let goals: Money
    public let named: Money
    public init(goals: Money, named: Money) { self.goals = goals; self.named = named }
}

public enum IdentityIntegrity {
    public static func hasUniqueIdentifiers(_ identifiers: [UUID]) -> Bool {
        Set(identifiers).count == identifiers.count
    }
}

public enum ProtectedReserveAccounting {
    public static func totals(goals: [GoalReserveAllocation], namedReserves: [NamedReserveAllocation],
                              scheduledItems: [ScheduledItem], settlements: [ScheduledSettlement],
                              from start: Date, through end: Date,
                              calendar: Calendar = .current) -> ProtectedReserveTotals {
        let validGoals = Dictionary(grouping: goals, by: \.goalID)
        let validPlans = Dictionary(grouping: scheduledItems, by: \.id)
        var goalLinks: [UUID: Money] = [:]
        var planLinks: [OccurrenceKey: Money] = [:]
        var namedTotal = Money.zero

        for reserve in namedReserves where reserve.amount > .zero {
            if let goalID = reserve.goalID, reserve.scheduledItemID == nil,
               reserve.occurrenceDate == nil, validGoals[goalID]?.count == 1 {
                goalLinks[goalID, default: .zero] = goalLinks[goalID, default: .zero] + reserve.amount
            } else if let planID = reserve.scheduledItemID, let date = reserve.occurrenceDate,
                      reserve.goalID == nil, validPlans[planID]?.count == 1 {
                let key = OccurrenceKey(planID: planID, day: calendar.startOfDay(for: date))
                planLinks[key, default: .zero] = planLinks[key, default: .zero] + reserve.amount
            } else {
                namedTotal = namedTotal + reserve.amount
            }
        }

        var goalTotal = Money.zero
        for (goalID, allocations) in validGoals {
            if allocations.count == 1 {
                let saved = max(.zero, allocations[0].amount)
                let linked = goalLinks.removeValue(forKey: goalID) ?? .zero
                goalTotal = goalTotal + max(saved, linked)
            } else {
                // Ambiguous identities cannot safely consume a linked envelope. Preserve
                // every saved allocation independently so corruption never frees cash.
                goalTotal = goalTotal + Money.sum(allocations.map { max(.zero, $0.amount) })
            }
        }
        // Stale goal links are retained as standalone reserves rather than disappearing.
        namedTotal = namedTotal + Money.sum(goalLinks.values)

        for (key, reserveAmount) in planLinks {
            guard let planMatches = validPlans[key.planID], planMatches.count == 1,
                  let plan = planMatches.first,
                  plan.isConfirmed,
                  let occurrence = scheduledItems.first(where: { $0.id == key.planID }),
                  let occurrenceAmount = ScheduledRecurrence.amount(for: key.day, of: occurrence,
                      calendar: calendar),
                  start <= end,
                  calendar.startOfDay(for: key.day) >= calendar.startOfDay(for: start),
                  calendar.startOfDay(for: key.day) <= calendar.startOfDay(for: end) else {
                // A target outside the active forecast range or no longer valid remains
                // protected as a standalone envelope.
                namedTotal = namedTotal + reserveAmount
                continue
            }
            let remainingObligation = ScheduledSettlementPolicy.remainingAmount(for: plan,
                occurrenceDate: key.day, settlements: settlements, calendar: calendar)
            let settled = max(.zero, occurrenceAmount - remainingObligation)
            let remainingEnvelope = max(.zero, reserveAmount - settled)
            // The obligation itself is subtracted as a cash-flow event. Count only the
            // part of its linked envelope that exceeds that remaining obligation.
            namedTotal = namedTotal + max(.zero, remainingEnvelope - remainingObligation)
        }
        return ProtectedReserveTotals(goals: goalTotal, named: namedTotal)
    }

    private struct OccurrenceKey: Hashable {
        let planID: UUID
        let day: Date
    }
}

/// A user-confirmed link from one posted outflow to one occurrence of a planned item.
/// The transaction is never inferred from merchant, amount, or date alone.
public struct ScheduledSettlement: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var scheduledItemID: UUID
    public var occurrenceDate: Date
    public var transactionID: UUID
    public var amount: Money

    public init(id: UUID = UUID(), scheduledItemID: UUID, occurrenceDate: Date,
                transactionID: UUID, amount: Money) {
        self.id = id
        self.scheduledItemID = scheduledItemID
        self.occurrenceDate = occurrenceDate
        self.transactionID = transactionID
        self.amount = amount
    }
}

/// Deterministic rules for explicitly reconciling a posted transaction against a planned occurrence.
public enum ScheduledSettlementPolicy {
    /// Account-linked payments affect the plan only while their source account is part
    /// of the same financial snapshot. Manual operations without an account remain valid.
    public static func sourceAccountIsIncluded(_ accountID: UUID?, includedAccountIDs: Set<UUID>) -> Bool {
        guard let accountID else { return true }
        return includedAccountIDs.contains(accountID)
    }

    /// Finds the next scheduled occurrence that still has an unpaid amount.
    /// The search is bounded by the settlement count: every skipped occurrence
    /// must have at least one valid positive settlement.
    public static func firstUnsettledOccurrence(onOrAfter target: Date, of item: ScheduledItem,
                                                settlements: [ScheduledSettlement],
                                                calendar: Calendar = .current) -> Date? {
        guard item.amount > .zero,
              var occurrence = ScheduledRecurrence.firstOccurrence(onOrAfter: target, of: item,
                                                                    calendar: calendar) else { return nil }
        for _ in 0...settlements.count {
            if remainingAmount(for: item, occurrenceDate: occurrence, settlements: settlements,
                               calendar: calendar) > .zero {
                return occurrence
            }
            guard let next = ScheduledRecurrence.nextDate(after: occurrence, anchoredAt: item.dueDate,
                    recurrence: item.recurrence, calendar: calendar), next > occurrence,
                  ScheduledRecurrence.occurrenceIndex(next, of: item, calendar: calendar) != nil else {
                return nil
            }
            occurrence = next
        }
        return nil
    }

    public static func remainingAmount(for item: ScheduledItem, occurrenceDate: Date,
                                       settlements: [ScheduledSettlement],
                                       calendar: Calendar = .current) -> Money {
        let occurrenceAmount = ScheduledRecurrence.amount(for: occurrenceDate, of: item,
            calendar: calendar) ?? max(.zero, item.amount)
        let transactionUseCounts = Dictionary(grouping: settlements, by: \.transactionID).mapValues(\.count)
        let paid = settlements.lazy.filter {
            $0.scheduledItemID == item.id && calendar.isDate($0.occurrenceDate, inSameDayAs: occurrenceDate) &&
                ScheduledRecurrence.isOccurrence($0.occurrenceDate, of: item, calendar: calendar) &&
                transactionUseCounts[$0.transactionID] == 1 && $0.amount > .zero
        }.reduce(Money.zero) { $0 + $1.amount }
        return max(.zero, occurrenceAmount - paid)
    }

    /// Ensures a plan edit does not orphan already confirmed settlements. The caller
    /// should pass only currently validated settlements that must remain linked.
    public static func canPreserveSettlements(for item: ScheduledItem,
                                              settlements: [ScheduledSettlement],
                                              calendar: Calendar = .current) -> Bool {
        let relevant = settlements.filter { $0.scheduledItemID == item.id }
        guard Set(relevant.map(\.transactionID)).count == relevant.count else { return false }
        var accepted: [ScheduledSettlement] = []
        for settlement in relevant.sorted(by: {
            if $0.occurrenceDate != $1.occurrenceDate { return $0.occurrenceDate < $1.occurrenceDate }
            return $0.transactionID.uuidString < $1.transactionID.uuidString
        }) {
            guard settlement.amount > .zero,
                  ScheduledRecurrence.isOccurrence(settlement.occurrenceDate, of: item, calendar: calendar),
                  settlement.amount <= remainingAmount(for: item, occurrenceDate: settlement.occurrenceDate,
                      settlements: accepted, calendar: calendar) else { return false }
            accepted.append(settlement)
        }
        return true
    }

    public static func settledAmount(for item: ScheduledItem, occurrenceDate: Date,
                                     settlements: [ScheduledSettlement],
                                     calendar: Calendar = .current) -> Money {
        let occurrenceAmount = ScheduledRecurrence.amount(for: occurrenceDate, of: item,
            calendar: calendar) ?? max(.zero, item.amount)
        return max(.zero, occurrenceAmount - remainingAmount(for: item, occurrenceDate: occurrenceDate,
            settlements: settlements, calendar: calendar))
    }

    public static func makeSettlement(transaction: Transaction, item: ScheduledItem,
                                      occurrenceDate: Date, settlements: [ScheduledSettlement],
                                      calendar: Calendar = .current) -> ScheduledSettlement? {
        guard transaction.isPosted, transaction.isOutflow, !transaction.isInternalTransfer,
              transaction.amount > .zero,
              ScheduledRecurrence.isOccurrence(occurrenceDate, of: item, calendar: calendar),
              !settlements.contains(where: { $0.transactionID == transaction.id }) else { return nil }
        let remaining = remainingAmount(for: item, occurrenceDate: occurrenceDate,
                                        settlements: settlements, calendar: calendar)
        guard remaining > .zero, transaction.amount <= remaining else { return nil }
        return ScheduledSettlement(scheduledItemID: item.id, occurrenceDate: occurrenceDate,
                                    transactionID: transaction.id, amount: transaction.amount)
    }
}

public struct IncomeEvent: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var amount: Money
    public var date: Date
    public var isConfirmed: Bool
    public var source: Source
    public enum Source: String, Codable, Sendable { case parentSupport, other }
    public init(id: UUID = UUID(), title: String, amount: Money, date: Date,
                isConfirmed: Bool = false, source: Source = .other) {
        self.id = id; self.title = title; self.amount = amount; self.date = date
        self.isConfirmed = isConfirmed; self.source = source
    }
}

/// Expected income can define a planning horizon only after an explicit confirmation,
/// with a positive amount and a date strictly after the current moment.
public enum ExpectedIncomeConfirmation {
    public static func canConfirm(amount: Money, date: Date?, asOf now: Date,
                                  calendar: Calendar = .current) -> Bool {
        guard amount > .zero, let date,
              date.timeIntervalSince1970.isFinite, now.timeIntervalSince1970.isFinite else { return false }
        return calendar.startOfDay(for: date) > calendar.startOfDay(for: now)
    }

    /// The picker captures only a calendar date, so conservatively place the expected credit
    /// at the final second of that day rather than at midnight before same-day outflows.
    public static func forecastBoundary(for date: Date, calendar: Calendar = .current) -> Date? {
        guard date.timeIntervalSince1970.isFinite,
              let interval = calendar.dateInterval(of: .day, for: date) else { return nil }
        let boundary = interval.end.addingTimeInterval(-1)
        return boundary >= interval.start && boundary.timeIntervalSince1970.isFinite ? boundary : nil
    }

    public static func isConfirmed(explicitlyConfirmed: Bool, amount: Money, date: Date?, asOf now: Date,
                                   calendar: Calendar = .current) -> Bool {
        explicitlyConfirmed && canConfirm(amount: amount, date: date, asOf: now, calendar: calendar)
    }
}

public struct FinanceSnapshot: Codable, Sendable {
    public var bankBalances: [Money]
    public var currentBalance: Money { Money.sum(bankBalances) }
    public var protectedReserve: Money
    /// Named funds intentionally kept for specific future purposes; separate from the minimum balance floor.
    public var earmarkedReserve: Money
    public var goalReserve: Money
    public var scheduledItems: [ScheduledItem]
    public var scheduledSettlements: [ScheduledSettlement]
    public var incomes: [IncomeEvent]
    public var nextIncomeDate: Date?
    /// Whether the amount/date pair defining the planning horizon was explicitly confirmed.
    public var nextIncomeConfirmed: Bool
    public var forecastDailySpend: Money
    public var hasReliableSpendForecast: Bool
    /// False when persisted plan rows contain values that cannot be interpreted safely.
    public var hasValidPlanData: Bool
    public var dataUpdatedAt: Date?
    /// A known posted/imported operation is dated after the confirmed balance snapshot.
    /// Until the user reconciles the balance, safe-to-spend advice must fail closed.
    public var balanceReconciliationIssue: String?
    public var goalAllocations: [GoalReserveAllocation]
    public var namedReserveAllocations: [NamedReserveAllocation]
    public var usesReserveAllocations: Bool
    public init(bankBalances: [Money], protectedReserve: Money = .zero,
                scheduledItems: [ScheduledItem] = [], incomes: [IncomeEvent] = [],
                scheduledSettlements: [ScheduledSettlement] = [],
                nextIncomeConfirmed: Bool = false, nextIncomeDate: Date? = nil,
                forecastDailySpend: Money = .zero, hasReliableSpendForecast: Bool = true,
                hasValidPlanData: Bool = true,
                dataUpdatedAt: Date? = nil, balanceReconciliationIssue: String? = nil,
                goalReserve: Money = .zero, earmarkedReserve: Money = .zero,
                goalAllocations: [GoalReserveAllocation] = [],
                namedReserveAllocations: [NamedReserveAllocation] = [],
                usesReserveAllocations: Bool = false) {
        self.bankBalances = bankBalances; self.protectedReserve = protectedReserve
        self.earmarkedReserve = earmarkedReserve
        self.scheduledItems = scheduledItems; self.scheduledSettlements = scheduledSettlements
        self.incomes = incomes
        self.nextIncomeDate = nextIncomeDate; self.nextIncomeConfirmed = nextIncomeConfirmed
        self.forecastDailySpend = forecastDailySpend
        self.hasReliableSpendForecast = hasReliableSpendForecast
        self.hasValidPlanData = hasValidPlanData
        self.dataUpdatedAt = dataUpdatedAt; self.goalReserve = goalReserve
        self.balanceReconciliationIssue = balanceReconciliationIssue
        self.goalAllocations = goalAllocations
        self.namedReserveAllocations = namedReserveAllocations
        self.usesReserveAllocations = usesReserveAllocations
    }

    private enum CodingKeys: String, CodingKey {
        case bankBalances, protectedReserve, earmarkedReserve, goalReserve, scheduledItems
        case scheduledSettlements, incomes, nextIncomeDate, nextIncomeConfirmed
        case forecastDailySpend, hasReliableSpendForecast, hasValidPlanData, dataUpdatedAt
        case balanceReconciliationIssue
        case goalAllocations, namedReserveAllocations, usesReserveAllocations
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        bankBalances = try values.decodeIfPresent([Money].self, forKey: .bankBalances) ?? []
        protectedReserve = try values.decodeIfPresent(Money.self, forKey: .protectedReserve) ?? .zero
        earmarkedReserve = try values.decodeIfPresent(Money.self, forKey: .earmarkedReserve) ?? .zero
        goalReserve = try values.decodeIfPresent(Money.self, forKey: .goalReserve) ?? .zero
        scheduledItems = try values.decodeIfPresent([ScheduledItem].self, forKey: .scheduledItems) ?? []
        scheduledSettlements = try values.decodeIfPresent([ScheduledSettlement].self, forKey: .scheduledSettlements) ?? []
        incomes = try values.decodeIfPresent([IncomeEvent].self, forKey: .incomes) ?? []
        nextIncomeDate = try values.decodeIfPresent(Date.self, forKey: .nextIncomeDate)
        nextIncomeConfirmed = try values.decodeIfPresent(Bool.self, forKey: .nextIncomeConfirmed) ?? false
        forecastDailySpend = try values.decodeIfPresent(Money.self, forKey: .forecastDailySpend) ?? .zero
        // A missing confidence bit must fail closed: never treat incomplete data as a reliable forecast.
        hasReliableSpendForecast = try values.decodeIfPresent(Bool.self, forKey: .hasReliableSpendForecast) ?? false
        // Older snapshots did not carry this derived validation bit; their Codable enum values
        // were decoded strictly, so a decodable legacy snapshot has interpretable plan data.
        hasValidPlanData = try values.decodeIfPresent(Bool.self, forKey: .hasValidPlanData) ?? true
        dataUpdatedAt = try values.decodeIfPresent(Date.self, forKey: .dataUpdatedAt)
        balanceReconciliationIssue = try values.decodeIfPresent(String.self, forKey: .balanceReconciliationIssue)
        goalAllocations = try values.decodeIfPresent([GoalReserveAllocation].self, forKey: .goalAllocations) ?? []
        namedReserveAllocations = try values.decodeIfPresent([NamedReserveAllocation].self,
            forKey: .namedReserveAllocations) ?? []
        usesReserveAllocations = try values.decodeIfPresent(Bool.self, forKey: .usesReserveAllocations) ?? false
    }
}

public enum FinanceDataFreshness {
    public static let maximumAge: TimeInterval = 72 * 60 * 60

    /// A combined balance is only as current as its oldest included source.
    public static func oldestUpdateDate(_ sourceDates: [Date], fallback: Date? = nil) -> Date? {
        sourceDates.min() ?? fallback
    }

    /// A timestamp must be present, finite, not in the future, and within the freshness window.
    public static func isFresh(_ updatedAt: Date?, asOf now: Date, maximumAge: TimeInterval = maximumAge) -> Bool {
        guard let updatedAt, maximumAge.isFinite, maximumAge >= 0, updatedAt <= now else { return false }
        let age = now.timeIntervalSince(updatedAt)
        return age.isFinite && age <= maximumAge
    }
}

public enum FinancePlanningPolicy {
    public static let maximumChartDays = 90
    public static let maximumIncomeHorizonDays = 730

    /// Beyond this window a variable-spend estimate is too uncertain for a safe-to-spend verdict.
    /// It also bounds recurring-event expansion so a distant date cannot produce unbounded work.
    public static func supportsForecast(from start: Date, to end: Date,
                                        calendar: Calendar = .current) -> Bool {
        guard end > start,
              let maximumDate = calendar.date(byAdding: .day, value: maximumIncomeHorizonDays,
                                              to: calendar.startOfDay(for: start)) else {
            return false
        }
        return calendar.startOfDay(for: end) <= maximumDate
    }
}

public enum BalanceUpdatePolicy {
    /// A changed balance must be confirmed after editing before it can be marked current.
    public static func requiresConfirmation(valueChanged: Bool, explicitlyConfirmed: Bool) -> Bool {
        valueChanged && !explicitlyConfirmed
    }

    /// Configuration edits and unconfirmed balance edits never refresh a balance.
    public static func updatedAt(previous: Date?, explicitlyConfirmed: Bool, now: Date) -> Date? {
        explicitlyConfirmed ? now : previous
    }
}

public enum PurchaseVerdict: Sendable, Equatable {
    case canBuy(minimumBalance: Money)
    case canBuyWithChanges(minimumBalance: Money, shortfall: Money)
    case unsafe(shortfall: Money, date: Date?)
    case insufficientData(String)
}

public enum DailySpendingLimitResult: Sendable, Equatable {
    case calculated(Money)
    case unsafe(shortfall: Money, date: Date?)
    case insufficientData(String)
}

public struct PurchaseOption: Identifiable, Sendable {
    public var id: String
    public var title: String
    public var changedGoalContribution: Money
    public var verdict: PurchaseVerdict
}
