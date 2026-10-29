import Foundation

public struct SpendingForecaster: Sendable {
    public init() {}

    public func estimateDailySpend(_ transactions: [Transaction], endingAt now: Date = .now,
                                  windowDays: Int = 30, minimumTransactions: Int = 10,
                                  minimumCoverageDays: Int = 13, safetyMultiplier: Double = 1.15,
                                  excludingTransactionIDs: Set<UUID> = []) -> Money? {
        guard windowDays > 0, minimumTransactions > 0,
              minimumCoverageDays > 0, minimumCoverageDays <= windowDays,
              safetyMultiplier.isFinite, safetyMultiplier >= 1 else { return nil }
        let start = Calendar.current.date(byAdding: .day, value: -windowDays, to: now) ?? .distantPast
        let relevant = transactions.filter {
            $0.date >= start && $0.date <= now && $0.isPosted && $0.isOutflow && !$0.isInternalTransfer &&
                $0.amount > .zero && !excludingTransactionIDs.contains($0.id)
        }
        guard relevant.count >= minimumTransactions,
              let firstDate = relevant.map(\.date).min() else { return nil }
        let calendar = Calendar.current
        let firstDay = calendar.startOfDay(for: firstDate)
        let currentDay = calendar.startOfDay(for: now)
        let elapsedCalendarDays = calendar.dateComponents([.day], from: firstDay, to: currentDay).day ?? 0
        let coveredDays = max(1, min(windowDays, elapsedCalendarDays))
        guard coveredDays >= minimumCoverageDays else { return nil }
        let totalKopecks = relevant.reduce(Decimal.zero) { $0 + Decimal($1.amount.kopecks) }
        guard let multiplier = Decimal(string: String(safetyMultiplier), locale: Locale(identifier: "en_US_POSIX")),
              !multiplier.isNaN else { return Money(kopecks: Int64.max) }

        var total = totalKopecks
        var days = Decimal(coveredDays)
        var average = Decimal.zero
        guard NSDecimalDivide(&average, &total, &days, .plain) != .overflow,
              !average.isNaN else { return Money(kopecks: Int64.max) }
        var scaled = Decimal.zero
        var multiplierValue = multiplier
        guard NSDecimalMultiply(&scaled, &average, &multiplierValue, .plain) != .overflow,
              !scaled.isNaN else { return Money(kopecks: Int64.max) }
        if scaled >= Decimal(Int64.max) { return Money(kopecks: Int64.max) }

        var rounded = Decimal.zero
        NSDecimalRound(&rounded, &scaled, 0, .up)
        guard !rounded.isNaN, rounded >= .zero else { return Money(kopecks: Int64.max) }
        return Money(kopecks: NSDecimalNumber(decimal: rounded).int64Value)
    }
}
