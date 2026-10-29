import Foundation

public struct HypotheticalPurchase: Sendable, Equatable {
    public var amount: Money
    public var date: Date
    public var title: String

    public init(amount: Money, date: Date, title: String = "Покупка") {
        self.amount = amount
        self.date = date
        self.title = title
    }
}

public struct FinancialHorizon: Sendable, Equatable {
    public enum Confidence: Sendable, Equatable {
        case reliable
        case uncertain(String)
        case insufficient(String)
    }

    public struct Point: Sendable, Equatable, Identifiable {
        public var date: Date
        public var projectedBalance: Money
        public var availableAfterReserves: Money
        public var confirmedInflows: Money
        public var confirmedOutflows: Money
        public var isHypotheticalPurchaseDay: Bool
        public var id: Date { date }

        public init(date: Date, projectedBalance: Money, availableAfterReserves: Money,
                    confirmedInflows: Money, confirmedOutflows: Money, isHypotheticalPurchaseDay: Bool) {
            self.date = date
            self.projectedBalance = projectedBalance
            self.availableAfterReserves = availableAfterReserves
            self.confirmedInflows = confirmedInflows
            self.confirmedOutflows = confirmedOutflows
            self.isHypotheticalPurchaseDay = isHypotheticalPurchaseDay
        }
    }

    public var days: Int
    public var points: [Point]
    public var confidence: Confidence
    public var hypotheticalPurchase: HypotheticalPurchase?

    public init(days: Int, points: [Point], confidence: Confidence,
                hypotheticalPurchase: HypotheticalPurchase? = nil) {
        self.days = days
        self.points = points
        self.confidence = confidence
        self.hypotheticalPurchase = hypotheticalPurchase
    }
}
