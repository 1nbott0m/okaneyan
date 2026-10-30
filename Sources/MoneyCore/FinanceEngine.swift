import Foundation

public struct FinanceEngine: Sendable {
    private struct ProjectionLowPoint {
        let balance: Money
        let date: Date
    }

    private struct CashFlowEvent {
        let date: Date
        let delta: Money
    }

    public init() {}

    /// Expands confirmed plans into concrete near-term occurrences using the same recurrence
    /// and partial-settlement rules used by purchase checks and balance projections.
    public func upcomingOccurrences(_ snapshot: FinanceSnapshot, from start: Date, through end: Date,
                                   calendar: Calendar = .current) -> [PlannedOccurrence] {
        guard end >= start else { return [] }
        return occurrences(snapshot.scheduledItems, settlements: snapshot.scheduledSettlements,
                           from: start, through: end, calendar: calendar)
            .filter { $0.item.isConfirmed }
            .map { PlannedOccurrence(planID: $0.item.id, title: $0.item.title,
                                     amount: $0.item.amount, date: $0.date) }
            .sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }
    }

    /// A read-only projection for the horizon UI. A hypothetical purchase is included only
    /// in the returned points; it is never written to a transaction or the snapshot.
    public func horizon(_ snapshot: FinanceSnapshot, days: Int, hypotheticalPurchase: HypotheticalPurchase? = nil,
                        now: Date = .now, calendar inputCalendar: Calendar = .current) -> FinancialHorizon {
        let dayCount = min(FinancePlanningPolicy.maximumChartDays, max(1, days))
        let calendar = inputCalendar
        guard !snapshot.bankBalances.isEmpty else {
            return FinancialHorizon(days: dayCount, points: [], confidence: .insufficient("Добавь баланс счёта — пока нечего проецировать."))
        }
        guard snapshot.hasValidPlanData else {
            return FinancialHorizon(days: dayCount, points: [],
                confidence: .uncertain("Проверь сохранённые операции, планы, цели и резервы: часть данных не распознана или повреждена."))
        }
        guard FinanceDataFreshness.isFresh(snapshot.dataUpdatedAt, asOf: now) else {
            return FinancialHorizon(days: dayCount, points: [],
                confidence: .uncertain("Баланс устарел или не подтверждён. Обнови данные для надёжного прогноза."))
        }
        if let issue = snapshot.balanceReconciliationIssue {
            return FinancialHorizon(days: dayCount, points: [], confidence: .uncertain(issue))
        }
        guard snapshot.hasReliableSpendForecast else {
            return FinancialHorizon(days: dayCount, points: [],
                confidence: .uncertain("Обычные расходы оценены не полностью: недостаточно истории операций."))
        }
        guard let end = calendar.date(byAdding: .day, value: dayCount, to: now) else {
            return FinancialHorizon(days: dayCount, points: [], confidence: .insufficient("Не удалось построить календарный горизонт."))
        }
        let scenario: HypotheticalPurchase? = hypotheticalPurchase.flatMap { purchase in
            var planned = purchase
            if calendar.isDate(purchase.date, inSameDayAs: now) {
                planned.date = max(now, purchase.date)
            }
            guard planned.amount.kopecks >= 0, planned.date >= now, planned.date < end else { return nil }
            return planned
        }
        let events = cashFlowEvents(snapshot: snapshot, purchase: scenario?.amount,
                                   purchaseDate: scenario?.date ?? now, now: now, end: end,
                                   calendar: calendar)
        let allocated = protectedReserveTotals(snapshot, from: now, through: end, calendar: calendar)
        let reserveFloor = nonNegative(snapshot.protectedReserve) + allocated.named + allocated.goals
        var balance = snapshot.currentBalance
        var cursor = now
        var eventIndex = 0
        var points = [FinancialHorizon.Point(date: now, projectedBalance: balance,
            availableAfterReserves: max(.zero, balance - reserveFloor),
            confirmedInflows: .zero, confirmedOutflows: .zero,
            isHypotheticalPurchaseDay: scenario.map { calendar.isDate($0.date, inSameDayAs: now) } ?? false)]
        for offset in 1...dayCount {
            guard let boundary = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            var dayInflows = Money.zero
            var dayOutflows = Money.zero
            // A point represents the balance at its exact timestamp, so cash flows
            // occurring on the boundary must already be reflected in that point.
            while eventIndex < events.count && events[eventIndex].date <= boundary {
                let event = events[eventIndex]
                let at = max(cursor, event.date)
                balance = balance - variableSpend(from: cursor, to: at, daily: snapshot.forecastDailySpend)
                cursor = at
                balance = balance + event.delta
                if event.delta >= .zero { dayInflows = dayInflows + event.delta }
                else { dayOutflows = dayOutflows - event.delta }
                eventIndex += 1
            }
            balance = balance - variableSpend(from: cursor, to: boundary, daily: snapshot.forecastDailySpend)
            cursor = boundary
            points.append(FinancialHorizon.Point(date: boundary, projectedBalance: balance,
                availableAfterReserves: max(.zero, balance - reserveFloor),
                confirmedInflows: dayInflows, confirmedOutflows: dayOutflows,
                isHypotheticalPurchaseDay: scenario.map { calendar.isDate($0.date, inSameDayAs: boundary) } ?? false))
        }
        return FinancialHorizon(days: dayCount, points: points, confidence: .reliable,
            hypotheticalPurchase: scenario)
    }

    public func availableNow(_ snapshot: FinanceSnapshot, now: Date = .now) -> Money {
        guard snapshot.hasValidPlanData, snapshot.hasReliableSpendForecast, snapshot.nextIncomeConfirmed,
              let limit = snapshot.nextIncomeDate, limit > now,
              FinancePlanningPolicy.supportsForecast(from: now, to: limit),
              FinanceDataFreshness.isFresh(snapshot.dataUpdatedAt, asOf: now),
              snapshot.balanceReconciliationIssue == nil else { return .zero }
        let reserved = occurrences(snapshot.scheduledItems, settlements: snapshot.scheduledSettlements,
                                   from: now, through: limit)
            .filter { $0.item.isConfirmed && $0.date <= limit }
            .reduce(Money.zero) { $0 + nonNegative($1.item.amount) }
        let allocated = protectedReserveTotals(snapshot, from: now, through: limit)
        let variable = limit > now ? variableSpend(from: now, to: limit, daily: nonNegative(snapshot.forecastDailySpend)) : .zero
        return max(.zero, snapshot.currentBalance - nonNegative(snapshot.protectedReserve) - allocated.named - allocated.goals - reserved - variable)
    }

    /// Maximum constant average variable outflow per day that preserves all protected reserves
    /// through the next income date, under the entered balance and confirmed obligations.
    public func safeDailySpendingLimit(_ snapshot: FinanceSnapshot, now: Date = .now) -> DailySpendingLimitResult {
        guard !snapshot.bankBalances.isEmpty else {
            return .insufficientData("Добавь баланс счёта, чтобы рассчитать дневной лимит.")
        }
        guard snapshot.hasValidPlanData else {
            return .insufficientData("Проверь сохранённые операции, планы, цели и резервы, прежде чем рассчитывать дневной лимит.")
        }
        guard let end = snapshot.nextIncomeDate, end > now else {
            return .insufficientData("Укажи будущую дату следующего поступления.")
        }
        guard FinancePlanningPolicy.supportsForecast(from: now, to: end) else {
            return .insufficientData("Безопасный прогноз надёжен максимум на 2 года. Уточни дату поступления или проверь план ближе к ней.")
        }
        guard snapshot.nextIncomeConfirmed else {
            return .insufficientData("Подтверди сумму и дату следующего поступления: без этого безопасный горизонт расходов неизвестен.")
        }
        guard let balanceUpdatedAt = snapshot.dataUpdatedAt else {
            return .insufficientData("Дата подтверждения баланса неизвестна. Подтверди текущий остаток перед расчётом дневного лимита.")
        }
        guard balanceUpdatedAt <= now else {
            return .insufficientData("Дата подтверждения баланса позже текущего времени. Проверь дату и время на iPhone и подтверди остаток снова.")
        }
        guard FinanceDataFreshness.isFresh(balanceUpdatedAt, asOf: now) else {
            let date = balanceUpdatedAt.formatted(date: .abbreviated, time: .shortened)
            return .insufficientData("Последнее подтверждение баланса: \(date), старше 72 часов. Обнови остаток перед расчётом дневного лимита.")
        }
        if let issue = snapshot.balanceReconciliationIssue { return .insufficientData(issue) }
        guard snapshot.hasReliableSpendForecast else {
            return .insufficientData("Недостаточно истории операций, чтобы оценить обычные расходы и дневной лимит.")
        }

        let allocated = protectedReserveTotals(snapshot, from: now, through: end)
        let protected = nonNegative(snapshot.protectedReserve) + allocated.named + allocated.goals
        let events = cashFlowEvents(snapshot: snapshot, purchase: nil, purchaseDate: now, now: now, end: end)
        let zeroSpendLowPoint = projectedLowPoint(startingBalance: snapshot.currentBalance, events: events,
                                                  from: now, through: end, dailySpend: .zero)
        guard zeroSpendLowPoint.balance >= protected else {
            let shortfall = protected - zeroSpendLowPoint.balance
            return .unsafe(shortfall: shortfall, date: zeroSpendLowPoint.date)
        }

        let isSafeDailyRate: (Int64) -> Bool = { rate in
            let lowPoint = self.projectedLowPoint(startingBalance: snapshot.currentBalance, events: events,
                from: now, through: end, dailySpend: Money(kopecks: rate))
            return lowPoint.balance >= protected
        }
        var lower: Int64 = 0
        var upper = max(1, snapshot.currentBalance.kopecks)
        while isSafeDailyRate(upper) {
            lower = upper
            guard upper < Int64.max else { return .calculated(Money(kopecks: upper)) }
            upper = upper > Int64.max / 2 ? Int64.max : upper * 2
        }
        while lower < upper {
            let distance = upper - lower
            let candidate = lower + distance / 2 + distance % 2
            if isSafeDailyRate(candidate) { lower = candidate } else { upper = candidate - 1 }
        }
        return .calculated(Money(kopecks: lower))
    }

    public func checkPurchase(_ purchase: Money, on purchaseDate: Date? = nil,
                              snapshot: FinanceSnapshot, now: Date = .now) -> PurchaseVerdict {
        guard purchase.kopecks >= 0 else { return .insufficientData("Укажи сумму не меньше нуля.") }
        guard !snapshot.bankBalances.isEmpty else { return .insufficientData("Добавь баланс счёта или импортируй выписку.") }
        guard let nextIncome = snapshot.nextIncomeDate, nextIncome > now else {
            return .insufficientData("Укажи дату следующего поступления, чтобы проверить расходы до него.")
        }
        guard FinancePlanningPolicy.supportsForecast(from: now, to: nextIncome) else {
            return .insufficientData("Безопасный прогноз надёжен максимум на 2 года. Уточни дату поступления или проверь покупку ближе к ней.")
        }
        guard snapshot.nextIncomeConfirmed else {
            return .insufficientData("Подтверди сумму и дату следующего поступления, прежде чем планировать эту покупку.")
        }
        let requestedPurchaseDate = purchaseDate ?? now
        let calendar = Calendar.current
        guard calendar.startOfDay(for: requestedPurchaseDate) >= calendar.startOfDay(for: now) else {
            return .insufficientData("Выбери сегодня или будущую дату покупки.")
        }
        let effectivePurchaseDate = calendar.isDate(requestedPurchaseDate, inSameDayAs: now) ? max(requestedPurchaseDate, now) : requestedPurchaseDate
        guard !calendar.isDate(effectivePurchaseDate, inSameDayAs: nextIncome) else {
            return .insufficientData("Покупка приходится на день ожидаемого поступления. Проверь её после фактического зачисления денег.")
        }
        guard effectivePurchaseDate < nextIncome else {
            return .insufficientData("Покупка запланирована на дату следующего поступления или позже. Проверь её после фактического зачисления денег.")
        }
        guard let balanceUpdatedAt = snapshot.dataUpdatedAt else {
            return .insufficientData("Дата подтверждения баланса неизвестна. Подтверди текущий остаток в настройках счёта.")
        }
        guard balanceUpdatedAt <= now else {
            return .insufficientData("Дата подтверждения баланса позже текущего времени. Проверь дату и время на iPhone и подтверди остаток снова.")
        }
        guard FinanceDataFreshness.isFresh(balanceUpdatedAt, asOf: now) else {
            let date = balanceUpdatedAt.formatted(date: .abbreviated, time: .shortened)
            return .insufficientData("Последнее подтверждение баланса: \(date), старше 72 часов. Обнови остаток перед проверкой покупки.")
        }
        if let issue = snapshot.balanceReconciliationIssue { return .insufficientData(issue) }
        guard snapshot.hasReliableSpendForecast else {
            return .insufficientData("Недостаточно истории операций, чтобы оценить обычные траты.")
        }
        guard snapshot.hasValidPlanData else {
            return .insufficientData("Проверь сохранённые операции, планы, цели и резервы, прежде чем оценивать покупку.")
        }
        let allocated = protectedReserveTotals(snapshot, from: now, through: nextIncome)
        let lowPoint = projectedLowPoint(snapshot: snapshot, purchase: purchase,
                                         purchaseDate: effectivePurchaseDate, now: now)
        let protected = nonNegative(snapshot.protectedReserve) + allocated.named + allocated.goals
        if lowPoint.balance >= protected { return .canBuy(minimumBalance: lowPoint.balance) }
        let shortfall = protected - lowPoint.balance
        let breachDate = lowPoint.date
        let flexible = occurrences(snapshot.scheduledItems, settlements: snapshot.scheduledSettlements,
                                   from: now, through: breachDate)
            .filter { $0.item.isConfirmed && $0.item.kind == .goalContribution && $0.date <= breachDate }
            .reduce(Money.zero) { $0 + nonNegative($1.item.amount) }
        if flexible >= shortfall { return .canBuyWithChanges(minimumBalance: lowPoint.balance + flexible, shortfall: shortfall) }
        return .unsafe(shortfall: shortfall, date: breachDate)
    }

    public func purchaseOptions(_ purchase: Money, on date: Date? = nil,
                                snapshot: FinanceSnapshot, now: Date = .now) -> [PurchaseOption] {
        let requestedDate = date ?? now
        let direct = checkPurchase(purchase, on: requestedDate, snapshot: snapshot, now: now)
        var result = [PurchaseOption(id: "direct", title: "Оставить план без изменений", changedGoalContribution: .zero, verdict: direct)]
        guard snapshot.hasValidPlanData else { return result }
        if let next = snapshot.nextIncomeDate,
           !FinancePlanningPolicy.supportsForecast(from: now, to: next) {
            return result
        }
        if let next = snapshot.nextIncomeDate, requestedDate < next {
            result.append(PurchaseOption(id: "later", title: "Перенести покупку на дату поступления",
                                         changedGoalContribution: .zero,
                                         verdict: .insufficientData("Проверь покупку повторно после фактического поступления денег.")))
        }
        return result
    }

    /// Rechecks a purchase after moving one selected monthly goal schedule forward by one
    /// occurrence. Other plans remain untouched. This is a read-only what-if; it never mutates storage.
    public func goalContributionShiftPurchaseOption(
        _ purchase: Money, on date: Date? = nil, snapshot: FinanceSnapshot, planID: UUID,
        goalTitle: String, shiftedFirstDate: Date, shiftedOccurrenceCount: Int,
        shiftedFinalContribution: Money?, now: Date = .now,
        calendar: Calendar = .current
    ) -> PurchaseOption? {
        guard snapshot.hasValidPlanData, snapshot.hasReliableSpendForecast,
              snapshot.nextIncomeConfirmed,
              let nextIncome = snapshot.nextIncomeDate,
              FinanceDataFreshness.isFresh(snapshot.dataUpdatedAt, asOf: now),
              FinancePlanningPolicy.supportsForecast(from: now, to: nextIncome),
              let plan = snapshot.scheduledItems.first(where: { $0.id == planID }),
              plan.isConfirmed, plan.kind == .goalContribution,
              plan.recurrence == .monthly, shiftedOccurrenceCount > 0 else { return nil }
        let affected = upcomingOccurrences(snapshot, from: now, through: nextIncome)
            .filter { $0.planID == planID }
        guard !affected.isEmpty else { return nil }
        let nextOccurrenceDate = affected[0].date
        guard let expectedShift = ScheduledRecurrence.nextDate(after: nextOccurrenceDate,
                anchoredAt: plan.dueDate, recurrence: .monthly, calendar: calendar),
              calendar.isDate(expectedShift, inSameDayAs: shiftedFirstDate) else { return nil }
        let firstShiftedOccurrenceBoundary = calendar.startOfDay(for: nextOccurrenceDate)
        // Moving the whole series would orphan a reconciliation attached to any future
        // occurrence, even when that occurrence is later than the next payment.
        guard !snapshot.scheduledSettlements.contains(where: {
            $0.scheduledItemID == planID && $0.occurrenceDate >= firstShiftedOccurrenceBoundary && $0.amount > .zero
        }) else { return nil }
        var adjusted = snapshot
        guard let planIndex = adjusted.scheduledItems.firstIndex(where: { $0.id == planID }) else { return nil }
        adjusted.scheduledItems[planIndex] = ScheduledItem(id: plan.id, title: plan.title,
            amount: plan.amount, dueDate: shiftedFirstDate, isConfirmed: plan.isConfirmed,
            kind: plan.kind, recurrence: .monthly, occurrencesRemaining: shiftedOccurrenceCount,
            finalOccurrenceAmount: shiftedFinalContribution)
        let originalTotal = Money.sum(affected.map(\.amount))
        let shiftedTotal = Money.sum(upcomingOccurrences(adjusted, from: now, through: nextIncome)
            .filter { $0.planID == planID }.map(\.amount))
        let deferredWithinHorizon = originalTotal > shiftedTotal ? originalTotal - shiftedTotal : .zero
        return PurchaseOption(id: "goal-\(planID.uuidString)",
                              title: "Сдвинуть график цели «\(goalTitle)» на месяц",
                              changedGoalContribution: deferredWithinHorizon,
                              verdict: checkPurchase(purchase, on: date, snapshot: adjusted, now: now))
    }

    private func projectedLowPoint(snapshot: FinanceSnapshot, purchase: Money?, purchaseDate: Date, now: Date,
                                   dailySpendOverride: Money? = nil) -> ProjectionLowPoint {
        guard let end = snapshot.nextIncomeDate else { return ProjectionLowPoint(balance: .zero, date: now) }
        let events = cashFlowEvents(snapshot: snapshot, purchase: purchase, purchaseDate: purchaseDate, now: now, end: end)
        return projectedLowPoint(startingBalance: snapshot.currentBalance, events: events, from: now, through: end,
                                 dailySpend: dailySpendOverride ?? snapshot.forecastDailySpend)
    }

    private func cashFlowEvents(snapshot: FinanceSnapshot, purchase: Money?, purchaseDate: Date,
                                now: Date, end: Date, calendar: Calendar = .current) -> [CashFlowEvent] {
        var events = occurrences(snapshot.scheduledItems, settlements: snapshot.scheduledSettlements,
                                 from: now, through: end, calendar: calendar)
            .filter { $0.item.isConfirmed }
            .map { CashFlowEvent(date: $0.date, delta: -nonNegative($0.item.amount)) }
        events += snapshot.incomes.filter { $0.isConfirmed && $0.date >= now && $0.date <= end }
            .map { CashFlowEvent(date: $0.date, delta: $0.amount) }
        if let purchase, purchaseDate >= now && purchaseDate < end {
            events.append(CashFlowEvent(date: purchaseDate, delta: -purchase))
        }
        return events.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.delta < rhs.delta // On the same timestamp, reserve the outflow before counting income.
        }
    }

    private func projectedLowPoint(startingBalance: Money, events: [CashFlowEvent], from start: Date,
                                   through end: Date, dailySpend: Money) -> ProjectionLowPoint {
        var balance = startingBalance
        var lowPoint = ProjectionLowPoint(balance: balance, date: start)
        var cursor = start
        for event in events {
            balance = balance - variableSpend(from: cursor, to: event.date, daily: dailySpend)
            if balance < lowPoint.balance { lowPoint = ProjectionLowPoint(balance: balance, date: event.date) }
            balance = balance + event.delta
            if balance < lowPoint.balance { lowPoint = ProjectionLowPoint(balance: balance, date: event.date) }
            cursor = event.date
        }
        balance = balance - variableSpend(from: cursor, to: end, daily: dailySpend)
        if balance < lowPoint.balance { lowPoint = ProjectionLowPoint(balance: balance, date: end) }
        return lowPoint
    }

    private func variableSpend(from start: Date, to end: Date, daily: Money) -> Money {
        let daily = nonNegative(daily)
        let seconds = max(0, end.timeIntervalSince(start))
        guard seconds > 0 else { return .zero }
        guard seconds.isFinite, ceil(seconds) < Double(Int64.max) else { return Money(kopecks: Int64.max) }
        let durationSeconds = Int64(ceil(seconds))
        let wholeDays = durationSeconds / 86_400
        let remainingSeconds = durationSeconds % 86_400
        guard wholeDays == 0 || daily.kopecks <= Int64.max / wholeDays else { return Money(kopecks: Int64.max) }
        let wholeDaySpend = daily.kopecks * wholeDays

        // Decompose the partial day to avoid multiplying a large kopeck value by seconds.
        let dailyQuotient = daily.kopecks / 86_400
        let dailyRemainder = daily.kopecks % 86_400
        let partialBase = dailyQuotient * remainingSeconds
        let remainderProduct = dailyRemainder * remainingSeconds // Both factors are below 86,400.
        let partialRemainder = (remainderProduct + 86_399) / 86_400
        let partialDaySpend = partialBase + partialRemainder
        return Money(kopecks: wholeDaySpend) + Money(kopecks: partialDaySpend)
    }

    private func nonNegative(_ amount: Money) -> Money { max(.zero, amount) }

    public func protectedReserveTotals(_ snapshot: FinanceSnapshot, from start: Date, through end: Date,
                                       calendar: Calendar = .current) -> ProtectedReserveTotals {
        guard snapshot.usesReserveAllocations else {
            return ProtectedReserveTotals(goals: nonNegative(snapshot.goalReserve),
                                          named: nonNegative(snapshot.earmarkedReserve))
        }
        return ProtectedReserveAccounting.totals(goals: snapshot.goalAllocations,
            namedReserves: snapshot.namedReserveAllocations, scheduledItems: snapshot.scheduledItems,
            settlements: snapshot.scheduledSettlements, from: start, through: end, calendar: calendar)
    }

    private func occurrences(_ items: [ScheduledItem], settlements: [ScheduledSettlement] = [],
                             from start: Date, through end: Date,
                             calendar inputCalendar: Calendar = .current) -> [(item: ScheduledItem, date: Date)] {
        var result: [(ScheduledItem, Date)] = []
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = inputCalendar.timeZone
        let startOfCurrentDay = calendar.startOfDay(for: start)
        for item in items where item.dueDate <= end {
            var date = item.dueDate
            let monthlyAnchorDay = calendar.component(.day, from: item.dueDate)
            let yearlyAnchorMonth = calendar.component(.month, from: item.dueDate)
            let yearlyAnchorDay = calendar.component(.day, from: item.dueDate)
            var emitted = 0
            guard item.recurrence != .none else {
                if date >= startOfCurrentDay && (item.occurrencesRemaining == nil || item.occurrencesRemaining! > 0) {
                    // Date-only plan entries can be stored at midnight. If the current
                    // day's payment is still in the plan, treat it as due now rather
                    // than dropping it because the clock has passed 00:00.
                    if calendar.isDate(date, inSameDayAs: start) { date = max(date, start) }
                    var occurrence = item
                    if item.occurrencesRemaining == 1, let finalAmount = item.finalOccurrenceAmount {
                        occurrence.amount = min(nonNegative(finalAmount), nonNegative(item.amount))
                    }
                    occurrence.amount = ScheduledSettlementPolicy.remainingAmount(for: occurrence,
                        occurrenceDate: date, settlements: settlements, calendar: calendar)
                    if occurrence.amount == .zero { continue }
                    result.append((occurrence, date))
                }
                continue
            }
            guard let first = firstOccurrence(onOrAfter: startOfCurrentDay, item: item, calendar: calendar,
                                              monthlyAnchorDay: monthlyAnchorDay,
                                              yearlyAnchorMonth: yearlyAnchorMonth,
                                              yearlyAnchorDay: yearlyAnchorDay) else { continue }
            // Keep the recurrence's scheduled timestamp separate from the effective
            // timestamp used to reserve an occurrence that is already due today.
            // Advancing from the effective time would permanently shift date-only plans
            // from midnight to the current clock time and could reorder them after income.
            var occurrenceDate = first.date
            emitted = first.pastOccurrences
            if let limit = item.occurrencesRemaining, emitted >= max(0, limit) { continue }
            while occurrenceDate <= end {
                if let limit = item.occurrencesRemaining, emitted >= max(0, limit) { break }
                let effectiveDate = calendar.isDate(occurrenceDate, inSameDayAs: start)
                    ? max(occurrenceDate, start) : occurrenceDate
                var occurrence = item
                if let limit = item.occurrencesRemaining, limit > 0, emitted == limit - 1,
                   let finalAmount = item.finalOccurrenceAmount {
                    occurrence.amount = min(nonNegative(finalAmount), nonNegative(item.amount))
                }
                occurrence.amount = ScheduledSettlementPolicy.remainingAmount(for: occurrence,
                    occurrenceDate: occurrenceDate, settlements: settlements, calendar: calendar)
                if occurrence.amount > .zero { result.append((occurrence, effectiveDate)) }
                emitted += 1
                guard let following = ScheduledRecurrence.nextDate(after: occurrenceDate, anchoredAt: item.dueDate,
                    recurrence: item.recurrence, calendar: calendar), following > occurrenceDate else { break }
                occurrenceDate = following
            }
        }
        return result
    }

    /// Jumps directly to the first occurrence on or after `start`, avoiding a loop over
    /// every historical week/month/year for long-lived recurring plans.
    private func firstOccurrence(onOrAfter start: Date, item: ScheduledItem, calendar: Calendar,
                                 monthlyAnchorDay: Int, yearlyAnchorMonth: Int,
                                 yearlyAnchorDay: Int) -> (date: Date, pastOccurrences: Int)? {
        guard item.dueDate < start else { return (item.dueDate, 0) }

        let anchor = item.dueDate
        let anchorParts = calendar.dateComponents([.era, .year, .month], from: anchor)
        let startParts = calendar.dateComponents([.era, .year, .month], from: start)
        let estimate: Int
        switch item.recurrence {
        case .none:
            return start <= anchor ? (anchor, 0) : nil
        case .weekly:
            let elapsedDays = calendar.dateComponents([.day], from: anchor, to: start).day ?? 0
            estimate = max(0, elapsedDays / 7)
        case .monthly:
            guard let anchorYear = anchorParts.year, let anchorMonth = anchorParts.month,
                  let startYear = startParts.year, let startMonth = startParts.month else { return nil }
            estimate = max(0, (startYear - anchorYear) * 12 + startMonth - anchorMonth)
        case .yearly:
            guard let anchorYear = anchorParts.year, let startYear = startParts.year else { return nil }
            estimate = max(0, startYear - anchorYear)
        }

        guard var index = occurrenceIndex(estimate, anchoredAt: anchor, recurrence: item.recurrence,
                                          calendar: calendar, monthlyAnchorDay: monthlyAnchorDay,
                                          yearlyAnchorMonth: yearlyAnchorMonth,
                                          yearlyAnchorDay: yearlyAnchorDay) else { return nil }

        while index.date < start {
            guard index.index < Int.max,
                  let following = occurrenceIndex(index.index + 1, anchoredAt: anchor,
                    recurrence: item.recurrence, calendar: calendar,
                    monthlyAnchorDay: monthlyAnchorDay, yearlyAnchorMonth: yearlyAnchorMonth,
                    yearlyAnchorDay: yearlyAnchorDay), following.date > index.date else { return nil }
            index = following
        }
        while index.index > 0,
              let previous = occurrenceIndex(index.index - 1, anchoredAt: anchor,
                recurrence: item.recurrence, calendar: calendar,
                monthlyAnchorDay: monthlyAnchorDay, yearlyAnchorMonth: yearlyAnchorMonth,
                yearlyAnchorDay: yearlyAnchorDay), previous.date >= start {
            index = previous
        }

        return (index.date, index.index)
    }

    private func occurrenceIndex(_ index: Int, anchoredAt anchor: Date,
                                 recurrence: ScheduledItem.Recurrence, calendar: Calendar,
                                 monthlyAnchorDay: Int, yearlyAnchorMonth: Int,
                                 yearlyAnchorDay: Int) -> (index: Int, date: Date)? {
        guard index >= 0 else { return nil }
        switch recurrence {
        case .none:
            return index == 0 ? (0, anchor) : nil
        case .weekly:
            guard let date = calendar.date(byAdding: .weekOfYear, value: index, to: anchor) else { return nil }
            return (index, date)
        case .monthly:
            guard let monthStart = calendar.date(from: calendar.dateComponents([.era, .year, .month], from: anchor)),
                  let targetMonth = calendar.date(byAdding: .month, value: index, to: monthStart),
                  let range = calendar.range(of: .day, in: .month, for: targetMonth) else { return nil }
            var components = calendar.dateComponents([.era, .year, .month], from: targetMonth)
            components.day = min(monthlyAnchorDay, range.count)
            components.hour = calendar.component(.hour, from: anchor)
            components.minute = calendar.component(.minute, from: anchor)
            components.second = calendar.component(.second, from: anchor)
            guard let date = calendar.date(from: components) else { return nil }
            return (index, date)
        case .yearly:
            guard let era = calendar.dateComponents([.era], from: anchor).era,
                  let targetYear = calendar.date(byAdding: .year, value: index, to: anchor),
                  let year = calendar.dateComponents([.year], from: targetYear).year,
                  let monthStart = calendar.date(from: DateComponents(era: era, year: year,
                                                                     month: yearlyAnchorMonth, day: 1)),
                  let range = calendar.range(of: .day, in: .month, for: monthStart) else { return nil }
            var components = calendar.dateComponents([.era, .year], from: targetYear)
            components.month = yearlyAnchorMonth
            components.day = min(yearlyAnchorDay, range.count)
            components.hour = calendar.component(.hour, from: anchor)
            components.minute = calendar.component(.minute, from: anchor)
            components.second = calendar.component(.second, from: anchor)
            guard let date = calendar.date(from: components) else { return nil }
            return (index, date)
        }
    }

}

