import Foundation
import MoneyCore

let formatter = ISO8601DateFormatter()
let nextIncome = Calendar.current.date(byAdding: .day, value: 7, to: .now)!
let roadDate = Calendar.current.date(byAdding: .day, value: 3, to: .now)!
let snapshot = FinanceSnapshot(bankBalances: [Money(rubles: 1_500)],
                               protectedReserve: Money(rubles: 0),
                               scheduledItems: [ScheduledItem(title: "Дорога", amount: Money(rubles: 500), dueDate: roadDate)],
                               nextIncomeConfirmed: true, nextIncomeDate: nextIncome, dataUpdatedAt: .now)
let verdict = FinanceEngine().checkPurchase(Money(rubles: 1_200), snapshot: snapshot)
print("Свободно: \(FinanceEngine().availableNow(snapshot).formatted)")
switch verdict {
case .canBuy: print("Покупка укладывается в план")
case .canBuyWithChanges(_, let gap): print("Можно с изменением плана; дефицит: \(gap.formatted)")
case .unsafe(let gap, _): print("Не покупай сейчас: не хватит \(gap.formatted) на план до следующего поступления")
case .insufficientData(let reason): print(reason)
}
