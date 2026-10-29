import Foundation
import MoneyCore

func verify(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError("CHECK FAILED: \(message)") }
    print("PASS: \(message)")
}

func runChecks() {
        let accountID = UUID()
        verify(IdentityIntegrity.hasUniqueIdentifiers([]) &&
               IdentityIntegrity.hasUniqueIdentifiers([accountID, UUID()]) &&
               !IdentityIntegrity.hasUniqueIdentifiers([accountID, accountID]),
               "identity integrity accepts unique identifiers and rejects duplicates")
        var horizonCalendar = Calendar(identifier: .gregorian)
        horizonCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let horizonNow = horizonCalendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 12))!
        let startOfToday = horizonCalendar.startOfDay(for: horizonNow)
        let startOfTomorrow = horizonCalendar.date(byAdding: .day, value: 1, to: startOfToday)!
        verify(!ExpectedIncomeConfirmation.canConfirm(amount: Money(rubles: 500), date: startOfToday,
                   asOf: horizonNow),
               "date-only income scheduled for today cannot be confirmed before it is received")
        let laterToday = startOfToday.addingTimeInterval(23 * 3_600)
        verify(!ExpectedIncomeConfirmation.canConfirm(amount: Money(rubles: 500), date: laterToday,
                   asOf: horizonNow, calendar: horizonCalendar),
               "date-only income remains unconfirmable even when its stored time is later today")
        verify(ExpectedIncomeConfirmation.canConfirm(amount: Money(rubles: 500), date: startOfTomorrow,
                   asOf: horizonNow) &&
               ExpectedIncomeConfirmation.isConfirmed(explicitlyConfirmed: true, amount: Money(rubles: 500),
                   date: startOfTomorrow, asOf: horizonNow),
               "positive expected income on a future date can define the planning horizon after confirmation")
        verify(!ExpectedIncomeConfirmation.isConfirmed(explicitlyConfirmed: false, amount: Money(rubles: 500),
                   date: startOfTomorrow, asOf: horizonNow) &&
               !ExpectedIncomeConfirmation.canConfirm(amount: .zero, date: startOfTomorrow, asOf: horizonNow),
               "expected income requires both explicit confirmation and a positive amount")
        let expectedBoundary = ExpectedIncomeConfirmation.forecastBoundary(for: startOfTomorrow, calendar: horizonCalendar)
        let tomorrowInterval = horizonCalendar.dateInterval(of: .day, for: startOfTomorrow)!
        verify(expectedBoundary == tomorrowInterval.end.addingTimeInterval(-1),
               "date-only expected income is conservatively forecast at the end of its selected day")
        let horizonIncomeDate = horizonCalendar.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: 9))!
        let horizonPaymentDate = horizonCalendar.date(from: DateComponents(year: 2026, month: 10, day: 2, hour: 8))!
        let horizonSnapshot = FinanceSnapshot(bankBalances: [Money(rubles: 10_000)],
            protectedReserve: Money(rubles: 1_000),
            scheduledItems: [ScheduledItem(title: "Аренда", amount: Money(rubles: 2_000), dueDate: horizonPaymentDate)],
            incomes: [IncomeEvent(title: "Зарплата", amount: Money(rubles: 5_000), date: horizonIncomeDate, isConfirmed: true),
                      IncomeEvent(title: "Не подтверждено", amount: Money(rubles: 99_000), date: horizonIncomeDate, isConfirmed: false)],
            forecastDailySpend: Money(rubles: 100), dataUpdatedAt: horizonNow, goalReserve: Money(rubles: 500))
        let horizonEngine = FinanceEngine()
        let baselineHorizon = horizonEngine.horizon(horizonSnapshot, days: 7, now: horizonNow, calendar: horizonCalendar)
        verify(baselineHorizon.points.count == 8 && baselineHorizon.days == 7,
               "financial horizon returns the current balance and seven daily projection points")
        verify(baselineHorizon.points.first?.date == horizonNow &&
               baselineHorizon.points.last?.date == horizonCalendar.date(byAdding: .day, value: 7, to: horizonNow),
               "financial horizon spans exactly seven calendar days from the current timestamp")
        var pacificCalendar = Calendar(identifier: .gregorian)
        pacificCalendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let pacificNow = pacificCalendar.date(from: DateComponents(year: 2026, month: 11, day: 29, hour: 23, minute: 30))!
        let pacificMonthlyDue = pacificCalendar.date(from: DateComponents(year: 2026, month: 11, day: 1))!
        let pacificHorizon = horizonEngine.horizon(FinanceSnapshot(bankBalances: [Money(rubles: 5_000)],
            scheduledItems: [ScheduledItem(title: "Платёж после перехода времени", amount: Money(rubles: 100),
                dueDate: pacificMonthlyDue, recurrence: .monthly)], forecastDailySpend: .zero,
            dataUpdatedAt: pacificNow), days: 2, now: pacificNow, calendar: pacificCalendar)
        verify(pacificHorizon.points[1].confirmedOutflows == .zero &&
               pacificHorizon.points[2].confirmedOutflows == Money(rubles: 100),
               "financial horizon expands recurring events in the projection timezone across a DST transition")
        let exactBoundary = horizonCalendar.date(byAdding: .day, value: 1, to: horizonNow)!
        let boundaryHorizon = horizonEngine.horizon(FinanceSnapshot(
            bankBalances: [Money(rubles: 10_000)],
            scheduledItems: [ScheduledItem(title: "Платёж на границе дня", amount: Money(rubles: 1_000),
                                           dueDate: exactBoundary)],
            forecastDailySpend: .zero, dataUpdatedAt: horizonNow),
            days: 2, now: horizonNow, calendar: horizonCalendar)
        verify(boundaryHorizon.points[1].date == exactBoundary &&
               boundaryHorizon.points[1].confirmedOutflows == Money(rubles: 1_000) &&
               boundaryHorizon.points[1].projectedBalance == Money(rubles: 9_000),
               "financial horizon applies a payment exactly at the day boundary to that day's point")
        verify(abs((baselineHorizon.points.last?.projectedBalance.kopecks ?? 0) - Money(rubles: 12_300).kopecks) < 100,
               "financial horizon applies ordinary spend, confirmed obligation and confirmed income")
        verify(abs((baselineHorizon.points.last?.availableAfterReserves.kopecks ?? 0) - Money(rubles: 10_800).kopecks) < 100,
               "financial horizon separates projected balance from protected and goal reserves")
        let historicalMonthlyPlan = ScheduledItem(title: "Подписка", amount: Money(rubles: 1_000),
            dueDate: horizonCalendar.date(from: DateComponents(year: 2026, month: 8, day: 1, hour: 12))!,
            recurrence: .monthly)
        let currentOccurrenceSettlement = ScheduledSettlement(scheduledItemID: historicalMonthlyPlan.id,
            occurrenceDate: horizonNow, transactionID: UUID(), amount: Money(rubles: 100))
        let upcomingEnd = horizonCalendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 12))!
        let unconfirmedOneOff = ScheduledItem(title: "Не подтверждено", amount: Money(rubles: 500),
            dueDate: horizonPaymentDate, isConfirmed: false)
        let upcoming = horizonEngine.upcomingOccurrences(FinanceSnapshot(bankBalances: [],
            scheduledItems: [historicalMonthlyPlan, unconfirmedOneOff],
            scheduledSettlements: [currentOccurrenceSettlement]), from: horizonNow,
            through: upcomingEnd,
            calendar: horizonCalendar)
        verify(upcoming.count == 2 && upcoming[0].date == horizonNow &&
               upcoming[0].amount == Money(rubles: 900) &&
               upcoming[1].date == horizonCalendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 12)) &&
               upcoming[1].amount == Money(rubles: 1_000),
               "upcoming payment list expands old recurring plans and deducts partial settlements")
        verify(upcoming.last?.date == upcomingEnd,
               "upcoming payment list includes an obligation exactly on the next-income boundary")
        let scenario = HypotheticalPurchase(amount: Money(rubles: 1_200), date: horizonPaymentDate, title: "Ноутбук")
        let scenarioHorizon = horizonEngine.horizon(horizonSnapshot, days: 7, hypotheticalPurchase: scenario,
                                                     now: horizonNow, calendar: horizonCalendar)
        verify(abs((scenarioHorizon.points.last?.projectedBalance.kopecks ?? 0) - Money(rubles: 11_100).kopecks) < 100 &&
               scenarioHorizon.hypotheticalPurchase == scenario,
               "hypothetical purchase changes only its read-only projection")
        verify(horizonSnapshot.scheduledItems.count == 1 && horizonSnapshot.scheduledItems[0].title == "Аренда",
               "hypothetical purchase does not mutate scheduled items or actual transaction data")
        let todayStart = horizonCalendar.startOfDay(for: horizonNow)
        let todayScenario = horizonEngine.horizon(horizonSnapshot, days: 7,
            hypotheticalPurchase: HypotheticalPurchase(amount: Money(rubles: 200), date: todayStart),
            now: horizonNow, calendar: horizonCalendar)
        let expectedTodayScenarioBalance = (scenarioHorizon.points.last?.projectedBalance ?? .zero) + Money(rubles: 1_000)
        verify(todayScenario.points.last?.projectedBalance == expectedTodayScenarioBalance,
               "a date-only hypothetical purchase selected for today is applied from the current time")
        let earmarkNow = horizonCalendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!
        let earmarkSnapshot = FinanceSnapshot(bankBalances: [Money(rubles: 10_000)],
            protectedReserve: Money(rubles: 1_000), nextIncomeConfirmed: true, nextIncomeDate: earmarkNow.addingTimeInterval(7 * 86_400),
            forecastDailySpend: .zero, hasReliableSpendForecast: true, dataUpdatedAt: earmarkNow,
            goalReserve: Money(rubles: 500), earmarkedReserve: Money(rubles: 1_500))
        verify(FinanceEngine().availableNow(earmarkSnapshot, now: earmarkNow) == Money(rubles: 7_000),
               "named reserves reduce the free balance alongside the separate minimum and goal reserves")
        verify(FinanceEngine().checkPurchase(Money(rubles: 8_000), snapshot: earmarkSnapshot, now: earmarkNow) ==
               .unsafe(shortfall: Money(rubles: 1_000), date: earmarkNow),
               "purchase safety checks include named reserves without changing the base reserve floor")
        let overlapDate = horizonCalendar.date(from: DateComponents(year: 2026, month: 10, day: 3))!
        let overlapPlanID = UUID()
        let overlapGoalID = UUID()
        let overlapPlan = ScheduledItem(id: overlapPlanID, title: "Платёж", amount: Money(rubles: 1_000),
            dueDate: overlapDate, isConfirmed: true)
        let overlapGoal = GoalReserveAllocation(goalID: overlapGoalID, amount: Money(rubles: 1_000))
        let overlapTotals = ProtectedReserveAccounting.totals(goals: [overlapGoal], namedReserves: [
            NamedReserveAllocation(amount: Money(rubles: 700), goalID: overlapGoalID),
            NamedReserveAllocation(amount: Money(rubles: 1_300), scheduledItemID: overlapPlanID, occurrenceDate: overlapDate)
        ], scheduledItems: [overlapPlan], settlements: [], from: horizonNow, through: overlapDate,
            calendar: horizonCalendar)
        verify(overlapTotals.goals == Money(rubles: 1_000) && overlapTotals.named == Money(rubles: 300),
               "linked goal reserves avoid double counting while linked payment envelopes count only excess")
        let ambiguousGoalTotals = ProtectedReserveAccounting.totals(goals: [
            GoalReserveAllocation(goalID: overlapGoalID, amount: Money(rubles: 500)),
            GoalReserveAllocation(goalID: overlapGoalID, amount: Money(rubles: 400))
        ], namedReserves: [NamedReserveAllocation(amount: Money(rubles: 300), goalID: overlapGoalID)],
            scheduledItems: [], settlements: [], from: horizonNow, through: overlapDate,
            calendar: horizonCalendar)
        verify(ambiguousGoalTotals.goals == Money(rubles: 900) &&
               ambiguousGoalTotals.named == Money(rubles: 300),
               "ambiguous goal identifiers preserve each saved reserve and keep linked envelopes independent")
        let linkedEnvelopeSnapshot = FinanceSnapshot(bankBalances: [Money(rubles: 5_000)],
            scheduledItems: [overlapPlan], nextIncomeConfirmed: true,
            nextIncomeDate: horizonCalendar.date(from: DateComponents(year: 2026, month: 10, day: 10))!,
            forecastDailySpend: .zero, dataUpdatedAt: horizonNow,
            namedReserveAllocations: [NamedReserveAllocation(amount: Money(rubles: 1_300),
                scheduledItemID: overlapPlanID, occurrenceDate: overlapDate)], usesReserveAllocations: true)
        verify(FinanceEngine().availableNow(linkedEnvelopeSnapshot, now: horizonNow) == Money(rubles: 3_700),
               "a linked payment reserve protects only the amount beyond the scheduled cash outflow")
        verify(FinanceEngine().upcomingOccurrences(linkedEnvelopeSnapshot, from: horizonNow, through: overlapDate,
               calendar: horizonCalendar).map(\.amount) == [Money(rubles: 1_000)],
               "a payment remains visible on its due date when its reserve already covers the obligation")
        let repeatedLinksTotals = ProtectedReserveAccounting.totals(goals: [overlapGoal], namedReserves: [
            NamedReserveAllocation(amount: Money(rubles: 500), goalID: overlapGoalID),
            NamedReserveAllocation(amount: Money(rubles: 700), goalID: overlapGoalID),
            NamedReserveAllocation(amount: Money(rubles: 1_300), scheduledItemID: overlapPlanID, occurrenceDate: overlapDate),
            NamedReserveAllocation(amount: Money(rubles: 200), scheduledItemID: overlapPlanID, occurrenceDate: overlapDate)
        ], scheduledItems: [overlapPlan], settlements: [], from: horizonNow, through: overlapDate,
            calendar: horizonCalendar)
        verify(repeatedLinksTotals.goals == Money(rubles: 1_200) && repeatedLinksTotals.named == Money(rubles: 500),
               "multiple envelopes on the same goal and payment aggregate without losing excess protection")
        let settledOverlap = ScheduledSettlement(scheduledItemID: overlapPlanID, occurrenceDate: overlapDate,
            transactionID: UUID(), amount: Money(rubles: 400))
        let settledTotals = ProtectedReserveAccounting.totals(goals: [], namedReserves: [
            NamedReserveAllocation(amount: Money(rubles: 1_000), scheduledItemID: overlapPlanID, occurrenceDate: overlapDate)
        ], scheduledItems: [overlapPlan], settlements: [settledOverlap], from: horizonNow,
            through: overlapDate, calendar: horizonCalendar)
        verify(settledTotals.named == .zero,
               "linked payment envelope tracks a partial settlement without duplicating remaining obligation")
        let fullySettledTotals = ProtectedReserveAccounting.totals(goals: [], namedReserves: [
            NamedReserveAllocation(amount: Money(rubles: 1_300), scheduledItemID: overlapPlanID, occurrenceDate: overlapDate)
        ], scheduledItems: [overlapPlan], settlements: [
            ScheduledSettlement(scheduledItemID: overlapPlanID, occurrenceDate: overlapDate,
                transactionID: UUID(), amount: Money(rubles: 1_000))
        ], from: horizonNow, through: overlapDate, calendar: horizonCalendar)
        verify(fullySettledTotals.named == Money(rubles: 300),
               "fully settled payment releases the obligation amount while preserving envelope excess")
        let outOfWindowTotals = ProtectedReserveAccounting.totals(goals: [], namedReserves: [
            NamedReserveAllocation(amount: Money(rubles: 1_000), scheduledItemID: overlapPlanID, occurrenceDate: overlapDate)
        ], scheduledItems: [overlapPlan], settlements: [], from: horizonNow,
            through: horizonCalendar.date(byAdding: .day, value: 1, to: horizonNow)!, calendar: horizonCalendar)
        verify(outOfWindowTotals.named == Money(rubles: 1_000),
               "linked payment envelope stays protected when its occurrence is outside the active forecast window")
        let finalDate = horizonCalendar.date(from: DateComponents(year: 2026, month: 11, day: 3))!
        var finalPlan = ScheduledItem(id: UUID(), title: "Последний взнос", amount: Money(rubles: 300),
            dueDate: overlapDate, isConfirmed: true, recurrence: .monthly, occurrencesRemaining: 2,
            finalOccurrenceAmount: Money(rubles: 100))
        let finalOccurrenceTotals = ProtectedReserveAccounting.totals(goals: [], namedReserves: [
            NamedReserveAllocation(amount: Money(rubles: 150), scheduledItemID: finalPlan.id, occurrenceDate: finalDate)
        ], scheduledItems: [finalPlan], settlements: [], from: horizonNow, through: finalDate,
            calendar: horizonCalendar)
        verify(finalOccurrenceTotals.named == Money(rubles: 50),
               "linked payment reserve uses the shortened final installment amount")
        finalPlan.isConfirmed = false
        let unconfirmedTotals = ProtectedReserveAccounting.totals(goals: [], namedReserves: [
            NamedReserveAllocation(amount: Money(rubles: 150), scheduledItemID: finalPlan.id, occurrenceDate: finalDate)
        ], scheduledItems: [finalPlan], settlements: [], from: horizonNow, through: finalDate,
            calendar: horizonCalendar)
        verify(unconfirmedTotals.named == Money(rubles: 150),
               "unconfirmed linked payment retains its reserve as an independent protected amount")
        let invalidOccurrenceTotals = ProtectedReserveAccounting.totals(goals: [], namedReserves: [
            NamedReserveAllocation(amount: Money(rubles: 150), scheduledItemID: finalPlan.id,
                occurrenceDate: horizonCalendar.date(byAdding: .day, value: 2, to: finalDate)!)
        ], scheduledItems: [finalPlan], settlements: [], from: horizonNow,
            through: horizonCalendar.date(byAdding: .day, value: 10, to: finalDate)!, calendar: horizonCalendar)
        verify(invalidOccurrenceTotals.named == Money(rubles: 150),
               "a reserve linked to a non-occurrence falls back to independent protection")
        let missingGoalTotals = ProtectedReserveAccounting.totals(goals: [], namedReserves: [
            NamedReserveAllocation(amount: Money(rubles: 250), goalID: UUID())
        ], scheduledItems: [], settlements: [], from: horizonNow, through: finalDate,
            calendar: horizonCalendar)
        verify(missingGoalTotals.named == Money(rubles: 250),
               "a reserve whose goal was removed remains protected as an independent envelope")
        let oldSnapshotJSON = try! JSONEncoder().encode(FinanceSnapshot(bankBalances: [Money(rubles: 900)],
            goalReserve: Money(rubles: 200), earmarkedReserve: Money(rubles: 100)))
        var oldSnapshotObject = try! JSONSerialization.jsonObject(with: oldSnapshotJSON) as! [String: Any]
        oldSnapshotObject.removeValue(forKey: "goalAllocations")
        oldSnapshotObject.removeValue(forKey: "namedReserveAllocations")
        oldSnapshotObject.removeValue(forKey: "usesReserveAllocations")
        oldSnapshotObject.removeValue(forKey: "hasValidPlanData")
        let decodedLegacySnapshot = try! JSONDecoder().decode(FinanceSnapshot.self,
            from: JSONSerialization.data(withJSONObject: oldSnapshotObject))
        verify(!decodedLegacySnapshot.usesReserveAllocations && decodedLegacySnapshot.goalAllocations.isEmpty &&
               decodedLegacySnapshot.namedReserveAllocations.isEmpty && decodedLegacySnapshot.goalReserve == Money(rubles: 200),
               "legacy finance snapshots decode with their scalar reserves and no guessed links")
        verify(decodedLegacySnapshot.hasValidPlanData,
               "legacy finance snapshots default to valid plan data when their Codable plans decoded successfully")
        var unconfirmedHorizon = earmarkSnapshot
        unconfirmedHorizon.nextIncomeConfirmed = false
        verify(FinanceEngine().availableNow(unconfirmedHorizon, now: earmarkNow) == .zero,
               "unconfirmed expected income cannot inflate the free-to-income amount")
        if case .insufficientData = FinanceEngine().safeDailySpendingLimit(unconfirmedHorizon, now: earmarkNow) {
            print("PASS: unconfirmed expected income cannot create a daily spending limit")
        } else { fatalError("Expected unconfirmed income to block daily limit") }
        if case .insufficientData = FinanceEngine().checkPurchase(Money(rubles: 1), snapshot: unconfirmedHorizon, now: earmarkNow) {
            print("PASS: unconfirmed expected income cannot authorize a planned purchase")
        } else { fatalError("Expected unconfirmed income to block purchase verdict") }
        var unrecognizedPlanSnapshot = earmarkSnapshot
        unrecognizedPlanSnapshot.hasValidPlanData = false
        verify(FinanceEngine().availableNow(unrecognizedPlanSnapshot, now: earmarkNow) == .zero &&
               FinanceEngine().purchaseOptions(Money(rubles: 100), snapshot: unrecognizedPlanSnapshot,
                   now: earmarkNow).count == 1,
               "unrecognized saved plan data disables spendable-cash totals and hypothetical plan options")
        if case .insufficientData = FinanceEngine().safeDailySpendingLimit(unrecognizedPlanSnapshot, now: earmarkNow) {
            print("PASS: unrecognized saved plan data blocks a safe daily spending limit")
        } else { fatalError("Expected invalid saved plan data to block daily limit") }
        if case .insufficientData = FinanceEngine().checkPurchase(Money(rubles: 100),
            snapshot: unrecognizedPlanSnapshot, now: earmarkNow) {
            print("PASS: unrecognized saved plan data blocks a purchase verdict")
        } else { fatalError("Expected invalid saved plan data to block purchase verdict") }
        let unrecognizedPlanHorizon = FinanceEngine().horizon(unrecognizedPlanSnapshot, days: 7,
            now: earmarkNow, calendar: horizonCalendar)
        verify(unrecognizedPlanHorizon.points.isEmpty,
               "unrecognized saved plan data does not expose confident numeric horizon points")
        let missingHorizon = horizonEngine.horizon(FinanceSnapshot(bankBalances: []), days: 7,
                                                   now: horizonNow, calendar: horizonCalendar)
        verify(missingHorizon.points.isEmpty && missingHorizon.confidence == .insufficient("Добавь баланс счёта — пока нечего проецировать."),
               "financial horizon reports missing balance instead of presenting fabricated projections")
        let incompleteHorizon = horizonEngine.horizon(FinanceSnapshot(bankBalances: [Money(rubles: 10_000)],
            hasReliableSpendForecast: false, dataUpdatedAt: horizonNow), days: 7,
            hypotheticalPurchase: scenario, now: horizonNow, calendar: horizonCalendar)
        verify(incompleteHorizon.points.isEmpty && incompleteHorizon.hypotheticalPurchase == nil,
               "financial horizon exposes no exact points or purchase scenario without a reliable spending estimate")
        if case .uncertain = incompleteHorizon.confidence {
            print("PASS: financial horizon identifies insufficient spending history")
        } else { fatalError("Expected uncertain confidence for incomplete spending history") }
        let staleHorizon = horizonEngine.horizon(FinanceSnapshot(bankBalances: [Money(rubles: 10_000)],
            hasReliableSpendForecast: true, dataUpdatedAt: horizonNow.addingTimeInterval(-73 * 3_600)), days: 7,
            hypotheticalPurchase: scenario, now: horizonNow, calendar: horizonCalendar)
        verify(staleHorizon.points.isEmpty && staleHorizon.hypotheticalPurchase == nil,
               "financial horizon exposes no exact points or purchase scenario with stale balance data")
        let cappedHorizon = horizonEngine.horizon(horizonSnapshot, days: 365, now: horizonNow, calendar: horizonCalendar)
        verify(cappedHorizon.days == 90 && cappedHorizon.points.count == 91,
               "financial horizon caps projections at the supported 90-day maximum")
        let supportedForecastEnd = horizonCalendar.date(byAdding: .day,
            value: FinancePlanningPolicy.maximumIncomeHorizonDays, to: horizonNow)!
        let unsupportedForecastEnd = horizonCalendar.date(byAdding: .day,
            value: FinancePlanningPolicy.maximumIncomeHorizonDays + 1, to: horizonNow)!
        verify(FinancePlanningPolicy.supportsForecast(from: horizonNow, to: supportedForecastEnd,
                   calendar: horizonCalendar) &&
               !FinancePlanningPolicy.supportsForecast(from: horizonNow, to: unsupportedForecastEnd,
                   calendar: horizonCalendar),
               "safe-to-spend forecast accepts the two-year boundary and rejects longer ranges")
        let distantIncome = horizonCalendar.date(byAdding: .year, value: 20, to: horizonNow)!
        let distantIncomeSnapshot = FinanceSnapshot(bankBalances: [Money(rubles: 20_000)],
            scheduledItems: [ScheduledItem(title: "Еженедельный платёж", amount: Money(rubles: 100),
                dueDate: horizonNow, recurrence: .weekly)],
            nextIncomeConfirmed: true, nextIncomeDate: distantIncome,
            forecastDailySpend: Money(rubles: 10), hasReliableSpendForecast: true, dataUpdatedAt: horizonNow)
        verify(FinanceEngine().availableNow(distantIncomeSnapshot, now: horizonNow) == .zero,
               "an income date beyond the supported forecast window cannot produce a spendable amount")
        if case .insufficientData = FinanceEngine().safeDailySpendingLimit(distantIncomeSnapshot, now: horizonNow),
           case .insufficientData = FinanceEngine().checkPurchase(Money(rubles: 1),
                snapshot: distantIncomeSnapshot, now: horizonNow) {
            verify(FinanceEngine().purchaseOptions(Money(rubles: 1), snapshot: distantIncomeSnapshot,
                       now: horizonNow).count == 1,
                   "income horizons beyond two years fail closed without expanding recurring events")
        } else { fatalError("Long horizons must not receive a precise daily limit or purchase verdict") }

        let learnedCategory = TransactionCategoryCorrection.applying(.groceries, to: Transaction(
            merchant: "Магазин", amount: Money(rubles: 100), kind: .purchase, category: .other))
        let invalidPurchaseCategory = TransactionCategoryCorrection.applying(.income, to: Transaction(
            merchant: "Магазин", amount: Money(rubles: 100), kind: .purchase, category: .other))
        let invalidTransferCategory = TransactionCategoryCorrection.applying(.transfers, to: Transaction(
            merchant: "Магазин", amount: Money(rubles: 100), kind: .purchase, category: .other))
        let invalidFeeCategory = TransactionCategoryCorrection.applying(.fees, to: Transaction(
            merchant: "Магазин", amount: Money(rubles: 100), kind: .purchase, category: .other))
        let protectedRefund = TransactionCategoryCorrection.applying(.groceries, to: Transaction(
            merchant: "Магазин", amount: Money(rubles: 100), kind: .refund, category: .refunds))
        let protectedTransfer = TransactionCategoryCorrection.applying(.groceries, to: Transaction(
            merchant: "Магазин", amount: Money(rubles: 100), kind: .transfer, category: .transfers))
        verify(learnedCategory.category == .groceries && protectedRefund.category == .refunds &&
               protectedTransfer.category == .transfers && invalidPurchaseCategory.category == .other &&
               invalidTransferCategory.category == .other && invalidFeeCategory.category == .other,
               "merchant rules classify purchases only with valid expense categories and preserve special transaction categories")
        let refundAccount = UUID()
        let originalPurchaseID = UUID()
        let refundOperation = Transaction(merchant: "Возврат", amount: Money(rubles: 100), kind: .refund,
            refundOfProviderTransactionID: "provider-purchase-1")
        let exactRefundCandidate = ProviderTransactionCandidate(id: originalPurchaseID, accountID: refundAccount,
            providerTransactionID: "provider-purchase-1", kind: .purchase, isInternalTransfer: false)
        verify(RefundLinkResolver.resolve(refund: refundOperation, accountID: refundAccount,
              candidates: [exactRefundCandidate]) == originalPurchaseID,
              "refund links to one exact provider-matched expense on the selected account")
        let otherAccountCandidate = ProviderTransactionCandidate(id: UUID(), accountID: UUID(),
            providerTransactionID: "provider-purchase-1", kind: .purchase, isInternalTransfer: false)
        verify(RefundLinkResolver.resolve(refund: refundOperation, accountID: refundAccount,
              candidates: [otherAccountCandidate]) == nil,
              "refund does not link to a matching provider ID on another account")
        verify(RefundLinkResolver.resolve(refund: refundOperation, accountID: refundAccount,
              candidates: [exactRefundCandidate, exactRefundCandidate]) == nil,
              "refund remains unlinked when a provider ID has multiple matches")
        verify(RefundLinkResolver.resolve(refund: refundOperation, accountID: nil,
              candidates: [exactRefundCandidate]) == nil,
              "account-less imports do not create cross-source refund links")
        let invalidExpenseCandidate = ProviderTransactionCandidate(id: UUID(), accountID: refundAccount,
            providerTransactionID: "provider-purchase-1", kind: .transfer, isInternalTransfer: true)
        verify(RefundLinkResolver.resolve(refund: refundOperation, accountID: refundAccount,
              candidates: [invalidExpenseCandidate]) == nil,
              "refund does not link to an internal transfer even when the provider ID matches")
        verify(DebtRepaymentSchedule.reservedInstallment(balance: Money(rubles: 1_000), payment: Money(rubles: 300)) == Money(rubles: 300),
               "debt plan reserves the stated installment while the confirmed balance exceeds it")
        verify(DebtRepaymentSchedule.reservedInstallment(balance: Money(rubles: 100), payment: Money(rubles: 300)) == Money(rubles: 100) &&
               DebtRepaymentSchedule.reservedInstallment(balance: .zero, payment: Money(rubles: 300)) == nil &&
               DebtRepaymentSchedule.reservedInstallment(balance: Money(rubles: 300), payment: .zero) == nil,
               "debt installment is capped at confirmed balance and stops only at zero or invalid input")
        let debtPlanDate = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 15))!
        let debtPlan = ScheduledItem(title: "Возврат долга", amount: Money(rubles: 300), dueDate: debtPlanDate,
            isConfirmed: true, kind: .debtRepayment, recurrence: .monthly)
        verify(DebtRepaymentSchedule.matchesPlan(balance: Money(rubles: 1_000), payment: Money(rubles: 300),
              firstPaymentDate: debtPlanDate, plan: debtPlan), "debt accepts one matching confirmed monthly plan")
        verify(!DebtRepaymentSchedule.matchesPlan(balance: Money(rubles: 1_000), payment: Money(rubles: 300),
              firstPaymentDate: debtPlanDate, plan: debtPlan, linkedDebtCount: 2),
              "multiple debts cannot share one repayment plan")
        var wrongAmountDebtPlan = debtPlan
        wrongAmountDebtPlan.amount = Money(rubles: 250)
        verify(!DebtRepaymentSchedule.matchesPlan(balance: Money(rubles: 1_000), payment: Money(rubles: 300),
              firstPaymentDate: debtPlanDate, plan: wrongAmountDebtPlan),
              "debt plan integrity rejects an understated installment")
        var clearedDebtPlan = debtPlan
        clearedDebtPlan.amount = Money(rubles: 300)
        clearedDebtPlan.occurrencesRemaining = 0
        verify(DebtRepaymentSchedule.matchesPlan(balance: .zero, payment: Money(rubles: 300),
              firstPaymentDate: debtPlanDate, plan: clearedDebtPlan),
              "confirmed zero-balance debt requires an exhausted plan")
        var goalCalendar = Calendar(identifier: .gregorian)
        goalCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let goalFirst = goalCalendar.date(from: DateComponents(year: 2026, month: 2, day: 10))!
        let goalDeadline = goalCalendar.date(from: DateComponents(year: 2026, month: 5, day: 10))!
        verify(GoalContributionPlan.occurrencesNeeded(target: Money(rubles: 1_000), saved: Money(rubles: 1_000),
              monthlyContribution: Money(rubles: 100), firstDate: goalFirst, targetDate: goalDeadline, calendar: goalCalendar) == 0,
              "funded goals do not schedule additional contributions")
        verify(GoalContributionPlan.reservedAmount(target: Money(rubles: 1_000), saved: Money(rubles: 400)) == Money(rubles: 400),
               "goal reserve includes the confirmed amount up to its target")
        verify(GoalContributionPlan.reservedAmount(target: Money(rubles: 1_000), saved: Money(rubles: 1_200)) == Money(rubles: 1_000),
               "goal reserve is capped at its target")
        verify(GoalContributionPlan.reservedAmount(target: Money(rubles: 1_000), saved: Money(rubles: -400)) == .zero &&
               GoalContributionPlan.reservedAmount(target: Money(rubles: -1_000), saved: Money(rubles: 400)) == .zero,
               "malformed negative goal values cannot cancel another protected goal reserve")
        verify(GoalContributionPlan.occurrencesNeeded(target: Money(rubles: 1_000), saved: Money(rubles: 750),
              monthlyContribution: Money(rubles: 300), firstDate: goalFirst, targetDate: goalDeadline, calendar: goalCalendar) == 1,
              "goal contribution count rounds remaining amount up to a whole payment")
        verify(GoalContributionPlan.occurrencesNeeded(target: Money(rubles: 1_000), saved: Money(rubles: 0),
              monthlyContribution: Money(rubles: 300), firstDate: goalFirst, targetDate: goalDeadline, calendar: goalCalendar) == 4,
              "goal contribution count includes each monthly date through the deadline")
        verify(GoalContributionPlan.matchesSchedule(target: Money(rubles: 1_000), saved: .zero,
              monthlyContribution: Money(rubles: 300), firstDate: goalFirst, targetDate: goalDeadline,
              hasSchedule: true, scheduledOccurrenceCount: 4,
              scheduledFinalContribution: Money(rubles: 100), calendar: goalCalendar),
              "goal integrity accepts a matching recurring contribution schedule")
        let validGoalPlan = ScheduledItem(title: "Цель", amount: Money(rubles: 300), dueDate: goalFirst,
            isConfirmed: true, kind: .goalContribution, recurrence: .monthly,
            occurrencesRemaining: 4, finalOccurrenceAmount: Money(rubles: 100))
        verify(GoalContributionPlan.matchesLinkedPlan(target: Money(rubles: 1_000), saved: .zero,
              monthlyContribution: Money(rubles: 300), firstDate: goalFirst, targetDate: goalDeadline,
              hasPlanReference: true, plan: validGoalPlan, linkedGoalCount: 1, calendar: goalCalendar),
              "goal accepts one matching confirmed monthly plan")
        verify(!GoalContributionPlan.matchesLinkedPlan(target: Money(rubles: 1_000), saved: .zero,
              monthlyContribution: Money(rubles: 300), firstDate: goalFirst, targetDate: goalDeadline,
              hasPlanReference: true, plan: validGoalPlan, linkedGoalCount: 2, calendar: goalCalendar),
              "multiple goals cannot share one contribution plan")
        var wrongGoalPlan = validGoalPlan
        wrongGoalPlan.kind = .obligation
        verify(!GoalContributionPlan.matchesLinkedPlan(target: Money(rubles: 1_000), saved: .zero,
              monthlyContribution: Money(rubles: 300), firstDate: goalFirst, targetDate: goalDeadline,
              hasPlanReference: true, plan: wrongGoalPlan, linkedGoalCount: 1, calendar: goalCalendar),
              "goal integrity rejects a linked plan with the wrong kind")
        var unconfirmedGoalPlan = validGoalPlan
        unconfirmedGoalPlan.isConfirmed = false
        verify(!GoalContributionPlan.matchesLinkedPlan(target: Money(rubles: 1_000), saved: .zero,
              monthlyContribution: Money(rubles: 300), firstDate: goalFirst, targetDate: goalDeadline,
              hasPlanReference: true, plan: unconfirmedGoalPlan, linkedGoalCount: 1, calendar: goalCalendar),
              "goal integrity rejects an unconfirmed contribution plan")
        verify(!GoalContributionPlan.matchesSchedule(target: Money(rubles: 1_000), saved: .zero,
              monthlyContribution: Money(rubles: 300), firstDate: goalFirst, targetDate: goalDeadline,
              hasSchedule: false, scheduledOccurrenceCount: nil, scheduledFinalContribution: nil,
              calendar: goalCalendar) &&
              !GoalContributionPlan.matchesSchedule(target: Money(rubles: 1_000), saved: .zero,
              monthlyContribution: Money(rubles: 300), firstDate: goalFirst, targetDate: goalDeadline,
              hasSchedule: true, scheduledOccurrenceCount: 2,
              scheduledFinalContribution: nil, calendar: goalCalendar),
              "goal integrity rejects a missing or understated required contribution schedule")
        verify(GoalContributionPlan.matchesSchedule(target: Money(rubles: 1_000), saved: Money(rubles: 1_000),
              monthlyContribution: Money(rubles: 300), firstDate: goalFirst, targetDate: goalDeadline,
              hasSchedule: false, scheduledOccurrenceCount: nil, scheduledFinalContribution: nil,
              calendar: goalCalendar),
              "goal integrity permits no schedule after the target is fully funded")
        let januaryEnd = goalCalendar.date(from: DateComponents(year: 2026, month: 1, day: 31))!
        let februaryEnd = goalCalendar.date(from: DateComponents(year: 2026, month: 2, day: 28))!
        let beforeFebruaryEnd = goalCalendar.date(from: DateComponents(year: 2026, month: 2, day: 27))!
        verify(GoalContributionPlan.occurrencesNeeded(target: Money(rubles: 600), saved: .zero,
              monthlyContribution: Money(rubles: 300), firstDate: januaryEnd, targetDate: februaryEnd, calendar: goalCalendar) == 2,
              "goal schedule includes the clamped end-of-month occurrence on the deadline")
        let marchEnd = goalCalendar.date(from: DateComponents(year: 2026, month: 3, day: 31))!
        verify(GoalContributionPlan.shiftedDeadlineAfterOneMonth(februaryEnd,
              firstContributionDate: marchEnd, calendar: goalCalendar) == marchEnd,
              "shifted goal deadline reaches the moved month-end contribution")
        let marchFirst = goalCalendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let marchDeadline = goalCalendar.date(from: DateComponents(year: 2026, month: 3, day: 28))!
        verify(GoalContributionPlan.shiftedDeadlineAfterOneMonth(februaryEnd,
              firstContributionDate: marchFirst, calendar: goalCalendar) == marchDeadline,
              "shifted goal deadline preserves its date when the contribution fits")
        verify(GoalContributionPlan.occurrencesNeeded(target: Money(rubles: 600), saved: .zero,
              monthlyContribution: Money(rubles: 300), firstDate: januaryEnd, targetDate: beforeFebruaryEnd, calendar: goalCalendar) == 1,
              "goal schedule excludes an end-of-month payment that falls after the deadline")
        verify(GoalContributionPlan.occurrencesNeeded(target: Money(rubles: 1_000), saved: Money(rubles: 0),
              monthlyContribution: Money(rubles: 300), firstDate: goalDeadline.addingTimeInterval(86_400), targetDate: goalDeadline, calendar: goalCalendar) == 0,
              "goal contributions are not scheduled when the first date misses the deadline")
        verify(GoalContributionPlan.finalContributionAmount(target: Money(rubles: 1_000), saved: .zero,
              monthlyContribution: Money(rubles: 300), occurrenceCount: 4) == Money(rubles: 100),
              "goal schedule reduces its final payment to the exact remaining amount")
        verify(GoalContributionPlan.finalContributionAmount(target: Money(rubles: 900), saved: .zero,
              monthlyContribution: Money(rubles: 300), occurrenceCount: 3) == nil &&
              GoalContributionPlan.finalContributionAmount(target: Money(rubles: 1_000), saved: .zero,
              monthlyContribution: Money(rubles: 300), occurrenceCount: 2) == nil,
              "goal schedule keeps full payments for exact totals and unreachable deadlines")
        let scheduleStart = goalCalendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let scheduleIncome = goalCalendar.date(from: DateComponents(year: 2026, month: 4, day: 1))!
        let goalPlanItem = ScheduledItem(title: "Телефон", amount: Money(rubles: 300), dueDate: scheduleStart,
            kind: .goalContribution, recurrence: .monthly, occurrencesRemaining: 4,
            finalOccurrenceAmount: Money(rubles: 100))
        let goalPlanSnapshot = FinanceSnapshot(bankBalances: [Money(rubles: 2_000)], scheduledItems: [goalPlanItem],
            nextIncomeConfirmed: true, nextIncomeDate: scheduleIncome, forecastDailySpend: .zero, dataUpdatedAt: scheduleStart)
        verify(FinanceEngine().availableNow(goalPlanSnapshot, now: scheduleStart) == Money(rubles: 1_000),
               "available cash reserves the exact goal total including its reduced final payment")
        var invalidFinalAmountSnapshot = goalPlanSnapshot
        invalidFinalAmountSnapshot.scheduledItems[0].finalOccurrenceAmount = Money(rubles: 1_000)
        verify(FinanceEngine().availableNow(invalidFinalAmountSnapshot, now: scheduleStart) == Money(rubles: 800),
               "invalid final payment data cannot increase a plan occurrence beyond its regular amount")
        let maximumRubles = Decimal(Int64.max) / 100
        let aboveMaximumRubles = Decimal(string: "92233720368547758.08")!
        let belowMinimumRubles = Decimal(string: "-92233720368547758.09")!
        verify(Money.canRepresent(rubles: maximumRubles), "Money accepts the exact maximum kopeck value")
        verify(!Money.canRepresent(rubles: aboveMaximumRubles) && Money(rubles: aboveMaximumRubles).kopecks == Int64.max,
               "Money rejects or safely saturates positive conversion overflow")
        verify(!Money.canRepresent(rubles: belowMinimumRubles) && Money(rubles: belowMinimumRubles).kopecks == Int64.min,
               "Money rejects or safely saturates negative conversion overflow")
        verify(Money.parseRubles("1\u{00A0}234,56") == Decimal(string: "1234.56"),
               "manual ruble input parses a localized decimal and grouped whitespace")
        verify(Money.parseRubles("1 234 567,89") == Decimal(string: "1234567.89") &&
               Money.parseRubles("1\u{202F}234.56") == Decimal(string: "1234.56") &&
               Money.parseRubles("1 2 3") == nil && Money.parseRubles("12 34,56") == nil &&
               Money.parseRubles("1  234") == nil && Money.parseRubles("1 \u{00A0}234") == nil &&
               Money.parseRubles("1 ,50") == nil && Money.parseRubles("1,2.3") == nil,
               "manual ruble input validates thousands grouping and rejects malformed or mixed separators")
        verify(Money.parseRubles("12.345") == nil && Money.parseRubles("12.340") == Decimal(string: "12.34"),
               "manual ruble input rejects fractional kopecks but accepts exact trailing zero precision")
        verify(Money.parseRubles("92233720368547758.08") == nil && Money.parseRubles("не число") == nil,
               "manual ruble input rejects out-of-range and malformed values")
        let maximumExactMoney = Money(kopecks: Int64.max)
        let maximumExactRubles = NSDecimalNumber(decimal: maximumExactMoney.decimalRubles).stringValue
        verify(Money.parseRubles(maximumExactRubles).map(Money.init(rubles:)) == maximumExactMoney,
               "decimal ruble text round-trips the maximum kopeck value without binary floating point")
        verify((Money(kopecks: Int64.max) + Money(kopecks: 1)).kopecks == Int64.max &&
               (Money(kopecks: Int64.min) + Money(kopecks: -1)).kopecks == Int64.min,
               "Money addition saturates without wrapping across zero")
        verify((Money(kopecks: Int64.max) - Money(kopecks: Int64.min)).kopecks == Int64.max &&
               (-Money(kopecks: Int64.min)).kopecks == Int64.max,
               "Money subtraction and negation saturate without integer traps")
        let maximumBalance = Money(kopecks: Int64.max)
        let negativeMaximumBalance = Money(kopecks: -Int64.max)
        verify(Money.sum([maximumBalance, maximumBalance, negativeMaximumBalance]) == maximumBalance &&
               Money.sum([maximumBalance, negativeMaximumBalance, maximumBalance]) == maximumBalance &&
               FinanceSnapshot(bankBalances: [maximumBalance, maximumBalance, negativeMaximumBalance]).currentBalance == maximumBalance,
               "net account aggregation clamps only the final sum and is independent of account order")
        verify(Money.sum([maximumBalance, maximumBalance]).kopecks == Int64.max &&
               Money.sum([Money(kopecks: Int64.min), Money(kopecks: -1)]).kopecks == Int64.min,
               "net account aggregation safely clamps a genuinely out-of-range final balance")
        verify(TransactionKind.refund.isInflow && !TransactionKind.refund.isOutflow &&
               TransactionKind.incomingTransfer.isInflow && !TransactionKind.incomingTransfer.isOutflow &&
               TransactionKind.income.isInflow && TransactionKind.fee.isOutflow,
               "transaction kinds expose consistent inflow and outflow semantics")
        verify(TransactionStatus.restoring(nil) == .posted &&
               TransactionStatus.restoring("posted") == .posted &&
               TransactionStatus.restoring("pending") == .pending &&
               TransactionStatus.restoring("corrupted-status") == .pending,
               "persisted statuses preserve legacy rows and fail closed on unknown values")
        verify(!TransactionStatus.canPromoteToPosted(fromStoredRawValue: nil) &&
               !TransactionStatus.canPromoteToPosted(fromStoredRawValue: "posted") &&
               TransactionStatus.canPromoteToPosted(fromStoredRawValue: "pending") &&
               !TransactionStatus.canPromoteToPosted(fromStoredRawValue: "corrupted-status"),
               "statement imports promote only explicitly pending stored transactions")
        verify(TransactionKind.restoring("purchase") == .purchase &&
               TransactionKind.restoring("income") == .income &&
               TransactionKind.restoring("unknown-future-kind") == .adjustment &&
               !TransactionKind.restoring("unknown-future-kind").isOutflow &&
               !TransactionKind.restoring("unknown-future-kind").isInflow,
               "unknown persisted transaction kinds remain neutral instead of becoming purchases")
        verify(TransactionKind.transfer.defaultCategory == .transfers &&
               TransactionKind.incomingTransfer.defaultCategory == .transfers &&
               TransactionKind.refund.defaultCategory == .refunds &&
               TransactionKind.fee.defaultCategory == .fees && TransactionKind.purchase.defaultCategory == nil,
               "transaction kinds provide safe default categories for manual correction")
        let pairPolicyDate = Date(timeIntervalSince1970: 1_800_000_000)
        let confirmedOutgoingTransfer = Transaction(date: pairPolicyDate, merchant: "Между своими счетами",
            amount: Money(rubles: 1_000), kind: .transfer, isInternalTransfer: true)
        var editedTransfer = confirmedOutgoingTransfer
        verify(!InternalTransferPairPolicy.shouldDetach(original: confirmedOutgoingTransfer, edited: editedTransfer),
               "unchanged confirmed internal transfer stays paired")
        editedTransfer.amount = Money(rubles: 999)
        let amountChangeBreaksPair = InternalTransferPairPolicy.shouldDetach(original: confirmedOutgoingTransfer, edited: editedTransfer)
        editedTransfer = confirmedOutgoingTransfer
        editedTransfer.date = pairPolicyDate.addingTimeInterval(1)
        let dateChangeBreaksPair = InternalTransferPairPolicy.shouldDetach(original: confirmedOutgoingTransfer, edited: editedTransfer)
        editedTransfer = confirmedOutgoingTransfer
        editedTransfer.kind = .purchase
        let directionChangeBreaksPair = InternalTransferPairPolicy.shouldDetach(original: confirmedOutgoingTransfer, edited: editedTransfer)
        editedTransfer = confirmedOutgoingTransfer
        editedTransfer.isInternalTransfer = false
        let explicitUnpairBreaksPair = InternalTransferPairPolicy.shouldDetach(original: confirmedOutgoingTransfer, edited: editedTransfer)
        verify(amountChangeBreaksPair && dateChangeBreaksPair && directionChangeBreaksPair && explicitUnpairBreaksPair,
               "amount, date, direction, or explicit status changes detach a confirmed internal transfer pair")

        let transferAccountA = UUID()
        let transferAccountB = UUID()
        let transferOutgoingID = UUID()
        let transferIncomingID = UUID()
        let transferDate = Date(timeIntervalSince1970: 1_800_000_000)
        let transferPair = [
            TransferMatchRecord(id: transferOutgoingID, accountID: transferAccountA, date: transferDate,
                amount: Money(rubles: 1_250), kind: .transfer),
            TransferMatchRecord(id: transferIncomingID, accountID: transferAccountB,
                date: transferDate.addingTimeInterval(36 * 60 * 60), amount: Money(rubles: 1_250), kind: .incomingTransfer)
        ]
        let transferCandidates = InternalTransferMatcher.candidates(among: transferPair)
        verify(transferCandidates.count == 1 && transferCandidates[0].outgoingID == transferOutgoingID &&
               transferCandidates[0].incomingID == transferIncomingID && transferCandidates[0].timeDifference == 36 * 60 * 60,
               "internal transfer matcher suggests exact-amount opposite-direction operations across accounts")
        let excludedAccountPair = [
            TransferMatchRecord(id: transferOutgoingID, accountID: transferAccountA, accountIncluded: true,
                date: transferDate, amount: Money(rubles: 1_250), kind: .transfer),
            TransferMatchRecord(id: transferIncomingID, accountID: transferAccountB, accountIncluded: false,
                date: transferDate, amount: Money(rubles: 1_250), kind: .incomingTransfer)
        ]
        verify(InternalTransferMatcher.candidates(among: excludedAccountPair).isEmpty,
               "internal transfer matcher preserves spending when either account is excluded from planning")
        let invalidTransferPairs = [
            TransferMatchRecord(id: UUID(), accountID: transferAccountA, date: transferDate,
                amount: Money(rubles: 100), kind: .transfer),
            TransferMatchRecord(id: UUID(), accountID: transferAccountA, date: transferDate,
                amount: Money(rubles: 100), kind: .incomingTransfer),
            TransferMatchRecord(id: UUID(), accountID: transferAccountB, date: transferDate,
                amount: Money(rubles: 101), kind: .incomingTransfer),
            TransferMatchRecord(id: UUID(), accountID: transferAccountB, date: transferDate.addingTimeInterval(73 * 60 * 60),
                amount: Money(rubles: 100), kind: .incomingTransfer),
            TransferMatchRecord(id: UUID(), accountID: nil, date: transferDate,
                amount: Money(rubles: 100), kind: .incomingTransfer)
        ]
        let invalidTransferSource = TransferMatchRecord(id: UUID(), accountID: transferAccountA,
            date: transferDate, amount: Money(rubles: 100), kind: .transfer)
        verify(InternalTransferMatcher.candidates(among: [invalidTransferSource] + invalidTransferPairs).isEmpty,
               "internal transfer matcher rejects same-account, unbound, unequal, and stale candidates")
        let ambiguousTransferRows = [
            TransferMatchRecord(id: transferOutgoingID, accountID: transferAccountA, date: transferDate,
                amount: Money(rubles: 500), kind: .transfer),
            TransferMatchRecord(id: transferIncomingID, accountID: transferAccountB, date: transferDate,
                amount: Money(rubles: 500), kind: .incomingTransfer),
            TransferMatchRecord(id: UUID(), accountID: UUID(), date: transferDate,
                amount: Money(rubles: 500), kind: .incomingTransfer)
        ]
        verify(InternalTransferMatcher.candidates(among: ambiguousTransferRows).count == 2,
               "ambiguous internal transfer matches remain separate user-review suggestions")
        let candidateOrder = InternalTransferMatcher.candidates(among: [
            TransferMatchRecord(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, accountID: transferAccountA,
                date: transferDate, amount: Money(rubles: 500), kind: .transfer),
            TransferMatchRecord(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, accountID: transferAccountB,
                date: transferDate.addingTimeInterval(30), amount: Money(rubles: 500), kind: .incomingTransfer),
            TransferMatchRecord(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, accountID: UUID(),
                date: transferDate.addingTimeInterval(30), amount: Money(rubles: 500), kind: .incomingTransfer)
        ])
        verify(candidateOrder.count == 2 && candidateOrder[0].timeDifference == candidateOrder[1].timeDifference &&
               candidateOrder[0].incomingID.uuidString < candidateOrder[1].incomingID.uuidString,
               "internal transfer suggestions have stable ordering when equally close")
        verify(InternalTransferMatcher.candidates(among: transferPair, within: .infinity).isEmpty &&
               InternalTransferMatcher.candidates(among: transferPair, within: -1).isEmpty,
               "internal transfer matcher rejects invalid matching windows")

        let assessmentNow = Date(timeIntervalSince1970: 1_800_000_000)
        let stableAssessment = PlanHealthAssessment.evaluate(FinanceSnapshot(
            bankBalances: [Money(rubles: 1_500)], nextIncomeConfirmed: true, nextIncomeDate: assessmentNow.addingTimeInterval(7 * 86_400),
            forecastDailySpend: Money(rubles: 1), dataUpdatedAt: assessmentNow), now: assessmentNow)
        verify(stableAssessment.level == .stable, "plan assessment marks a covered plan stable")
        let riskyAssessment = PlanHealthAssessment.evaluate(FinanceSnapshot(
            bankBalances: [Money(rubles: 1_000)], protectedReserve: Money(rubles: 300),
            scheduledItems: [ScheduledItem(title: "Дорога", amount: Money(rubles: 900), dueDate: assessmentNow.addingTimeInterval(86_400))],
            nextIncomeConfirmed: true, nextIncomeDate: assessmentNow.addingTimeInterval(7 * 86_400), forecastDailySpend: Money(rubles: 1), dataUpdatedAt: assessmentNow), now: assessmentNow)
        verify(riskyAssessment.level == .unsafe, "plan assessment marks reserve shortfall unsafe")
        let adjustableAssessment = PlanHealthAssessment.evaluate(FinanceSnapshot(
            bankBalances: [Money(rubles: 500)],
            scheduledItems: [ScheduledItem(title: "Цель", amount: Money(rubles: 300), dueDate: assessmentNow.addingTimeInterval(2 * 86_400), kind: .goalContribution)],
            nextIncomeConfirmed: true, nextIncomeDate: assessmentNow.addingTimeInterval(7 * 86_400), forecastDailySpend: Money(kopecks: 1),
            dataUpdatedAt: assessmentNow, goalReserve: Money(rubles: 300)), now: assessmentNow)
        verify(adjustableAssessment.level == .adjustmentNeeded, "plan assessment shows when moving a goal contribution can protect the reserve")
        let missingAssessment = PlanHealthAssessment.evaluate(FinanceSnapshot(bankBalances: []), now: assessmentNow)
        verify(missingAssessment.level == .insufficientData, "plan assessment does not guess without balances")
        let noHistoryAssessment = PlanHealthAssessment.evaluate(FinanceSnapshot(
            bankBalances: [Money(rubles: 1_500)], nextIncomeConfirmed: true, nextIncomeDate: assessmentNow.addingTimeInterval(7 * 86_400),
            hasReliableSpendForecast: false, dataUpdatedAt: assessmentNow), now: assessmentNow)
        verify(noHistoryAssessment.level == .insufficientData, "plan assessment requires a variable-spending estimate")
        let noHistoryPurchase = FinanceEngine().checkPurchase(Money(rubles: 100), snapshot: FinanceSnapshot(
            bankBalances: [Money(rubles: 1_500)], nextIncomeConfirmed: true, nextIncomeDate: assessmentNow.addingTimeInterval(7 * 86_400),
            hasReliableSpendForecast: false, dataUpdatedAt: assessmentNow), now: assessmentNow)
        if case .insufficientData = noHistoryPurchase { print("PASS: purchase check blocks a confident answer without spending history") }
        else { fatalError("Expected insufficient spending-history data") }
        let noHistorySnapshot = FinanceSnapshot(bankBalances: [Money(rubles: 1_500)],
            nextIncomeConfirmed: true, nextIncomeDate: assessmentNow.addingTimeInterval(7 * 86_400),
            hasReliableSpendForecast: false, dataUpdatedAt: assessmentNow)
        if case .insufficientData = FinanceEngine().safeDailySpendingLimit(noHistorySnapshot, now: assessmentNow) {
            print("PASS: daily spending limit requires reliable spending history")
        } else { fatalError("Expected daily limit to require a reliable spending forecast") }
        verify(FinanceEngine().availableNow(noHistorySnapshot, now: assessmentNow) == .zero,
               "free-to-income amount is hidden when ordinary spending history is insufficient")

        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let income = now.addingTimeInterval(7 * 86_400)
        let road = now.addingTimeInterval(3 * 86_400)
        let snapshot = FinanceSnapshot(bankBalances: [Money(rubles: 1_500)],
                                       scheduledItems: [ScheduledItem(title: "Дорога", amount: Money(rubles: 500), dueDate: road)],
                                       nextIncomeConfirmed: true, nextIncomeDate: income, dataUpdatedAt: now)
        let result = FinanceEngine().checkPurchase(Money(rubles: 1_200), on: now, snapshot: snapshot, now: now)
        if case .unsafe(let shortfall, _) = result { verify(shortfall == Money(rubles: 200), "purchase protects transport reserve") }
        else { fatalError("Expected unsafe purchase verdict") }

        do {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = FinanceSnapshot(bankBalances: [Money(rubles: -100)],
            nextIncomeConfirmed: true, nextIncomeDate: now.addingTimeInterval(7 * 86_400), forecastDailySpend: .zero, dataUpdatedAt: now)
        verify(FinanceEngine().availableNow(snapshot, now: now) == .zero,
               "negative account balance cannot create spendable money")
        if case .unsafe(let shortfall, _) = FinanceEngine().checkPurchase(Money(rubles: 1), snapshot: snapshot, now: now) {
            verify(shortfall == Money(rubles: 101), "negative account balance blocks even a small purchase")
        } else { fatalError("Negative account balance must not allow a purchase") }
        }

        do {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = FinanceSnapshot(bankBalances: [Money(rubles: 1_000)], nextIncomeConfirmed: true, nextIncomeDate: now.addingTimeInterval(3 * 86_400),
                                       dataUpdatedAt: now)
        let todayAtMidnight = Calendar.current.startOfDay(for: now)
        let todayVerdict = FinanceEngine().checkPurchase(Money(rubles: 100), on: todayAtMidnight, snapshot: snapshot, now: now)
        if case .canBuy(let minimum) = todayVerdict { verify(minimum == Money(rubles: 900), "purchase selected for today is included even when the date picker returns midnight") }
        else { fatalError("Expected today's purchase to be included") }
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        if case .insufficientData = FinanceEngine().checkPurchase(Money(rubles: 100), on: pastDate, snapshot: snapshot, now: now) {
            print("PASS: purchase check rejects past purchase dates")
        } else { fatalError("Expected past purchase date rejection") }
        let afterIncome = snapshot.nextIncomeDate!.addingTimeInterval(86_400)
        if case .insufficientData = FinanceEngine().checkPurchase(Money(rubles: 100), on: afterIncome, snapshot: snapshot, now: now) {
            print("PASS: purchase after expected income requires a fresh check after the money arrives")
        } else { fatalError("Expected purchase-after-income rejection") }
        let incomeDay = Calendar.current.startOfDay(for: snapshot.nextIncomeDate!)
        let sameIncomeDay = FinanceEngine().checkPurchase(Money(rubles: 100), on: incomeDay,
                                                            snapshot: snapshot, now: now)
        if case .insufficientData = sameIncomeDay {
            print("PASS: purchase on expected-income day requires actual credit first")
        } else { fatalError("Expected same-day purchase rejection") }
        }

        do {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = FinanceSnapshot(bankBalances: [Money(rubles: 1_000)],
                                       incomes: [IncomeEvent(title: "Родители", amount: Money(rubles: 5_000), date: now.addingTimeInterval(5 * 86_400), source: .parentSupport)],
                                       nextIncomeConfirmed: true, nextIncomeDate: now.addingTimeInterval(5 * 86_400), dataUpdatedAt: now)
        verify(FinanceEngine().availableNow(snapshot, now: now) == Money(rubles: 1_000), "future income is not currently spendable")
        }

        do {
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            let income = now.addingTimeInterval(10 * 86_400)
            let snapshot = FinanceSnapshot(bankBalances: [Money(rubles: 1_000)],
                protectedReserve: Money(rubles: 100),
                scheduledItems: [ScheduledItem(title: "Обязательный платёж", amount: Money(rubles: 200),
                    dueDate: now.addingTimeInterval(5 * 86_400))],
                nextIncomeConfirmed: true, nextIncomeDate: income, dataUpdatedAt: now)
            verify(FinanceEngine().safeDailySpendingLimit(snapshot, now: now) == .calculated(Money(rubles: 70)),
                   "safe daily spending limit reserves the balance, commitment and protected reserve")

            let calendar = Calendar.current
            let todayAtMidnight = calendar.startOfDay(for: now)
            let dueToday = FinanceSnapshot(bankBalances: [Money(rubles: 1_000)],
                scheduledItems: [ScheduledItem(title: "Счёт сегодня", amount: Money(rubles: 200), dueDate: todayAtMidnight)],
                nextIncomeConfirmed: true, nextIncomeDate: now.addingTimeInterval(5 * 86_400),
                forecastDailySpend: .zero, dataUpdatedAt: now)
            verify(FinanceEngine().availableNow(dueToday, now: now) == Money(rubles: 800),
                   "a one-time payment dated today remains reserved after midnight")
            if case .unsafe(let shortfall, _) = FinanceEngine().checkPurchase(Money(rubles: 900), snapshot: dueToday, now: now) {
                verify(shortfall == Money(rubles: 100), "purchase check includes today's date-only obligation")
            } else { fatalError("Expected today's obligation to prevent overspending") }
            let todayHorizon = FinanceEngine().horizon(dueToday, days: 5, now: now, calendar: calendar)
            verify(todayHorizon.points.count == 6 && todayHorizon.points[1].confirmedOutflows == Money(rubles: 200) &&
                   todayHorizon.points[1].projectedBalance == Money(rubles: 800),
                   "financial horizon places a midnight-dated obligation into today's point")
            var weeklyDueToday = dueToday
            weeklyDueToday.scheduledItems[0] = ScheduledItem(title: "Еженедельный платёж сегодня",
                amount: Money(rubles: 100), dueDate: todayAtMidnight, recurrence: .weekly)
            verify(FinanceEngine().availableNow(weeklyDueToday, now: now) == Money(rubles: 900),
                   "weekly recurrence includes its current calendar-day occurrence after midnight")

            let nextMonthlyOccurrence = calendar.date(byAdding: .month, value: 1, to: todayAtMidnight)!
            let recurringPaymentAndIncome = FinanceSnapshot(bankBalances: [Money(rubles: 100)],
                scheduledItems: [ScheduledItem(title: "Ежемесячный платёж", amount: Money(rubles: 100),
                    dueDate: todayAtMidnight, recurrence: .monthly)],
                incomes: [IncomeEvent(title: "Поступление в дату платежа", amount: Money(rubles: 100),
                    date: nextMonthlyOccurrence, isConfirmed: true)],
                nextIncomeConfirmed: true, nextIncomeDate: nextMonthlyOccurrence,
                forecastDailySpend: .zero, dataUpdatedAt: now)
            if case .unsafe(let shortfall, let date) = FinanceEngine().checkPurchase(.zero,
                snapshot: recurringPaymentAndIncome, now: now) {
                verify(shortfall == Money(rubles: 100) && date == nextMonthlyOccurrence,
                       "date-only recurring payment remains due before same-time income in the next cycle")
            } else {
                fatalError("Expected a deficit when the dated recurring payment precedes same-time income")
            }
            if case .unsafe(let shortfall, let date) = FinanceEngine().checkPurchase(Money(rubles: 1),
                snapshot: recurringPaymentAndIncome, now: now) {
                verify(shortfall == Money(rubles: 101) && date == nextMonthlyOccurrence,
                       "purchase projection includes today's obligation, the income-day payment, and same-time income ordering")
            } else {
                fatalError("A purchase must not rely on same-time income to cover the next scheduled payment")
            }

            let shortHorizon = FinanceSnapshot(bankBalances: [Money(rubles: 1_000)],
                nextIncomeConfirmed: true, nextIncomeDate: now.addingTimeInterval(12 * 3_600),
                forecastDailySpend: .zero, dataUpdatedAt: now)
            verify(FinanceEngine().safeDailySpendingLimit(shortHorizon, now: now) == .calculated(Money(rubles: 2_000)),
                   "daily spending rate can exceed the current balance when only half a day remains")
            var shortHorizonWithBill = shortHorizon
            shortHorizonWithBill.scheduledItems = [ScheduledItem(title: "Счёт через шесть часов",
                amount: Money(rubles: 300), dueDate: now.addingTimeInterval(6 * 3_600))]
            verify(FinanceEngine().safeDailySpendingLimit(shortHorizonWithBill, now: now) == .calculated(Money(rubles: 1_400)),
                   "short-horizon daily rate respects obligations before the confirmed income")

            var unaffordable = snapshot
            unaffordable.bankBalances = [Money(rubles: 300)]
            unaffordable.scheduledItems = [ScheduledItem(title: "Платёж", amount: Money(rubles: 300),
                dueDate: now.addingTimeInterval(5 * 86_400))]
            if case .unsafe(let shortfall, let date) = FinanceEngine().safeDailySpendingLimit(unaffordable, now: now) {
                verify(shortfall == Money(rubles: 100) && date == now.addingTimeInterval(5 * 86_400),
                       "daily limit reports an existing commitment shortfall even with zero discretionary spend")
            } else { fatalError("Expected unsafe daily spending plan") }

            let laterDeeperDeficit = FinanceSnapshot(bankBalances: [Money(rubles: 1_000)],
                protectedReserve: Money(rubles: 500),
                scheduledItems: [
                    ScheduledItem(title: "Первый платёж", amount: Money(rubles: 600), dueDate: now.addingTimeInterval(86_400)),
                    ScheduledItem(title: "Второй платёж", amount: Money(rubles: 500), dueDate: now.addingTimeInterval(2 * 86_400))
                ], nextIncomeConfirmed: true, nextIncomeDate: now.addingTimeInterval(5 * 86_400), forecastDailySpend: .zero,
                hasReliableSpendForecast: true, dataUpdatedAt: now)
            let deepestDate = now.addingTimeInterval(2 * 86_400)
            if case .unsafe(let shortfall, let date) = FinanceEngine().safeDailySpendingLimit(laterDeeperDeficit, now: now) {
                verify(shortfall == Money(rubles: 600) && date == deepestDate,
                       "daily-limit deficit amount and date refer to the same lowest-balance point")
            } else { fatalError("Expected the deepest future reserve deficit") }
            if case .unsafe(let shortfall, let date) = FinanceEngine().checkPurchase(.zero, snapshot: laterDeeperDeficit, now: now) {
                verify(shortfall == Money(rubles: 600) && date == deepestDate,
                       "purchase-check deficit amount and date refer to the same lowest-balance point")
            } else { fatalError("Expected purchase check to report the deepest future reserve deficit") }

            let incompleteGoalAdjustment = FinanceSnapshot(bankBalances: [Money(rubles: 1_000)],
                protectedReserve: Money(rubles: 500),
                scheduledItems: [
                    ScheduledItem(title: "Взнос в цель", amount: Money(rubles: 300), dueDate: now.addingTimeInterval(86_400), kind: .goalContribution),
                    ScheduledItem(title: "Обязательный платёж", amount: Money(rubles: 400), dueDate: now.addingTimeInterval(2 * 86_400))
                ], nextIncomeConfirmed: true, nextIncomeDate: now.addingTimeInterval(5 * 86_400), forecastDailySpend: .zero,
                hasReliableSpendForecast: true, dataUpdatedAt: now)
            let incompleteAdjustmentVerdict = FinanceEngine().checkPurchase(Money(rubles: 250), snapshot: incompleteGoalAdjustment, now: now)
            if case .unsafe(let shortfall, let date) = incompleteAdjustmentVerdict {
                verify(shortfall == Money(rubles: 450) && date == deepestDate,
                       "moving an early goal payment does not hide a deeper later mandatory deficit")
            } else { fatalError("An insufficient goal adjustment must not present a safe purchase") }
            let genericOptions = FinanceEngine().purchaseOptions(
                Money(rubles: 250), snapshot: incompleteGoalAdjustment, now: now)
            verify(genericOptions.allSatisfy { $0.id == "direct" || $0.id == "later" },
                   "generic purchase options never imply changing every goal at once")

            let firstGoalPlan = ScheduledItem(title: "Цель A", amount: Money(rubles: 500),
                dueDate: now.addingTimeInterval(86_400), kind: .goalContribution, recurrence: .monthly)
            let secondGoalPlan = ScheduledItem(title: "Цель B", amount: Money(rubles: 700),
                dueDate: now.addingTimeInterval(2 * 86_400), kind: .goalContribution, recurrence: .monthly)
            let scopedGoalSnapshot = FinanceSnapshot(bankBalances: [Money(rubles: 3_000)],
                scheduledItems: [firstGoalPlan, secondGoalPlan,
                    ScheduledItem(title: "Обязательный платёж", amount: Money(rubles: 800),
                                  dueDate: now.addingTimeInterval(3 * 86_400))],
                nextIncomeConfirmed: true, nextIncomeDate: now.addingTimeInterval(5 * 86_400),
                forecastDailySpend: .zero, hasReliableSpendForecast: true, dataUpdatedAt: now)
            let shiftedGoalDate = ScheduledRecurrence.nextDate(after: firstGoalPlan.dueDate,
                anchoredAt: firstGoalPlan.dueDate, recurrence: .monthly)!
            let scopedGoalOption = FinanceEngine().goalContributionShiftPurchaseOption(
                Money(rubles: 1_600), snapshot: scopedGoalSnapshot, planID: firstGoalPlan.id,
                goalTitle: "Цель A", shiftedFirstDate: shiftedGoalDate,
                shiftedOccurrenceCount: 1, shiftedFinalContribution: nil, now: now)
            guard let scopedGoalOption else { fatalError("Expected selected goal option") }
            verify(scopedGoalOption.changedGoalContribution == Money(rubles: 500),
                   "goal what-if totals only the selected plan's occurrences")
            if case .canBuyWithChanges(_, let shortfall) = scopedGoalOption.verdict {
                verify(shortfall == Money(rubles: 100),
                       "goal what-if keeps other goals and mandatory payments in the forecast")
            } else { fatalError("Selected goal option verdict: \(scopedGoalOption.verdict)") }
            var unconfirmedGoalHorizon = scopedGoalSnapshot
            unconfirmedGoalHorizon.nextIncomeConfirmed = false
            switch FinanceEngine().goalContributionShiftPurchaseOption(
                Money(rubles: 100), snapshot: unconfirmedGoalHorizon, planID: firstGoalPlan.id,
                goalTitle: "Цель A", shiftedFirstDate: shiftedGoalDate,
                shiftedOccurrenceCount: 1, shiftedFinalContribution: nil, now: now) {
            case nil: print("PASS: goal change scenario requires confirmed next income")
            case .some: fatalError("Unconfirmed income must not enable a goal change scenario")
            }
            var partiallySettledGoal = scopedGoalSnapshot
            partiallySettledGoal.scheduledSettlements = [ScheduledSettlement(
                scheduledItemID: firstGoalPlan.id, occurrenceDate: firstGoalPlan.dueDate,
                transactionID: UUID(), amount: Money(rubles: 100))]
            verify(FinanceEngine().goalContributionShiftPurchaseOption(
                Money(rubles: 100), snapshot: partiallySettledGoal, planID: firstGoalPlan.id,
                goalTitle: "Цель A", shiftedFirstDate: shiftedGoalDate,
                shiftedOccurrenceCount: 1, shiftedFinalContribution: nil, now: now) == nil,
                "goal schedule shift cannot move a partially settled occurrence")
            var settledFutureGoal = scopedGoalSnapshot
            let laterOriginalOccurrence = ScheduledRecurrence.nextDate(after: shiftedGoalDate,
                anchoredAt: firstGoalPlan.dueDate, recurrence: .monthly)!
            settledFutureGoal.scheduledSettlements = [ScheduledSettlement(
                scheduledItemID: firstGoalPlan.id, occurrenceDate: laterOriginalOccurrence,
                transactionID: UUID(), amount: Money(rubles: 100))]
            verify(FinanceEngine().goalContributionShiftPurchaseOption(
                Money(rubles: 100), snapshot: settledFutureGoal, planID: firstGoalPlan.id,
                goalTitle: "Цель A", shiftedFirstDate: shiftedGoalDate,
                shiftedOccurrenceCount: 1, shiftedFinalContribution: nil, now: now) == nil,
                "goal schedule shift cannot orphan an already reconciled later payment")

            let monthEndPlanDate = horizonCalendar.date(from: DateComponents(year: 2026, month: 1, day: 31, hour: 12))!
            let februaryGoalOccurrence = horizonCalendar.date(from: DateComponents(year: 2026, month: 2, day: 28, hour: 12))!
            let marchIncome = horizonCalendar.date(from: DateComponents(year: 2026, month: 3, day: 5, hour: 12))!
            let monthEndGoalPlan = ScheduledItem(title: "Цель с графиком 31-го", amount: Money(rubles: 500),
                dueDate: monthEndPlanDate, kind: .goalContribution, recurrence: .monthly)
            let monthEndGoalSnapshot = FinanceSnapshot(bankBalances: [Money(rubles: 5_000)],
                scheduledItems: [monthEndGoalPlan], nextIncomeConfirmed: true, nextIncomeDate: marchIncome,
                forecastDailySpend: .zero, hasReliableSpendForecast: true, dataUpdatedAt: februaryGoalOccurrence)
            let shiftedMarch31 = horizonCalendar.date(from: DateComponents(year: 2026, month: 3, day: 31, hour: 12))!
            verify(FinanceEngine().goalContributionShiftPurchaseOption(
                Money(rubles: 100), snapshot: monthEndGoalSnapshot, planID: monthEndGoalPlan.id,
                goalTitle: "Цель с графиком 31-го", shiftedFirstDate: shiftedMarch31,
                shiftedOccurrenceCount: 1, shiftedFinalContribution: nil, now: februaryGoalOccurrence,
                calendar: horizonCalendar) != nil,
                "goal schedule shift preserves the original month-end anchor after February")
            let shiftedMarch28 = horizonCalendar.date(from: DateComponents(year: 2026, month: 3, day: 28, hour: 12))!
            verify(FinanceEngine().goalContributionShiftPurchaseOption(
                Money(rubles: 100), snapshot: monthEndGoalSnapshot, planID: monthEndGoalPlan.id,
                goalTitle: "Цель с графиком 31-го", shiftedFirstDate: shiftedMarch28,
                shiftedOccurrenceCount: 1, shiftedFinalContribution: nil, now: februaryGoalOccurrence,
                calendar: horizonCalendar) == nil,
                "goal schedule shift rejects a date that drifts from the original month-end anchor")

            var stale = snapshot
            stale.dataUpdatedAt = now.addingTimeInterval(-73 * 3_600)
            if case .insufficientData = FinanceEngine().safeDailySpendingLimit(stale, now: now) {
                print("PASS: stale balance cannot produce a daily spending limit")
            } else { fatalError("Expected stale balance to block daily limit") }

            var withoutBalance = snapshot
            withoutBalance.bankBalances = []
            if case .insufficientData = FinanceEngine().safeDailySpendingLimit(withoutBalance, now: now) {
                print("PASS: missing account balances cannot produce a daily spending limit")
            } else { fatalError("Expected missing balances to block daily limit") }

            var withoutIncomeDate = snapshot
            withoutIncomeDate.nextIncomeDate = nil
            if case .insufficientData = FinanceEngine().safeDailySpendingLimit(withoutIncomeDate, now: now) {
                print("PASS: missing next income date cannot produce a daily spending limit")
            } else { fatalError("Expected missing income date to block daily limit") }
        }

        do {
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            let incomeDate = now.addingTimeInterval(7 * 86_400)
            let snapshot = FinanceSnapshot(bankBalances: [Money(rubles: 1_000)],
                scheduledItems: [ScheduledItem(title: "Платёж в день поступления", amount: Money(rubles: 300), dueDate: incomeDate)],
                incomes: [IncomeEvent(title: "Ожидаемый доход", amount: Money(rubles: 10_000), date: incomeDate, isConfirmed: true)],
                nextIncomeConfirmed: true, nextIncomeDate: incomeDate, forecastDailySpend: .zero, dataUpdatedAt: now)
            verify(FinanceEngine().availableNow(snapshot, now: now) == Money(rubles: 700),
                   "available amount reserves obligations due on the income date before the deposit")
        }

        do {
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            let sameDate = now.addingTimeInterval(3 * 86_400)
            let snapshot = FinanceSnapshot(bankBalances: [.zero],
                scheduledItems: [ScheduledItem(title: "Обязательный платёж", amount: Money(rubles: 100), dueDate: sameDate)],
                incomes: [IncomeEvent(title: "Поступление", amount: Money(rubles: 100), date: sameDate, isConfirmed: true)],
                nextIncomeConfirmed: true, nextIncomeDate: now.addingTimeInterval(7 * 86_400), forecastDailySpend: .zero, dataUpdatedAt: now)
            let verdict = FinanceEngine().checkPurchase(.zero, snapshot: snapshot, now: now)
            if case .unsafe(let shortfall, let date) = verdict {
                verify(shortfall == Money(rubles: 100) && date == sameDate,
                       "same-date obligation is evaluated before uncertain-time income")
            } else { fatalError("Same-date obligation must not rely on unverified income timing") }
        }

        do {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = FinanceSnapshot(bankBalances: [Money(rubles: 1_000)], nextIncomeConfirmed: true, nextIncomeDate: now.addingTimeInterval(7 * 86_400), dataUpdatedAt: now.addingTimeInterval(-80 * 3_600))
        let result = FinanceEngine().checkPurchase(Money(rubles: 100), snapshot: snapshot, now: now)
        if case .insufficientData = result { print("PASS: stale bank data blocks confident verdict") }
        else { fatalError("Expected stale data warning") }
        verify(FinanceEngine().availableNow(snapshot, now: now) == .zero,
               "stale balance cannot produce an available-to-spend amount")
        }

        do {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let stale = now.addingTimeInterval(-73 * 60 * 60)
        let recent = now.addingTimeInterval(-60 * 60)
        let unchangedBalanceTimestamp = BalanceUpdatePolicy.updatedAt(
            previous: stale, explicitlyConfirmed: false, now: now
        )
        verify(unchangedBalanceTimestamp == stale && !FinanceDataFreshness.isFresh(unchangedBalanceTimestamp, asOf: now),
               "editing reserve, income date, account name, or inclusion never refreshes balance freshness")
        verify(BalanceUpdatePolicy.updatedAt(previous: stale, explicitlyConfirmed: true, now: now) == now,
               "explicitly confirming the balance refreshes its timestamp")
        verify(BalanceUpdatePolicy.requiresConfirmation(valueChanged: true, explicitlyConfirmed: false) &&
               !BalanceUpdatePolicy.requiresConfirmation(valueChanged: true, explicitlyConfirmed: true) &&
               !BalanceUpdatePolicy.requiresConfirmation(valueChanged: false, explicitlyConfirmed: false),
               "a changed balance must be reconfirmed after editing before it can become fresh")
        let combinedTimestamp = FinanceDataFreshness.oldestUpdateDate([recent, stale])
        verify(combinedTimestamp == stale, "combined account freshness uses the oldest included account")
        verify(FinanceDataFreshness.oldestUpdateDate([], fallback: recent) == recent,
               "manual balance freshness remains the fallback when there are no bank accounts")
        verify(FinanceDataFreshness.isFresh(now.addingTimeInterval(-FinanceDataFreshness.maximumAge), asOf: now),
               "balance at the exact freshness boundary remains usable")
        verify(!FinanceDataFreshness.isFresh(nil, asOf: now) &&
               !FinanceDataFreshness.isFresh(now.addingTimeInterval(1), asOf: now) &&
               !FinanceDataFreshness.isFresh(now, asOf: now, maximumAge: .infinity),
               "missing, future, and invalid freshness inputs are rejected")
        let missingTimestampVerdict = FinanceEngine().checkPurchase(Money(rubles: 1), snapshot: FinanceSnapshot(
            bankBalances: [Money(rubles: 1_000)], nextIncomeConfirmed: true, nextIncomeDate: now.addingTimeInterval(5 * 86_400)), now: now)
        if case .insufficientData = missingTimestampVerdict {
            print("PASS: purchase check requires a known balance update time")
        } else { fatalError("Missing balance timestamp must block a confident purchase verdict") }
        let futureTimestampVerdict = FinanceEngine().checkPurchase(Money(rubles: 1), snapshot: FinanceSnapshot(
            bankBalances: [Money(rubles: 1_000)], nextIncomeConfirmed: true, nextIncomeDate: now.addingTimeInterval(5 * 86_400),
            dataUpdatedAt: now.addingTimeInterval(1)), now: now)
        if case .insufficientData = futureTimestampVerdict {
            print("PASS: purchase check rejects a future balance update time")
        } else { fatalError("Future balance timestamp must block a confident purchase verdict") }
        let snapshot = FinanceSnapshot(bankBalances: [Money(rubles: 1_000), Money(rubles: 1_000)],
            nextIncomeConfirmed: true, nextIncomeDate: now.addingTimeInterval(5 * 86_400), dataUpdatedAt: combinedTimestamp)
        if case .insufficientData = FinanceEngine().checkPurchase(Money(rubles: 100), snapshot: snapshot, now: now) {
            print("PASS: a fresh account cannot hide another stale account")
        } else { fatalError("A combined balance with one stale source must not receive a confident verdict") }
        let allFresh = FinanceDataFreshness.oldestUpdateDate([recent, now.addingTimeInterval(-2 * 60 * 60)])
        let freshSnapshot = FinanceSnapshot(bankBalances: [Money(rubles: 1_000), Money(rubles: 1_000)],
            nextIncomeConfirmed: true, nextIncomeDate: now.addingTimeInterval(5 * 86_400), dataUpdatedAt: allFresh)
        if case .canBuy = FinanceEngine().checkPurchase(Money(rubles: 100), snapshot: freshSnapshot, now: now) {
            print("PASS: a combined balance remains usable when every source is fresh")
        } else { fatalError("Fresh combined account balances should remain usable") }
        }

        do {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!
        let due = calendar.date(from: DateComponents(year: 2025, month: 11, day: 1, hour: 12))!
        let income = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 12))!
        let snapshot = FinanceSnapshot(bankBalances: [Money(rubles: 1_000)],
            scheduledItems: [ScheduledItem(title: "Подписка", amount: Money(rubles: 400), dueDate: due, recurrence: .monthly)],
            nextIncomeConfirmed: true, nextIncomeDate: income, dataUpdatedAt: now)
        verify(FinanceEngine().availableNow(snapshot, now: now) == Money(rubles: 200),
               "monthly obligations through the income date are reserved before income")
        }

        do {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 12))!
        let due = calendar.date(from: DateComponents(year: 2026, month: 5, day: 3, hour: 12))!
        let income = calendar.date(from: DateComponents(year: 2026, month: 5, day: 10, hour: 12))!
        let plan = ScheduledItem(title: "Платёж", amount: Money(rubles: 1_000), dueDate: due)
        let payment = Transaction(date: due, merchant: "Получатель", amount: Money(rubles: 400), kind: .transfer)
        let settlement = ScheduledSettlementPolicy.makeSettlement(transaction: payment, item: plan,
            occurrenceDate: due, settlements: [], calendar: calendar) ??
            ScheduledSettlement(scheduledItemID: plan.id, occurrenceDate: due,
                transactionID: payment.id, amount: .zero)
        let snapshot = FinanceSnapshot(bankBalances: [Money(rubles: 2_000)], scheduledItems: [plan],
            scheduledSettlements: [settlement], nextIncomeConfirmed: true, nextIncomeDate: income,
            forecastDailySpend: .zero, dataUpdatedAt: now)
        let encodedSnapshot = try? JSONEncoder().encode(snapshot)
        var legacySnapshotObject = encodedSnapshot.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        legacySnapshotObject?.removeValue(forKey: "scheduledSettlements")
        let legacySnapshotData = legacySnapshotObject.flatMap { try? JSONSerialization.data(withJSONObject: $0) }
        let legacySnapshot = legacySnapshotData.flatMap { try? JSONDecoder().decode(FinanceSnapshot.self, from: $0) }
        verify(legacySnapshot?.scheduledSettlements.isEmpty == true && legacySnapshot?.bankBalances == snapshot.bankBalances,
               "legacy finance snapshots decode without the optional settlement ledger")
        var incompleteSnapshotObject = encodedSnapshot.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        incompleteSnapshotObject?.removeValue(forKey: "hasReliableSpendForecast")
        let incompleteSnapshotData = incompleteSnapshotObject.flatMap { try? JSONSerialization.data(withJSONObject: $0) }
        let incompleteSnapshot = incompleteSnapshotData.flatMap { try? JSONDecoder().decode(FinanceSnapshot.self, from: $0) }
        verify(incompleteSnapshot?.hasReliableSpendForecast == false,
               "missing forecast-confidence data defaults to unsafe rather than reliable")
        verify(FinanceEngine().availableNow(snapshot, now: now) == Money(rubles: 1_400),
               "available-money calculation reserves only the unpaid part of a settled obligation")
        let horizon = FinanceEngine().horizon(snapshot, days: 4, now: now, calendar: calendar)
        verify(horizon.points.last?.projectedBalance == Money(rubles: 1_400),
               "financial horizon applies the remaining settled obligation once")
        var fullySettled = snapshot
        fullySettled.scheduledSettlements = [
            settlement,
            ScheduledSettlement(scheduledItemID: plan.id, occurrenceDate: due,
                transactionID: UUID(), amount: Money(rubles: 600))
        ]
        verify(FinanceEngine().availableNow(fullySettled, now: now) == Money(rubles: 2_000),
               "fully settled obligation is removed from available-money reservation")
        }

        do {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1, hour: 12))!
        let due = calendar.date(from: DateComponents(year: 2026, month: 1, day: 31, hour: 12))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 3, day: 29, hour: 12))!
        let februaryDue = ScheduledRecurrence.nextDate(after: due, anchoredAt: due,
            recurrence: .monthly, calendar: calendar)
        let marchDue = februaryDue.flatMap { ScheduledRecurrence.nextDate(after: $0, anchoredAt: due,
            recurrence: .monthly, calendar: calendar) }
        verify(februaryDue == calendar.date(from: DateComponents(year: 2026, month: 2, day: 28, hour: 12)) &&
               marchDue == calendar.date(from: DateComponents(year: 2026, month: 3, day: 31, hour: 12)),
               "shared recurrence rule restores the original day after a short month")
        let monthEndPlan = ScheduledItem(title: "Платёж 31 числа", amount: Money(rubles: 100),
            dueDate: due, recurrence: .monthly)
        verify(ScheduledRecurrence.isOccurrence(februaryDue!, of: monthEndPlan, calendar: calendar) &&
               !ScheduledRecurrence.isOccurrence(calendar.date(from: DateComponents(year: 2026, month: 3, day: 30, hour: 12))!,
                   of: monthEndPlan, calendar: calendar),
               "settlement accepts only dates in the anchored recurrence schedule")
        let finiteMonthEndPlan = ScheduledItem(title: "Два платежа", amount: Money(rubles: 100),
            dueDate: due, recurrence: .monthly, occurrencesRemaining: 2)
        verify(!ScheduledRecurrence.isOccurrence(marchDue!, of: finiteMonthEndPlan, calendar: calendar),
               "settlement rejects an occurrence beyond a finite plan limit")
        let invalidDateSettlement = ScheduledSettlement(scheduledItemID: monthEndPlan.id,
            occurrenceDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 30, hour: 12))!,
            transactionID: UUID(), amount: Money(rubles: 100))
        verify(ScheduledSettlementPolicy.remainingAmount(for: monthEndPlan,
               occurrenceDate: invalidDateSettlement.occurrenceDate, settlements: [invalidDateSettlement],
               calendar: calendar) == Money(rubles: 100),
               "malformed settlement ledger cannot reduce an obligation on a non-occurrence date")
        let weeklyPlan = ScheduledItem(title: "Еженедельный платёж", amount: Money(rubles: 100),
            dueDate: due, recurrence: .weekly)
        verify(ScheduledRecurrence.isOccurrence(calendar.date(from: DateComponents(year: 2026, month: 2, day: 7, hour: 12))!,
                   of: weeklyPlan, calendar: calendar) &&
               !ScheduledRecurrence.isOccurrence(calendar.date(from: DateComponents(year: 2026, month: 2, day: 8, hour: 12))!,
                   of: weeklyPlan, calendar: calendar),
               "settlement validates weekly occurrence dates without replaying old weeks")
        let annualLeapPlan = ScheduledItem(title: "Ежегодный платёж", amount: Money(rubles: 100),
            dueDate: calendar.date(from: DateComponents(year: 2024, month: 2, day: 29, hour: 12))!, recurrence: .yearly)
        verify(ScheduledRecurrence.isOccurrence(calendar.date(from: DateComponents(year: 2025, month: 2, day: 28, hour: 12))!,
                   of: annualLeapPlan, calendar: calendar),
               "settlement preserves the February 29 anchor in non-leap years")
        let marchFirst = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 8))!
        let firstMonthEndAfterTarget = ScheduledRecurrence.firstOccurrence(onOrAfter: marchFirst,
            of: monthEndPlan, calendar: calendar)
        verify(firstMonthEndAfterTarget == calendar.date(from: DateComponents(year: 2026, month: 3, day: 31, hour: 12)),
               "first future monthly occurrence jumps to the anchored month-end date")
        let oldWeeklyPlan = ScheduledItem(title: "Старый еженедельный план", amount: Money(rubles: 100),
            dueDate: calendar.date(from: DateComponents(year: 1900, month: 1, day: 1, hour: 12))!, recurrence: .weekly)
        let firstOldWeeklyAfterTarget = ScheduledRecurrence.firstOccurrence(onOrAfter: marchFirst,
            of: oldWeeklyPlan, calendar: calendar)
        verify(firstOldWeeklyAfterTarget.map { $0 >= calendar.startOfDay(for: marchFirst) &&
            ScheduledRecurrence.isOccurrence($0, of: oldWeeklyPlan, calendar: calendar) } == true,
               "first future weekly occurrence jumps over a century of missed dates")
        let exhaustedReminderPlan = ScheduledItem(title: "Одноразовый старый план", amount: Money(rubles: 100),
            dueDate: calendar.date(from: DateComponents(year: 2026, month: 1, day: 31, hour: 12))!,
            recurrence: .monthly, occurrencesRemaining: 1)
        verify(ScheduledRecurrence.firstOccurrence(onOrAfter: marchFirst, of: exhaustedReminderPlan,
                                                    calendar: calendar) == nil,
               "first future occurrence respects an exhausted finite plan")
        let snapshot = FinanceSnapshot(bankBalances: [Money(rubles: 2_000)],
            scheduledItems: [ScheduledItem(title: "Платёж 31 числа", amount: Money(rubles: 100), dueDate: due, recurrence: .monthly)],
            nextIncomeConfirmed: true, nextIncomeDate: end, forecastDailySpend: .zero, dataUpdatedAt: now)
        verify(FinanceEngine().availableNow(snapshot, now: now) == Money(rubles: 1_900),
               "end-of-month recurrence returns to day 31 after February")
        let oldWeeklyDue = calendar.date(from: DateComponents(year: 1900, month: 1, day: 1, hour: 12))!
        let oldWeeklyEnd = calendar.date(byAdding: .day, value: 10, to: now)!
        let oldWeeklySnapshot = FinanceSnapshot(bankBalances: [Money(rubles: 1_000)],
            scheduledItems: [ScheduledItem(title: "Давний еженедельный план", amount: Money(rubles: 100),
                dueDate: oldWeeklyDue, recurrence: .weekly)],
            nextIncomeConfirmed: true, nextIncomeDate: oldWeeklyEnd, forecastDailySpend: .zero, dataUpdatedAt: now)
        verify(FinanceEngine().availableNow(oldWeeklySnapshot, now: now) == Money(rubles: 800),
               "old weekly recurrence jumps to only the two occurrences inside the horizon")
        var oldMonthlySnapshot = snapshot
        oldMonthlySnapshot.scheduledItems[0].dueDate = calendar.date(from: DateComponents(year: 1900, month: 1, day: 31, hour: 12))!
        verify(FinanceEngine().availableNow(oldMonthlySnapshot, now: now) == Money(rubles: 1_900),
               "old month-end recurrence jumps to the clamped day in the current month")
        var oldFiniteWeeklySnapshot = oldWeeklySnapshot
        oldFiniteWeeklySnapshot.scheduledItems[0].occurrencesRemaining = 2
        verify(FinanceEngine().availableNow(oldFiniteWeeklySnapshot, now: now) == Money(rubles: 1_000),
               "old finite weekly recurrence is exhausted without replaying its full history")
        let oldAnnualDue = calendar.date(from: DateComponents(year: 1904, month: 2, day: 29, hour: 12))!
        let annualJumpNow = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 12))!
        let annualJumpEnd = calendar.date(from: DateComponents(year: 2028, month: 2, day: 29, hour: 13))!
        let oldAnnualSnapshot = FinanceSnapshot(bankBalances: [Money(rubles: 1_000)],
            scheduledItems: [ScheduledItem(title: "Давний годовой платёж", amount: Money(rubles: 100),
                dueDate: oldAnnualDue, recurrence: .yearly)],
            nextIncomeConfirmed: true, nextIncomeDate: annualJumpEnd, forecastDailySpend: .zero,
            dataUpdatedAt: annualJumpNow)
        verify(FinanceEngine().availableNow(oldAnnualSnapshot, now: annualJumpNow) == Money(rubles: 800),
               "old leap-day annual recurrence jumps across years and returns to February 29")
        let leapNow = calendar.date(from: DateComponents(year: 2024, month: 2, day: 1, hour: 12))!
        let leapDue = calendar.date(from: DateComponents(year: 2024, month: 1, day: 31, hour: 12))!
        let leapEnd = calendar.date(from: DateComponents(year: 2024, month: 3, day: 1, hour: 12))!
        let leapSnapshot = FinanceSnapshot(bankBalances: [Money(rubles: 1_000)],
            scheduledItems: [ScheduledItem(title: "Високосный месяц", amount: Money(rubles: 100), dueDate: leapDue, recurrence: .monthly)],
            nextIncomeConfirmed: true, nextIncomeDate: leapEnd, forecastDailySpend: .zero, dataUpdatedAt: leapNow)
        verify(FinanceEngine().availableNow(leapSnapshot, now: leapNow) == Money(rubles: 900),
               "monthly recurrence uses February 29 in a leap year")
        let annualDue = calendar.date(from: DateComponents(year: 2024, month: 2, day: 29, hour: 12))!
        let annualNow = calendar.date(from: DateComponents(year: 2024, month: 3, day: 1, hour: 12))!
        let annualLimit = calendar.date(from: DateComponents(year: 2025, month: 2, day: 28, hour: 13))!
        let annualSnapshot = FinanceSnapshot(bankBalances: [Money(rubles: 1_000)],
            scheduledItems: [ScheduledItem(title: "Годовой платёж 29 февраля", amount: Money(rubles: 100),
                dueDate: annualDue, recurrence: .yearly)],
            nextIncomeConfirmed: true, nextIncomeDate: annualLimit, forecastDailySpend: .zero, dataUpdatedAt: annualNow)
        verify(FinanceEngine().availableNow(annualSnapshot, now: annualNow) == Money(rubles: 900),
               "annual leap-day recurrence uses February 28 in a non-leap year")
        let leapReturnNow = calendar.date(from: DateComponents(year: 2027, month: 3, day: 1, hour: 12))!
        let leapReturnLimit = calendar.date(from: DateComponents(year: 2028, month: 2, day: 29, hour: 13))!
        var leapReturnSnapshot = annualSnapshot
        leapReturnSnapshot.nextIncomeDate = leapReturnLimit
        leapReturnSnapshot.dataUpdatedAt = leapReturnNow
        verify(FinanceEngine().availableNow(leapReturnSnapshot, now: leapReturnNow) == Money(rubles: 900),
               "annual leap-day recurrence returns to February 29 in a leap year")
        let exhaustedSnapshot = FinanceSnapshot(bankBalances: [Money(rubles: 1_000)],
            scheduledItems: [ScheduledItem(title: "Завершённый платёж", amount: Money(rubles: 100), dueDate: due,
                recurrence: .monthly, occurrencesRemaining: 1)],
            nextIncomeConfirmed: true, nextIncomeDate: end, forecastDailySpend: .zero, dataUpdatedAt: now)
        verify(FinanceEngine().availableNow(exhaustedSnapshot, now: now) == Money(rubles: 1_000),
               "finite recurring item stops reserving money after its last occurrence")
        let invalidCountSnapshot = FinanceSnapshot(bankBalances: [Money(rubles: 1_000)],
            scheduledItems: [ScheduledItem(title: "Некорректный счётчик", amount: Money(rubles: 100), dueDate: now,
                recurrence: .monthly, occurrencesRemaining: -1)],
            nextIncomeConfirmed: true, nextIncomeDate: end, forecastDailySpend: .zero, dataUpdatedAt: now)
        verify(FinanceEngine().availableNow(invalidCountSnapshot, now: now) == Money(rubles: 1_000),
               "negative remaining-occurrence count is treated as exhausted")
        }

        do {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = FinanceSnapshot(bankBalances: [Money(rubles: 1_000)], nextIncomeConfirmed: true, nextIncomeDate: now.addingTimeInterval(5 * 86_400),
                                       forecastDailySpend: Money(rubles: 100), dataUpdatedAt: now)
        verify(FinanceEngine().availableNow(snapshot, now: now) == Money(rubles: 500), "forecast variable spend reduces available amount")

        let largeFractionalSpend = FinanceSnapshot(bankBalances: [Money(kopecks: Int64.max)],
            nextIncomeConfirmed: true, nextIncomeDate: now.addingTimeInterval(12 * 3_600), forecastDailySpend: Money(kopecks: Int64.max), dataUpdatedAt: now)
        verify(FinanceEngine().availableNow(largeFractionalSpend, now: now) == Money(kopecks: Int64.max / 2),
               "fractional-day spending rounds up exactly without floating-point kopeck drift")
        }

        do {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = FinanceSnapshot(bankBalances: [Money(rubles: 1_000)],
            protectedReserve: Money(rubles: 200),
            scheduledItems: [ScheduledItem(title: "Некорректный отрицательный платёж", amount: Money(rubles: -800),
                dueDate: now.addingTimeInterval(86_400))],
            nextIncomeConfirmed: true, nextIncomeDate: now.addingTimeInterval(5 * 86_400), forecastDailySpend: Money(rubles: -100),
            dataUpdatedAt: now, goalReserve: Money(rubles: -400))
        verify(FinanceEngine().availableNow(snapshot, now: now) == Money(rubles: 800),
               "negative reserve, obligation and daily estimate cannot inflate spendable money")
        if case .unsafe(let shortfall, _) = FinanceEngine().checkPurchase(Money(rubles: 900), snapshot: snapshot, now: now) {
            verify(shortfall == Money(rubles: 100), "negative obligation and daily spend cannot make an unsafe purchase appear affordable")
        } else { fatalError("Malformed negative planning amounts must not create phantom income") }
        }

        do {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let dayThree = calendar.date(from: DateComponents(year: 2026, month: 1, day: 3, hour: 12))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 1, day: 4))!
        let transactions = [
            Transaction(date: start.addingTimeInterval(3_600), merchant: "Продукты", amount: Money(rubles: 100), kind: .purchase, category: .groceries),
            Transaction(date: start.addingTimeInterval(7_200), merchant: "Кафе", amount: Money(rubles: 200), kind: .purchase, category: .cafe),
            Transaction(date: dayThree, merchant: "Метро", amount: Money(rubles: 50), kind: .purchase, category: .transport),
            Transaction(date: dayThree, merchant: "Зачисление", amount: Money(rubles: 5_000), kind: .income, category: .income),
            Transaction(date: dayThree, merchant: "Возврат покупки", amount: Money(rubles: 250), kind: .refund, category: .refunds),
            Transaction(date: dayThree, merchant: "Свой счёт", amount: Money(rubles: 900), kind: .transfer, category: .transfers, isInternalTransfer: true),
            Transaction(date: dayThree, merchant: "Перевод другу", amount: Money(rubles: 70), kind: .transfer, category: .transfers),
            Transaction(date: dayThree, merchant: "Комиссия", amount: Money(rubles: 5), kind: .fee, category: .fees),
            Transaction(date: end, merchant: "Вне диапазона", amount: Money(rubles: 400), kind: .purchase, category: .other)
        ]
        let summary = SpendingAnalytics.summarize(transactions, from: start, to: end, calendar: calendar)
        verify(summary.total == Money(rubles: 425) && summary.transactionCount == 5, "spending analytics includes purchases, external transfers and fees but excludes income, refunds and internal transfers")
        let customCurrent = DateInterval(start: start, end: end)
        let previousCustom = SpendingAnalytics.previousEqualLengthInterval(before: customCurrent,
            earliestAvailableDate: start.addingTimeInterval(-7 * 86_400), calendar: calendar)
        verify(previousCustom?.start == calendar.date(byAdding: .day, value: -3, to: start) &&
               previousCustom?.end == start,
               "custom analytics comparison uses the immediately preceding equal calendar interval")
        verify(SpendingAnalytics.previousEqualLengthInterval(before: customCurrent,
            earliestAvailableDate: start.addingTimeInterval(-2 * 86_400), calendar: calendar) == nil,
               "custom analytics comparison is hidden when the full previous period is outside loaded history")
        verify(SpendingAnalytics.totalOutflow(transactions, from: start, to: end) == summary.total,
               "shared outflow total matches dashboard analytics")
        verify(SpendingAnalytics.totalOutflow(transactions, from: start, to: end, category: .transfers) == Money(rubles: 70),
               "shared outflow total supports category budget checks")
        let validBudgetDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        verify(CategoryBudgetPolicy.isValid(category: .groceries, limit: Money(rubles: 1_000),
              periodStart: validBudgetDate, calendar: calendar), "category budget accepts a supported category and positive monthly limit")
        verify(!CategoryBudgetPolicy.isValid(category: .groceries, limit: .zero,
              periodStart: validBudgetDate, calendar: calendar), "category budget rejects a zero limit")
        verify(!CategoryBudgetPolicy.isValid(category: .groceries, limit: Money(kopecks: -1),
              periodStart: validBudgetDate, calendar: calendar), "category budget rejects a negative limit")
        verify(!CategoryBudgetPolicy.isValid(category: .transfers, limit: Money(rubles: 1_000),
              periodStart: validBudgetDate, calendar: calendar), "category budget rejects a non-purchase category")
        verify(!CategoryBudgetPolicy.isValid(category: .groceries, limit: Money(rubles: 1_000),
              periodStart: Date(timeIntervalSince1970: .infinity), calendar: calendar),
              "category budget rejects a non-finite period date")
        verify(summary.daily.map(\.amount) == [Money(rubles: 300), .zero, Money(rubles: 125)], "spending analytics fills zero-spend days and counts outgoing transfers/fees")
        verify(summary.categories.map(\.category) == [.cafe, .groceries, .transfers, .transport, .fees], "spending analytics ranks expense categories and excludes income/internal transfers")
        let futureDatedPurchase = Transaction(date: dayThree.addingTimeInterval(60 * 60),
            merchant: "Покупка с будущей отметкой", amount: Money(rubles: 500), kind: .purchase)
        let cutoffSummary = SpendingAnalytics.summarize(transactions + [futureDatedPurchase],
            from: start, to: end, calendar: calendar, asOf: dayThree)
        verify(cutoffSummary.total == summary.total && cutoffSummary.transactionCount == summary.transactionCount &&
               cutoffSummary.daily == summary.daily,
               "analytics as of now excludes posted outflows timestamped later today")
        verify(SpendingAnalytics.totalOutflow(transactions + [futureDatedPurchase], from: start, to: end,
              asOf: dayThree) == summary.total,
              "category budget outflow total excludes posted transactions after its as-of date")
        let cutoffComparison = SpendingAnalytics.compare(transactions + [futureDatedPurchase],
            current: DateInterval(start: dayThree, end: end),
            previous: DateInterval(start: start, end: dayThree), asOf: dayThree)
        verify(cutoffComparison?.currentTotal == Money(rubles: 125) &&
               cutoffComparison?.previousTotal == Money(rubles: 300),
               "period comparison applies the current-time cutoff to today's portion")
        let comparison = SpendingAnalytics.compare(
            transactions,
            current: DateInterval(start: dayThree, end: end),
            previous: DateInterval(start: start, end: dayThree)
        )
        verify(comparison?.currentTotal == Money(rubles: 125) && comparison?.previousTotal == Money(rubles: 300) &&
               comparison?.difference == Money(rubles: -175),
               "period comparison uses shared outflow rules and reports the exact signed difference")
        verify(SpendingAnalytics.compare(transactions,
               current: DateInterval(start: end, end: end),
               previous: DateInterval(start: start, end: dayThree)) == nil,
               "period comparison declines an empty interval")
        let jan31 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 31, hour: 12))!
        let februaryComparison = SpendingAnalytics.previousMonthToDateInterval(for: jan31, calendar: calendar)
        verify(februaryComparison?.start == calendar.date(from: DateComponents(year: 2025, month: 12, day: 1))! &&
               februaryComparison?.end == calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!,
               "month comparison clamps a 31st-day date to the previous month's final day")
        let march31 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 31, hour: 12))!
        let leapFebruaryComparison = SpendingAnalytics.previousMonthToDateInterval(for: march31, calendar: calendar)
        verify(leapFebruaryComparison?.start == calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))! &&
               leapFebruaryComparison?.end == calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!,
               "month comparison uses the leap February's final day")
        let janIncome = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12))!
        let febIncome = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1, hour: 12))!
        let feb10 = calendar.date(from: DateComponents(year: 2026, month: 2, day: 10, hour: 12))!
        let cycleTransactions = [
            Transaction(date: janIncome, merchant: "Поддержка", amount: Money(rubles: 5_000), kind: .income, category: .income),
            Transaction(date: febIncome, merchant: "Поддержка", amount: Money(rubles: 5_000), kind: .income, category: .income),
            Transaction(date: febIncome.addingTimeInterval(3_600), merchant: "Доплата", amount: Money(rubles: 500), kind: .incomingTransfer),
            Transaction(date: calendar.date(from: DateComponents(year: 2026, month: 1, day: 3))!, merchant: "Прошлая покупка", amount: Money(rubles: 70), kind: .purchase),
            Transaction(date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 3))!, merchant: "Покупка цикла", amount: Money(rubles: 100), kind: .purchase),
            Transaction(date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 8))!, merchant: "Свой счёт", amount: Money(rubles: 9_000), kind: .incomingTransfer, isInternalTransfer: true),
            Transaction(date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 9))!, merchant: "Возврат", amount: Money(rubles: 2_000), kind: .refund)
        ]
        let futurePostedIncome = Transaction(date: feb10.addingTimeInterval(6 * 60 * 60),
            merchant: "Будущее зачисление", amount: Money(rubles: 10_000), kind: .income)
        verify(SpendingAnalytics.incomeCyclePeriods([futurePostedIncome], asOf: feb10, calendar: calendar) == nil,
               "future-dated posted income cannot create a current income cycle")
        let cycleWithFutureIncome = SpendingAnalytics.incomeCyclePeriods(
            cycleTransactions + [futurePostedIncome], asOf: feb10, calendar: calendar)
        verify(cycleWithFutureIncome?.current.start == febIncome && cycleWithFutureIncome?.current.end == feb10,
               "future-dated income does not replace or extend the current as-of income-cycle interval")
        let cyclePeriods = SpendingAnalytics.incomeCyclePeriods(cycleTransactions, asOf: feb10, calendar: calendar)
        verify(cyclePeriods?.current.start == febIncome && cyclePeriods?.previousComparable != nil,
               "income-cycle analytics anchors to the latest posted income and finds a previous comparison")
        if let cyclePeriods, let previous = cyclePeriods.previousComparable {
            let currentTotal = SpendingAnalytics.totalOutflow(cycleTransactions, from: cyclePeriods.current.start, to: cyclePeriods.current.end)
            let previousTotal = SpendingAnalytics.totalOutflow(cycleTransactions, from: previous.start, to: previous.end)
            verify(currentTotal == Money(rubles: 100) && previousTotal == Money(rubles: 70),
                   "income-cycle comparison excludes internal transfers and refunds from both boundaries and outflows")
            verify(abs(previous.duration - feb10.timeIntervalSince(febIncome)) < 0.001,
                   "income-cycle comparison uses the exact elapsed as-of duration, not the rest of today")
        } else { fatalError("Two posted incomes should produce comparable cycle periods") }
        let oneIncome = SpendingAnalytics.incomeCyclePeriods([cycleTransactions[1], cycleTransactions[2]], asOf: feb10, calendar: calendar)
        verify(oneIncome?.current != nil && oneIncome?.previousComparable == nil,
               "multiple deposits on one day form one income boundary without fabricating a historical comparison")
        verify(SpendingAnalytics.incomeCyclePeriods([cycleTransactions[5], cycleTransactions[6]], asOf: feb10, calendar: calendar) == nil,
               "internal transfers and refunds cannot establish an income cycle")
        let empty = SpendingAnalytics.summarize(transactions, from: end, to: start, calendar: calendar)
        verify(empty.total == .zero && empty.daily.isEmpty, "spending analytics safely handles an invalid date interval")
        let extremeRows = [
            Transaction(date: start, merchant: "Максимальная трата 1", amount: Money(kopecks: Int64.max), kind: .purchase, category: .shopping),
            Transaction(date: start, merchant: "Максимальная трата 2", amount: Money(kopecks: Int64.max), kind: .purchase, category: .shopping)
        ]
        let saturated = SpendingAnalytics.summarize(extremeRows, from: start, to: end, calendar: calendar)
        verify(saturated.total.kopecks == Int64.max && saturated.daily[0].amount.kopecks == Int64.max &&
               saturated.categories[0].amount.kopecks == Int64.max,
               "spending analytics saturates totals instead of overflowing into a negative spend")
        }

        do {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = FinanceSnapshot(bankBalances: [Money(rubles: 1_500)],
            scheduledItems: [
                ScheduledItem(title: "Цель", amount: Money(rubles: 500), dueDate: now.addingTimeInterval(2 * 86_400), kind: .goalContribution),
                ScheduledItem(title: "Дорога", amount: Money(rubles: 500), dueDate: now.addingTimeInterval(4 * 86_400))
            ], nextIncomeConfirmed: true, nextIncomeDate: now.addingTimeInterval(7 * 86_400), dataUpdatedAt: now)
        let verdict = FinanceEngine().checkPurchase(Money(rubles: 800), on: now, snapshot: snapshot, now: now)
        if case .canBuyWithChanges = verdict { print("PASS: flexible goal contribution can be offered as a purchase tradeoff") }
        else { fatalError("Expected a valid goal adjustment option") }
        }

        do {
        let csv = "Дата;Описание;Сумма\n28.10.2026;Метро; -95,50\n"
        let rows = try CSVStatementImporter().parse(data: Data(csv.utf8))
        verify(rows.count == 1, "CSV parser reads one operation")
        verify(rows[0].statementDateIdentity?.hasPrefix("wall:") == true,
               "CSV preserves date-only source wall-clock identity for stable account fingerprints")
        verify(rows[0].amount == Money(rubles: 95.5), "CSV parser preserves decimal kopecks")
        verify(rows[0].category == .transport, "CSV parser categorizes transit")
        let tabSeparated = try CSVStatementImporter().parse(data: Data(
            "Дата\tОписание\tСумма\n28.10.2026\t\"Магазин, дом; сектор 2\"\t-95,50\n".utf8))
        verify(tabSeparated.count == 1 && tabSeparated[0].amount == Money(rubles: 95.5) &&
               tabSeparated[0].merchant == "Магазин, дом; сектор 2",
               "statement importer detects tab-separated files and preserves quoted delimiter characters")
        do {
            _ = try CSVStatementImporter().parse(data: Data("Дата,Описание;Сумма\n28.10.2026,Метро;-95\n".utf8))
            verify(false, "CSV importer rejects ambiguous header delimiters")
        } catch ImportError.ambiguousDelimiter {
            verify(true, "CSV importer rejects ambiguous header delimiters")
        }
        let quotedCommaAmount = try CSVStatementImporter().parse(data: Data(
            "Date,Description,Amount\n2026-10-28,Metro,\"-95,50\"\n".utf8))
        verify(quotedCommaAmount[0].amount == Money(rubles: 95.5),
               "comma-delimited CSV preserves decimal-comma amounts when correctly quoted")
        do {
            _ = try CSVStatementImporter().parse(data: Data("Date,Description,Amount\n2026-10-28,Metro,-95,50\n".utf8))
            verify(false, "CSV importer rejects extra fields that could silently truncate decimal-comma amounts")
        } catch ImportError.invalidRow(2) {
            verify(true, "CSV importer rejects extra fields that could silently truncate decimal-comma amounts")
        }
        let categoryBoundaryRows = try CSVStatementImporter().parse(data: Data(
            "Дата;Описание;Сумма\n28.10.2026;Метрополь;-100\n28.10.2026;Кафельный дом;-200\n28.10.2026;Переводчик книг;-300\n28.10.2026;Яндекс Такси;-400\n28.10.2026;Кофейня у дома;-150\n28.10.2026;Yandex Plus;-399\n".utf8))
        verify(categoryBoundaryRows.map(\.category) == [.other, .other, .other, .transport, .cafe, .subscriptions] &&
               categoryBoundaryRows[2].kind == .purchase,
               "CSV category and transfer keywords match whole words and phrases instead of misleading substrings")
        let pendingRows = try CSVStatementImporter().parse(data: Data(
            "Дата;Описание;Сумма;Статус операции\n28.10.2026;Метро;-95,50;В обработке\n".utf8),
            sourceNamespace: "status-account")
        verify(pendingRows[0].status == .pending, "CSV status column imports a pending operation")
        verify(rows[0].status == .posted, "CSV without a status column treats statement rows as posted")
        let encodedPending = try JSONEncoder().encode(pendingRows[0])
        var legacyJSON = try JSONSerialization.jsonObject(with: encodedPending) as! [String: Any]
        legacyJSON.removeValue(forKey: "status")
        legacyJSON.removeValue(forKey: "providerTransactionID")
        legacyJSON.removeValue(forKey: "refundOfProviderTransactionID")
        legacyJSON.removeValue(forKey: "refundOfTransactionID")
        legacyJSON.removeValue(forKey: "statementDateIdentity")
        let legacyTransaction = try JSONDecoder().decode(Transaction.self, from: JSONSerialization.data(withJSONObject: legacyJSON))
        verify(legacyTransaction.isPosted && legacyTransaction.providerTransactionID == nil &&
               legacyTransaction.refundOfProviderTransactionID == nil && legacyTransaction.refundOfTransactionID == nil &&
               legacyTransaction.statementDateIdentity == nil,
               "legacy serialized transactions without newer status, provider metadata, or CSV date identity remain decodable")
        let pendingExpense = Transaction(date: .now, merchant: "Ожидает", amount: Money(rubles: 900),
                                         kind: .purchase, status: .pending)
        verify(SpendingAnalytics.totalOutflow([pendingExpense], from: .distantPast, to: .distantFuture) == .zero,
               "pending purchases are excluded from posted spending analytics")
        verify(SpendingForecaster().estimateDailySpend([pendingExpense], endingAt: .now) == nil,
               "pending purchases cannot distort the spending forecast")
        verify(RecurringDetector().detect([pendingExpense, pendingExpense, pendingExpense]).isEmpty,
               "pending purchases cannot generate recurring-payment suggestions")
        verify(SpendingAnalytics.incomeCyclePeriods([
            Transaction(date: .now.addingTimeInterval(-86_400), merchant: "Доход", amount: Money(rubles: 1_000),
                        kind: .income, status: .pending)
        ], asOf: .now) == nil, "pending income cannot establish an income cycle")
        var flipGesture = DoubleFlipPrivacyGesture(maximumInterval: 3)
        let flipStart = Date(timeIntervalSince1970: 1_800_000_000)
        verify(!flipGesture.record(isFaceDown: false, at: flipStart) &&
               !flipGesture.record(isFaceDown: true, at: flipStart.addingTimeInterval(0.2)) &&
               !flipGesture.record(isFaceDown: true, at: flipStart.addingTimeInterval(0.3)) &&
               flipGesture.record(isFaceDown: false, at: flipStart.addingTimeInterval(0.4)) == false &&
               flipGesture.record(isFaceDown: true, at: flipStart.addingTimeInterval(0.6)),
               "two face-down flips separated by face-up hide amounts, while repeated sensor events do not")
        flipGesture.reset()
        verify(!flipGesture.record(isFaceDown: false, at: flipStart) &&
               !flipGesture.record(isFaceDown: true, at: flipStart.addingTimeInterval(0.1)) &&
               !flipGesture.record(isFaceDown: false, at: flipStart.addingTimeInterval(0.2)) &&
               !flipGesture.record(isFaceDown: true, at: flipStart.addingTimeInterval(3.2)),
               "privacy flip gesture expires after its configured time window")
        do {
            _ = try CSVStatementImporter().parse(data: Data(
                "Дата;Описание;Сумма;Статус\n28.10.2026;Метро;-95;Неизвестный статус\n".utf8))
            fatalError("Expected an unknown operation status to be rejected")
        } catch ImportError.invalidStatus(let row, _) {
            verify(row == 2, "CSV importer rejects unknown statuses with the source row number")
        }
        let localizedHeaderRows = try CSVStatementImporter().parse(data: Data(
            "Дата операции;Назначение платежа;Дебет;Кредит\n28.10.2026;Метро;95,50;\n".utf8))
        verify(localizedHeaderRows.count == 1 && localizedHeaderRows[0].kind == .purchase &&
               localizedHeaderRows[0].category == .transport,
               "CSV recognizes operation date, payment purpose, and debit/credit Russian headers")
        for duplicateProviderIDCSV in [
            "Дата;Описание;Сумма;ID операции\n28.10.2026;Покупка;-100;txn-1\n28.10.2026;Покупка;-100;txn-1\n",
            "Дата;Описание;Сумма;ID операции\n28.10.2026;Покупка;-100;txn-1\n29.10.2026;Изменённая версия;-120;txn-1\n"
        ] {
            do {
                _ = try CSVStatementImporter().parse(data: Data(duplicateProviderIDCSV.utf8))
                fatalError("Expected duplicate provider transaction ID rejection")
            } catch ImportError.duplicateProviderTransactionID(let row) {
                verify(row == 3, "CSV rejects a repeated bank transaction ID instead of importing duplicate/conflicting rows")
            }
        }
        let creditLimitHeaderRows = try CSVStatementImporter().parse(data: Data(
            "Дата;Описание;Дебет;Кредитный лимит\n28.10.2026;Метро;95,50;30 000,00\n".utf8))
        verify(creditLimitHeaderRows.count == 1 && creditLimitHeaderRows[0].kind == .purchase &&
               creditLimitHeaderRows[0].amount == Money(rubles: 95.5),
               "CSV does not mistake a credit limit column for incoming transaction amount")
        for duplicateDirectionHeader in [
            "Дата;Описание;Дебет;Дебет (RUB);Кредит\n28.10.2026;Метро;95,50;;\n",
            "Дата;Описание;Дебет;Кредит;Кредит (RUB)\n28.10.2026;Поступление;;500,00;500,00\n"
        ] {
            do {
                _ = try CSVStatementImporter().parse(data: Data(duplicateDirectionHeader.utf8))
                fatalError("Expected duplicate debit/credit header rejection")
            } catch ImportError.ambiguousAmountColumns {
                print("PASS: CSV rejects duplicate debit/credit amount headers")
            }
        }
        let operationDateRows = try CSVStatementImporter().parse(data: Data(
            "Дата выписки;Дата операции;Описание;Сумма\n01.11.2026;02.11.2026;Метро;-50\n".utf8))
        verify(Calendar.current.component(.day, from: operationDateRows[0].date) == 2,
               "CSV prefers the transaction date over the statement-generation date")
        let zonedTimestamp = "2026-10-28T09:30:00+03:00"
        let fractionalTimestamp = "2026-10-28T06:30:00.125Z"
        let isoDateRows = try CSVStatementImporter().parse(data: Data(
            ("Дата;Описание;Сумма\n\(zonedTimestamp);Метро;-50\n\(fractionalTimestamp);Кафе;-100\n").utf8))
        let expectedZonedDate = ISO8601DateFormatter().date(from: zonedTimestamp)
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let expectedFractionalDate = fractionalFormatter.date(from: fractionalTimestamp)
        verify(isoDateRows.count == 2 && isoDateRows[0].date == expectedZonedDate &&
               isoDateRows[1].date == expectedFractionalDate,
               "CSV preserves ISO-8601 timezone offsets and fractional seconds")
        verify(isoDateRows.allSatisfy { $0.statementDateIdentity?.hasPrefix("instant:") == true },
               "CSV fingerprints ISO-8601 rows by their absolute timestamp")
        let timezoneStatement = Data("Дата;Описание;Сумма\n28.10.2026;Метро;-50\n2026-10-28 09:30:00;Кафе;-100\n2026-10-28T09:30:00+03:00;Такси;-200\n".utf8)
        let moscowTimeZone = TimeZone(secondsFromGMT: 3 * 60 * 60)!
        let vladivostokTimeZone = TimeZone(secondsFromGMT: 10 * 60 * 60)!
        let moscowParsed = try CSVStatementImporter().parse(data: timezoneStatement,
            sourceNamespace: "timezone-test-account", timeZone: moscowTimeZone)
        let vladivostokParsed = try CSVStatementImporter().parse(data: timezoneStatement,
            sourceNamespace: "timezone-test-account", timeZone: vladivostokTimeZone)
        verify(moscowParsed.count == 3 && vladivostokParsed.count == 3 &&
               moscowParsed[0].date != vladivostokParsed[0].date &&
               moscowParsed[0].sourceID == vladivostokParsed[0].sourceID &&
               moscowParsed[1].date != vladivostokParsed[1].date &&
               moscowParsed[1].sourceID == vladivostokParsed[1].sourceID &&
               moscowParsed[2].date == vladivostokParsed[2].date &&
               moscowParsed[2].sourceID == vladivostokParsed[2].sourceID,
               "CSV source IDs preserve wall-clock rows across timezone changes and absolute ISO timestamps across zones")
        do {
            _ = try CSVStatementImporter().parse(data: Data(
                "Дата выписки;Дата валютирования;Описание;Сумма\n01.11.2026;02.11.2026;Метро;-50\n".utf8))
            fatalError("Expected ambiguous date columns rejection")
        } catch ImportError.ambiguousDateColumns {
            print("PASS: CSV rejects multiple non-operation date columns instead of guessing")
        }
        do {
            _ = try CSVStatementImporter().parse(data: Data(
                "Дата валютирования;Описание;Сумма\n02.11.2026;Метро;-50\n".utf8))
            fatalError("Expected value-date-only CSV rejection")
        } catch ImportError.ambiguousDateColumns {
            print("PASS: CSV rejects a value date when no transaction date is available")
        }
        let bomCSV = "\u{FEFF}Дата;Описание;Сумма\n28.10.2026;Метро;-95,50\n"
        let bomRows = try CSVStatementImporter().parse(data: Data(bomCSV.utf8))
        verify(bomRows.count == 1 && bomRows[0].kind == .purchase && bomRows[0].amount == Money(rubles: 95.5),
               "CSV parser ignores a UTF-8 BOM before the header")
        let trailingEmptyColumns = "Дата;Описание;Сумма;Дебет;Кредит\n28.10.2026;Метро;-95,50\n"
        let trailingEmptyRows = try CSVStatementImporter().parse(data: Data(trailingEmptyColumns.utf8))
        verify(trailingEmptyRows.count == 1 && trailingEmptyRows[0].amount == Money(rubles: 95.5),
               "CSV parser keeps transactions when optional trailing columns are omitted")
        let amountWithDebitCredit: [Transaction]
        do {
            amountWithDebitCredit = try CSVStatementImporter().parse(data: Data(
                "Дата;Описание;Сумма;Дебет;Кредит\n28.10.2026;Метро;95,50;95,50;\n28.10.2026;Возврат;95,50;;95,50\n".utf8))
        } catch { fatalError("CSV mixed amount/debit-credit rows errored: \(error)") }
        verify(amountWithDebitCredit.count == 2 && amountWithDebitCredit[0].kind == .purchase &&
               amountWithDebitCredit[1].kind == .refund,
               "CSV uses explicit debit/credit direction when a matching unsigned amount column is also present")
        for inconsistentAmountAndDirection in [
            "Дата;Описание;Сумма;Дебет;Кредит\n28.10.2026;Метро;95,50;90,00;\n",
            "Дата;Описание;Сумма;Дебет;Кредит\n28.10.2026;Операция;95,50;95,50;95,50\n"
        ] {
            do {
                _ = try CSVStatementImporter().parse(data: Data(inconsistentAmountAndDirection.utf8))
                fatalError("Expected mixed amount/debit-credit conflict to be rejected")
            } catch ImportError.invalidRow(let row) {
                verify(row == 2, "CSV rejects conflicting magnitude or simultaneous debit and credit when amount columns overlap")
            }
        }
        let omittedCreditColumn = "Дата;Описание;Дебет;Кредит\n28.10.2026;Метро;95,50\n"
        let omittedCreditRows = try CSVStatementImporter().parse(data: Data(omittedCreditColumn.utf8))
        verify(omittedCreditRows.count == 1 && omittedCreditRows[0].kind == .purchase && omittedCreditRows[0].amount == Money(rubles: 95.5),
               "CSV debit/credit parsing tolerates an omitted trailing empty credit column")
        let creditOnlyRows = try CSVStatementImporter().parse(data: Data(
            "Дата;Описание;Дебет;Кредит\n28.10.2026;Поступление;;1 250,00\n".utf8))
        verify(creditOnlyRows.count == 1 && creditOnlyRows[0].kind == .income &&
               creditOnlyRows[0].amount == Money(rubles: 1_250),
               "CSV debit/credit parsing preserves a valid credit when debit is blank")
        for malformedDebitCredit in [
            "Дата;Описание;Дебет;Кредит\n28.10.2026;Метро;ошибка;500,00\n",
            "Дата;Описание;Дебет;Кредит\n28.10.2026;Метро;95,50;ошибка\n"
        ] {
            do {
                _ = try CSVStatementImporter().parse(data: Data(malformedDebitCredit.utf8))
                fatalError("Expected malformed debit/credit cell rejection")
            } catch ImportError.invalidRow(let row) {
                verify(row == 2, "CSV rejects malformed populated debit/credit cells instead of treating them as zero")
            }
        }
        let contradictoryRows = [
            "Дата;Описание;Дебет;Кредит\n28.10.2026;Метро;95,50;500,00\n",
            "Дата;Описание;Дебет;Кредит\n28.10.2026;Метро;-95,50;500,00\n",
            "Дата;Описание;Дебет;Кредит\n28.10.2026;Метро;95,50;-500,00\n",
            "Дата;Описание;Дебет;Кредит\n28.10.2026;Метро;-95,50;-500,00\n"
        ]
        for contradictory in contradictoryRows {
            do {
                _ = try CSVStatementImporter().parse(data: Data(contradictory.utf8))
                fatalError("Expected contradictory debit/credit row rejection")
            } catch ImportError.invalidRow(let row) {
                verify(row == 2, "CSV parser rejects rows that report both a debit and a credit, regardless of signs")
            }
        }
        do {
            _ = try CSVStatementImporter().parse(data: Data("Дата;Описание;Сумма\n28.10.2026;Метро\n".utf8))
            fatalError("Expected short transaction row rejection")
        } catch ImportError.invalidRow(let row) {
            verify(row == 2, "CSV parser reports a short transaction row instead of silently dropping it")
        }
        let multilineCSV = "Дата;Описание;Сумма\r\n28.10.2026;\"Магазин; отдел\r\nпродуктов\";123,45\r\n29.10.2026;Кафе;200\r\n"
        let multilineRows = try CSVStatementImporter().parse(data: Data(multilineCSV.utf8))
        verify(multilineRows.count == 2 && multilineRows[0].merchant == "Магазин; отдел\nпродуктов" && multilineRows[1].merchant == "Кафе",
               "CSV parser preserves quoted line breaks without splitting a transaction into extra rows")
        let sameOperationFromAnotherAccount = try CSVStatementImporter().parse(data: Data(csv.utf8), sourceNamespace: "another-account")
        verify(rows[0].sourceID != sameOperationFromAnotherAccount[0].sourceID, "CSV deduplication keeps identical operations from separate source accounts")
        let importer = CSVStatementImporter()
        let movedFileRows = try importer.parse(data: Data(csv.utf8), sourceNamespace: "file-at-new-path")
        let accountScopedRows = importer.assigningSourceIDs(to: rows, sourceNamespace: "account-123")
        let sameAccountFromMovedFile = importer.assigningSourceIDs(to: movedFileRows, sourceNamespace: "account-123")
        let otherAccountRows = importer.assigningSourceIDs(to: rows, sourceNamespace: "account-456")
        verify(accountScopedRows[0].sourceID == sameAccountFromMovedFile[0].sourceID,
               "account-scoped CSV IDs stay stable when the same statement moves to another file path")
        var timezoneShiftedRows = rows
        timezoneShiftedRows[0].date = timezoneShiftedRows[0].date.addingTimeInterval(7 * 60 * 60)
        let timezoneShiftedImport = importer.prepareImport(timezoneShiftedRows, sourceNamespace: "account-123",
            existingSourceIDs: Set(accountScopedRows.compactMap(\.sourceID)))
        verify(timezoneShiftedImport.transactions.isEmpty && timezoneShiftedImport.duplicateCount == rows.count,
               "date-only account-scoped CSV re-import stays deduplicated after a device timezone shift")
        var legacyTimestampRows = rows
        legacyTimestampRows[0].statementDateIdentity = nil
        let legacyTimestampIDs = Set(importer.assigningSourceIDs(to: legacyTimestampRows,
            sourceNamespace: "account-123").compactMap(\.sourceID))
        let legacyTimestampReimport = importer.prepareImport(rows, sourceNamespace: "account-123",
            existingSourceIDs: legacyTimestampIDs)
        verify(legacyTimestampReimport.transactions.isEmpty && legacyTimestampReimport.duplicateCount == rows.count,
               "new stable CSV fingerprints continue to match previously stored timestamp-based fingerprints")
        verify(importer.excludingStoredDuplicates(accountScopedRows, existingSourceIDs: legacyTimestampIDs).isEmpty,
               "persistence-time recheck matches legacy timestamp IDs after the preview was prepared")
        verify(accountScopedRows[0].sourceID != otherAccountRows[0].sourceID,
               "account-scoped CSV IDs keep matching purchases from separate accounts distinct")
        var normalizedMerchant = rows[0]
        normalizedMerchant.merchant = "  МЕТРО  "
        let normalizedMerchantID = importer.assigningSourceIDs(to: [normalizedMerchant], sourceNamespace: "account-123")[0].sourceID
        verify(normalizedMerchantID == accountScopedRows[0].sourceID,
               "account-scoped CSV IDs ignore merchant case and surrounding whitespace")
        let repeatedRowsCSV = "Дата;Описание;Сумма\n28.10.2026;Метро;95,50\n28.10.2026;Метро;95,50\n"
        let repeatedRows = try importer.parse(data: Data(repeatedRowsCSV.utf8), sourceNamespace: "statement")
        let repeatedIDs = importer.assigningSourceIDs(to: repeatedRows, sourceNamespace: "account-123").compactMap(\.sourceID)
        verify(repeatedIDs.count == 2 && Set(repeatedIDs).count == 2,
               "account-scoped CSV IDs preserve two genuinely repeated identical transactions")
        let firstImport = importer.prepareImport(rows, sourceNamespace: "account-123", existingSourceIDs: [])
        verify(firstImport.transactions.count == 1 && firstImport.duplicateCount == 0,
               "statement import preview reports all rows as new on first import")
        let movedFileImport = importer.prepareImport(movedFileRows, sourceNamespace: "account-123",
            existingSourceIDs: Set(firstImport.transactions.compactMap(\.sourceID)))
        verify(movedFileImport.transactions.isEmpty && movedFileImport.duplicateCount == 1,
               "statement import preview identifies moved-file re-imports as duplicates")
        let providerIDRow = Transaction(merchant: "Обновлённое название магазина", amount: Money(rubles: 125),
            kind: .fee, providerTransactionID: "bank-operation-7")
        let existingProviderRow = ExistingProviderTransaction(providerTransactionID: "bank-operation-7",
            sourceID: "old-fingerprint", status: .posted, merchant: "Старое название магазина",
            amount: Money(rubles: 120), date: providerIDRow.date.addingTimeInterval(-86_400), kind: .purchase)
        let providerDuplicate = importer.prepareImport([providerIDRow], sourceNamespace: "account-123",
            existingSourceIDs: [], existingProviderTransactions: [existingProviderRow])
        verify(providerDuplicate.transactions.isEmpty && providerDuplicate.duplicateCount == 1 &&
               providerDuplicate.providerConflicts.count == 1 &&
               providerDuplicate.providerConflicts[0].existingMerchant == "Старое название магазина" &&
               providerDuplicate.providerConflicts[0].importedAmount == Money(rubles: 125) &&
               providerDuplicate.providerConflicts[0].existingDate == existingProviderRow.date &&
               providerDuplicate.providerConflicts[0].importedDate == providerIDRow.date &&
               providerDuplicate.providerConflicts[0].existingKind == .purchase &&
               providerDuplicate.providerConflicts[0].importedKind == .fee,
               "provider ID conflict preview preserves old and imported merchant, amount, date and kind")
        let conflictingPostedProviderRow = Transaction(merchant: "Магазин", amount: Money(rubles: 125),
            kind: .purchase, status: .posted, providerTransactionID: "bank-operation-conflict-pending")
        let conflictingPendingSourceID = importer.assigningSourceIDs(to: [conflictingPostedProviderRow],
            sourceNamespace: "account-conflict-pending")[0].sourceID!
        let conflictingPendingProviderRow = ExistingProviderTransaction(
            providerTransactionID: "bank-operation-conflict-pending", sourceID: conflictingPendingSourceID,
            status: .pending, merchant: "Магазин", amount: Money(rubles: 100),
            date: conflictingPostedProviderRow.date, kind: .purchase)
        let conflictingPendingRefresh = importer.prepareImport([conflictingPostedProviderRow],
            sourceNamespace: "account-conflict-pending",
            existingStatuses: [conflictingPendingSourceID: .pending],
            existingProviderTransactions: [conflictingPendingProviderRow])
        verify(conflictingPendingRefresh.providerConflicts.count == 1 &&
               conflictingPendingRefresh.statusUpdates.isEmpty && conflictingPendingRefresh.transactions.isEmpty,
               "conflicting posted bank row cannot silently promote a pending row or keep its stale amount")
        let ambiguousProviderRows = [existingProviderRow,
            ExistingProviderTransaction(providerTransactionID: "bank-operation-7", sourceID: "another-source",
                status: .pending, merchant: "Другая запись", amount: Money(rubles: 110),
                date: providerIDRow.date, kind: .purchase)]
        let ambiguousProviderDuplicate = importer.prepareImport([providerIDRow], sourceNamespace: "account-123",
            existingStatuses: [:], existingProviderTransactions: ambiguousProviderRows)
        verify(ambiguousProviderDuplicate.transactions.isEmpty && ambiguousProviderDuplicate.duplicateCount == 1 &&
               ambiguousProviderDuplicate.providerConflicts.isEmpty && ambiguousProviderDuplicate.statusUpdates.isEmpty,
               "ambiguous stored provider IDs suppress import without guessing a conflict row or promoting status")
        let pendingProviderRow = ExistingProviderTransaction(providerTransactionID: "bank-operation-8",
            sourceID: "pending-fingerprint", status: .pending, merchant: "Магазин",
            amount: Money(rubles: 125), date: .now, kind: .purchase)
        var postedProviderRow = Transaction(merchant: "Магазин", amount: Money(rubles: 125),
            kind: .purchase, status: .posted, providerTransactionID: "bank-operation-8")
        postedProviderRow.date = pendingProviderRow.date
        let providerStatusRefresh = importer.prepareImport([postedProviderRow], sourceNamespace: "account-123",
            existingStatuses: [:], existingProviderTransactions: [pendingProviderRow])
        verify(providerStatusRefresh.transactions.isEmpty && providerStatusRefresh.duplicateCount == 1 &&
               providerStatusRefresh.statusUpdates.count == 1 &&
               providerStatusRefresh.statusUpdates[0].identity == .providerTransactionID("bank-operation-8") &&
               providerStatusRefresh.statusUpdates[0].status == .posted &&
               providerStatusRefresh.statusUpdates[0].expectedStoredValues?.matches(
                   merchant: pendingProviderRow.merchant, amount: pendingProviderRow.amount,
                   date: pendingProviderRow.date, kind: pendingProviderRow.kind) == true &&
               providerStatusRefresh.statusUpdates[0].expectedStoredValues?.matches(
                   merchant: pendingProviderRow.merchant, amount: Money(rubles: 126),
                   date: pendingProviderRow.date, kind: pendingProviderRow.kind) == false,
               "provider ID re-import promotes one pending row without adding a changed-fingerprint duplicate")
        var sourceAndProviderPending = Transaction(merchant: "Магазин", amount: Money(rubles: 125),
            kind: .purchase, status: .pending, providerTransactionID: "bank-operation-9")
        let sourceAndProviderID = importer.assigningSourceIDs(to: [sourceAndProviderPending],
            sourceNamespace: "account-123")[0].sourceID!
        sourceAndProviderPending.status = .posted
        let existingSourceAndProvider = ExistingProviderTransaction(providerTransactionID: "bank-operation-9",
            sourceID: sourceAndProviderID, status: .pending, merchant: "Магазин", amount: Money(rubles: 125),
            date: sourceAndProviderPending.date, kind: .purchase)
        let singleStatusPromotion = importer.prepareImport([sourceAndProviderPending], sourceNamespace: "account-123",
            existingStatuses: [sourceAndProviderID: .pending], existingProviderTransactions: [existingSourceAndProvider])
        verify(singleStatusPromotion.statusUpdates.count == 1 &&
               singleStatusPromotion.statusUpdates[0].identity == .sourceID(sourceAndProviderID) &&
               singleStatusPromotion.statusUpdates[0].status == .posted,
            "source-ID status promotion prevents a duplicate provider-ID update for the same stored row")
        verify(importer.excludingStoredDuplicates([providerIDRow], existingSourceIDs: [],
              existingProviderTransactionIDs: ["bank-operation-7"]).isEmpty,
               "persistence-time recheck suppresses provider-ID duplicates from a stale preview")
        var newlyPostedRows = rows
        newlyPostedRows[0].status = .posted
        let pendingSourceID = importer.assigningSourceIDs(to: rows, sourceNamespace: "account-status")[0].sourceID!
        let statusRefresh = importer.prepareImport(newlyPostedRows, sourceNamespace: "account-status",
            existingStatuses: [pendingSourceID: .pending])
        verify(statusRefresh.transactions.isEmpty && statusRefresh.duplicateCount == 1 &&
               statusRefresh.statusUpdates.count == 1 &&
               statusRefresh.statusUpdates[0].identity == .sourceID(pendingSourceID) &&
               statusRefresh.statusUpdates[0].status == .posted &&
               statusRefresh.statusUpdates[0].expectedStoredValues != nil,
               "re-importing a now-posted operation updates status instead of adding a duplicate")
        let distinctAccountImport = importer.prepareImport(rows, sourceNamespace: "account-456",
            existingSourceIDs: Set(firstImport.transactions.compactMap(\.sourceID)))
        verify(distinctAccountImport.transactions.count == 1 && distinctAccountImport.duplicateCount == 0,
               "statement import preview does not suppress an identical row from another account")
        let firstRepeatedImport = importer.prepareImport(repeatedRows, sourceNamespace: "account-123", existingSourceIDs: [])
        let repeatedReimport = importer.prepareImport(repeatedRows, sourceNamespace: "account-123",
            existingSourceIDs: Set(firstRepeatedImport.transactions.compactMap(\.sourceID)))
        verify(firstRepeatedImport.transactions.count == 2 && repeatedReimport.transactions.isEmpty && repeatedReimport.duplicateCount == 2,
               "statement import preview preserves repeated purchases initially and skips both on re-import")
        let stalePreviewRows = importer.excludingStoredDuplicates(firstRepeatedImport.transactions,
            existingSourceIDs: [firstRepeatedImport.transactions[0].sourceID!])
        verify(stalePreviewRows.count == 1 &&
               stalePreviewRows[0].sourceID == firstRepeatedImport.transactions[1].sourceID,
               "persistence-time duplicate recheck retains the second identical row with its original source ID")
        let unscopedManualRow = Transaction(merchant: "Ручная операция", amount: Money(rubles: 10), kind: .purchase)
        verify(importer.excludingStoredDuplicates([unscopedManualRow], existingSourceIDs: Set(repeatedIDs)).count == 1,
               "persistence-time duplicate recheck keeps rows without provider/source identifiers")
        verify(RecurringDetector().detect(repeatedReimport.transactions).isEmpty,
               "re-imported duplicate rows do not create duplicate recurring-payment suggestions")
        let unboundLegacy = try importer.parse(data: Data(csv.utf8), sourceNamespace: "legacy-file-path")
        let upgradedImport = importer.prepareImport(unboundLegacy, sourceNamespace: "account-123",
            existingSourceIDs: Set(unboundLegacy.compactMap(\.sourceID)))
        verify(upgradedImport.transactions.isEmpty && upgradedImport.duplicateCount == 1,
               "account binding avoids duplicating an unbound import from the same file path")

        let localizedAmounts = "Дата;Описание;Сумма\n" + [
            "28.10.2026;NBSP;1\u{00A0}234,56 ₽",
            "28.10.2026;Narrow NBSP;1\u{202F}234,56",
            "28.10.2026;European separators;1.234,56",
            "28.10.2026;English separators;1,234.56",
            "28.10.2026;Apostrophe grouping;1'234,56",
            "28.10.2026;Ruble suffix;1 234,56 руб.",
            "28.10.2026;Multiple space groups;1 234 567,89",
            "28.10.2026;Unicode minus;−95,50",
            "28.10.2026;Accounting negative;(95,50)"
        ].joined(separator: "\n") + "\n"
        let amountRows = try CSVStatementImporter().parse(data: Data(localizedAmounts.utf8))
        verify(amountRows.prefix(6).allSatisfy { $0.amount == Money(rubles: 1_234.56) }, "CSV parser handles valid Russian, English, space, and apostrophe number grouping")
        verify(amountRows[6].amount == Money(rubles: 1_234_567.89), "CSV parser accepts correctly grouped multiple thousands")
        verify(amountRows[7].kind == .purchase && amountRows[7].amount == Money(rubles: 95.5), "CSV parser recognizes Unicode minus in expense values")
        verify(amountRows[8].kind == .purchase && amountRows[8].amount == Money(rubles: 95.5), "CSV parser recognizes accounting parentheses as negative amounts")
        for malformedAmount in ["1,2,3", "12,34,567", "1.234.56", "1₽2", "1 2 3"] {
            do {
                _ = try CSVStatementImporter().parse(data: Data("Дата;Описание;Сумма\n28.10.2026;Некорректная сумма;\(malformedAmount)\n".utf8))
                fatalError("Expected malformed grouping rejection for \(malformedAmount)")
            } catch ImportError.invalidRow(let row) {
                verify(row == 2, "CSV rejects malformed or misplaced numeric separators")
            }
        }
        let exactTrailingZero = try CSVStatementImporter().parse(data: Data("Дата;Описание;Сумма\n28.10.2026;Точный ноль;1,230\n".utf8))
        verify(exactTrailingZero[0].amount == Money(rubles: 1.23), "CSV accepts extra decimal zeros when the value is exactly representable in kopecks")
        let zeroValueRow = try CSVStatementImporter().parse(data: Data("Дата;Описание;Сумма\n28.10.2026;Проверка карты;0,00\n".utf8))
        verify(zeroValueRow[0].kind == .adjustment && zeroValueRow[0].category == .other && zeroValueRow[0].amount == .zero,
               "CSV zero-value rows remain neutral adjustments instead of being mislabeled as income")
        let rubleCurrencyRows = try CSVStatementImporter().parse(data: Data(
            "Дата;Описание;Сумма;Валюта\n28.10.2026;Метро;-95,50;RUB (643)\n".utf8))
        verify(rubleCurrencyRows.count == 1 && rubleCurrencyRows[0].amount == Money(rubles: 95.5),
               "CSV accepts explicitly identified ruble operations")
        let rubleSettlementRows = try CSVStatementImporter().parse(data: Data(
            "Дата;Описание;Сумма операции;Валюта операции;Сумма в рублях\n28.10.2026;Покупка;-10,00;USD;-1 000,00\n".utf8))
        verify(rubleSettlementRows.count == 1 && rubleSettlementRows[0].amount == Money(rubles: 1_000),
               "CSV prefers an explicit ruble settlement amount over the foreign operation amount")
        do {
            _ = try CSVStatementImporter().parse(data: Data(
                "Дата;Описание;Сумма операции;Сумма в валюте операции\n28.10.2026;Покупка;10,00;10,00\n".utf8))
            fatalError("Expected ambiguous amount columns rejection")
        } catch ImportError.ambiguousAmountColumns {
            print("PASS: CSV rejects multiple amounts when no ruble column or debit/credit mapping is explicit")
        }
        do {
            _ = try CSVStatementImporter().parse(data: Data(
                "Дата;Описание;Сумма;Валюта операции;Валюта счёта\n28.10.2026;Покупка;-10,00;USD;RUB\n".utf8))
            fatalError("Expected ambiguous currency columns rejection")
        } catch ImportError.ambiguousCurrencyColumns {
            print("PASS: CSV rejects multiple currency fields when the amount is not explicitly in rubles")
        }
        do {
            _ = try CSVStatementImporter().parse(data: Data(
                "Дата;Описание;Сумма;Валюта\n28.10.2026;Покупка;-10,00;USD\n".utf8))
            fatalError("Expected non-ruble statement rejection")
        } catch ImportError.unsupportedCurrency(let row, let value) {
            verify(row == 2 && value == "USD", "CSV rejects foreign-currency values instead of treating them as rubles")
        }
        do {
            _ = try CSVStatementImporter().parse(data: Data("Дата;Описание;Сумма\n28.10.2026;Доля копейки;1,005\n".utf8))
            fatalError("Expected sub-kopeck CSV amount rejection")
        } catch ImportError.subKopeckAmount(let row) {
            verify(row == 2, "CSV rejects a fractional kopeck rather than rounding an imported bank amount")
        }
        } catch { fatalError("CSV import test errored: \(error)") }

        do {
            _ = try CSVStatementImporter().parse(data: Data("Дата;Описание;Сумма\n28.10.2026;\"Незакрытое поле;100\n".utf8))
            fatalError("Expected malformed quoted field rejection")
        } catch ImportError.malformedQuoting(let row) {
            verify(row == 2, "CSV parser reports an unterminated quoted field at its starting row")
        } catch { fatalError("CSV malformed-quote test errored: \(error)") }
        for malformedQuotedRow in [
            "Дата;Описание;Сумма\n28.10.2026;Метро;1\"2\n",
            "Дата;Описание;Сумма\n28.10.2026;Метро;\"100\"x\n"
        ] {
            do {
                _ = try CSVStatementImporter().parse(data: Data(malformedQuotedRow.utf8))
                fatalError("Expected invalid CSV quote placement rejection")
            } catch ImportError.malformedQuoting(let row) {
                verify(row == 2, "CSV parser rejects quote placement that could change an imported value")
            } catch { fatalError("CSV invalid quote placement check errored: \(error)") }
        }
        do {
            let escapedQuoteRow = try CSVStatementImporter().parse(data: Data(
                "Дата;Описание;Сумма\n28.10.2026;\"Магазин \"\"Альфа\"\"\";-100\n".utf8))
            verify(escapedQuoteRow.count == 1 && escapedQuoteRow[0].merchant == "Магазин \"Альфа\"",
                   "CSV parser preserves standards-compliant escaped quotes")
        } catch { fatalError("CSV escaped-quote check errored: \(error)") }

        do {
            _ = try CSVStatementImporter().parse(data: Data("Дата;Описание;Сумма\n31.02.2026;Несуществующая дата;100\n".utf8))
            fatalError("Expected invalid calendar date rejection")
        } catch ImportError.invalidRow(let row) {
            verify(row == 2, "CSV parser rejects impossible calendar dates instead of normalizing them")
        } catch { fatalError("CSV date validation test errored: \(error)") }

        for incompleteCSV in [
            "Дата;Описание;Сумма\n;Метро;-100\n",
            "Дата;Контрагент;Описание операции;Сумма\n28.10.2026;;;-100\n",
            "Дата;Описание;Сумма\n28.10.2026;Метро;\n",
            "Дата;Описание;Дебет;Кредит\n28.10.2026;Метро;;\n"
        ] {
            do {
                _ = try CSVStatementImporter().parse(data: Data(incompleteCSV.utf8))
                fatalError("Expected incomplete required CSV fields to be rejected")
            } catch ImportError.invalidRow(let row) {
                verify(row == 2, "CSV rejects a row missing its date, all descriptions, or every amount")
            } catch { fatalError("CSV required-field validation errored: \(error)") }
        }

        do {
            let oversizedAmountCSV = "Дата;Описание;Сумма\n28.10.2026;Сверхлимит;92233720368547758.08\n"
            _ = try CSVStatementImporter().parse(data: Data(oversizedAmountCSV.utf8))
            fatalError("Expected out-of-range financial amount rejection")
        } catch ImportError.amountOutOfRange(let row) {
            verify(row == 2, "CSV import rejects an amount that cannot be represented in kopecks")
        } catch { fatalError("CSV amount-range check errored: \(error)") }

        do {
        let oversized = Data(repeating: 0x20, count: CSVStatementImporter.maximumFileBytes + 1)
        do {
            _ = try CSVStatementImporter().parse(data: oversized)
            fatalError("Expected oversized CSV rejection")
        } catch ImportError.fileTooLarge {
            print("PASS: CSV parser rejects files above the byte limit")
        }
        let tooManyColumns = (0...CSVStatementImporter.maximumColumns).map { "c\($0)" }.joined(separator: ";")
        do {
            _ = try CSVStatementImporter().parse(data: Data((tooManyColumns + "\nrow\n").utf8))
            fatalError("Expected too many columns rejection")
        } catch ImportError.tooManyColumns {
            print("PASS: CSV parser rejects excessive columns")
        }
        let tooLongField = "Дата;Описание;Сумма\n28.10.2026;" + String(repeating: "x", count: CSVStatementImporter.maximumFieldCharacters + 1) + ";1\n"
        do {
            _ = try CSVStatementImporter().parse(data: Data(tooLongField.utf8))
            fatalError("Expected oversized field rejection")
        } catch ImportError.fieldTooLarge {
            print("PASS: CSV parser rejects oversized fields")
        }
        let oversizedMultilineField = "Дата;Описание;Сумма\n28.10.2026;\"" +
            String(repeating: "x", count: CSVStatementImporter.maximumFieldCharacters / 2) + "\n" +
            String(repeating: "y", count: CSVStatementImporter.maximumFieldCharacters / 2 + 1) + "\";1\n"
        do {
            _ = try CSVStatementImporter().parse(data: Data(oversizedMultilineField.utf8))
            fatalError("Expected oversized multiline field rejection")
        } catch ImportError.fieldTooLarge {
            print("PASS: CSV parser applies the field limit across multiline quoted records")
        }
        let tooManyRows = "Дата;Описание;Сумма\n" + String(repeating: "28.10.2026;Метро;1\n", count: CSVStatementImporter.maximumRows + 1)
        do {
            _ = try CSVStatementImporter().parse(data: Data(tooManyRows.utf8))
            fatalError("Expected too many rows rejection")
        } catch ImportError.tooManyRows {
            print("PASS: CSV parser rejects excessive transaction rows")
        }
        } catch { fatalError("CSV resource-limit check errored: \(error)") }

        do {
        let importer = CSVStatementImporter()
        let csv = "Дата;Описание;Сумма\n28.10.2026;Перевод другу; -600,00\n"
        let row = try importer.parse(data: Data(csv.utf8), sourceNamespace: "transfer-statement")[0]
        verify(row.kind == .transfer && row.category == .transfers && row.kind.isOutflow,
               "outgoing transfer remains an expense until confirmed internal")
        let incomingCSV = "Дата;Описание;Сумма\n28.10.2026;Перевод от родителя;600,00\n"
        let incoming = try importer.parse(data: Data(incomingCSV.utf8), sourceNamespace: "incoming-transfer-statement")[0]
        verify(incoming.kind == .incomingTransfer && incoming.category == .transfers && incoming.kind.isInflow &&
               incoming.incomeSource == .parentSupport,
               "parent support remains identifiable without reclassifying an incoming transfer as earned income")
        let multiTextColumnCSV = "Дата;Контрагент;Описание операции;Сумма\n28.10.2026;Мама;Перевод от родителей;600,00\n"
        let multiTextColumn = try importer.parse(data: Data(multiTextColumnCSV.utf8))[0]
        verify(multiTextColumn.merchant == "Мама" && multiTextColumn.kind == .incomingTransfer &&
               multiTextColumn.incomeSource == .parentSupport,
               "CSV classifies transfers and parent support from operation description even when counterparty appears first")
        let missingCounterpartyCSV = "Дата;Контрагент;Описание операции;Сумма\n28.10.2026;;Перевод от родителей;600,00\n"
        let missingCounterparty = try importer.parse(data: Data(missingCounterpartyCSV.utf8))[0]
        verify(missingCounterparty.merchant == "Перевод от родителей" &&
               missingCounterparty.kind == .incomingTransfer && missingCounterparty.incomeSource == .parentSupport,
               "CSV falls back to a populated operation description when the earlier counterparty field is blank")
        let genericIncomingCSV = "Дата;Описание;Сумма\n28.10.2026;Перевод от друга;600,00\n"
        let genericIncoming = try importer.parse(data: Data(genericIncomingCSV.utf8), sourceNamespace: "generic-incoming-transfer")[0]
        verify(genericIncoming.kind == .incomingTransfer && genericIncoming.incomeSource == nil,
               "generic incoming transfers remain distinct from parent support")
        let oldPurchase = Transaction(date: row.date, merchant: row.merchant, amount: row.amount,
            kind: .purchase, category: .transfers)
        let oldPurchaseID = importer.assigningSourceIDs(to: [oldPurchase], sourceNamespace: "transfer-account")[0].sourceID!
        let currentOutgoingID = importer.assigningSourceIDs(to: [row], sourceNamespace: "transfer-account")[0]
        verify(importer.excludingStoredDuplicates([currentOutgoingID], existingSourceIDs: [oldPurchaseID]).isEmpty,
               "persistence-time duplicate recheck also catches an operation concurrently stored under its previous purchase classification")
        let reclassifiedOutgoing = importer.prepareImport([row], sourceNamespace: "transfer-account", existingSourceIDs: [oldPurchaseID])
        verify(reclassifiedOutgoing.transactions.isEmpty && reclassifiedOutgoing.duplicateCount == 1,
               "outgoing transfer reclassification remains compatible with previous purchase IDs")
        var pendingLegacyPurchase = oldPurchase
        pendingLegacyPurchase.status = .pending
        let pendingLegacyID = importer.assigningSourceIDs(to: [pendingLegacyPurchase], sourceNamespace: "transfer-account")[0].sourceID!
        let postedReclassification = importer.prepareImport([row], sourceNamespace: "transfer-account",
            existingStatuses: [pendingLegacyID: .pending])
        verify(postedReclassification.transactions.isEmpty &&
               postedReclassification.statusUpdates.count == 1 &&
               postedReclassification.statusUpdates[0].identity == .sourceID(pendingLegacyID) &&
               postedReclassification.statusUpdates[0].status == .posted &&
               postedReclassification.statusUpdates[0].expectedStoredValues?.kind == .purchase,
               "a pending row promoted by reclassification updates the legacy source row without duplication")
        let oldIncome = Transaction(date: incoming.date, merchant: incoming.merchant, amount: incoming.amount,
            kind: .income, category: .income, incomeSource: .other)
        let oldIncomeID = importer.assigningSourceIDs(to: [oldIncome], sourceNamespace: "incoming-transfer-account")[0].sourceID!
        let reclassifiedIncoming = importer.prepareImport([incoming], sourceNamespace: "incoming-transfer-account", existingSourceIDs: [oldIncomeID])
        verify(reclassifiedIncoming.transactions.isEmpty && reclassifiedIncoming.duplicateCount == 1,
               "incoming transfer reclassification remains compatible with previous income IDs")
        let previousUnboundID = importer.assigningSourceIDs(to: [oldIncome], sourceNamespace: "incoming-transfer-statement")[0].sourceID!
        let reclassifiedUnbound = importer.prepareImport([incoming], sourceNamespace: nil, existingSourceIDs: [previousUnboundID])
        verify(reclassifiedUnbound.transactions.isEmpty && reclassifiedUnbound.duplicateCount == 1,
               "unbound incoming transfer reclassification remains compatible with previous income IDs")
        var pipedIncoming = incoming
        pipedIncoming.merchant = "Перевод | СБП | получатель"
        pipedIncoming = importer.assigningSourceIDs(to: [pipedIncoming], sourceNamespace: "incoming-transfer-statement")[0]
        var pipedOldIncome = oldIncome
        pipedOldIncome.merchant = pipedIncoming.merchant
        let pipedOldID = importer.assigningSourceIDs(to: [pipedOldIncome], sourceNamespace: "incoming-transfer-statement")[0].sourceID!
        let pipedReimport = importer.prepareImport([pipedIncoming], sourceNamespace: nil, existingSourceIDs: [pipedOldID])
        verify(pipedReimport.transactions.isEmpty && pipedReimport.duplicateCount == 1,
               "unbound reclassification IDs preserve merchants containing fingerprint delimiters")
        } catch { fatalError("CSV transfer classification test errored: \(error)") }

        do {
        let csv = "Дата;Описание;Приход;Расход\n27.10.2026;Поддержка от родителей;5000,00;\n28.10.2026;Метро;;95,50\n"
        let rows = try CSVStatementImporter().parse(data: Data(csv.utf8))
        verify(rows.count == 2 && rows[0].kind == .income && rows[1].kind == .purchase, "CSV parser reads separate income and expense columns")
        verify(rows[0].amount == Money(rubles: 5_000) && rows[1].amount == Money(rubles: 95.5), "CSV parser preserves debit and credit values")
        verify(rows[0].incomeSource == .parentSupport, "CSV parser recognizes explicit parent support")
        let unclearIncome = try CSVStatementImporter().parse(data: Data("Дата;Описание;Сумма\n29.10.2026;Зачисление;3000\n".utf8))
        verify(unclearIncome.first?.incomeSource == .other, "unrecognized CSV income stays a separate general income source")
        let feeImporter = CSVStatementImporter()
        let feeRows = try feeImporter.parse(data: Data(
            "Дата;Описание;Сумма\n29.10.2026;Комиссия за обслуживание;-45,00\n29.10.2026;Комиссия за перевод СБП;-15,00\n29.10.2026;Возврат комиссии;15,00\n".utf8),
            sourceNamespace: "fee-statement")
        verify(feeRows.count == 3 && feeRows[0].kind == .fee && feeRows[0].category == .fees &&
               feeRows[1].kind == .fee && feeRows[1].category == .fees &&
               feeRows[2].kind == .refund && feeRows[2].category == .refunds,
               "CSV classifies outgoing service and transfer fees separately while keeping returned fees as refunds")
        let feeDayStart = Calendar.current.startOfDay(for: feeRows[0].date)
        let feeDayEnd = Calendar.current.date(byAdding: .day, value: 1, to: feeDayStart)!
        let importedFeeAnalytics = SpendingAnalytics.summarize(feeRows, from: feeDayStart, to: feeDayEnd)
        verify(importedFeeAnalytics.total == Money(rubles: 60) &&
               importedFeeAnalytics.categories.first?.category == .fees &&
               importedFeeAnalytics.categories.first?.amount == Money(rubles: 60),
               "imported bank fees flow into total outflow and fee-category analytics while refunds stay excluded")
        let legacyFeePurchase = Transaction(date: feeRows[0].date, merchant: feeRows[0].merchant,
            amount: feeRows[0].amount, kind: .purchase, category: .other)
        let scopedLegacyFeeID = feeImporter.assigningSourceIDs(to: [legacyFeePurchase], sourceNamespace: "fee-account")[0].sourceID!
        let scopedFeeReimport = feeImporter.prepareImport([feeRows[0]], sourceNamespace: "fee-account",
            existingSourceIDs: [scopedLegacyFeeID])
        verify(scopedFeeReimport.transactions.isEmpty && scopedFeeReimport.duplicateCount == 1,
               "account-scoped fee re-import matches the earlier purchase classification")
        let unboundLegacyFeeID = feeImporter.assigningSourceIDs(to: [legacyFeePurchase], sourceNamespace: "fee-statement")[0].sourceID!
        let unboundFeeReimport = feeImporter.prepareImport([feeRows[0]], sourceNamespace: nil,
            existingSourceIDs: [unboundLegacyFeeID])
        verify(unboundFeeReimport.transactions.isEmpty && unboundFeeReimport.duplicateCount == 1,
               "unbound fee re-import matches the earlier purchase classification")
        let refundCSV = "Дата;Описание;Сумма\n29.10.2026;Возврат покупки;300,00\n"
        let refunds = try CSVStatementImporter().parse(data: Data(refundCSV.utf8), sourceNamespace: "refund-statement")
        verify(refunds.count == 1 && refunds[0].kind == .refund && refunds[0].category == .refunds && refunds[0].incomeSource == nil,
               "CSV purchase refunds are separated from income")
        let refundReversal = try CSVStatementImporter().parse(data: Data(
            "Дата;Описание;Сумма\n29.10.2026;Отмена возврата покупки;-300,00\n".utf8))
        verify(refundReversal.count == 1 && refundReversal[0].kind == .purchase &&
               refundReversal[0].amount == Money(rubles: 300),
               "a negative refund reversal remains an outflow instead of being counted as refund income")
        let linkedRefundCSV = "Дата;Описание;Сумма;ID операции;ID исходной операции\n29.10.2026;Возврат покупки;300,00;refund-2;purchase-1\n"
        let linkedRefunds = try CSVStatementImporter().parse(data: Data(linkedRefundCSV.utf8), sourceNamespace: "refund-linked")
        let linkedRefund = linkedRefunds[0]
        let repeatedLinkedRefunds = try CSVStatementImporter().parse(data: Data(linkedRefundCSV.utf8), sourceNamespace: "refund-linked")
        verify(linkedRefund.providerTransactionID == "refund-2",
               "CSV captures the explicitly labeled provider transaction ID")
        verify(linkedRefund.refundOfProviderTransactionID == "purchase-1",
               "CSV captures the explicitly labeled original transaction ID for refunds")
        let descriptionlessRefund = try CSVStatementImporter().parse(data: Data(
            "Дата;Описание;Сумма;ID исходной операции\n29.10.2026;Example Store;300,00;purchase-1\n".utf8))
        verify(descriptionlessRefund.count == 1 && descriptionlessRefund[0].kind == .refund &&
               descriptionlessRefund[0].category == .refunds && descriptionlessRefund[0].incomeSource == nil,
               "CSV classifies a positive operation with an explicit original-operation reference as a refund")
        verify(linkedRefund.sourceID == repeatedLinkedRefunds[0].sourceID,
               "provider metadata does not change stable import deduplication")
        do {
            _ = try CSVStatementImporter().parse(data: Data("Дата;Описание;Сумма;ID операции;Transaction ID\n29.10.2026;Покупка;10;one;two\n".utf8))
            verify(false, "CSV rejects ambiguous provider transaction ID columns")
        } catch ImportError.ambiguousTransactionIDColumns {
            verify(true, "CSV rejects ambiguous provider transaction ID columns")
        }
        do {
            _ = try CSVStatementImporter().parse(data: Data("Дата;Описание;Сумма;ID исходной операции;Original transaction ID\n29.10.2026;Возврат покупки;10;one;two\n".utf8))
            verify(false, "CSV rejects ambiguous refund reference columns")
        } catch ImportError.ambiguousRefundReferenceColumns {
            verify(true, "CSV rejects ambiguous refund reference columns")
        }
        let oldIncomeRow = Transaction(date: refunds[0].date, merchant: refunds[0].merchant, amount: refunds[0].amount,
            kind: .income, category: .income, incomeSource: .other)
        let oldAccountID = CSVStatementImporter().assigningSourceIDs(to: [oldIncomeRow], sourceNamespace: "account-refund")[0].sourceID!
        let correctedAccountImport = CSVStatementImporter().prepareImport(refunds, sourceNamespace: "account-refund",
            existingSourceIDs: [oldAccountID])
        verify(correctedAccountImport.transactions.isEmpty && correctedAccountImport.duplicateCount == 1,
               "refund reclassification does not duplicate a row previously imported as income")
        let oldUnboundID = CSVStatementImporter().assigningSourceIDs(to: [oldIncomeRow], sourceNamespace: "refund-statement")[0].sourceID!
        let correctedUnboundImport = CSVStatementImporter().prepareImport(refunds, sourceNamespace: nil,
            existingSourceIDs: [oldUnboundID])
        verify(correctedUnboundImport.transactions.isEmpty && correctedUnboundImport.duplicateCount == 1,
               "unbound refund reclassification remains compatible with existing source IDs")
        } catch { fatalError("CSV debit-credit test errored: \(error)") }

        do {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let dates = [
            calendar.date(from: DateComponents(year: 2026, month: 1, day: 10))!,
            calendar.date(from: DateComponents(year: 2026, month: 2, day: 10))!,
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        ]
        let rows = dates.map { Transaction(date: $0, merchant: "Yandex Plus", amount: Money(rubles: 299), kind: .purchase, category: .subscriptions) }
        let candidates = RecurringDetector().detect(rows, calendar: calendar)
        verify(candidates.count == 1, "recurring detector suggests stable repeated expenses")
        verify(candidates.first?.recurrence == .monthly && candidates.first?.amount == Money(rubles: 299), "recurring suggestion preserves period and typical amount")
        let recurringDetector = RecurringDetector()
        let existingSubscription = ScheduledItem(title: "Yandex-Plus", amount: Money(rubles: 310),
            dueDate: dates[2], kind: .subscription, recurrence: .monthly)
        verify(candidates.first.map { recurringDetector.matchesExistingPlan($0, plan: existingSubscription) } == true,
               "recurring candidate matches an existing normalized subscription within amount tolerance")
        let differentPeriodPlan = ScheduledItem(title: "Yandex Plus", amount: Money(rubles: 299),
            dueDate: dates[2], kind: .subscription, recurrence: .weekly)
        verify(candidates.first.map { !recurringDetector.matchesExistingPlan($0, plan: differentPeriodPlan) } == true,
               "recurring candidate does not match an existing subscription with a different recurrence")
        let differentTitlePlan = ScheduledItem(title: "Other service", amount: Money(rubles: 299),
            dueDate: dates[2], kind: .subscription, recurrence: .monthly)
        verify(candidates.first.map { !recurringDetector.matchesExistingPlan($0, plan: differentTitlePlan) } == true,
               "recurring candidate does not match a same-price plan with a different merchant")
        let differentAmountPlan = ScheduledItem(title: "Yandex Plus", amount: Money(rubles: 400),
            dueDate: dates[2], kind: .subscription, recurrence: .monthly)
        verify(candidates.first.map { !recurringDetector.matchesExistingPlan($0, plan: differentAmountPlan) } == true,
               "recurring candidate does not match a same-merchant plan outside amount tolerance")
        let rentTransfers = dates.map {
            Transaction(date: $0, merchant: "Аренда квартиры", amount: Money(rubles: 15_000), kind: .transfer, category: .transfers)
        }
        let withRent = RecurringDetector().detect(rows + rentTransfers, calendar: calendar)
        verify(withRent.count == 2 && withRent.contains(where: { $0.title == "Аренда квартиры" && $0.amount == Money(rubles: 15_000) }),
               "recurring detector suggests regular external transfers such as rent")
        let invalidRecurringRows = dates.map {
            Transaction(date: $0, merchant: "Ошибка суммы", amount: Money(rubles: -500), kind: .purchase)
        }
        verify(RecurringDetector().detect(invalidRecurringRows, calendar: calendar).isEmpty,
               "recurring detector ignores non-positive outflows")
        let monthEndDates = [
            calendar.date(from: DateComponents(year: 2026, month: 1, day: 31))!,
            calendar.date(from: DateComponents(year: 2026, month: 2, day: 28))!,
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 31))!
        ]
        let monthEndRows = monthEndDates.map {
            Transaction(date: $0, merchant: "Списание в конце месяца", amount: Money(rubles: 700), kind: .purchase)
        }
        let monthEndCandidate = RecurringDetector().detect(monthEndRows, calendar: calendar).first
        verify(monthEndCandidate?.nextDate == calendar.date(from: DateComponents(year: 2026, month: 4, day: 30)),
               "recurring detector schedules end-of-month charges on the next month's final day")
        var leapCalendar = Calendar(identifier: .gregorian)
        leapCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let leapMonthEndDates = [
            leapCalendar.date(from: DateComponents(year: 2026, month: 12, day: 31))!,
            leapCalendar.date(from: DateComponents(year: 2027, month: 1, day: 31))!,
            leapCalendar.date(from: DateComponents(year: 2027, month: 2, day: 28))!
        ]
        let leapMonthEndRows = leapMonthEndDates.map {
            Transaction(date: $0, merchant: "Платеж 31 числа", amount: Money(rubles: 700), kind: .purchase)
        }
        let leapMonthEndCandidate = RecurringDetector().detect(leapMonthEndRows, calendar: leapCalendar).first
        verify(leapMonthEndCandidate?.nextDate == leapCalendar.date(from: DateComponents(year: 2027, month: 3, day: 31)),
               "recurring detector retains the original month-end anchor after a short February")
        let settlementPlan = ScheduledItem(title: "Аренда", amount: Money(rubles: 1_000), dueDate: dates[0])
        let includedSettlementAccountID = UUID()
        let excludedSettlementAccountID = UUID()
        verify(ScheduledSettlementPolicy.sourceAccountIsIncluded(includedSettlementAccountID,
               includedAccountIDs: [includedSettlementAccountID]) &&
               !ScheduledSettlementPolicy.sourceAccountIsIncluded(excludedSettlementAccountID,
                   includedAccountIDs: [includedSettlementAccountID]) &&
               ScheduledSettlementPolicy.sourceAccountIsIncluded(nil, includedAccountIDs: []),
               "settlement and transaction accounting share account inclusion rules while manual rows remain included")
        let postedPart = Transaction(date: dates[0], merchant: "Арендодатель", amount: Money(rubles: 400), kind: .transfer)
        let partialSettlement = ScheduledSettlementPolicy.makeSettlement(transaction: postedPart, item: settlementPlan,
            occurrenceDate: dates[0], settlements: [], calendar: calendar)
        verify(partialSettlement?.amount == Money(rubles: 400) &&
               partialSettlement.map { ScheduledSettlementPolicy.remainingAmount(for: settlementPlan,
                   occurrenceDate: dates[0], settlements: [$0], calendar: calendar) } == Money(rubles: 600),
               "explicit partial payment reduces only the selected planned occurrence")
        let partialSettlementRows = partialSettlement.map { [$0] } ?? []
        verify(ScheduledSettlementPolicy.canPreserveSettlements(for: settlementPlan,
               settlements: partialSettlementRows, calendar: calendar),
               "plan edit preserves a valid future partial payment")
        var shiftedSettlementPlan = settlementPlan
        shiftedSettlementPlan.dueDate = calendar.date(byAdding: .day, value: 1, to: dates[0])!
        verify(!ScheduledSettlementPolicy.canPreserveSettlements(for: shiftedSettlementPlan,
               settlements: partialSettlementRows, calendar: calendar),
               "plan edit rejects a date shift that would orphan a confirmed settlement")
        var reducedSettlementPlan = settlementPlan
        reducedSettlementPlan.amount = Money(rubles: 300)
        verify(!ScheduledSettlementPolicy.canPreserveSettlements(for: reducedSettlementPlan,
               settlements: partialSettlementRows, calendar: calendar),
               "plan edit rejects an amount change smaller than its confirmed partial settlement")
        verify(ScheduledSettlementPolicy.makeSettlement(transaction: postedPart, item: settlementPlan,
               occurrenceDate: dates[0], settlements: partialSettlementRows, calendar: calendar) == nil,
               "one posted transaction cannot be linked to a planned payment twice")
        let pendingPayment = Transaction(date: dates[0], merchant: "Ожидающий платёж", amount: Money(rubles: 100),
                                         kind: .transfer, status: .pending)
        let internalPayment = Transaction(date: dates[0], merchant: "Между своими счетами", amount: Money(rubles: 100),
                                          kind: .transfer, isInternalTransfer: true)
        let overpayment = Transaction(date: dates[0], merchant: "Слишком большая оплата", amount: Money(rubles: 1_001),
                                      kind: .transfer)
        verify(ScheduledSettlementPolicy.makeSettlement(transaction: pendingPayment, item: settlementPlan,
               occurrenceDate: dates[0], settlements: [], calendar: calendar) == nil &&
               ScheduledSettlementPolicy.makeSettlement(transaction: internalPayment, item: settlementPlan,
               occurrenceDate: dates[0], settlements: [], calendar: calendar) == nil &&
               ScheduledSettlementPolicy.makeSettlement(transaction: overpayment, item: settlementPlan,
               occurrenceDate: dates[0], settlements: [], calendar: calendar) == nil,
               "settlement rejects pending, internal, and overpayment transactions")
        let reusedIDSettlement = ScheduledSettlement(scheduledItemID: settlementPlan.id, occurrenceDate: dates[0],
            transactionID: postedPart.id, amount: Money(rubles: 400))
        let reusedIDElsewhere = ScheduledSettlement(scheduledItemID: UUID(), occurrenceDate: dates[0],
            transactionID: postedPart.id, amount: Money(rubles: 400))
        verify(ScheduledSettlementPolicy.remainingAmount(for: settlementPlan, occurrenceDate: dates[0],
               settlements: [reusedIDSettlement, reusedIDElsewhere], calendar: calendar) == Money(rubles: 1_000),
               "ambiguous duplicate transaction links are ignored instead of double-settling")
        let monthlyReminderPlan = ScheduledItem(title: "Подписка", amount: Money(rubles: 1_000),
            dueDate: dates[0], recurrence: .monthly)
        let fullReminderSettlement = ScheduledSettlement(scheduledItemID: monthlyReminderPlan.id,
            occurrenceDate: dates[0], transactionID: UUID(), amount: Money(rubles: 1_000))
        let nextReminderDate = ScheduledRecurrence.nextDate(after: dates[0], anchoredAt: dates[0],
            recurrence: .monthly, calendar: calendar)
        verify(ScheduledSettlementPolicy.firstUnsettledOccurrence(onOrAfter: dates[0],
               of: monthlyReminderPlan, settlements: [fullReminderSettlement], calendar: calendar) == nextReminderDate,
               "payment reminder skips a fully settled recurring occurrence")
        verify(ScheduledSettlementPolicy.firstUnsettledOccurrence(onOrAfter: dates[0],
               of: monthlyReminderPlan, settlements: [ScheduledSettlement(scheduledItemID: monthlyReminderPlan.id,
                   occurrenceDate: dates[0], transactionID: UUID(), amount: Money(rubles: 400))],
               calendar: calendar) == dates[0],
               "payment reminder keeps a partially settled occurrence")
        verify(ScheduledSettlementPolicy.firstUnsettledOccurrence(onOrAfter: dates[0],
               of: settlementPlan, settlements: [ScheduledSettlement(scheduledItemID: settlementPlan.id,
                   occurrenceDate: dates[0], transactionID: UUID(), amount: Money(rubles: 1_000))],
               calendar: calendar) == nil,
               "payment reminder ends after a one-off plan is fully settled")
        let finiteGoalPlan = ScheduledItem(title: "Последний взнос цели", amount: Money(rubles: 300),
            dueDate: dates[0], recurrence: .monthly, occurrencesRemaining: 2,
            finalOccurrenceAmount: Money(rubles: 100))
        let finalGoalDate = ScheduledRecurrence.nextDate(after: dates[0], anchoredAt: dates[0],
            recurrence: .monthly, calendar: calendar)!
        let firstGoalSettlement = ScheduledSettlement(scheduledItemID: finiteGoalPlan.id,
            occurrenceDate: dates[0], transactionID: UUID(), amount: Money(rubles: 300))
        let finalGoalSettlement = ScheduledSettlement(scheduledItemID: finiteGoalPlan.id,
            occurrenceDate: finalGoalDate, transactionID: UUID(), amount: Money(rubles: 100))
        verify(ScheduledSettlementPolicy.firstUnsettledOccurrence(onOrAfter: dates[0], of: finiteGoalPlan,
               settlements: [firstGoalSettlement], calendar: calendar) == finalGoalDate,
               "payment reminder advances to a reduced final goal contribution")
        verify(ScheduledSettlementPolicy.firstUnsettledOccurrence(onOrAfter: dates[0], of: finiteGoalPlan,
               settlements: [firstGoalSettlement, finalGoalSettlement], calendar: calendar) == nil,
               "payment reminder ends after the reduced final goal contribution is settled")
        let confirmedInternalTransfer = Transaction(date: dates[2], merchant: "Перевод между счетами", amount: Money(rubles: 299), kind: .transfer, isInternalTransfer: true)
        verify(RecurringDetector().detect(rows + [confirmedInternalTransfer], calendar: calendar).count == 1,
               "recurring detector ignores confirmed internal transfers")
        }

        do {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let purchases = (0..<10).map { index in
            Transaction(date: now.addingTimeInterval(Double(-index * 2 * 86_400)), merchant: "Магазин", amount: Money(rubles: 100), kind: .purchase)
        }
        let internalTransfer = Transaction(date: now, merchant: "Между своими счетами", amount: Money(rubles: 50_000), kind: .transfer, category: .transfers, isInternalTransfer: true)
        let estimate = SpendingForecaster().estimateDailySpend(purchases + [internalTransfer], endingAt: now)
        verify(estimate == Money(kopecks: 6_389), "daily spend estimate excludes confirmed internal transfers")
        let externalTransfer = Transaction(date: now, merchant: "Перевод другу", amount: Money(rubles: 100), kind: .transfer, category: .transfers)
        let fee = Transaction(date: now, merchant: "Комиссия", amount: Money(rubles: 50), kind: .fee, category: .fees)
        verify(SpendingForecaster().estimateDailySpend(purchases + [externalTransfer, fee], endingAt: now) == Money(kopecks: 7_348),
               "daily spend estimate includes external transfers and bank fees")
        let settledRecurring = Transaction(date: purchases[0].date, merchant: "Подписка", amount: Money(rubles: 1_000), kind: .purchase)
        let historyWithSettledRecurring = purchases + [settledRecurring]
        verify(SpendingForecaster().estimateDailySpend(historyWithSettledRecurring, endingAt: now,
               excludingTransactionIDs: [settledRecurring.id]) == estimate,
               "daily variable-spend estimate excludes a transaction already represented by its planned settlement")
        verify(SpendingForecaster().estimateDailySpend(Array(purchases.prefix(3)), endingAt: now) == nil, "daily spend estimate requires sufficient transaction history")
        verify(SpendingForecaster().estimateDailySpend(purchases, endingAt: now, safetyMultiplier: .nan) == nil &&
               SpendingForecaster().estimateDailySpend(purchases, endingAt: now, windowDays: 10, minimumCoverageDays: 13) == nil,
               "daily spend estimate rejects invalid confidence parameters")
        let largeHistoryStart = Calendar.current.date(byAdding: .day, value: -13, to: now)!
        let largeHistory = (0..<10).map { _ in
            Transaction(date: largeHistoryStart, merchant: "Большая операция",
                        amount: Money(kopecks: Int64.max / 2), kind: .purchase)
        }
        let exactTotal = Decimal(Int64.max / 2) * 10
        var exactDaily = exactTotal / 13 * Decimal(string: "1.15")!
        var expectedRounded = Decimal.zero
        NSDecimalRound(&expectedRounded, &exactDaily, 0, .up)
        let largeEstimate = SpendingForecaster().estimateDailySpend(largeHistory, endingAt: now)
        verify(largeEstimate?.kopecks == NSDecimalNumber(decimal: expectedRounded).int64Value,
               "daily spend forecast keeps full precision when transaction totals exceed Int64 before division")
        }
}
