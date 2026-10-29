import Foundation

public struct DailySpending: Identifiable, Sendable, Equatable {
    public let date: Date
    public let amount: Money
    public var id: Date { date }
}

public struct CategorySpending: Identifiable, Sendable, Equatable {
    public let category: Category
    public let amount: Money
    public var id: Category { category }
}

public struct SpendingAnalyticsSummary: Sendable, Equatable {
    public let total: Money
    public let transactionCount: Int
    public let daily: [DailySpending]
    public let categories: [CategorySpending]
}

public struct SpendingPeriodComparison: Sendable, Equatable {
    public let currentTotal: Money
    public let previousTotal: Money

    public var difference: Money { currentTotal - previousTotal }
}

public struct IncomeCyclePeriods: Sendable, Equatable {
    public let current: DateInterval
    public let previousComparable: DateInterval?
}

public enum SpendingAnalytics {
    /// Finds the latest two posted income events and compares equal elapsed portions
    /// of the current and preceding income cycles. Refunds and confirmed internal transfers
    /// never establish an income-cycle boundary.
    public static func incomeCyclePeriods(
        _ transactions: [Transaction],
        asOf date: Date,
        calendar: Calendar = .current
    ) -> IncomeCyclePeriods? {
        let postedIncomeDates = transactions.compactMap { transaction -> Date? in
            guard (transaction.kind == .income || transaction.kind == .incomingTransfer),
                  transaction.isPosted,
                  !transaction.isInternalTransfer,
                  transaction.amount > .zero,
                  transaction.date <= date else { return nil }
            return transaction.date
        }
        // Multiple deposits on one calendar day form one boundary, not multiple cycles.
        let incomeDates = Dictionary(grouping: postedIncomeDates, by: { calendar.startOfDay(for: $0) })
            .values.compactMap { $0.min() }.sorted(by: >)
        guard let latestIncome = incomeDates.first else { return nil }
        // The current interval ends at the calculation time, not tomorrow midnight.
        // The dashboard can then compare genuinely equal elapsed portions of both cycles.
        let current = DateInterval(start: latestIncome, end: date)
        guard latestIncome < date, incomeDates.count > 1 else {
            return IncomeCyclePeriods(current: current, previousComparable: nil)
        }

        let previousIncome = incomeDates[1]
        let elapsed = date.timeIntervalSince(latestIncome)
        guard elapsed.isFinite, elapsed > 0 else { return IncomeCyclePeriods(current: current, previousComparable: nil) }
        let unclampedEnd = previousIncome.addingTimeInterval(elapsed)
        let previousEnd = min(unclampedEnd, latestIncome)
        let previous = previousIncome < previousEnd ? DateInterval(start: previousIncome, end: previousEnd) : nil
        return IncomeCyclePeriods(current: current, previousComparable: previous)
    }

    /// Returns the previous calendar month through the same day number as the current date,
    /// clamped to that month's final day. The end is exclusive.
    public static func previousMonthToDateInterval(for date: Date, calendar: Calendar = .current) -> DateInterval? {
        let day = calendar.component(.day, from: date)
        guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: date),
              let start = calendar.dateInterval(of: .month, for: previousMonth)?.start,
              let dayRange = calendar.range(of: .day, in: .month, for: previousMonth),
              let end = calendar.date(byAdding: .day, value: min(day, dayRange.count), to: start),
              start < end else { return nil }
        return DateInterval(start: start, end: end)
    }

    /// Returns the immediately preceding interval with the same number of calendar days,
    /// only when that complete interval is inside the available history window.
    public static func previousEqualLengthInterval(before current: DateInterval,
                                                   earliestAvailableDate: Date,
                                                   calendar: Calendar = .current) -> DateInterval? {
        guard current.start < current.end,
              let days = calendar.dateComponents([.day], from: current.start, to: current.end).day,
              days > 0,
              let previousStart = calendar.date(byAdding: .day, value: -days, to: current.start),
              previousStart >= earliestAvailableDate else { return nil }
        return DateInterval(start: previousStart, end: current.start)
    }

    /// Returns posted outflows using the same eligibility rules as the dashboard.
    /// The interval is half-open: [start, end).
    public static func totalOutflow(
        _ transactions: [Transaction],
        from start: Date,
        to end: Date,
        category: Category? = nil,
        asOf date: Date? = nil
    ) -> Money {
        guard start < end else { return .zero }
        return eligibleOutflows(transactions, from: start, to: end, category: category, asOf: date)
            .reduce(.zero) { $0 + $1.amount }
    }

    /// Compares two half-open periods using the same outflow rules as dashboard analytics.
    public static func compare(
        _ transactions: [Transaction],
        current: DateInterval,
        previous: DateInterval,
        asOf date: Date? = nil
    ) -> SpendingPeriodComparison? {
        guard current.start < current.end, previous.start < previous.end else { return nil }
        return SpendingPeriodComparison(
            currentTotal: totalOutflow(transactions, from: current.start, to: current.end, asOf: date),
            previousTotal: totalOutflow(transactions, from: previous.start, to: previous.end, asOf: date)
        )
    }

    /// Summarizes posted outflows in the half-open interval [start, end).
    /// Confirmed internal transfers and non-outflow operations are excluded.
    public static func summarize(
        _ transactions: [Transaction],
        from start: Date,
        to end: Date,
        calendar: Calendar = .current,
        asOf date: Date? = nil
    ) -> SpendingAnalyticsSummary {
        guard start < end else {
            return SpendingAnalyticsSummary(total: .zero, transactionCount: 0, daily: [], categories: [])
        }

        let purchases = eligibleOutflows(transactions, from: start, to: end, asOf: date)
        var dailyTotals: [Date: Money] = [:]
        var categoryTotals: [Category: Money] = [:]
        var total = Money.zero

        for transaction in purchases {
            let day = calendar.startOfDay(for: transaction.date)
            dailyTotals[day] = (dailyTotals[day] ?? .zero) + transaction.amount
            categoryTotals[transaction.category] = (categoryTotals[transaction.category] ?? .zero) + transaction.amount
            total = total + transaction.amount
        }

        var daily: [DailySpending] = []
        var day = calendar.startOfDay(for: start)
        while day < end {
            daily.append(DailySpending(date: day, amount: dailyTotals[day, default: .zero]))
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day), nextDay > day else { break }
            day = nextDay
        }

        let categories = categoryTotals
            .map { CategorySpending(category: $0.key, amount: $0.value) }
            .sorted {
                if $0.amount != $1.amount { return $0.amount > $1.amount }
                return $0.category.title.localizedStandardCompare($1.category.title) == .orderedAscending
            }

        return SpendingAnalyticsSummary(total: total, transactionCount: purchases.count,
                                        daily: daily, categories: categories)
    }

    private static func eligibleOutflows(
        _ transactions: [Transaction],
        from start: Date,
        to end: Date,
        category: Category? = nil,
        asOf date: Date? = nil
    ) -> [Transaction] {
        transactions.filter { transaction in
            transaction.date >= start && transaction.date < end && transaction.isOutflow &&
            transaction.isPosted && !transaction.isInternalTransfer && transaction.amount > .zero &&
            (date.map { transaction.date <= $0 } ?? true) &&
            (category == nil || transaction.category == category)
        }
    }
}
