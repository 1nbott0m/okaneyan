import Foundation

public enum GoalContributionPlan {
    /// Moves a goal deadline by one calendar month, but never leaves it before
    /// the first contribution in the shifted schedule (for example Mar 28 vs Mar 31).
    public static func shiftedDeadlineAfterOneMonth(_ targetDate: Date, firstContributionDate: Date,
                                                    calendar: Calendar = .current) -> Date? {
        guard let shifted = ScheduledRecurrence.nextDate(after: targetDate, anchoredAt: targetDate,
                                                          recurrence: .monthly, calendar: calendar) else { return nil }
        return max(shifted, firstContributionDate)
    }

    /// Amount to protect for a goal, independent of malformed values in other goals.
    public static func reservedAmount(target: Money, saved: Money) -> Money {
        guard target > .zero, saved > .zero else { return .zero }
        return min(target, saved)
    }

    /// Number of monthly contributions that fit before the target date, including the first date.
    public static func occurrencesNeeded(target: Money, saved: Money, monthlyContribution: Money,
                                         firstDate: Date, targetDate: Date,
                                         calendar: Calendar = .current) -> Int {
        guard target > .zero, saved >= .zero, monthlyContribution > .zero,
              firstDate <= targetDate else { return 0 }
        guard saved.kopecks < target.kopecks else { return 0 }

        let remaining = target.kopecks - saved.kopecks
        let amount = monthlyContribution.kopecks
        let quotient = remaining / amount
        let roundedUp = quotient + (remaining % amount == 0 ? 0 : 1)
        guard let firstMonth = calendar.date(from: calendar.dateComponents([.era, .year, .month], from: firstDate)),
              let targetMonth = calendar.date(from: calendar.dateComponents([.era, .year, .month], from: targetDate)) else { return 0 }
        let monthOffset = max(0, calendar.dateComponents([.month], from: firstMonth, to: targetMonth).month ?? 0)
        guard let candidate = monthlyDate(anchor: firstDate, monthOffset: monthOffset, calendar: calendar) else { return 0 }
        let occurrencesAvailable = monthOffset + (candidate <= targetDate ? 1 : 0)
        return Int(min(roundedUp, Int64(occurrencesAvailable)))
    }

    /// Returns a smaller last payment only when the full goal can be reached within the schedule horizon.
    public static func finalContributionAmount(target: Money, saved: Money, monthlyContribution: Money,
                                               occurrenceCount: Int) -> Money? {
        guard target > .zero, saved >= .zero, monthlyContribution > .zero, occurrenceCount > 0 else { return nil }
        guard saved.kopecks < target.kopecks else { return nil }
        let remaining = target.kopecks - saved.kopecks
        let monthly = monthlyContribution.kopecks
        let quotient = remaining / monthly
        let requiredCount = quotient + (remaining % monthly == 0 ? 0 : 1)
        guard Int64(occurrenceCount) >= requiredCount else { return nil }
        let remainder = remaining % monthly
        return remainder > 0 ? Money(kopecks: remainder) : nil
    }

    /// Checks that a persisted goal schedule still matches its current target and savings.
    /// A missing schedule is valid only when no future contribution is required before the deadline.
    public static func matchesSchedule(target: Money, saved: Money, monthlyContribution: Money,
                                       firstDate: Date, targetDate: Date,
                                       hasSchedule: Bool, scheduledOccurrenceCount: Int?,
                                       scheduledFinalContribution: Money?,
                                       calendar: Calendar = .current) -> Bool {
        let expectedCount = occurrencesNeeded(target: target, saved: saved,
            monthlyContribution: monthlyContribution, firstDate: firstDate,
            targetDate: targetDate, calendar: calendar)
        let expectedFinalAmount = finalContributionAmount(target: target, saved: saved,
            monthlyContribution: monthlyContribution, occurrenceCount: expectedCount)
        guard hasSchedule else {
            return expectedCount == 0 && scheduledOccurrenceCount == nil && scheduledFinalContribution == nil
        }
        guard let scheduledOccurrenceCount else { return false }
        return scheduledOccurrenceCount == expectedCount &&
            scheduledFinalContribution == expectedFinalAmount
    }

    public static func matchesLinkedPlan(target: Money, saved: Money, monthlyContribution: Money,
                                         firstDate: Date, targetDate: Date,
                                         hasPlanReference: Bool, plan: ScheduledItem?,
                                         linkedGoalCount: Int,
                                         calendar: Calendar = .current) -> Bool {
        guard hasPlanReference == (plan != nil),
              linkedGoalCount == (hasPlanReference ? 1 : 0) else { return false }
        if let plan {
            guard plan.isConfirmed, plan.kind == .goalContribution,
                  plan.recurrence == .monthly, plan.amount == monthlyContribution,
                  plan.dueDate == firstDate else { return false }
            return matchesSchedule(target: target, saved: saved,
                monthlyContribution: monthlyContribution, firstDate: firstDate, targetDate: targetDate,
                hasSchedule: true, scheduledOccurrenceCount: plan.occurrencesRemaining,
                scheduledFinalContribution: plan.finalOccurrenceAmount, calendar: calendar)
        }
        return matchesSchedule(target: target, saved: saved,
            monthlyContribution: monthlyContribution, firstDate: firstDate, targetDate: targetDate,
            hasSchedule: false, scheduledOccurrenceCount: nil,
            scheduledFinalContribution: nil, calendar: calendar)
    }

    private static func monthlyDate(anchor: Date, monthOffset: Int, calendar: Calendar) -> Date? {
        guard let firstMonth = calendar.date(from: calendar.dateComponents([.era, .year, .month], from: anchor)),
              let targetMonth = calendar.date(byAdding: .month, value: monthOffset, to: firstMonth),
              let days = calendar.range(of: .day, in: .month, for: targetMonth) else { return nil }
        var components = calendar.dateComponents([.era, .year, .month], from: targetMonth)
        components.day = min(calendar.component(.day, from: anchor), days.count)
        let time = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: anchor)
        components.hour = time.hour
        components.minute = time.minute
        components.second = time.second
        components.nanosecond = time.nanosecond
        return calendar.date(from: components)
    }
}
