import Foundation

public struct RecurringCandidate: Identifiable, Sendable {
    public var id: String
    public var title: String
    public var amount: Money
    public var recurrence: ScheduledItem.Recurrence
    public var nextDate: Date
    public var observedCount: Int
}

public struct RecurringDetector: Sendable {
    public init() {}

    /// Prevents repeated statement imports from adding the same inferred subscription again.
    /// The amount tolerance mirrors the detector's own recurring-amount consistency rule.
    public func matchesExistingPlan(_ candidate: RecurringCandidate, plan: ScheduledItem) -> Bool {
        let planMerchant = Self.normalizedMerchant(plan.title)
        let candidateMerchant = Self.normalizedMerchant(candidate.title)
        guard plan.kind == .subscription, plan.recurrence == candidate.recurrence,
              !planMerchant.isEmpty, planMerchant == candidateMerchant,
              candidate.amount > .zero, plan.amount > .zero else { return false }
        let difference = candidate.amount.kopecks >= plan.amount.kopecks
            ? candidate.amount.kopecks - plan.amount.kopecks
            : plan.amount.kopecks - candidate.amount.kopecks
        let tolerance = max(Int64(1_000), candidate.amount.kopecks / 10)
        return difference <= tolerance
    }

    public func detect(_ transactions: [Transaction], calendar: Calendar = .current) -> [RecurringCandidate] {
        let groups = Dictionary(grouping: transactions.filter {
            $0.isPosted && $0.isOutflow && !$0.isInternalTransfer && $0.amount > .zero
        }) {
            Self.normalizedMerchant($0.merchant)
        }
        return groups.compactMap { key, rows in
            guard !key.isEmpty else { return nil }
            let ordered = rows.sorted { $0.date < $1.date }
            guard ordered.count >= 3,
                  let recurrence = classify(ordered.map(\.date), calendar: calendar) else { return nil }
            let amounts = ordered.map { $0.amount.kopecks }.sorted()
            let median = amounts[amounts.count / 2]
            guard amounts.allSatisfy({ abs($0 - median) <= max(1_000, median / 10) }) else { return nil }
            guard let first = ordered.first, let last = ordered.last else { return nil }
            let next = ScheduledRecurrence.nextDate(after: last.date, anchoredAt: first.date,
                recurrence: recurrence, calendar: calendar) ?? last.date
            return RecurringCandidate(id: key, title: last.merchant, amount: Money(kopecks: median),
                                      recurrence: recurrence, nextDate: next, observedCount: ordered.count)
        }.sorted { $0.nextDate < $1.nextDate }
    }

    private static func normalizedMerchant(_ merchant: String) -> String {
        merchant.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func classify(_ dates: [Date], calendar: Calendar) -> ScheduledItem.Recurrence? {
        guard dates.count >= 3 else { return nil }
        let intervals = zip(dates, dates.dropFirst()).map { ($0, $1) }
        let monthly = intervals.allSatisfy { first, second in
            guard let expected = calendar.date(byAdding: .month, value: 1, to: first) else { return false }
            return abs(second.timeIntervalSince(expected)) <= 4 * 86_400
        }
        if monthly { return .monthly }
        let weekly = intervals.allSatisfy { first, second in
            guard let expected = calendar.date(byAdding: .day, value: 7, to: first) else { return false }
            return abs(second.timeIntervalSince(expected)) <= 1.5 * 86_400
        }
        return weekly ? .weekly : nil
    }

}