public enum PlanHealthLevel: Sendable, Equatable {
    case stable
    case adjustmentNeeded
    case unsafe
    case insufficientData
}

public struct PlanHealthAssessment: Sendable, Equatable {
    public let level: PlanHealthLevel
    public let title: String
    public let detail: String

    public static func evaluate(_ snapshot: FinanceSnapshot, now: Date = .now) -> PlanHealthAssessment {
        guard snapshot.hasReliableSpendForecast else {
            return PlanHealthAssessment(level: .insufficientData, title: "Недостаточно истории", detail: "Нужны операции, чтобы оценить обычные траты.")
        }
        return from(FinanceEngine().checkPurchase(.zero, snapshot: snapshot, now: now))
    }

    public static func from(_ verdict: PurchaseVerdict) -> PlanHealthAssessment {
        switch verdict {
        case .canBuy:
            PlanHealthAssessment(level: .stable, title: "План устойчив", detail: "Прогноз сохраняет защищённый резерв до поступления.")
        case .canBuyWithChanges:
            PlanHealthAssessment(level: .adjustmentNeeded, title: "Нужно изменить план", detail: "Перенеси взнос в цель или пересмотри расход.")
        case .unsafe:
            PlanHealthAssessment(level: .unsafe, title: "Прогноз ниже резерва", detail: "Текущих денег не хватит, чтобы сохранить резерв до поступления.")
        case .insufficientData(let reason):
            PlanHealthAssessment(level: .insufficientData, title: "Недостаточно данных", detail: reason)
        }
    }
}
