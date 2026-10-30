import SwiftUI
import SwiftData
import Charts
import LocalAuthentication
import UserNotifications
import Combine
import UIKit

@main
struct MoneyWiseApp: App {
    @StateObject private var startup: AppStartup
    @State private var isRootReady = false
    @State private var isShowingIntro = true
    @State private var hasFinishedIntro = false
    @AppStorage("okaneyan.hasShownIntro") private var hasShownIntro = false
    @AppStorage("okaneyan.appearanceMode") private var appearanceMode = "dark"

    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": .light
        case "system": nil
        default: .dark
        }
    }

    init() {
        _startup = StateObject(wrappedValue: AppStartup())
        let introWasShown = UserDefaults.standard.bool(forKey: "okaneyan.hasShownIntro")
        _isShowingIntro = State(initialValue: !introWasShown)
        _hasFinishedIntro = State(initialValue: introWasShown)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container = startup.container,
                   let importWriter = startup.importWriter {
                    RootView(importWriter: importWriter, isIntroFinished: hasFinishedIntro) { isRootReady = true }
                        .modelContainer(container)
                        .accessibilityHidden(isShowingIntro)
                } else {
                    StoreOpenFailureView(message: startup.errorMessage ?? "Хранилище пока недоступно.", onRetry: startup.openStore)
                }
            }
            .preferredColorScheme(preferredColorScheme)
            .overlay {
                if startup.container != nil && isShowingIntro {
                    OkaneyanLaunchIntro(isAppReady: isRootReady) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            hasShownIntro = true
                            hasFinishedIntro = true
                            isShowingIntro = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
        }
    }
}

@MainActor
private final class AppStartup: ObservableObject {
    @Published private(set) var container: ModelContainer?
    @Published private(set) var importWriter: LocalStatementImportWriter?
    @Published private(set) var errorMessage: String?

    init() { openStore() }

    func openStore() {
        container = nil
        importWriter = nil
        let schema = Schema([StoredTransaction.self, StoredInternalTransferPair.self, StoredPlanItem.self, StoredSettings.self,
                             StoredBudget.self, StoredDebt.self, StoredAccount.self, StoredGoal.self,
                             StoredMerchantRule.self, StoredProtectedReserve.self])
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let storeDirectory = appSupport.appendingPathComponent("MoneyWise", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
            try Self.protectStoreFiles(in: storeDirectory)
            let storeURL = storeDirectory.appendingPathComponent("MoneyWise.store")
            let configuration = ModelConfiguration("MoneyWise", schema: schema, url: storeURL, cloudKitDatabase: .none)
            let openedContainer = try ModelContainer(for: schema, configurations: [configuration])
#if DEBUG || targetEnvironment(simulator)
            if ProcessInfo.processInfo.arguments.contains("--moneywise-p0-ui-fixture")
                || ProcessInfo.processInfo.environment["MONEYWISE_P0_UI_FIXTURE"] == "1" {
                try Self.seedP0UITestFixture(in: openedContainer)
            }
#endif
            // SwiftData may create the database and SQLite sidecars during container
            // initialization. Reapply file protection and backup exclusion to those
            // newly-created files before exposing the store to the rest of the app.
            try Self.protectStoreFiles(in: storeDirectory)
            importWriter = LocalStatementImportWriter(modelContainer: openedContainer)
            container = openedContainer
            errorMessage = nil
        } catch {
            container = nil
            importWriter = nil
            errorMessage = "Не удалось открыть локальную базу. Разблокируй iPhone и попробуй ещё раз. Данные не были удалены. Подробность: \(error.localizedDescription)"
        }
    }

#if DEBUG || targetEnvironment(simulator)
    private static func seedP0UITestFixture(in container: ModelContainer) throws {
        let context = ModelContext(container)
        let fixtureAccount = try context.fetch(FetchDescriptor<StoredAccount>()).first { $0.name == "P0 тестовый счёт" }
        if fixtureAccount != nil { return }
        let existingRows = try context.fetchCount(FetchDescriptor<StoredTransaction>())
            + context.fetchCount(FetchDescriptor<StoredPlanItem>())
            + context.fetchCount(FetchDescriptor<StoredSettings>())
            + context.fetchCount(FetchDescriptor<StoredBudget>())
            + context.fetchCount(FetchDescriptor<StoredDebt>())
            + context.fetchCount(FetchDescriptor<StoredAccount>())
            + context.fetchCount(FetchDescriptor<StoredGoal>())
            + context.fetchCount(FetchDescriptor<StoredMerchantRule>())
            + context.fetchCount(FetchDescriptor<StoredProtectedReserve>())
        guard existingRows == 0 else {
            throw NSError(domain: "MoneyWiseUITestFixture", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "P0 UI fixture requires an empty Simulator store; no existing data was changed."])
        }

        let account = StoredAccount(bank: .other, name: "P0 тестовый счёт", balance: Money(rubles: 10_000))
        context.insert(account)
        let settings = StoredSettings()
        settings.balanceKopecks = Money(rubles: 10_000).kopecks
        settings.hasManualBalance = true
        settings.updatedAt = .now
        settings.nextIncomeKopecks = Money(rubles: 5_000).kopecks
        settings.nextIncomeDate = calendarDateAfterDays(7)
        settings.nextIncomeConfirmed = true
        context.insert(settings)
        let calendar = Calendar.current
        let offsets = [15, 13, 12, 10, 9, 7, 6, 4, 3, 1]
        for (index, offset) in offsets.enumerated() {
            let date = calendar.date(byAdding: .day, value: -offset, to: .now) ?? .now
            let transaction = Transaction(date: date, merchant: "P0 тестовая история \(index + 1)",
                                          amount: Money(rubles: 100), kind: .purchase, category: .other)
            context.insert(StoredTransaction(transaction, sourceAccountID: account.id))
        }
        try context.save()
    }

    private static func calendarDateAfterDays(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: .now) ?? .now
    }
#endif

    private static func protectStoreFiles(in directory: URL) throws {
        let fileManager = FileManager.default
        try fileManager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
        var directoryValues = URLResourceValues()
        directoryValues.isExcludedFromBackup = true
        var protectedDirectory = directory
        try protectedDirectory.setResourceValues(directoryValues)

        // An older store may contain files created before the app protection policy was set.
        // Apply the policy to the database and SQLite sidecars before SwiftData opens them.
        for fileURL in try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isRegularFileKey]) {
            guard (try fileURL.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile == true else { continue }
            try fileManager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: fileURL.path)
            var fileValues = URLResourceValues()
            fileValues.isExcludedFromBackup = true
            var protectedFile = fileURL
            try protectedFile.setResourceValues(fileValues)
        }
    }
}

private struct StoreOpenFailureView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.database").font(.system(size: 42)).foregroundStyle(AppPalette.accent)
            Text("Не удалось открыть данные").font(.title2.weight(.semibold))
            Text(message).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Повторить", action: onRetry).buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
}

@Model final class StoredTransaction {
    var id: UUID
    var date: Date
    var merchant: String
    var amountKopecks: Int64
    var kindRaw: String
    var statusRaw: String?
    var categoryRaw: String
    var sourceID: String?
    var providerTransactionID: String?
    var refundOfProviderTransactionID: String?
    var refundOfTransactionID: UUID?
    var sourceAccountID: UUID?
    var scheduledPlanItemID: UUID?
    var scheduledOccurrenceDate: Date?
    var internalTransfer: Bool
    var incomeSourceRaw: String
    var originalMerchant: String
    var note: String?
    init(_ transaction: Transaction, sourceAccountID: UUID? = nil) {
        id = transaction.id; date = transaction.date; merchant = transaction.merchant
        amountKopecks = transaction.amount.kopecks; kindRaw = transaction.kind.rawValue
        statusRaw = transaction.status?.rawValue
        categoryRaw = transaction.category.rawValue; sourceID = transaction.sourceID
        providerTransactionID = transaction.providerTransactionID
        refundOfProviderTransactionID = transaction.refundOfProviderTransactionID
        refundOfTransactionID = transaction.refundOfTransactionID
        self.sourceAccountID = sourceAccountID
        scheduledPlanItemID = nil
        scheduledOccurrenceDate = nil
        internalTransfer = transaction.isInternalTransfer
        incomeSourceRaw = transaction.incomeSource?.rawValue ?? (transaction.kind == .income ? IncomeSource.other.rawValue : "")
        originalMerchant = transaction.merchant
        note = transaction.note.isEmpty ? nil : transaction.note
    }
    var amount: Money { Money(kopecks: amountKopecks) }
    var kind: TransactionKind { TransactionKind.restoring(kindRaw) }
    var hasValidFinancialData: Bool {
        TransactionKind(rawValue: kindRaw) != nil &&
            (statusRaw.map { TransactionStatus(rawValue: $0) != nil } ?? true) &&
            amountKopecks >= 0 && date.timeIntervalSince1970.isFinite
    }
    var status: TransactionStatus {
        get { TransactionStatus.restoring(statusRaw) }
        set { statusRaw = newValue.rawValue }
    }
    var category: Category { Category(rawValue: categoryRaw) ?? .other }
    var hasValidCategory: Bool { Category(rawValue: categoryRaw) != nil }
    var incomeSource: IncomeSource { IncomeSource(rawValue: incomeSourceRaw) ?? .other }
}

@Model final class StoredInternalTransferPair {
    var id: UUID
    var outgoingTransactionID: UUID
    var incomingTransactionID: UUID

    init(outgoingTransactionID: UUID, incomingTransactionID: UUID) {
        id = UUID()
        self.outgoingTransactionID = outgoingTransactionID
        self.incomingTransactionID = incomingTransactionID
    }
}

@Model final class StoredMerchantRule {
    var merchantKey: String
    var categoryRaw: String
    var updatedAt: Date

    init(merchantKey: String, category: Category) {
        self.merchantKey = merchantKey
        categoryRaw = category.rawValue
        updatedAt = .now
    }

    var category: Category { Category(rawValue: categoryRaw) ?? .other }
    var hasValidCategory: Bool { Category(rawValue: categoryRaw) != nil }
}

private func normalizedMerchantKey(_ merchant: String) -> String {
    merchant
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ru_RU"))
        .components(separatedBy: CharacterSet.letters.union(.decimalDigits).inverted)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
}

@Model final class StoredPlanItem {
    var id: UUID
    var title: String
    var amountKopecks: Int64
    var dueDate: Date
    var kindRaw: String
    var isConfirmed: Bool
    var recurrenceRaw: String
    var reminderDays: Int
    var occurrencesRemaining: Int?
    var finalOccurrenceKopecks: Int64?
    init(title: String, amount: Money, dueDate: Date, kind: ScheduledItem.Kind = .obligation,
         recurrence: ScheduledItem.Recurrence = .none, reminderDays: Int = 0,
         occurrencesRemaining: Int? = nil, finalOccurrenceAmount: Money? = nil) {
        id = UUID(); self.title = title; amountKopecks = amount.kopecks; self.dueDate = dueDate
        kindRaw = kind.rawValue; isConfirmed = true; recurrenceRaw = recurrence.rawValue
        self.reminderDays = reminderDays; self.occurrencesRemaining = occurrencesRemaining
        finalOccurrenceKopecks = finalOccurrenceAmount?.kopecks
    }
    var scheduled: ScheduledItem {
        ScheduledItem(id: id, title: title, amount: Money(kopecks: amountKopecks), dueDate: dueDate,
                      isConfirmed: isConfirmed, kind: ScheduledItem.Kind(rawValue: kindRaw) ?? .obligation,
                      recurrence: ScheduledItem.Recurrence(rawValue: recurrenceRaw) ?? .none,
                      occurrencesRemaining: occurrencesRemaining,
                      finalOccurrenceAmount: finalOccurrenceKopecks.map(Money.init(kopecks:)))
    }
    var hasValidFinancialData: Bool {
        ScheduledItem.Kind(rawValue: kindRaw) != nil &&
            ScheduledItem.Recurrence(rawValue: recurrenceRaw) != nil &&
            amountKopecks >= 0 &&
            (finalOccurrenceKopecks.map { $0 >= 0 } ?? true) &&
            dueDate.timeIntervalSince1970.isFinite &&
            (occurrencesRemaining.map { $0 >= 0 } ?? true)
    }
}

@Model final class StoredBudget {
    var id: UUID
    var categoryRaw: String
    var limitKopecks: Int64
    var periodStart: Date
    init(category: Category, limit: Money, periodStart: Date = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now) {
        id = UUID(); categoryRaw = category.rawValue; limitKopecks = limit.kopecks; self.periodStart = periodStart
    }
    var category: Category { Category(rawValue: categoryRaw) ?? .other }
    var hasValidBudget: Bool {
        guard let category = Category(rawValue: categoryRaw) else { return false }
        return CategoryBudgetPolicy.isValid(category: category, limit: Money(kopecks: limitKopecks),
                                            periodStart: periodStart)
    }
}

@Model final class StoredDebt {
    var id: UUID
    var creditor: String
    var balanceKopecks: Int64
    var paymentKopecks: Int64
    var firstPaymentDate: Date
    var planItemID: UUID
    var directionRaw: String?
    init(creditor: String, balance: Money, payment: Money, firstPaymentDate: Date,
         planItemID: UUID, direction: DebtDirection = .owedByMe) {
        id = UUID(); self.creditor = creditor; balanceKopecks = balance.kopecks
        paymentKopecks = payment.kopecks; self.firstPaymentDate = firstPaymentDate; self.planItemID = planItemID
        directionRaw = direction.rawValue
    }
    var direction: DebtDirection { directionRaw.flatMap(DebtDirection.init(rawValue:)) ?? .owedByMe }
    /// Last balance explicitly entered or confirmed by the user. It is never reduced by time alone.
    var currentBalance: Money { Money(kopecks: balanceKopecks) }
}

@Model final class StoredGoal {
    var id: UUID
    var title: String
    var targetKopecks: Int64
    var savedKopecks: Int64
    var monthlyContributionKopecks: Int64
    var targetDate: Date
    var planItemID: UUID?
    init(title: String, target: Money, saved: Money, monthlyContribution: Money, targetDate: Date, planItemID: UUID?) {
        id = UUID(); self.title = title; targetKopecks = target.kopecks; savedKopecks = saved.kopecks
        monthlyContributionKopecks = monthlyContribution.kopecks; self.targetDate = targetDate; self.planItemID = planItemID
    }
    var progress: Double { targetKopecks > 0 ? min(1, Double(savedKopecks) / Double(targetKopecks)) : 0 }
    var hasValidFinancialData: Bool {
        targetKopecks > 0 && savedKopecks >= 0 && monthlyContributionKopecks >= 0 &&
            targetDate.timeIntervalSince1970.isFinite
    }
}

@Model final class StoredAccount {
    var id: UUID
    var bankRaw: String
    var name: String
    var balanceKopecks: Int64
    var included: Bool
    var updatedAt: Date
    init(bank: BankName, name: String, balance: Money, included: Bool = true, updatedAt: Date = .now) {
        id = UUID(); bankRaw = bank.rawValue; self.name = name; balanceKopecks = balance.kopecks
        self.included = included; self.updatedAt = updatedAt
    }
    var bank: BankName { BankName(rawValue: bankRaw) ?? .other }
}

enum BankName: String, CaseIterable, Identifiable {
    case sber = "Сбербанк", alfa = "Альфа-Банк", ozon = "Ozon Банк", vtb = "ВТБ", otp = "ОТП Банк", cash = "Наличные", other = "Другой банк"
    var id: String { rawValue }
}

@Model final class StoredSettings {
    var balanceKopecks: Int64
    var reserveKopecks: Int64
    var nextIncomeDate: Date?
    var nextIncomeKopecks: Int64
    var nextIncomeConfirmed: Bool = false
    var updatedAt: Date?
    var lockEnabled: Bool
    var hasManualBalance: Bool
    var hasConfirmedFutureIncome: Bool {
        ExpectedIncomeConfirmation.isConfirmed(explicitlyConfirmed: nextIncomeConfirmed,
            amount: Money(kopecks: nextIncomeKopecks), date: nextIncomeDate, asOf: .now)
    }
    init() { balanceKopecks = 0; reserveKopecks = 0; nextIncomeDate = nil; nextIncomeKopecks = 0; nextIncomeConfirmed = false; updatedAt = nil; lockEnabled = false; hasManualBalance = false }
}

@Model final class StoredProtectedReserve {
    var id: UUID
    var title: String
    var amountKopecks: Int64
    var createdAt: Date
    var linkedGoalID: UUID? = nil
    var linkedPlanItemID: UUID? = nil
    var linkedOccurrenceDate: Date? = nil
    init(id: UUID = UUID(), title: String, amount: Money, createdAt: Date = .now,
         linkedGoalID: UUID? = nil, linkedPlanItemID: UUID? = nil,
         linkedOccurrenceDate: Date? = nil) {
        self.id = id; self.title = title; amountKopecks = amount.kopecks; self.createdAt = createdAt
        self.linkedGoalID = linkedGoalID
        self.linkedPlanItemID = linkedPlanItemID
        self.linkedOccurrenceDate = linkedOccurrenceDate
    }
    var amount: Money { Money(kopecks: amountKopecks) }
    var hasValidFinancialData: Bool {
        amountKopecks >= 0 && createdAt.timeIntervalSince1970.isFinite &&
            (linkedOccurrenceDate.map { $0.timeIntervalSince1970.isFinite } ?? true)
    }
}

private func validatedScheduledSettlements(transactions: [StoredTransaction], plans: [StoredPlanItem],
                                            accounts: [StoredAccount], settings: StoredSettings?,
                                            excludingTransactionID: UUID? = nil) -> [ScheduledSettlement] {
    let plansByID = Dictionary(plans.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    let includedAccountIDs = Set(accounts.filter(\.included).map(\.id))
    let ordered = transactions.filter { $0.id != excludingTransactionID }.sorted {
        if $0.date != $1.date { return $0.date < $1.date }
        return $0.id.uuidString < $1.id.uuidString
    }
    var result: [ScheduledSettlement] = []
    for transaction in ordered {
        guard ScheduledSettlementPolicy.sourceAccountIsIncluded(transaction.sourceAccountID,
                                                                 includedAccountIDs: includedAccountIDs) else { continue }
        guard let planID = transaction.scheduledPlanItemID,
              let occurrenceDate = transaction.scheduledOccurrenceDate,
              let plan = plansByID[planID]?.scheduled,
              transaction.status == .posted,
              (plan.kind == .debtCollection
                ? (transaction.kind == .income || transaction.kind == .incomingTransfer)
                : transaction.kind.isOutflow),
              !transaction.internalTransfer else { continue }
        let balanceUpdatedAt = settlementBalanceTimestamp(sourceAccountID: transaction.sourceAccountID,
            accounts: accounts, manualBalanceUpdatedAt: settings?.updatedAt)
        guard let balanceUpdatedAt, balanceUpdatedAt >= transaction.date,
              let settlement = ScheduledSettlementPolicy.makeSettlement(
                transaction: Transaction(id: transaction.id, date: transaction.date,
                    merchant: transaction.merchant, amount: transaction.amount, kind: transaction.kind,
                    category: transaction.category, isInternalTransfer: transaction.internalTransfer,
                    status: transaction.status),
                item: plan, occurrenceDate: occurrenceDate, settlements: result) else { continue }
        result.append(settlement)
    }
    return result
}

private func canPreserveUpcomingSettlements(for proposedPlan: ScheduledItem, in context: ModelContext,
                                            now: Date = .now) throws -> Bool {
    let planID = proposedPlan.id
    let transactions = try context.fetch(FetchDescriptor<StoredTransaction>(
        predicate: #Predicate { $0.scheduledPlanItemID == planID }
    ))
    let plans = try context.fetch(FetchDescriptor<StoredPlanItem>())
    let accounts = try context.fetch(FetchDescriptor<StoredAccount>())
    let settings = try context.fetch(FetchDescriptor<StoredSettings>()).first
    let currentSettlements = validatedScheduledSettlements(transactions: transactions, plans: plans,
        accounts: accounts, settings: settings).filter {
            $0.scheduledItemID == proposedPlan.id &&
                Calendar.current.startOfDay(for: $0.occurrenceDate) >= Calendar.current.startOfDay(for: now)
        }
    return ScheduledSettlementPolicy.canPreserveSettlements(for: proposedPlan,
        settlements: currentSettlements)
}

private func settlementBalanceTimestamp(sourceAccountID: UUID?, accounts: [StoredAccount],
                                        manualBalanceUpdatedAt: Date?) -> Date? {
    if let sourceAccountID, let sourceAccount = accounts.first(where: { $0.id == sourceAccountID }) {
        return sourceAccount.updatedAt
    }
    let includedAccounts = accounts.filter(\.included)
    return FinanceDataFreshness.oldestUpdateDate(includedAccounts.map(\.updatedAt),
        fallback: manualBalanceUpdatedAt)
}

private func clearScheduledSettlementLinks(to planIDs: Set<UUID>, in context: ModelContext) throws {
    guard !planIDs.isEmpty else { return }
    let linkedTransactions = try context.fetch(FetchDescriptor<StoredTransaction>(
        predicate: #Predicate { $0.scheduledPlanItemID != nil }
    ))
    for transaction in linkedTransactions where transaction.scheduledPlanItemID.map(planIDs.contains) == true {
        transaction.scheduledPlanItemID = nil
        transaction.scheduledOccurrenceDate = nil
    }
    let reserves = try context.fetch(FetchDescriptor<StoredProtectedReserve>())
    for reserve in reserves where reserve.linkedPlanItemID.map(planIDs.contains) == true {
        reserve.linkedPlanItemID = nil
        reserve.linkedOccurrenceDate = nil
    }
}

private func clearGoalReserveLinks(to goalIDs: Set<UUID>, in context: ModelContext) throws {
    guard !goalIDs.isEmpty else { return }
    let reserves = try context.fetch(FetchDescriptor<StoredProtectedReserve>())
    for reserve in reserves where reserve.linkedGoalID.map(goalIDs.contains) == true {
        reserve.linkedGoalID = nil
    }
}

private struct RootView: View {
    private let importWriter: LocalStatementImportWriter
    private let isIntroFinished: Bool
    private let onFirstContentReady: () -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var recentTransactions: [StoredTransaction]
    @Query private var settlementTransactions: [StoredTransaction]
    @Query private var planItems: [StoredPlanItem]
    @Query private var settingsRows: [StoredSettings]
    @Query private var budgets: [StoredBudget]
    @Query private var debts: [StoredDebt]
    @Query private var accounts: [StoredAccount]
    @Query private var goals: [StoredGoal]
    @Query private var merchantRules: [StoredMerchantRule]
    @Query private var namedReserves: [StoredProtectedReserve]
    @State private var selectedTab = 0
    @State private var transactionAccountFilter: UUID?
    @State private var transactionCategoryFilter: Category?
    @State private var transactionStatusFilter: TransactionStatus?
    @State private var transactionSearchText = ""
    @State private var transactionPage = 0
    @State private var showingImport = false
    @State private var isPreparingImport = false
    @State private var activeSheet: ActiveSheet?
    @State private var importPreview: [Transaction] = []
    @State private var existingSourceStatuses: [String: TransactionStatus] = [:]
    @State private var existingProviderTransactionsByAccount: [UUID: [ExistingProviderTransaction]] = [:]
    @State private var importError: String?
    @State private var importNotice: String?
    @State private var pendingDebtDeletionIDs: [UUID] = []
    @State private var confirmDebtDeletion = false
    @State private var isUnlocked = false
    @State private var isAuthenticating = false
    @State private var authenticationUnavailable = false
    @State private var activeAuthenticationAttemptID: UUID?
    @State private var authenticationContext: LAContext?
    @AppStorage("moneywise.hideAmounts") private var hideAmounts = false
    @AppStorage("moneywise.doubleFlipHideAmountsEnabled") private var doubleFlipHideAmountsEnabled = false
    @State private var doubleFlipGesture = DoubleFlipPrivacyGesture()
    @State private var isGeneratingOrientationNotifications = false
    @Namespace private var featureTransitionNamespace

    init(importWriter: LocalStatementImportWriter, isIntroFinished: Bool = true, onFirstContentReady: @escaping () -> Void = {}) {
        self.importWriter = importWriter
        self.isIntroFinished = isIntroFinished
        self.onFirstContentReady = onFirstContentReady
        let now = Date.now
        let recentHistoryStart = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? .distantPast
        let currentMonthStart = Calendar.current.dateInterval(of: .month, for: now)?.start ?? .distantPast
        let start = min(recentHistoryStart, currentMonthStart)
        _recentTransactions = Query(
            // Keep the upper bound dynamic below. A fixed `now` in this query would
            // hide transactions added later during the same app session.
            filter: #Predicate<StoredTransaction> { $0.date >= start },
            sort: \StoredTransaction.date,
            order: .reverse
        )
        _settlementTransactions = Query(
            filter: #Predicate<StoredTransaction> { $0.scheduledPlanItemID != nil },
            sort: \StoredTransaction.date,
            order: .reverse
        )
    }

    private var settings: StoredSettings { settingsRows.first ?? StoredSettings() }
    private var includedAccountIDs: Set<UUID> { Set(accounts.filter(\.included).map(\.id)) }
    private var reminderRefreshKey: [String] {
        var values = planItems.map { item in
            ["plan", item.id.uuidString, item.title, String(item.amountKopecks),
             String(item.dueDate.timeIntervalSince1970.bitPattern), item.kindRaw, item.recurrenceRaw,
             String(item.reminderDays), item.occurrencesRemaining.map(String.init) ?? "infinite",
             item.finalOccurrenceKopecks.map(String.init) ?? "no-final"].joined(separator: "|")
        }
        values += settlementTransactions.map { transaction in
            ["settlement", transaction.id.uuidString, String(transaction.date.timeIntervalSince1970.bitPattern),
             String(transaction.amountKopecks), transaction.kindRaw, transaction.statusRaw ?? "default-status",
             transaction.internalTransfer ? "internal" : "external",
             transaction.scheduledPlanItemID?.uuidString ?? "no-plan",
             transaction.scheduledOccurrenceDate.map { String($0.timeIntervalSince1970.bitPattern) } ?? "no-occurrence",
             transaction.sourceAccountID?.uuidString ?? "manual"].joined(separator: "|")
        }
        values += accounts.map { account in
            ["account", account.id.uuidString, account.included ? "included" : "excluded",
             String(account.updatedAt.timeIntervalSince1970.bitPattern)].joined(separator: "|")
        }
        values.append("settings|\(settingsRows.first?.updatedAt.map { String($0.timeIntervalSince1970.bitPattern) } ?? "no-update")")
        return values.sorted()
    }
    private var currentMonthBudgets: [StoredBudget] {
        guard let month = Calendar.current.dateInterval(of: .month, for: .now) else { return [] }
        return budgets.filter { month.contains($0.periodStart) }
    }

    private var hasValidFinancialData: Bool {
        settingsRows.count <= 1 &&
            IdentityIntegrity.hasUniqueIdentifiers(accounts.map(\.id)) &&
            IdentityIntegrity.hasUniqueIdentifiers(goals.map(\.id)) &&
            planItems.allSatisfy(\.hasValidFinancialData) &&
            goals.allSatisfy { $0.hasValidFinancialData && hasValidGoalPlan($0) } &&
            debts.allSatisfy(hasValidDebtPlan) &&
            namedReserves.allSatisfy(\.hasValidFinancialData) &&
            transactionsFromIncludedAccounts(dashboardTransactions).allSatisfy(\.hasValidFinancialData) &&
            settings.reserveKopecks >= 0
    }

    /// A debt balance without its matching recurring payment would make the safe-to-spend
    /// projection too optimistic. Treat broken or ambiguous persisted links as invalid plan data.
    private func hasValidDebtPlan(_ debt: StoredDebt) -> Bool {
        let linkedPlans = planItems.filter { $0.id == debt.planItemID }
        guard linkedPlans.count == 1, let plan = linkedPlans.first else { return false }
        let linkedDebtCount = debts.filter { $0.planItemID == debt.planItemID }.count
        if debt.direction == .owedToMe {
            return DebtCollectionSchedule.matchesPlan(balance: Money(kopecks: debt.balanceKopecks),
                payment: Money(kopecks: debt.paymentKopecks), firstPaymentDate: debt.firstPaymentDate,
                plan: plan.scheduled, linkedDebtCount: linkedDebtCount)
        }
        return DebtRepaymentSchedule.matchesPlan(balance: Money(kopecks: debt.balanceKopecks),
            payment: Money(kopecks: debt.paymentKopecks), firstPaymentDate: debt.firstPaymentDate,
            plan: plan.scheduled, linkedDebtCount: linkedDebtCount)
    }

    /// Goal contributions are forecast cash outflows. A missing, shared, or malformed
    /// contribution plan must not silently disappear from a confident spending projection.
    private func hasValidGoalPlan(_ goal: StoredGoal) -> Bool {
        let firstPossibleDate = Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now
        let linkedPlan: ScheduledItem?
        let linkedGoalCount: Int
        if let planID = goal.planItemID {
            let matches = planItems.filter { $0.id == planID }
            guard matches.count == 1, let plan = matches.first else { return false }
            linkedPlan = plan.scheduled
            linkedGoalCount = goals.filter { $0.planItemID == planID }.count
        } else {
            linkedPlan = nil
            linkedGoalCount = 0
        }

        return GoalContributionPlan.matchesLinkedPlan(
            target: Money(kopecks: goal.targetKopecks),
            saved: Money(kopecks: goal.savedKopecks),
            monthlyContribution: Money(kopecks: goal.monthlyContributionKopecks),
            firstDate: linkedPlan?.dueDate ?? firstPossibleDate,
            targetDate: goal.targetDate,
            hasPlanReference: goal.planItemID != nil, plan: linkedPlan,
            linkedGoalCount: linkedGoalCount)
    }

    private var dashboardTransactions: [StoredTransaction] {
        recentTransactions.filter { $0.date <= .now }
    }

    private var snapshot: FinanceSnapshot {
        let s = settings
        let includedAccounts = accounts.filter(\.included)
        let accountBalances = includedAccounts.map { Money(kopecks: $0.balanceKopecks) }
        let balances = accounts.isEmpty ? (s.hasManualBalance ? [Money(kopecks: s.balanceKopecks)] : []) : accountBalances
        let settlements = validatedScheduledSettlements(transactions: settlementTransactions,
            plans: planItems, accounts: accounts, settings: s)
        let spendEstimate = estimateDailySpend(excluding: Set(settlements.map(\.transactionID)))
        let forecastIncomeDate = s.nextIncomeDate.flatMap { ExpectedIncomeConfirmation.forecastBoundary(for: $0) }
        let plannedIncome = forecastIncomeDate.map { date in
            [IncomeEvent(title: "Следующее поступление", amount: Money(kopecks: s.nextIncomeKopecks), date: date,
                         isConfirmed: s.hasConfirmedFutureIncome)]
        } ?? []
        return FinanceSnapshot(bankBalances: balances,
                               protectedReserve: Money(kopecks: s.reserveKopecks),
                               scheduledItems: planItems.map(\.scheduled), incomes: plannedIncome,
                               scheduledSettlements: settlements,
                               nextIncomeConfirmed: s.hasConfirmedFutureIncome,
                               nextIncomeDate: forecastIncomeDate,
                               forecastDailySpend: spendEstimate ?? .zero, hasReliableSpendForecast: spendEstimate != nil,
                               hasValidPlanData: hasValidFinancialData,
                               dataUpdatedAt: FinanceDataFreshness.oldestUpdateDate(
                                   includedAccounts.map(\.updatedAt),
                                   fallback: accounts.isEmpty ? s.updatedAt : nil
                               ),
                               balanceReconciliationIssue: balanceReconciliationIssue,
                               goalReserve: goals.reduce(Money.zero) { total, goal in
                                   total + GoalContributionPlan.reservedAmount(
                                       target: Money(kopecks: goal.targetKopecks), saved: Money(kopecks: goal.savedKopecks))
                               },
                               earmarkedReserve: Money.sum(namedReserves.map(\.amount)),
                               goalAllocations: goals.map { goal in
                                   GoalReserveAllocation(goalID: goal.id,
                                       amount: GoalContributionPlan.reservedAmount(
                                           target: Money(kopecks: goal.targetKopecks),
                                           saved: Money(kopecks: goal.savedKopecks)))
                               },
                               namedReserveAllocations: namedReserves.map { reserve in
                                   NamedReserveAllocation(amount: reserve.amount, goalID: reserve.linkedGoalID,
                                       scheduledItemID: reserve.linkedPlanItemID,
                                       occurrenceDate: reserve.linkedOccurrenceDate)
                               },
                               usesReserveAllocations: true)
    }

    /// A dated operation later than an account balance snapshot can make the displayed
    /// balance stale even when the account's confirmation timestamp is recent. We do not
    /// infer a replacement balance from an incomplete transaction history.
    private var balanceReconciliationIssue: String? {
        let includedTransactions = transactionsFromIncludedAccounts(dashboardTransactions)
        if accounts.isEmpty {
            guard settings.hasManualBalance, let confirmedAt = settings.updatedAt else { return nil }
            guard let transaction = includedTransactions
                .filter({ $0.status == .posted && $0.date > confirmedAt })
                .max(by: { $0.date < $1.date }) else { return nil }
            return reconciliationMessage(transactionDate: transaction.date, confirmedAt: confirmedAt)
        }

        let includedAccounts = accounts.filter(\.included)
        for account in includedAccounts {
            guard let transaction = includedTransactions
                .filter({ $0.sourceAccountID == account.id && $0.status == .posted && $0.date > account.updatedAt })
                .max(by: { $0.date < $1.date }) else { continue }
            return reconciliationMessage(transactionDate: transaction.date, confirmedAt: account.updatedAt)
        }
        return nil
    }

    private func reconciliationMessage(transactionDate: Date, confirmedAt: Date) -> String {
        "Есть операция от \(transactionDate.formatted(date: .abbreviated, time: .omitted)), датированная позже подтверждения баланса (\(confirmedAt.formatted(date: .abbreviated, time: .omitted))). Сверь операции и подтверди текущую сумму счёта: остаток не пересчитывается автоматически."
    }

    private var effectiveReserveTotals: ProtectedReserveTotals {
        let end = settings.hasConfirmedFutureIncome ? (settings.nextIncomeDate ?? .now) : .now
        return FinanceEngine().protectedReserveTotals(snapshot, from: .now, through: end)
    }
    private var hasAvailableNowData: Bool {
        guard snapshot.hasValidPlanData, snapshot.hasReliableSpendForecast,
              !snapshot.bankBalances.isEmpty,
              let incomeDate = snapshot.nextIncomeDate, incomeDate > .now,
              FinancePlanningPolicy.supportsForecast(from: .now, to: incomeDate),
              snapshot.nextIncomeConfirmed,
              snapshot.balanceReconciliationIssue == nil,
              FinanceDataFreshness.isFresh(snapshot.dataUpdatedAt, asOf: .now) else { return false }
        return true
    }

    private var availableNowText: String {
        guard hasAvailableNowData else { return "—" }
        return FinanceEngine().availableNow(snapshot).formatted
    }

    private var availableNowExplanation: String {
        if let issue = snapshot.balanceReconciliationIssue { return issue }
        guard snapshot.hasValidPlanData else {
            return "Проверь операции, планы, долги, цели и резервы: часть данных не распознана или связь платежа с долгом/целью повреждена."
        }
        guard snapshot.hasReliableSpendForecast else {
            return "Нужно больше истории операций для оценки обычных расходов."
        }
        guard !snapshot.bankBalances.isEmpty else {
            return "Добавьте ручной баланс, чтобы рассчитать свободную сумму."
        }
        guard let incomeDate = snapshot.nextIncomeDate else {
            return "Укажите дату следующего поступления."
        }
        guard incomeDate > .now else {
            return "Укажите будущую дату следующего поступления."
        }
        guard FinancePlanningPolicy.supportsForecast(from: .now, to: incomeDate) else {
            return "Безопасный прогноз надёжен максимум на 2 года. Уточните дату поступления или проверьте план ближе к ней."
        }
        guard snapshot.nextIncomeConfirmed else {
            return "Подтверди сумму и дату следующего поступления, чтобы рассчитать свободные деньги до него."
        }
        guard let updatedAt = snapshot.dataUpdatedAt else {
            return "Обновите ручной баланс перед расчётом."
        }
        guard updatedAt <= .now else {
            return "Время обновления баланса позже текущего времени. Проверьте дату и время на iPhone."
        }
        guard FinanceDataFreshness.isFresh(updatedAt, asOf: .now) else {
            return "Баланс не обновлялся больше 72 часов. Последнее подтверждение: \(updatedAt.formatted(date: .abbreviated, time: .shortened)). Обновите данные."
        }
        return "С учётом резервов, обязательств и обычных расходов."
    }

    private var nearTermItems: [PlannedOccurrence] {
        let now = Date.now
        let fallbackEnd = Calendar.current.date(byAdding: .day, value: 90, to: now) ?? now
        let maximumEnd = Calendar.current.date(byAdding: .day, value: FinancePlanningPolicy.maximumIncomeHorizonDays,
                                               to: now) ?? fallbackEnd
        let confirmedIncomeDate = snapshot.nextIncomeConfirmed ? snapshot.nextIncomeDate : nil
        let end = min(confirmedIncomeDate ?? fallbackEnd, maximumEnd)
        return FinanceEngine().upcomingOccurrences(snapshot, from: now, through: end)
    }

    private var gravityNodes: [FinancialGravityNode] {
        let today = Calendar.current.startOfDay(for: .now)
        let nextMonth = Calendar.current.date(byAdding: .day, value: 30, to: today) ?? .distantFuture
        var nodes: [FinancialGravityNode] = []
        if snapshot.protectedReserve > .zero {
            nodes.append(.init(id: "minimum", title: "Минимальный резерв", amount: snapshot.protectedReserve, kind: .minimum))
        }
        if effectiveReserveTotals.named > .zero {
            nodes.append(.init(id: "named-reserves", title: "Именные резервы", amount: effectiveReserveTotals.named, kind: .reserve))
        }
        if effectiveReserveTotals.goals > .zero {
            nodes.append(.init(id: "goals", title: "Цели и связанные конверты", amount: effectiveReserveTotals.goals, kind: .goal))
        }
        let obligations = FinanceEngine().upcomingOccurrences(snapshot, from: .now,
            through: nextMonth.addingTimeInterval(-0.001))
            .filter { occurrence in
                snapshot.scheduledItems.first(where: { $0.id == occurrence.planID })?.kind != .debtCollection
            }
        let obligationsTotal = Money.sum(obligations.map(\.amount))
        if obligationsTotal > .zero {
            nodes.append(.init(id: "obligations", title: "Платежи · 30 дней", amount: obligationsTotal, kind: .obligation))
        }
        let confirmedIncome = snapshot.incomes.filter { $0.isConfirmed && $0.date >= .now && $0.date < nextMonth }
        let plannedDebtReturns = FinanceEngine().upcomingOccurrences(snapshot, from: .now,
            through: nextMonth.addingTimeInterval(-0.001)).filter { $0.kind == .debtCollection }
        let incomeTotal = Money.sum(confirmedIncome.map(\.amount) + plannedDebtReturns.map(\.amount))
        if incomeTotal > .zero {
            nodes.append(.init(id: "income", title: "Поступления · 30 дней", amount: incomeTotal, kind: .income))
        }
        return nodes
    }

    var body: some View {
        Group {
        if settings.lockEnabled && !isUnlocked {
            AppLockView(onUnlock: authenticate, isAuthenticating: isAuthenticating,
                        authenticationUnavailable: authenticationUnavailable)
        } else {
        TabView(selection: $selectedTab) {
            home.tabItem { Label("Обзор", systemImage: "chart.pie.fill").font(AppTypography.ui(12, weight: .medium)) }.tag(0)
            transactionsView.tabItem { Label("Операции", systemImage: "list.bullet.rectangle").font(AppTypography.ui(12, weight: .medium)) }.tag(1)
            planView.tabItem { Label("План", systemImage: "calendar").font(AppTypography.ui(12, weight: .medium)) }.tag(2)
        }
        .font(AppTypography.ui(16))
        .tint(AppPalette.accent)
        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.88), value: selectedTab)
        .sensoryFeedback(.selection, trigger: selectedTab)
        .fileImporter(isPresented: $showingImport, allowedContentTypes: [.commaSeparatedText, .plainText], allowsMultipleSelection: false) { result in
            importCSV(result)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .settings: SettingsView(settings: getOrCreateSettings(context))
            case .addTransaction: AddTransactionView()
            case .importPreview: ImportPreviewView(transactions: importPreview, accounts: accounts,
                                                   existingStatuses: existingSourceStatuses,
                                                   existingProviderTransactionsByAccount: existingProviderTransactionsByAccount,
                                                   onCancel: { activeSheet = nil }, onConfirm: confirmImport)
            case .account: AddAccountView()
            case .goal: AddGoalView()
            }
        }
        .alert(importError == nil ? "Импорт завершён" : "Не удалось выполнить операцию",
               isPresented: Binding(get: { importError != nil || importNotice != nil }, set: { if !$0 { importError = nil; importNotice = nil } })) {
            Button("Понятно", role: .cancel) { importError = nil; importNotice = nil }
        } message: { Text(importError ?? importNotice ?? "") }
        .overlay {
            if isPreparingImport {
                ProgressView("Готовим операции к импорту…")
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityLabel("Читаем выписку и проверяем повторы")
            }
        }
        }
        }
        .task {
            if !settings.lockEnabled { isUnlocked = true }
            else if isIntroFinished { authenticate() }
            onFirstContentReady()
        }
        .onChange(of: isIntroFinished) { _, finished in
            if finished && settings.lockEnabled { authenticate() }
        }
        .onChange(of: settings.lockEnabled) { _, enabled in
            if enabled {
                isUnlocked = false
                authenticate()
            } else {
                authenticationContext?.invalidate()
                authenticationContext = nil
                activeAuthenticationAttemptID = nil
                isAuthenticating = false
                isUnlocked = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Cover the finance UI before iOS captures the app-switcher snapshot.
            // `inactive` happens before `background` when the user leaves the app.
            if (phase == .inactive || phase == .background) && settings.lockEnabled {
                isUnlocked = false
            }
            // LocalAuthentication may itself temporarily make the scene inactive.
            // Invalidate only after the app actually enters the background.
            if phase == .background && settings.lockEnabled {
                authenticationContext?.invalidate()
                authenticationContext = nil
                activeAuthenticationAttemptID = nil
                isAuthenticating = false
            }
            if phase == .active { refreshPlanReminders() }
            if phase == .active && settings.lockEnabled { authenticate() }
            setOrientationMonitoring(doubleFlipHideAmountsEnabled && phase == .active)
        }
        .onAppear {
            setOrientationMonitoring(doubleFlipHideAmountsEnabled && scenePhase == .active)
            if scenePhase == .active { refreshPlanReminders() }
        }
        .onDisappear { setOrientationMonitoring(false) }
        .onChange(of: doubleFlipHideAmountsEnabled) { _, enabled in
            setOrientationMonitoring(enabled && scenePhase == .active)
        }
        .onChange(of: reminderRefreshKey) { _, _ in
            refreshPlanReminders()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            guard doubleFlipHideAmountsEnabled, scenePhase == .active, isUnlocked else { return }
            let orientation = UIDevice.current.orientation
            guard orientation != .unknown else { return }
            let isFaceDown = orientation == .faceDown
            if doubleFlipGesture.record(isFaceDown: isFaceDown, at: .now) {
                hideAmounts.toggle()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }

    private func setOrientationMonitoring(_ enabled: Bool) {
        if enabled && !isGeneratingOrientationNotifications {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            isGeneratingOrientationNotifications = true
            doubleFlipGesture.reset()
            let orientation = UIDevice.current.orientation
            if orientation != .unknown {
                _ = doubleFlipGesture.record(isFaceDown: orientation == .faceDown, at: .now)
            }
        } else if !enabled && isGeneratingOrientationNotifications {
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
            isGeneratingOrientationNotifications = false
            doubleFlipGesture.reset()
        }
    }

    private var homeShortcuts: some View {
        HStack(spacing: 2) {
            homeShortcut("Горизонт", symbol: "chart.xyaxis.line", id: "horizon-mark") {
                FinancialHorizonView(snapshot: snapshot, protectedTotals: effectiveReserveTotals,
                                     namespace: featureTransitionNamespace)
            }
            homeShortcut("Резервы", symbol: "lock.shield.fill", id: "reserve-mark") {
                ProtectedReservesView(balance: snapshot.currentBalance,
                    minimumReserve: snapshot.protectedReserve, protectedTotals: effectiveReserveTotals,
                    namespace: featureTransitionNamespace)
            }
            homeShortcut("Структура", symbol: "list.bullet.indent", id: "gravity-mark") {
                FinancialGravityView(balance: snapshot.currentBalance,
                    freeCash: hasAvailableNowData ? FinanceEngine().availableNow(snapshot) : nil,
                    freeCashExplanation: availableNowExplanation, nodes: gravityNodes,
                    namespace: featureTransitionNamespace)
            }
            homeShortcut("Покупка", symbol: "cart.badge.questionmark", id: "purchase-check-mark") {
                PurchaseCheckView(snapshot: snapshot)
            }
        }
        .padding(.vertical, 5)
        .overlay(alignment: .top) { Rectangle().fill(AppPalette.line).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(AppPalette.line).frame(height: 1) }
    }

    private func homeShortcut<Destination: View>(
        _ title: String,
        symbol: String,
        id: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppPalette.accent)
                    .frame(width: 17, height: 19)
                    .modifier(FeatureMatchedGeometryModifier(
                        id: id, namespace: featureTransitionNamespace, enabled: !reduceMotion
                    ))
                Text(title)
                    .font(AppTypography.ui(12, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var home: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AvailableBalanceCard(
                        amount: availableNowText,
                        explanation: availableNowExplanation,
                    accountBalance: snapshot.bankBalances.isEmpty ||
                        !IdentityIntegrity.hasUniqueIdentifiers(accounts.map(\.id)) ? nil : snapshot.currentBalance,
                        accountBalanceStatus: snapshot.balanceReconciliationIssue ?? balanceFreshnessLabel(for: snapshot.dataUpdatedAt),
                        reserve: Money(kopecks: settings.reserveKopecks) + effectiveReserveTotals.named,
                        goalReserve: effectiveReserveTotals.goals,
                        averageDailySpend: snapshot.hasReliableSpendForecast ? snapshot.forecastDailySpend : nil,
                        safeDailyLimit: FinanceEngine().safeDailySpendingLimit(snapshot),
                        nextIncomeDate: settings.nextIncomeDate,
                        nextIncomeAmount: settings.nextIncomeDate == nil ? nil : Money(kopecks: settings.nextIncomeKopecks),
                        scheduledItems: nearTermItems,
                        onConfigure: { activeSheet = .settings }
                    )

                    HStack(spacing: 12) {
                        SummaryCard(title: "Защищено", value: (Money(kopecks: settings.reserveKopecks) + effectiveReserveTotals.named).formatted, icon: "lock.shield")
                        SummaryCard(title: "На цели", value: effectiveReserveTotals.goals.formatted, icon: "scope")
                    }
                    NavigationLink {
                        AccountsOverviewView(accounts: accounts)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "building.columns").font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppPalette.accent)
                            Text("Счета и источники баланса").font(AppTypography.ui(14, weight: .medium))
                            Spacer()
                            Text("\(accounts.count)").font(AppTypography.amount(13, weight: .medium)).foregroundStyle(.secondary)
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    homeShortcuts
                    HStack {
                        Text("Последние операции").font(AppTypography.ui(23, weight: .semibold))
                        Spacer()
                        Button { activeSheet = .addTransaction } label: { Image(systemName: "plus.circle.fill") }
                            .accessibilityLabel("Добавить операцию")
                    }
                    if dashboardTransactions.isEmpty {
                        ContentUnavailableView("За последний месяц операций нет", systemImage: "tray", description: Text("Старую историю можно открыть во вкладке «Операции»."))
                    } else {
                        ForEach(dashboardTransactions.prefix(5)) { transaction in
                            TransactionRow(transaction: transaction, accountName: accountName(for: transaction))
                        }
                    }
                }.padding()
            }
            .background(AppPalette.canvas)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: 96)
            }
            .navigationTitle("Обзор")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { hideAmounts.toggle() } label: { Image(systemName: hideAmounts ? "eye.slash" : "eye") }.accessibilityLabel(hideAmounts ? "Показать суммы" : "Скрыть суммы")
                    Button { beginStatementImport() } label: { Image(systemName: "square.and.arrow.down") }
                        .accessibilityLabel("Импортировать операции")
                }
            }
        }
    }

private struct AccountsOverviewView: View {
    let accounts: [StoredAccount]
    @State private var addingAccount = false

    var body: some View {
        List {
            if accounts.isEmpty {
                ContentUnavailableView(
                    "Отдельных счетов пока нет",
                    systemImage: "building.columns",
                    description: Text("Можно добавить банковский, наличный или другой счёт. Баланс появится в расчёте только после явного включения.")
                )
            } else {
                ForEach(accounts) { account in
                    NavigationLink {
                        EditAccountView(account: account)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(account.name)
                                Text(account.bank.rawValue).font(.caption).foregroundStyle(.secondary)
                                Text(balanceFreshnessLabel(for: account.updatedAt))
                                    .font(.caption2)
                                    .foregroundStyle(FinanceDataFreshness.isFresh(account.updatedAt, asOf: .now)
                                        ? Color.secondary : Color.orange)
                            }
                            Spacer()
                            SensitiveAmount(value: Money(kopecks: account.balanceKopecks).formatted)
                                .font(AppTypography.amount(15, weight: .semibold))
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Счета")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { addingAccount = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Добавить счёт")
            }
        }
        .sheet(isPresented: $addingAccount) { AddAccountView() }
    }
}

    private var transactionsView: some View {
        TransactionHistoryView(
            accounts: accounts,
            selectedAccountID: $transactionAccountFilter,
            selectedCategory: $transactionCategoryFilter,
            selectedStatus: $transactionStatusFilter,
            searchText: $transactionSearchText,
            page: $transactionPage,
            hideAmounts: $hideAmounts,
            onImport: { beginStatementImport() },
            onError: { importError = $0 },
            accountName: accountName
        )
    }

    private func planRowDetails(_ item: StoredPlanItem) -> String {
        let kind = ScheduledItem.Kind(rawValue: item.kindRaw).map { value in
            switch value {
            case .obligation: "Обязательство"
            case .goalContribution: "Взнос в цель"
            case .debtRepayment: "Платёж по долгу"
            case .debtCollection: "Возврат долга тебе"
            case .subscription: "Подписка"
            }
        } ?? "Тип не распознан"

        let recurrence = ScheduledItem.Recurrence(rawValue: item.recurrenceRaw)
        let dateDetails: String
        if let recurrence, recurrence == .none {
            let today = Calendar.current.startOfDay(for: .now)
            dateDetails = item.dueDate < today
                ? "Просрочено с \(item.dueDate.formatted(date: .abbreviated, time: .omitted))"
                : "Разово · \(item.dueDate.formatted(date: .abbreviated, time: .omitted))"
        } else if recurrence != nil,
                  let nextDate = ScheduledRecurrence.firstOccurrence(onOrAfter: .now, of: item.scheduled) {
            let label = item.kindRaw == ScheduledItem.Kind.debtCollection.rawValue ? "Следующий ожидаемый возврат" : "Следующий платёж"
            dateDetails = "\(label) · \(nextDate.formatted(date: .abbreviated, time: .omitted))"
        } else if recurrence == nil {
            dateDetails = "Периодичность не распознана"
        } else {
            dateDetails = "График завершён"
        }

        let calculationStatus = item.isConfirmed ? "В расчёте" : "Не учитывается"
        let reminder = item.reminderDays > 0 ? "Напоминание за \(item.reminderDays) дн." : nil
        return ([kind, dateDetails, calculationStatus] + [reminder].compactMap { $0 })
            .joined(separator: " · ")
    }

    private var planView: some View {
        NavigationStack {
            List {
                Section("Поступление") {
                    LabeledContent("Следующая дата", value: settings.nextIncomeDate?.formatted(date: .abbreviated, time: .omitted) ?? "Не задана")
                    LabeledContent(settings.hasConfirmedFutureIncome ? "Подтверждено" : "Ожидается", value: settings.hasConfirmedFutureIncome ? "Включено в прогноз" : "Не включено в прогноз")
                    LabeledContent("Сумма") { SensitiveAmount(value: Money(kopecks: settings.nextIncomeKopecks).formatted) }
                }
                Section("Обязательства и цели") {
                    if planItems.isEmpty { Text("Добавь дорогу, подписки, платежи и взносы в цели.").foregroundStyle(.secondary) }
                    ForEach(planItems) { item in
                        NavigationLink {
                            if let goal = goals.first(where: { $0.planItemID == item.id }) {
                                EditGoalView(goal: goal, plan: item)
                            } else if let debt = debts.first(where: { $0.planItemID == item.id }) {
                                EditDebtView(debt: debt, plan: item)
                            } else {
                                EditPlanItemView(item: item)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                    Text(planRowDetails(item))
                                        .font(.caption).foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 8)
                                SensitiveAmount(value: Money(kopecks: item.amountKopecks).formatted)
                            }
                        }
                    }.onDelete { offsets in
                        let removed = offsets.map { planItems[$0] }
                        let linkedDebtPayments = removed.filter { item in
                            debts.contains { $0.planItemID == item.id && $0.balanceKopecks > 0 }
                        }
                        guard linkedDebtPayments.isEmpty else {
                            importError = "Это платёж по долгу с подтверждённым остатком. Измени его через карточку долга или сначала подтверди нулевой остаток после фактического погашения."
                            return
                        }
                        performDataChange({
                            try clearScheduledSettlementLinks(to: Set(removed.map(\.id)), in: context)
                            for item in removed {
                                if let goal = goals.first(where: { $0.planItemID == item.id }) {
                                    goal.monthlyContributionKopecks = 0
                                    goal.planItemID = nil
                                }
                                context.delete(item)
                            }
                        }) {
                            removed.forEach { PaymentReminderScheduler.cancel(id: $0.id) }
                        }
                    }
                }
                Section("Цели накоплений") {
                    if goals.isEmpty { Text("Целей пока нет.").foregroundStyle(.secondary) }
                    ForEach(goals) { goal in
                        NavigationLink {
                            EditGoalView(goal: goal, plan: planItems.first(where: { $0.id == goal.planItemID }))
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack { Text(goal.title); Spacer(); SensitiveAmount(value: "\(Money(kopecks: goal.savedKopecks).formatted) / \(Money(kopecks: goal.targetKopecks).formatted)").font(AppTypography.amount(12)) }
                                ProgressView(value: goal.progress).tint(.green)
                                Text("Цель к \(goal.targetDate.formatted(date: .abbreviated, time: .omitted))").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }.onDelete { offsets in
                        let removed = offsets.map { goals[$0] }
                        performDataChange {
                            try clearGoalReserveLinks(to: Set(removed.map(\.id)), in: context)
                            try clearScheduledSettlementLinks(
                                to: Set(removed.compactMap(\.planItemID)), in: context)
                            for goal in removed {
                                if let id = goal.planItemID, let item = planItems.first(where: { $0.id == id }) { context.delete(item) }
                                context.delete(goal)
                            }
                        } afterSave: {
                            removed.compactMap(\.planItemID).forEach { PaymentReminderScheduler.cancel(id: $0) }
                        }
                    }
                    NavigationLink("Добавить цель", destination: AddGoalView())
                }
                Section("Бюджеты на этот месяц") {
                    if currentMonthBudgets.isEmpty { Text("Бюджеты на этот месяц пока не заданы.").foregroundStyle(.secondary) }
                    ForEach(currentMonthBudgets) { budget in
                        if budget.hasValidBudget {
                            let used = monthSpend(for: budget.category)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack { Text(budget.category.title); Spacer(); SensitiveAmount(value: "\(Money(kopecks: used).formatted) / \(Money(kopecks: budget.limitKopecks).formatted)").font(AppTypography.amount(12)) }
                                ProgressView(value: min(1, Double(used) / Double(budget.limitKopecks)))
                                    .tint(used > budget.limitKopecks ? .red : AppPalette.accent)
                            }
                        } else {
                            Label("\(budget.category.title): бюджет требует исправления", systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote).foregroundStyle(.orange)
                        }
                    }.onDelete { offsets in
                        let visibleBudgets = currentMonthBudgets
                        let removed = offsets.map { visibleBudgets[$0] }
                        performDataChange { removed.forEach(context.delete) }
                    }
                    NavigationLink("Добавить бюджет", destination: AddBudgetView())
                }
                Section("Долги") {
                    if debts.isEmpty { Text("Долгов не записано.").foregroundStyle(.secondary) }
                    ForEach(debts) { debt in
                        NavigationLink {
                            EditDebtView(debt: debt, plan: planItems.first(where: { $0.id == debt.planItemID }))
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack { Text(debt.creditor); Spacer(); SensitiveAmount(value: debt.currentBalance.formatted).fontWeight(.semibold) }
                                Text(debt.direction.title).font(.caption.weight(.medium)).foregroundStyle(debt.direction == .owedToMe ? .green : .secondary)
                                Text("Остаток, подтверждённый вручную · обнови после реального платежа")
                                    .font(.caption2).foregroundStyle(.secondary)
                                HStack { Text("Платёж"); SensitiveAmount(value: Money(kopecks: debt.paymentKopecks).formatted); Text("· следующий: \(debt.firstPaymentDate.formatted(date: .abbreviated, time: .omitted))") }
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }.onDelete { offsets in
                        pendingDebtDeletionIDs = offsets.map { debts[$0].id }
                        confirmDebtDeletion = !pendingDebtDeletionIDs.isEmpty
                    }
                    NavigationLink("Добавить долг", destination: AddDebtView())
                }
            }.navigationTitle("План")
                .confirmationDialog("Удалить запись о долге?", isPresented: $confirmDebtDeletion, titleVisibility: .visible) {
                    Button("Отмена", role: .cancel) { pendingDebtDeletionIDs = [] }
                    Button("Удалить долг и его платёж", role: .destructive, action: deleteSelectedDebts)
                } message: {
                    Text("Долг и связанный плановый платёж будут удалены. Свободная сумма увеличится, поэтому подтверждай только если запись действительно больше не нужна.")
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { activeSheet = .settings } label: { Image(systemName: "slider.horizontal.3") }
                            .accessibilityLabel("Настройки приложения")
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button { hideAmounts.toggle() } label: { Image(systemName: hideAmounts ? "eye.slash" : "eye") }.accessibilityLabel(hideAmounts ? "Показать суммы" : "Скрыть суммы")
                        NavigationLink { AddPlanItemView() } label: { Image(systemName: "plus") }
                            .accessibilityLabel("Добавить в план")
                    }
                }
        }
    }

    private func accountName(for transaction: StoredTransaction) -> String? {
        guard let id = transaction.sourceAccountID else { return nil }
        guard let account = accounts.first(where: { $0.id == id }) else { return "Счёт удалён" }
        return "\(account.bank.rawValue) · \(account.name)"
    }

    private func transactionsFromIncludedAccounts(_ transactions: [StoredTransaction]) -> [StoredTransaction] {
        let includedIDs = includedAccountIDs
        return transactions.filter {
            ScheduledSettlementPolicy.sourceAccountIsIncluded($0.sourceAccountID,
                includedAccountIDs: includedIDs)
        }
    }

    private func refreshPlanReminders() {
        let settlements = validatedScheduledSettlements(transactions: settlementTransactions,
            plans: planItems, accounts: accounts, settings: settingsRows.first)
        for item in planItems {
            guard item.hasValidFinancialData, (1...2).contains(item.reminderDays),
                  item.occurrencesRemaining != 0,
                  let recurrence = ScheduledItem.Recurrence(rawValue: item.recurrenceRaw) else {
                PaymentReminderScheduler.cancel(id: item.id)
                continue
            }
            PaymentReminderScheduler.schedule(title: item.title, dueDate: item.dueDate,
                amount: item.scheduled.amount, daysBefore: item.reminderDays, recurrence: recurrence,
                occurrencesRemaining: item.occurrencesRemaining,
                finalOccurrenceAmount: item.scheduled.finalOccurrenceAmount,
                settlements: settlements, kind: item.scheduled.kind, id: item.id)
        }
    }

    private func estimateDailySpend(excluding settledTransactionIDs: Set<UUID> = []) -> Money? {
        let storedTransactions = transactionsFromIncludedAccounts(dashboardTransactions)
        guard storedTransactions.allSatisfy(\.hasValidFinancialData) else { return nil }
        let coreTransactions = storedTransactions.map {
            Transaction(id: $0.id, date: $0.date, merchant: $0.merchant, amount: $0.amount,
                        kind: $0.kind, category: $0.category, isInternalTransfer: $0.internalTransfer,
                        sourceID: $0.sourceID, status: $0.status,
                        providerTransactionID: $0.providerTransactionID,
                        refundOfProviderTransactionID: $0.refundOfProviderTransactionID,
                        refundOfTransactionID: $0.refundOfTransactionID)
        }
        return SpendingForecaster().estimateDailySpend(coreTransactions,
            excludingTransactionIDs: settledTransactionIDs)
    }

    private func monthSpend(for category: Category) -> Int64 {
        let start = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .distantPast
        let end = Calendar.current.dateInterval(of: .month, for: .now)?.end ?? .distantFuture
        let transactions = transactionsFromIncludedAccounts(dashboardTransactions).map {
            Transaction(id: $0.id, date: $0.date, merchant: $0.merchant, amount: $0.amount,
                        kind: $0.kind, category: $0.category, isInternalTransfer: $0.internalTransfer,
                        sourceID: $0.sourceID, status: $0.status,
                        providerTransactionID: $0.providerTransactionID,
                        refundOfProviderTransactionID: $0.refundOfProviderTransactionID,
                        refundOfTransactionID: $0.refundOfTransactionID)
        }
        return SpendingAnalytics.totalOutflow(transactions, from: start, to: end, category: category,
                                              asOf: .now).kopecks
    }

    private func importCSV(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        Task {
            isPreparingImport = true
            defer { isPreparingImport = false }
            let parsingTask = Task.detached(priority: .userInitiated) {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let transactions = try CSVStatementImporter().parse(contentsOf: url, sourceNamespace: url.standardizedFileURL.path)
                return transactions
            }
            defer { parsingTask.cancel() }
            do {
                importPreview = try await parsingTask.value
                let importHistory = try await importWriter.fetchImportHistory()
                existingSourceStatuses = importHistory.statuses
                existingProviderTransactionsByAccount = importHistory.providerTransactionsByAccount
                activeSheet = .importPreview
            } catch {
                importError = error.localizedDescription
            }
        }
    }

    private func beginStatementImport() {
        #if DEBUG || targetEnvironment(simulator)
        if let fixtureName = ProcessInfo.processInfo.environment["MONEYWISE_TEST_IMPORT_FIXTURE"],
           let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            importCSV(.success([documentsDirectory.appendingPathComponent(fixtureName)]))
            return
        }
        #endif
        showingImport = true
    }

    private func performDataChange(_ change: () throws -> Void, afterSave: () -> Void = {}) {
        do {
            try context.transaction { try change() }
            afterSave()
        } catch {
            context.rollback()
            importError = error.localizedDescription
        }
    }

    private func deleteSelectedDebts() {
        let selectedIDs = Set(pendingDebtDeletionIDs)
        let removed = debts.filter { selectedIDs.contains($0.id) }
        performDataChange({
            try clearScheduledSettlementLinks(to: Set(removed.map(\.planItemID)), in: context)
            for debt in removed {
                if let plan = planItems.first(where: { $0.id == debt.planItemID }) { context.delete(plan) }
                context.delete(debt)
            }
        }) {
            removed.forEach { PaymentReminderScheduler.cancel(id: $0.planItemID) }
        }
        pendingDebtDeletionIDs = []
    }

    private func confirmImport(_ recurringCandidates: [RecurringCandidate], sourceAccountID: UUID?,
                               preparedImport: PreparedStatementImport) async -> Bool {
        importError = nil
        importNotice = nil
        do {
            let result = try await importWriter.persistImport(preparedImport,
                recurringCandidates: recurringCandidates, sourceAccountID: sourceAccountID)
            var lines = ["Добавлено операций: \(result.insertedCount).",
                         "Повторы пропущены: \(result.duplicateCount).",
                         "Статусы обновлены: \(result.updatedStatusCount)."]
            if result.skippedStatusCount > 0 {
                lines.append("Статусы не обновлены: \(result.skippedStatusCount) — операция уже изменилась или была обработана.")
            }
            if result.conflictCount > 0 {
                lines.append("Конфликты с данными банка для проверки: \(result.conflictCount).")
            }
            if !result.reminders.isEmpty {
                lines.append("Добавлено напоминаний о регулярных платежах: \(result.reminders.count).")
            }
            if result.skippedRecurringCount > 0 {
                lines.append("Повторные планы не добавлены: \(result.skippedRecurringCount).")
            }
            importNotice = lines.joined(separator: "\n")
            importPreview = []; activeSheet = nil
            return true
        }
        catch {
            importNotice = nil
            importError = error.localizedDescription
            return false
        }
    }

    private func getOrCreateSettings(_ context: ModelContext) -> StoredSettings {
        if let existing = settingsRows.first { return existing }
        let new = StoredSettings()
        context.insert(new)
        do { try context.save() }
        catch { importError = error.localizedDescription }
        return new
    }

    private func authenticate() {
        guard settings.lockEnabled else { isUnlocked = true; return }
        guard !isAuthenticating else { return }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            authenticationUnavailable = true
            return
        }
        authenticationUnavailable = false
        let attemptID = UUID()
        activeAuthenticationAttemptID = attemptID
        authenticationContext = context
        isAuthenticating = true
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Открой финансовые данные") { success, _ in
            DispatchQueue.main.async {
                guard activeAuthenticationAttemptID == attemptID else { return }
                activeAuthenticationAttemptID = nil
                authenticationContext = nil
                isAuthenticating = false
                isUnlocked = success && settings.lockEnabled
            }
        }
    }
}

@ModelActor
private actor LocalStatementImportWriter {
    func fetchImportHistory() throws -> StatementImportHistory {
        let rows = try modelContext.fetch(FetchDescriptor<StoredTransaction>())
        var statuses: [String: TransactionStatus] = [:]
        var providerTransactionsByAccount: [UUID: [ExistingProviderTransaction]] = [:]
        for row in rows {
            if let sourceID = row.sourceID { statuses[sourceID] = row.status }
            guard let accountID = row.sourceAccountID,
                  let providerID = row.providerTransactionID,
                  !providerID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            providerTransactionsByAccount[accountID, default: []].append(ExistingProviderTransaction(
                providerTransactionID: providerID, sourceID: row.sourceID, status: row.status,
                merchant: row.merchant, amount: row.amount, date: row.date, kind: row.kind
            ))
        }
        return StatementImportHistory(statuses: statuses,
            providerTransactionsByAccount: providerTransactionsByAccount)
    }

    func persistImport(_ preparedImport: PreparedStatementImport, recurringCandidates: [RecurringCandidate],
                       sourceAccountID: UUID?) throws -> StatementImportPersistenceResult {
        if let sourceAccountID {
            var descriptor = FetchDescriptor<StoredAccount>(
                predicate: #Predicate<StoredAccount> { $0.id == sourceAccountID }
            )
            descriptor.fetchLimit = 1
            guard try modelContext.fetch(descriptor).first != nil else {
                throw StatementImportPersistenceError.accountNotFound
            }
        }

        // The preview can become stale if another window imports the same file.
        // Recheck identifiers on the writer actor immediately before inserting.
        let storedRows = try modelContext.fetch(FetchDescriptor<StoredTransaction>())
        let storedSourceIDs = Set(storedRows.compactMap(\.sourceID))
        var storedRowsByProviderID: [String: [StoredTransaction]] = [:]
        if let sourceAccountID {
            for row in storedRows where row.sourceAccountID == sourceAccountID {
                guard let providerID = row.providerTransactionID else { continue }
                storedRowsByProviderID[providerID, default: []].append(row)
            }
        }
        let existingProviderTransactionIDs = Set(storedRowsByProviderID.keys)
        let newTransactions = CSVStatementImporter().excludingStoredDuplicates(
            preparedImport.transactions, existingSourceIDs: storedSourceIDs,
            existingProviderTransactionIDs: existingProviderTransactionIDs)
        let providerCandidates = storedRows.map { row in
            ProviderTransactionCandidate(id: row.id, accountID: row.sourceAccountID,
                providerTransactionID: row.providerTransactionID, kind: row.kind,
                isInternalTransfer: row.internalTransfer)
        } + newTransactions.map { row in
            ProviderTransactionCandidate(id: row.id, accountID: sourceAccountID,
                providerTransactionID: row.providerTransactionID, kind: row.kind,
                isInternalTransfer: row.isInternalTransfer)
        }
        let selectedRecurringIDs = Set(recurringCandidates.map(\.id))
        let selectedRecurringCandidates = RecurringDetector().detect(newTransactions).filter {
            selectedRecurringIDs.contains($0.id)
        }
        let recurringDetector = RecurringDetector()
        let existingRecurringPlans = try modelContext.fetch(FetchDescriptor<StoredPlanItem>())
            .map(\.scheduled)
        let newRecurringCandidates = selectedRecurringCandidates.filter { candidate in
            !existingRecurringPlans.contains { recurringDetector.matchesExistingPlan(candidate, plan: $0) }
        }
        let skippedRecurringCount = selectedRecurringCandidates.count - newRecurringCandidates.count

        let rules = try modelContext.fetch(FetchDescriptor<StoredMerchantRule>())
        let learnedCategories = rules.reduce(into: [String: StoredMerchantRule]()) { latest, rule in
            guard let current = latest[rule.merchantKey] else {
                latest[rule.merchantKey] = rule
                return
            }
            if rule.updatedAt > current.updatedAt ||
                (rule.updatedAt == current.updatedAt && rule.categoryRaw > current.categoryRaw) {
                latest[rule.merchantKey] = rule
            }
        }

        let reminders = newRecurringCandidates.map { candidate in
            PendingImportReminder(title: candidate.title, dueDate: candidate.nextDate,
                                  recurrence: candidate.recurrence, id: UUID())
        }
        do {
            var importedRows: [StoredTransaction] = []
            importedRows.reserveCapacity(newTransactions.count)
            let storedRowsBySourceID = storedRows.reduce(into: [String: [StoredTransaction]]()) { result, row in
                guard let sourceID = row.sourceID else { return }
                result[sourceID, default: []].append(row)
            }
            var updatedStatusCount = 0
            var skippedStatusCount = 0
            for update in preparedImport.statusUpdates {
                guard update.status == .posted else { skippedStatusCount += 1; continue }
                switch update.identity {
                case .sourceID(let sourceID):
                    let matches = storedRowsBySourceID[sourceID] ?? []
                    guard matches.count == 1, let row = matches.first,
                          row.sourceAccountID == sourceAccountID,
                          TransactionStatus.canPromoteToPosted(fromStoredRawValue: row.statusRaw),
                          let expected = update.expectedStoredValues,
                          expected.matches(merchant: row.merchant, amount: row.amount,
                                           date: row.date, kind: row.kind) else {
                        skippedStatusCount += 1
                        continue
                    }
                    row.status = .posted
                    updatedStatusCount += 1
                case .providerTransactionID(let providerID):
                    let matches = storedRowsByProviderID[providerID] ?? []
                    guard matches.count == 1,
                          TransactionStatus.canPromoteToPosted(fromStoredRawValue: matches[0].statusRaw),
                          let expected = update.expectedStoredValues,
                          expected.matches(merchant: matches[0].merchant, amount: matches[0].amount,
                                           date: matches[0].date, kind: matches[0].kind) else {
                        skippedStatusCount += 1
                        continue
                    }
                    matches[0].status = .posted
                    updatedStatusCount += 1
                }
            }
            for transaction in newTransactions {
                var categorized = transaction
                let key = normalizedMerchantKey(transaction.merchant)
                if let rule = learnedCategories[key], rule.hasValidCategory {
                    categorized = TransactionCategoryCorrection.applying(rule.category, to: categorized)
                }
                let storedTransaction = StoredTransaction(categorized, sourceAccountID: sourceAccountID)
                storedTransaction.refundOfTransactionID = RefundLinkResolver.resolve(
                    refund: categorized, accountID: sourceAccountID, candidates: providerCandidates
                )
                modelContext.insert(storedTransaction)
                importedRows.append(storedTransaction)
            }
            // A refund imported before its original operation can be linked on a later import.
            // Recompute against the full local set so newly introduced ambiguity also clears links.
            let allImportedAndStoredRows = storedRows + importedRows
            let completeProviderCandidates = allImportedAndStoredRows.map { row in
                ProviderTransactionCandidate(id: row.id, accountID: row.sourceAccountID,
                    providerTransactionID: row.providerTransactionID, kind: row.kind,
                    isInternalTransfer: row.internalTransfer)
            }
            for row in allImportedAndStoredRows where row.kind == .refund {
                let refund = Transaction(id: row.id, date: row.date, merchant: row.merchant,
                    amount: row.amount, kind: .refund,
                    refundOfProviderTransactionID: row.refundOfProviderTransactionID)
                row.refundOfTransactionID = RefundLinkResolver.resolve(refund: refund,
                    accountID: row.sourceAccountID, candidates: completeProviderCandidates)
            }
            for (candidate, reminder) in zip(newRecurringCandidates, reminders) {
                let item = StoredPlanItem(title: candidate.title, amount: candidate.amount,
                    dueDate: candidate.nextDate, kind: .subscription,
                    recurrence: candidate.recurrence, reminderDays: 1)
                item.id = reminder.id
                modelContext.insert(item)
            }
            try modelContext.save()
            let newlyFoundDuplicates = max(0, preparedImport.transactions.count - newTransactions.count)
            return StatementImportPersistenceResult(reminders: reminders,
                insertedCount: newTransactions.count,
                duplicateCount: preparedImport.duplicateCount + newlyFoundDuplicates,
                updatedStatusCount: updatedStatusCount, skippedStatusCount: skippedStatusCount,
                conflictCount: preparedImport.providerConflicts.count,
                skippedRecurringCount: skippedRecurringCount)
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}

private struct StatementImportHistory: Sendable {
    let statuses: [String: TransactionStatus]
    let providerTransactionsByAccount: [UUID: [ExistingProviderTransaction]]
}

private struct PendingImportReminder: Sendable {
    let title: String
    let dueDate: Date
    let recurrence: ScheduledItem.Recurrence
    let id: UUID
}

private struct StatementImportPersistenceResult: Sendable {
    let reminders: [PendingImportReminder]
    let insertedCount: Int
    let duplicateCount: Int
    let updatedStatusCount: Int
    let skippedStatusCount: Int
    let conflictCount: Int
    let skippedRecurringCount: Int
}

private enum StatementImportPersistenceError: LocalizedError {
    case accountNotFound
    var errorDescription: String? {
        "Выбранный счёт больше не найден. Закрой предпросмотр и выбери счёт заново."
    }
}

private func storedTransferPair(for transactionID: UUID,
                                in context: ModelContext) throws -> StoredInternalTransferPair? {
    var descriptor = FetchDescriptor<StoredInternalTransferPair>(
        predicate: #Predicate<StoredInternalTransferPair> { $0.outgoingTransactionID == transactionID || $0.incomingTransactionID == transactionID }
    )
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
}

private func storedTransaction(for id: UUID, in context: ModelContext) throws -> StoredTransaction? {
    var descriptor = FetchDescriptor<StoredTransaction>(predicate: #Predicate<StoredTransaction> { $0.id == id })
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
}

private struct TransferPairCleanup {
    let pairs: [StoredInternalTransferPair]
    let transactions: [StoredTransaction]
}

private func transferPairCleanup(forAccountID accountID: UUID,
                                 in context: ModelContext) throws -> TransferPairCleanup {
    let accountTransactions = try context.fetch(FetchDescriptor<StoredTransaction>(
        predicate: #Predicate<StoredTransaction> { $0.sourceAccountID == accountID }
    ))
    let accountTransactionIDs = Set(accountTransactions.map(\.id))
    let pairs = try context.fetch(FetchDescriptor<StoredInternalTransferPair>()).filter {
        accountTransactionIDs.contains($0.outgoingTransactionID) || accountTransactionIDs.contains($0.incomingTransactionID)
    }
    var transactionsByID = Dictionary(uniqueKeysWithValues: accountTransactions.map { ($0.id, $0) })
    for pair in pairs {
        let counterpartID = accountTransactionIDs.contains(pair.outgoingTransactionID)
            ? pair.incomingTransactionID : pair.outgoingTransactionID
        if !accountTransactionIDs.contains(counterpartID),
           let counterpart = try storedTransaction(for: counterpartID, in: context) {
            transactionsByID[counterpart.id] = counterpart
        }
    }
    return TransferPairCleanup(pairs: pairs, transactions: Array(transactionsByID.values))
}

private struct TransactionHistoryView: View {
    let accounts: [StoredAccount]
    @Binding var selectedAccountID: UUID?
    @Binding var selectedCategory: Category?
    @Binding var selectedStatus: TransactionStatus?
    @Binding var searchText: String
    @Binding var page: Int
    @Binding var hideAmounts: Bool
    let onImport: () -> Void
    let onError: (String) -> Void
    let accountName: (StoredTransaction) -> String?

    var body: some View {
        NavigationStack {
            List {
                Section("Фильтры") {
                    if !accounts.isEmpty {
                        Picker("Показать операции", selection: $selectedAccountID) {
                            Text("Все счета").tag(Optional<UUID>.none)
                            ForEach(accounts) { account in
                                Text("\(account.bank.rawValue) · \(account.name)").tag(Optional(account.id))
                            }
                        }
                        .onChange(of: selectedAccountID) { _, _ in page = 0 }
                    }
                    Picker("Категория", selection: $selectedCategory) {
                        Text("Все категории").tag(Optional<Category>.none)
                        ForEach(Category.allCases) { category in
                            Text(category.title).tag(Optional(category))
                        }
                    }
                    .onChange(of: selectedCategory) { _, _ in page = 0 }
                    Picker("Статус", selection: $selectedStatus) {
                        Text("Все статусы").tag(Optional<TransactionStatus>.none)
                        Text("Ожидают проведения").tag(Optional(TransactionStatus.pending))
                        Text("Проведены").tag(Optional(TransactionStatus.posted))
                    }
                    .onChange(of: selectedStatus) { _, _ in page = 0 }
                }
                TransactionHistoryPage(
                    page: page,
                    accountID: selectedAccountID,
                    category: selectedCategory,
                    status: selectedStatus,
                    searchText: searchText,
                    accounts: accounts,
                    accountName: accountName,
                    onError: onError,
                    onPageChange: { page = $0 }
                )
                .id("\(page)-\(selectedAccountID?.uuidString ?? "all")-\(selectedCategory?.rawValue ?? "all")-\(selectedStatus?.rawValue ?? "all")-\(searchText)")
            }
            .navigationTitle("Операции")
            .searchable(text: $searchText, prompt: "Магазин или получатель")
            .onChange(of: searchText) { _, _ in page = 0 }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { hideAmounts.toggle() } label: { Image(systemName: hideAmounts ? "eye.slash" : "eye") }
                        .accessibilityLabel(hideAmounts ? "Показать суммы" : "Скрыть суммы")
                    Button(action: onImport) { Image(systemName: "square.and.arrow.down") }
                        .accessibilityLabel("Импортировать операции")
                }
            }
        }
    }
}

private struct TransactionHistoryPage: View {
    private static let pageSize = 100
    @Environment(\.modelContext) private var context
    @Query private var transactions: [StoredTransaction]
    let accounts: [StoredAccount]
    let page: Int
    let category: Category?
    let status: TransactionStatus?
    let searchText: String
    let accountName: (StoredTransaction) -> String?
    let onError: (String) -> Void
    let onPageChange: (Int) -> Void

    init(page: Int, accountID: UUID?, category: Category?, status: TransactionStatus?, searchText: String,
         accounts: [StoredAccount],
         accountName: @escaping (StoredTransaction) -> String?,
         onError: @escaping (String) -> Void, onPageChange: @escaping (Int) -> Void) {
        self.page = page
        self.category = category
        self.status = status
        self.searchText = searchText
        self.accounts = accounts
        self.accountName = accountName
        self.onError = onError
        self.onPageChange = onPageChange
        var descriptor = FetchDescriptor<StoredTransaction>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let accountPredicate: Predicate<StoredTransaction>
        if let accountID {
            accountPredicate = #Predicate { $0.sourceAccountID == accountID }
        } else {
            accountPredicate = .true
        }
        let categoryPredicate: Predicate<StoredTransaction>
        if let category {
            let categoryRaw = category.rawValue
            categoryPredicate = #Predicate { $0.categoryRaw == categoryRaw }
        } else {
            categoryPredicate = .true
        }
        let statusPredicate: Predicate<StoredTransaction>
        switch status {
        case .pending:
            statusPredicate = #Predicate { transaction in
                transaction.statusRaw == "pending" ||
                    (transaction.statusRaw != nil && transaction.statusRaw != "posted")
            }
        case .posted:
            statusPredicate = #Predicate { $0.statusRaw == nil || $0.statusRaw == "posted" }
        case nil:
            statusPredicate = .true
        }
        let searchTerm = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchPredicate: Predicate<StoredTransaction>
        if searchTerm.isEmpty {
            searchPredicate = .true
        } else {
            searchPredicate = #Predicate { $0.merchant.localizedStandardContains(searchTerm) }
        }
        if #available(iOS 27.0, *) {
            descriptor.predicate = Predicate(all: [accountPredicate, categoryPredicate, statusPredicate, searchPredicate])
            descriptor.fetchLimit = Self.pageSize + 1
            descriptor.fetchOffset = page * Self.pageSize
        } else {
            // Predicate composition is available from iOS 27. Older systems keep the account filter in SwiftData
            // and apply the remaining filters before paging so the list never skips matching transactions.
            descriptor.predicate = accountPredicate
        }
        _transactions = Query(descriptor)
    }

    private var filteredTransactions: [StoredTransaction] {
        let searchTerm = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return transactions.filter { transaction in
            let matchesCategory = category.map { transaction.categoryRaw == $0.rawValue } ?? true
            let matchesStatus: Bool
            switch status {
            case .pending:
                matchesStatus = transaction.statusRaw == "pending" ||
                    (transaction.statusRaw != nil && transaction.statusRaw != "posted")
            case .posted:
                matchesStatus = transaction.statusRaw == nil || transaction.statusRaw == "posted"
            case nil:
                matchesStatus = true
            }
            let matchesSearch = searchTerm.isEmpty || transaction.merchant.localizedStandardContains(searchTerm)
            return matchesCategory && matchesStatus && matchesSearch
        }
    }

    private var visibleTransactions: [StoredTransaction] {
        if #available(iOS 27.0, *) {
            return Array(transactions.prefix(Self.pageSize))
        }
        return Array(filteredTransactions.dropFirst(page * Self.pageSize).prefix(Self.pageSize))
    }

    private var hasNextPage: Bool {
        if #available(iOS 27.0, *) {
            return transactions.count > Self.pageSize
        }
        return filteredTransactions.count > (page + 1) * Self.pageSize
    }

    var body: some View {
        if visibleTransactions.isEmpty && page == 0 {
            ContentUnavailableView("Нет операций", systemImage: "list.bullet.rectangle")
        } else {
            Section {
                if visibleTransactions.isEmpty {
                    ContentUnavailableView("На этой странице операций нет", systemImage: "list.bullet.rectangle")
                }
                ForEach(visibleTransactions) { transaction in
                    NavigationLink { EditTransactionView(transaction: transaction, accounts: accounts) } label: {
                        TransactionRow(transaction: transaction, accountName: accountName(transaction))
                    }
                }
                .onDelete(perform: delete)
            } footer: {
                HStack {
                    Button("Назад") { onPageChange(max(0, page - 1)) }
                        .disabled(page == 0)
                    Spacer()
                    Text("Страница \(page + 1)")
                    Spacer()
                    Button("Дальше") { onPageChange(page + 1) }
                        .disabled(!hasNextPage)
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        let removed = offsets.map { visibleTransactions[$0] }
        do {
            let removedIDs = Set(removed.map(\.id))
            let refundReferences = try context.fetch(FetchDescriptor<StoredTransaction>()).filter { row in
                row.refundOfTransactionID.map(removedIDs.contains) ?? false
            }
            var pairsByID: [UUID: StoredInternalTransferPair] = [:]
            var counterpartsByID: [UUID: StoredTransaction] = [:]
            for transaction in removed {
                guard let pair = try storedTransferPair(for: transaction.id, in: context) else { continue }
                pairsByID[pair.id] = pair
                let counterpartID = pair.outgoingTransactionID == transaction.id ? pair.incomingTransactionID : pair.outgoingTransactionID
                if !removedIDs.contains(counterpartID), let counterpart = try storedTransaction(for: counterpartID, in: context) {
                    counterpartsByID[counterpart.id] = counterpart
                }
            }
            try context.transaction {
                counterpartsByID.values.forEach { $0.internalTransfer = false }
                refundReferences.forEach { $0.refundOfTransactionID = nil }
                pairsByID.values.forEach(context.delete)
                removed.forEach(context.delete)
            }
        } catch {
            context.rollback()
            onError(error.localizedDescription)
        }
    }
}

private enum ActiveSheet: String, Identifiable {
    case settings, addTransaction, importPreview, account, goal
    var id: String { rawValue }
}

private struct AppLockView: View {
    let onUnlock: () -> Void
    let isAuthenticating: Bool
    let authenticationUnavailable: Bool
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill").font(.system(size: 42)).foregroundStyle(AppPalette.accent)
            Text("Данные защищены").font(.title2.bold())
            if authenticationUnavailable {
                Text("Системная проверка недоступна. Включи код-пароль в настройках iPhone и вернись в приложение.")
                    .font(.footnote).multilineTextAlignment(.center).foregroundStyle(.secondary)
            }
            Button(isAuthenticating ? "Проверяем…" : "Разблокировать", action: onUnlock)
                .buttonStyle(.borderedProminent)
                .disabled(isAuthenticating)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(AppPalette.canvas)
    }
}

private struct AvailableBalanceCard: View {
    let amount: String
    let explanation: String
    let accountBalance: Money?
    let accountBalanceStatus: String
    let reserve: Money
    let goalReserve: Money
    let averageDailySpend: Money?
    let safeDailyLimit: DailySpendingLimitResult
    let nextIncomeDate: Date?
    let nextIncomeAmount: Money?
    let scheduledItems: [PlannedOccurrence]
    let onConfigure: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("moneywise.hideAmounts") private var hideAmounts = false
    @Namespace private var balanceNamespace
    @State private var isExpanded = false
    @GestureState private var materialTouch: CGPoint? = nil

    private var detailsTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 8) {
                Circle().fill(AppPalette.heroAccent).frame(width: 7, height: 7)
                    .padding(.top, dynamicTypeSize.isAccessibilitySize ? 8 : 0)
                    .accessibilityHidden(true)
                Text("ДЕНЕЖНЫЙ ГОРИЗОНТ")
                    .font(.caption.weight(.semibold))
                    .tracking(1.1)
                    .foregroundStyle(AppPalette.heroMuted)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppPalette.heroMuted)
                        .accessibilityHidden(true)
                }
            }
            if dynamicTypeSize.isAccessibilitySize {
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppPalette.heroMuted)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityHidden(true)
            }

            Text("Свободно до поступления")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppPalette.heroMuted)

            if isExpanded {
                HStack(alignment: .firstTextBaseline) {
                    Text("Свободно")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppPalette.heroMuted)
                    Spacer(minLength: 12)
                    amountView(font: .system(.title2, design: .default).weight(.semibold))
                }
                .matchedGeometryEffect(id: "available-balance", in: balanceNamespace)
            } else {
                amountView(font: .system(.largeTitle, design: .default).weight(.semibold))
                    .matchedGeometryEffect(id: "available-balance", in: balanceNamespace)
            }

            if let accountBalance {
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("На счетах")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(AppPalette.heroMuted)
                            accountBalanceAmount(accountBalance)
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("На счетах")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(AppPalette.heroMuted)
                            Spacer(minLength: 8)
                            accountBalanceAmount(accountBalance)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                Text(accountBalanceStatus)
                    .font(.caption2)
                    .foregroundStyle(AppPalette.heroMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: accountBalance == nil ? "info.circle" : "lock.shield")
                    .font(.caption)
                    .foregroundStyle(AppPalette.heroAccent)
                    .accessibilityHidden(true)
                Text(explanation)
                    .font(.footnote)
                    .foregroundStyle(AppPalette.heroMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            dailyLimitSummary

            if !isExpanded, !hasReliableAmount {
                Button(action: onConfigure) {
                    Label("Настроить расчёт", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.heroAccent)
                        .frame(minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Rectangle().fill(AppPalette.heroLine).frame(height: 1)
                    if let accountBalance {
                        valueRow("На счетах", value: accountBalance.formatted)
                        Text("Последнее подтверждение: \(accountBalanceStatus). Это сохранённый баланс, не онлайн-остаток банка.")
                            .font(.footnote)
                            .foregroundStyle(AppPalette.heroMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        valueRow("На счетах", value: "Не задан")
                    }
                    valueRow("Защищённый резерв", value: reserve.formatted)
                    valueRow("Отложено на цели", value: goalReserve.formatted)
                    if let averageDailySpend {
                        valueRow("Обычные траты по истории · в день", value: averageDailySpend.formatted)
                    } else {
                        Text("Средние траты пока не включены: недостаточно истории операций.")
                            .font(.footnote)
                            .foregroundStyle(AppPalette.heroMuted)
                    }

                    if scheduledItems.isEmpty {
                        Text("В ближайшем периоде нет подтверждённых платежей или поступлений.")
                            .font(.footnote)
                            .foregroundStyle(AppPalette.heroMuted)
                    } else {
                        Text("Подтверждённые события")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppPalette.heroMuted)
                        ForEach(scheduledItems.prefix(3)) { item in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title).lineLimit(2)
                                    Text(item.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption2)
                                        .foregroundStyle(AppPalette.heroMuted)
                                }
                                Spacer(minLength: 8)
                                SensitiveAmount(value: "\(item.kind == .debtCollection ? "+" : "−")\(item.amount.formatted)")
                                    .font(.footnote.weight(.semibold))
                            }
                            .foregroundStyle(AppPalette.heroInk)
                            .accessibilityElement(children: .combine)
                        }
                        if scheduledItems.count > 3 {
                            Text("И ещё \(scheduledItems.count - 3) в разделе «План»")
                                .font(.caption)
                            .foregroundStyle(AppPalette.heroMuted)
                        }
                    }

                    if let nextIncomeDate, let nextIncomeAmount, nextIncomeAmount > .zero {
                        Rectangle().fill(AppPalette.heroLine).frame(height: 1).padding(.top, 2)
                        valueRow("Ожидаемое поступление · \(nextIncomeDate.formatted(date: .abbreviated, time: .omitted))",
                                 value: nextIncomeAmount.formatted)
                        Text("Ожидаемая сумма не включена в доступный остаток до фактического зачисления.")
                            .font(.caption)
                            .foregroundStyle(AppPalette.heroMuted)
                    }
                }
                .transition(detailsTransition)
            }

            Button {
                withAnimation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.86)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(isExpanded ? "Скрыть состав суммы" : "Показать состав суммы")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .foregroundStyle(AppPalette.heroAccent)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Скрыть состав свободной суммы" : "Показать состав свободной суммы")
            .accessibilityValue(isExpanded ? "Раскрыто" : "Свернуто")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(AppPalette.hero)
                Capsule(style: .continuous)
                    .fill(AppPalette.heroAccent.opacity(0.82))
                    .frame(width: 2, height: 42)
                    .padding(.leading, 1)
                    .accessibilityHidden(true)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(AppPalette.metalEdge.opacity(0.34), lineWidth: 1))
        .overlay {
            GeometryReader { geometry in
                if !reduceMotion, let materialTouch {
                    let path = metallicEdgePath(in: geometry.size, around: materialTouch)
                    ZStack {
                        path.stroke(AppPalette.metalEdge.opacity(0.28), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                        path.stroke(AppPalette.metalHighlight.opacity(0.52), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .shadow(color: .black.opacity(0.12), radius: 22, x: 0, y: 12)
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .simultaneousGesture(
            DragGesture(minimumDistance: 12, coordinateSpace: .local)
                .updating($materialTouch) { value, state, _ in
                    let translation = value.translation
                    guard !reduceMotion,
                          abs(translation.width) > abs(translation.height) * 1.15 else {
                        state = nil
                        return
                    }
                    state = value.location
                }
        )
    }

    private func accountBalanceAmount(_ accountBalance: Money) -> some View {
        SensitiveAmount(value: accountBalance.formatted)
            .font(.footnote.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(AppPalette.heroInk)
    }

    private func metallicEdgePath(in size: CGSize, around point: CGPoint) -> Path {
        let length: CGFloat = 46
        let corner: CGFloat = 28
        let edgeDistances = [point.y, size.width - point.x, size.height - point.y, point.x]
        let edge = edgeDistances.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
        var path = Path()
        switch edge {
        case 0:
            let x = min(max(corner, point.x - length / 2), max(corner, size.width - corner - length))
            path.move(to: CGPoint(x: x, y: 2))
            path.addLine(to: CGPoint(x: x + length, y: 2))
        case 1:
            let y = min(max(corner, point.y - length / 2), max(corner, size.height - corner - length))
            path.move(to: CGPoint(x: size.width - 2, y: y))
            path.addLine(to: CGPoint(x: size.width - 2, y: y + length))
        case 2:
            let x = min(max(corner, point.x - length / 2), max(corner, size.width - corner - length))
            path.move(to: CGPoint(x: x, y: size.height - 2))
            path.addLine(to: CGPoint(x: x + length, y: size.height - 2))
        default:
            let y = min(max(corner, point.y - length / 2), max(corner, size.height - corner - length))
            path.move(to: CGPoint(x: 2, y: y))
            path.addLine(to: CGPoint(x: 2, y: y + length))
        }
        return path
    }

    private var hasReliableAmount: Bool { amount != "—" }

    @ViewBuilder
    private var dailyLimitSummary: some View {
        switch safeDailyLimit {
        case .calculated(let limit):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Средний лимит в день")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppPalette.heroMuted)
                Spacer(minLength: 8)
                SensitiveAmount(value: limit.formatted)
                    .font(.system(.title3, design: .monospaced).weight(.semibold))
                    .foregroundStyle(AppPalette.heroInk)
            }
            Text("До следующего поступления, с учётом резерва и подтверждённых платежей.")
                .font(.caption)
                .foregroundStyle(AppPalette.heroMuted)
        case .unsafe(let shortfall, let date):
            VStack(alignment: .leading, spacing: 4) {
                Label("Даже без новых трат прогноз ниже защищённого плана\(date.map { " к \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "").",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                SensitiveAmount(value: "Не хватает \(shortfall.formatted)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        case .insufficientData(let reason):
            Text("Дневной лимит не рассчитан: \(reason)")
                .font(.footnote)
                .foregroundStyle(AppPalette.heroMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func amountView(font: Font) -> some View {
        SensitiveAmount(value: amount)
            .font(font)
            .monospacedDigit()
            .foregroundStyle(AppPalette.heroInk)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .accessibilityLabel(hideAmounts ? "Свободная сумма скрыта" : "Свободно до поступления \(amount)")
    }

    private func valueRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(AppPalette.heroMuted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            SensitiveAmount(value: value)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppPalette.heroInk)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SummaryCard: View {
    let title: String; let value: String; let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.caption).foregroundStyle(.secondary)
            SensitiveAmount(value: value).font(AppTypography.amount(17, weight: .bold))
        }.frame(maxWidth: .infinity, alignment: .leading).padding()
            .background(AppPalette.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppPalette.line, lineWidth: 1))
    }
}

private struct ForecastCard: View {
    let snapshot: FinanceSnapshot
    var body: some View {
        let verdict = FinanceEngine().checkPurchase(.zero, snapshot: snapshot)
        let assessment = PlanHealthAssessment.from(verdict)
        VStack(alignment: .leading, spacing: 8) {
            Label("Прогноз до следующего поступления", systemImage: "chart.line.uptrend.xyaxis").font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 10) {
                Circle().fill(color(for: assessment.level)).frame(width: 12, height: 12).padding(.top, 4)
                VStack(alignment: .leading, spacing: 3) {
                    Text(assessment.title).font(.subheadline.bold())
                    Text(assessment.detail).font(.footnote).foregroundStyle(.secondary)
                }
            }
            switch verdict {
            case .canBuy(let minimum):
                HStack { Text("Минимальный остаток по плану"); Spacer(); SensitiveAmount(value: minimum.formatted).fontWeight(.semibold) }
            case .canBuyWithChanges:
                Label("Нужна корректировка взносов в цели", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            case .unsafe(let shortfall, let date):
                HStack(alignment: .top) {
                    Text("Прогнозный минимум ниже резерва\(date.map { " к \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "")")
                    Spacer()
                    SensitiveAmount(value: "−\(shortfall.formatted)").foregroundStyle(.red).fontWeight(.semibold)
                }
            case .insufficientData(let reason):
                Text(reason).font(.subheadline).foregroundStyle(.secondary)
            }
            if snapshot.forecastDailySpend == .zero {
                Text("Пока расчёт учитывает только внесённые платежи. Оценка обычных трат появится после достаточной истории операций.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppPalette.line, lineWidth: 1))
    }

    private func color(for level: PlanHealthLevel) -> Color {
        switch level {
        case .stable: .green
        case .adjustmentNeeded: .orange
        case .unsafe: .red
        case .insufficientData: .secondary
        }
    }
}

private struct SpendingAnalyticsCard: View {
    private enum Range: String, CaseIterable, Identifiable {
        case week = "Неделя"
        case month = "Месяц"
        case incomeCycle = "С поступления"
        case custom = "Даты"
        var id: String { rawValue }
    }

    @Query private var transactions: [StoredTransaction]
    let includedAccountIDs: Set<UUID>
    @State private var range: Range = .month
    @State private var customStartDate = Calendar.current.date(byAdding: .day, value: -29, to: .now) ?? .now
    @State private var customEndDate = Date.now
    @AppStorage("moneywise.hideAmounts") private var hideAmounts = false

    init(includedAccountIDs: Set<UUID>) {
        self.includedAccountIDs = includedAccountIDs
        let calendar = Calendar.current
        let lookbackStart = calendar.date(byAdding: .day, value: -120, to: calendar.startOfDay(for: .now)) ?? .distantPast
        _transactions = Query(
            filter: #Predicate<StoredTransaction> { $0.date >= lookbackStart },
            sort: \StoredTransaction.date,
            order: .forward
        )
    }

    private var incomePeriods: IncomeCyclePeriods? {
        SpendingAnalytics.incomeCyclePeriods(coreTransactions, asOf: .now)
    }

    private var earliestAnalyticsDate: Date {
        Calendar.current.date(byAdding: .day, value: -119, to: Calendar.current.startOfDay(for: .now)) ?? .distantPast
    }

    private var interval: DateInterval {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)
        let start: Date
        switch range {
        case .week:
            start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        case .month:
            start = calendar.dateInterval(of: .month, for: today)?.start ?? today
        case .incomeCycle:
            if let current = incomePeriods?.current { return current }
            start = today
        case .custom:
            start = calendar.startOfDay(for: customStartDate)
            let customEnd = calendar.startOfDay(for: customEndDate)
            let endExclusive = calendar.date(byAdding: .day, value: 1, to: customEnd) ?? customEnd.addingTimeInterval(86_400)
            return DateInterval(start: start, end: endExclusive)
        }
        return DateInterval(start: start, end: end)
    }

    private var previousInterval: DateInterval? {
        let calendar = Calendar.current
        let current = interval
        switch range {
        case .week:
            let end = current.start
            let start = calendar.date(byAdding: .day, value: -7, to: end) ?? end
            return DateInterval(start: start, end: end)
        case .month:
            return SpendingAnalytics.previousMonthToDateInterval(for: .now, calendar: calendar)
        case .incomeCycle:
            return incomePeriods?.previousComparable
        case .custom:
            return SpendingAnalytics.previousEqualLengthInterval(before: current,
                earliestAvailableDate: earliestAnalyticsDate, calendar: calendar)
        }
    }

    private var coreTransactions: [Transaction] {
        transactions.filter {
            ScheduledSettlementPolicy.sourceAccountIsIncluded($0.sourceAccountID,
                includedAccountIDs: includedAccountIDs)
        }.map {
            Transaction(id: $0.id, date: $0.date, merchant: $0.merchant, amount: $0.amount,
                        kind: $0.kind, category: $0.category, isInternalTransfer: $0.internalTransfer,
                        sourceID: $0.sourceID, status: $0.status,
                        providerTransactionID: $0.providerTransactionID,
                        refundOfProviderTransactionID: $0.refundOfProviderTransactionID,
                        refundOfTransactionID: $0.refundOfTransactionID)
        }
    }

    private var summary: SpendingAnalyticsSummary {
        SpendingAnalytics.summarize(coreTransactions, from: interval.start, to: interval.end, asOf: .now)
    }

    private var comparison: SpendingPeriodComparison? {
        guard let previousInterval else { return nil }
        return SpendingAnalytics.compare(coreTransactions, current: interval, previous: previousInterval, asOf: .now)
    }

    private var comparisonCaption: String? {
        if range == .incomeCycle && incomePeriods?.previousComparable == nil {
            return "Для сравнения добавь ещё одно поступление в историю."
        }
        if range == .custom && previousInterval == nil {
            return "В выбранной истории нет полного предыдущего периода для сравнения."
        }
        guard let comparison else { return nil }
        let reference: String
        switch range {
        case .week: reference = "предыдущими 7 днями"
        case .month: reference = "прошлым месяцем к этой дате"
        case .incomeCycle: reference = "сопоставимой частью предыдущего периода между поступлениями"
        case .custom: reference = "предыдущим периодом такой же длительности"
        }
        if comparison.difference.kopecks == 0 {
            return "Столько же, сколько за \(reference)"
        }
        let direction = comparison.difference.kopecks > 0 ? "больше" : "меньше"
        return "На \(Money(kopecks: abs(comparison.difference.kopecks)).formatted) \(direction), чем за \(reference)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Расходы").font(AppTypography.ui(21, weight: .semibold))
                Spacer()
                Picker("Период расходов", selection: $range) {
                    ForEach(Range.allCases) { option in Text(option.rawValue).tag(option) }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Период статистики расходов")
            }

            if range == .custom {
                VStack(alignment: .leading, spacing: 8) {
                    DatePicker("С", selection: $customStartDate,
                               in: earliestAnalyticsDate...customEndDate, displayedComponents: .date)
                    DatePicker("По", selection: $customEndDate,
                               in: customStartDate...Date.now, displayedComponents: .date)
                    Text("Можно выбрать даты за последние 120 дней.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if hideAmounts {
                Label("Статистика скрыта вместе с суммами", systemImage: "eye.slash")
                    .font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else if range == .incomeCycle && incomePeriods == nil {
                ContentUnavailableView("Не найдено поступление", systemImage: "arrow.down.left.circle",
                                       description: Text("Импортируй или добавь операцию поступления за последние 120 дней, чтобы построить период."))
                    .frame(minHeight: 150)
            } else if summary.transactionCount == 0 {
                ContentUnavailableView("Покупок за этот период нет", systemImage: "chart.bar",
                                       description: Text("Импортируй выписку или добавь расходы — здесь появится динамика."))
                    .frame(minHeight: 150)
                if let comparisonCaption {
                    Text(comparisonCaption).font(.caption).foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    Text("Потрачено").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    SensitiveAmount(value: summary.total.formatted).font(AppTypography.amount(20, weight: .bold))
                }
                if let comparisonCaption {
                    Text(comparisonCaption).font(.caption).foregroundStyle(.secondary)
                }

                Chart(summary.daily) { item in
                    BarMark(
                        x: .value("Дата", item.date, unit: .day),
                        y: .value("Расходы, ₽", NSDecimalNumber(decimal: item.amount.decimalRubles).doubleValue)
                    )
                    .foregroundStyle(AppPalette.accent)
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: range == .week ? 7 : (range == .incomeCycle ? 8 : (range == .custom ? 6 : 5)))) {
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) {
                        AxisGridLine()
                        AxisValueLabel(format: .currency(code: "RUB").precision(.fractionLength(0)))
                    }
                }
                .frame(height: 185)
                .accessibilityLabel("Расходы по дням за период: \(summary.total.formatted), \(summary.transactionCount) операций")

                if !summary.categories.isEmpty {
                    Text("По категориям").font(.subheadline.bold()).padding(.top, 2)
                    Chart(summary.categories) { item in
                        SectorMark(
                            angle: .value("Расходы", NSDecimalNumber(decimal: item.amount.decimalRubles).doubleValue),
                            innerRadius: .ratio(0.62),
                            angularInset: 1
                        )
                        .foregroundStyle(by: .value("Категория", item.category.title))
                    }
                    .chartLegend(.hidden)
                    .frame(height: 170)
                    .accessibilityLabel("Распределение расходов по категориям")

                    ForEach(summary.categories) { item in
                        HStack {
                            Text(item.category.title).lineLimit(1)
                            Spacer(minLength: 8)
                            Text("\(percentage(item.amount.kopecks, of: summary.total.kopecks))%")
                                .font(.caption).foregroundStyle(.secondary)
                            SensitiveAmount(value: item.amount.formatted).font(AppTypography.amount(15, weight: .medium))
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppPalette.line, lineWidth: 1))
    }

    private func percentage(_ amount: Int64, of total: Int64) -> Int {
        guard total > 0 else { return 0 }
        return Int((Double(amount) / Double(total) * 100).rounded())
    }
}

private struct TransactionRow: View {
    @Bindable var transaction: StoredTransaction
    var accountName: String? = nil
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(transaction.kind.isInflow ? .green : (transaction.kind == .adjustment ? .orange : .primary))
                .frame(width: 34, height: 34).background(.quaternary, in: Circle())
            VStack(alignment: .leading) {
                Text(transaction.merchant).font(AppTypography.detail(15, weight: .medium))
                Text(detailText)
                    .font(AppTypography.detail(12)).foregroundStyle(.secondary)
                if transaction.status == .pending {
                    Text("Ожидает проведения · пока не учитывается в прогнозе")
                        .font(.caption2).foregroundStyle(.orange)
                }
                if let refundID = transaction.refundOfProviderTransactionID {
                    Text("ID исходной операции: \(refundID)").font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                }
                if transaction.refundOfTransactionID != nil {
                    Text("Связано с исходной расходной операцией").font(.caption2).foregroundStyle(.tertiary)
                }
                if let accountName { Text(accountName).font(.caption2).foregroundStyle(.tertiary) }
                if transaction.originalMerchant != transaction.merchant,
                   transaction.sourceID != nil || transaction.providerTransactionID != nil {
                    Text("В выписке: \(transaction.originalMerchant)")
                        .font(.caption2).foregroundStyle(.tertiary).lineLimit(2)
                }
                if let note = transaction.note, !note.isEmpty {
                    Text(note).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer()
            SensitiveAmount(value: "\(amountPrefix)\(transaction.amount.formatted)").font(AppTypography.amount(15, weight: .semibold))
        }.padding(.vertical, 3)
    }

    private var iconName: String {
        switch transaction.kind {
        case .income, .incomingTransfer, .refund: "arrow.down.left"
        case .purchase, .transfer, .fee: "arrow.up.right"
        case .adjustment: "questionmark"
        }
    }

    private var detailText: String {
        if transaction.internalTransfer { return "Перевод между своими счетами" }
        switch transaction.kind {
        case .income: return transaction.incomeSource.rawValue
        case .incomingTransfer:
            return transaction.incomeSourceRaw == IncomeSource.parentSupport.rawValue
                ? "Поддержка от родителей · входящий перевод" : "Входящий перевод"
        case .refund: return "Возврат"
        case .adjustment: return "Направление не определено"
        case .purchase, .transfer, .fee: return transaction.category.title
        }
    }

    private var amountPrefix: String {
        if transaction.internalTransfer { return "↔" }
        if transaction.kind.isInflow { return "+" }
        if transaction.kind.isOutflow { return "−" }
        return ""
    }
}

private struct SensitiveAmount: View {
    @AppStorage("moneywise.hideAmounts") private var hidden = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: String
    var body: some View {
        Text(hidden ? "••••••" : value)
            .monospacedDigit()
            .contentTransition(reduceMotion ? .identity : .numericText())
            .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: hidden)
            .privacySensitive()
    }
}

private struct SaveFailureAlert: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.alert("Не удалось сохранить изменения", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("Понятно", role: .cancel) { message = nil }
        } message: {
            Text(message ?? "Изменения не подтверждены. Проверь свободное место и повтори попытку.")
        }
    }
}

private extension View {
    func saveFailureAlert(_ message: Binding<String?>) -> some View {
        modifier(SaveFailureAlert(message: message))
    }
}

private struct AddGoalView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var target = ""
    @State private var saved = "0"
    @State private var monthly = ""
    @State private var saveError: String?
    @State private var targetDate = Calendar.current.date(byAdding: .month, value: 6, to: .now) ?? .now
    var body: some View {
        Form {
            Section("Цель") {
                TextField("Например: новый телефон", text: $title)
                TextField("Сколько нужно, ₽", text: $target).keyboardType(.decimalPad)
                TextField("Уже накоплено, ₽", text: $saved).keyboardType(.decimalPad)
                TextField("Откладывать в месяц, ₽", text: $monthly).keyboardType(.decimalPad)
                DatePicker("Желаемая дата", selection: $targetDate, in: Date()..., displayedComponents: .date)
            }
            Section { Text("Регулярное пополнение цели учитывается как гибкий взнос. При нехватке денег приложение покажет, какой платёж можно перенести.").font(.footnote).foregroundStyle(.secondary) }
        }
        .navigationTitle("Новая цель")
        .saveFailureAlert($saveError)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Сохранить", action: save).disabled(title.isEmpty || target.isEmpty) } }
    }
    private func save() {
        guard let targetValue = Money.parseRubles(target), let savedValue = Money.parseRubles(saved),
              let monthlyValue = Money.parseRubles(monthly) else {
            saveError = "Проверь суммы: они должны быть числами в рублях и помещаться в точный денежный диапазон."
            return
        }
        let targetAmount = Money(rubles: targetValue), savedAmount = Money(rubles: savedValue), monthlyAmount = Money(rubles: monthlyValue)
        guard targetAmount > .zero, savedAmount >= .zero, monthlyAmount >= .zero else {
            saveError = "Цель должна быть больше нуля, а уже накопленная сумма и взнос не могут быть отрицательными."
            return
        }
        var plan: StoredPlanItem?
        if savedAmount < targetAmount && monthlyAmount > .zero,
           let firstDate = Calendar.current.date(byAdding: .month, value: 1, to: .now), firstDate <= targetDate {
            let count = GoalContributionPlan.occurrencesNeeded(target: targetAmount, saved: savedAmount,
                monthlyContribution: monthlyAmount, firstDate: firstDate, targetDate: targetDate)
            let finalAmount = GoalContributionPlan.finalContributionAmount(target: targetAmount, saved: savedAmount,
                monthlyContribution: monthlyAmount, occurrenceCount: count)
            let item = StoredPlanItem(title: "Цель: \(title)", amount: monthlyAmount, dueDate: firstDate,
                                      kind: .goalContribution, recurrence: .monthly, reminderDays: 0,
                                      occurrencesRemaining: count, finalOccurrenceAmount: finalAmount)
            context.insert(item); plan = item
        }
        context.insert(StoredGoal(title: title, target: targetAmount, saved: savedAmount,
                                  monthlyContribution: monthlyAmount, targetDate: targetDate, planItemID: plan?.id))
        do { try context.save(); dismiss() }
        catch { context.rollback(); saveError = error.localizedDescription }
    }
}

private struct EditGoalView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let goal: StoredGoal
    let plan: StoredPlanItem?
    @State private var title = ""
    @State private var target = ""
    @State private var saved = ""
    @State private var monthly = ""
    @State private var targetDate = Date()
    @State private var firstContributionDate = Date()
    @State private var saveError: String?

    var body: some View {
        Form {
            Section("Цель") {
                TextField("Название", text: $title)
                TextField("Нужно всего, ₽", text: $target).keyboardType(.decimalPad)
                TextField("Уже накоплено, ₽", text: $saved).keyboardType(.decimalPad)
                TextField("Откладывать в месяц, ₽", text: $monthly).keyboardType(.decimalPad)
                DatePicker("Желаемая дата", selection: $targetDate, in: Date()..., displayedComponents: .date)
                DatePicker("Следующий взнос", selection: $firstContributionDate, in: Date()..., displayedComponents: .date)
            }
            Section {
                Text("Обновляй сумму накоплений после фактического пополнения. План взносов пересчитывается при сохранении, а остаток цели отражается в резерве.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Изменить цель")
        .saveFailureAlert($saveError)
        .toolbar { ToolbarItem(placement: .confirmationAction) {
            Button("Сохранить", action: save).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } }
        .onAppear(perform: load)
    }

    private func load() {
        title = goal.title
        target = NSDecimalNumber(decimal: Money(kopecks: goal.targetKopecks).decimalRubles).stringValue
        saved = NSDecimalNumber(decimal: Money(kopecks: goal.savedKopecks).decimalRubles).stringValue
        monthly = NSDecimalNumber(decimal: Money(kopecks: goal.monthlyContributionKopecks).decimalRubles).stringValue
        targetDate = max(goal.targetDate, Calendar.current.startOfDay(for: .now))
        firstContributionDate = max(plan?.dueDate ?? (Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now),
                                    Calendar.current.startOfDay(for: .now))
    }

    private func save() {
        guard let targetValue = Money.parseRubles(target), let savedValue = Money.parseRubles(saved),
              let monthlyValue = Money.parseRubles(monthly) else {
            saveError = "Проверь суммы: они должны быть числами в рублях и помещаться в точный денежный диапазон."
            return
        }
        let targetAmount = Money(rubles: targetValue)
        let savedAmount = Money(rubles: savedValue)
        let monthlyAmount = Money(rubles: monthlyValue)
        guard targetAmount > .zero, savedAmount >= .zero, monthlyAmount >= .zero,
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            saveError = "Цель должна быть больше нуля, накопления и взнос не могут быть отрицательными, а названию нельзя быть пустым."
            return
        }

        let count = GoalContributionPlan.occurrencesNeeded(target: targetAmount, saved: savedAmount,
            monthlyContribution: monthlyAmount, firstDate: firstContributionDate, targetDate: targetDate)
        let finalAmount = GoalContributionPlan.finalContributionAmount(target: targetAmount, saved: savedAmount,
            monthlyContribution: monthlyAmount, occurrenceCount: count)
        if let plan {
            let proposedPlan = ScheduledItem(id: plan.id, title: "Цель: \(title)", amount: monthlyAmount,
                dueDate: firstContributionDate, isConfirmed: plan.isConfirmed, kind: .goalContribution,
                recurrence: .monthly, occurrencesRemaining: count, finalOccurrenceAmount: finalAmount)
            let canPreserveSettlements: Bool
            do { canPreserveSettlements = try canPreserveUpcomingSettlements(for: proposedPlan, in: context) }
            catch { saveError = error.localizedDescription; return }
            guard canPreserveSettlements else {
                saveError = "Изменение графика нарушит привязку уже подтверждённого будущего взноса. Сначала проверь или отвяжи эту операцию в истории."
                return
            }
        }
        do {
            try context.transaction {
                goal.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                goal.targetKopecks = targetAmount.kopecks
                goal.savedKopecks = savedAmount.kopecks
                goal.monthlyContributionKopecks = monthlyAmount.kopecks
                goal.targetDate = targetDate

                if let plan {
                    plan.title = "Цель: \(goal.title)"
                    plan.amountKopecks = monthlyAmount.kopecks
                    plan.dueDate = firstContributionDate
                    plan.kindRaw = ScheduledItem.Kind.goalContribution.rawValue
                    plan.recurrenceRaw = ScheduledItem.Recurrence.monthly.rawValue
                    plan.occurrencesRemaining = count
                    plan.finalOccurrenceKopecks = finalAmount?.kopecks
                } else if count > 0 {
                    let item = StoredPlanItem(title: "Цель: \(goal.title)", amount: monthlyAmount,
                        dueDate: firstContributionDate, kind: .goalContribution, recurrence: .monthly,
                        reminderDays: 0, occurrencesRemaining: count, finalOccurrenceAmount: finalAmount)
                    goal.planItemID = item.id
                    context.insert(item)
                }
            }
            dismiss()
        } catch {
            context.rollback()
            saveError = error.localizedDescription
        }
    }
}

private func balanceFreshnessLabel(for updatedAt: Date) -> String {
    guard updatedAt <= .now else { return "Проверьте дату подтверждения баланса" }
    guard FinanceDataFreshness.isFresh(updatedAt, asOf: .now) else {
        return "Устарел · подтверждён \(updatedAt.formatted(date: .abbreviated, time: .omitted))"
    }
    return "Подтверждён \(updatedAt.formatted(date: .abbreviated, time: .shortened))"
}

private func balanceFreshnessLabel(for updatedAt: Date?) -> String {
    guard let updatedAt else { return "Баланс не подтверждён" }
    return balanceFreshnessLabel(for: updatedAt)
}

private struct AddAccountView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var bank: BankName = .sber
    @State private var name = ""
    @State private var balance = ""
    @State private var saveError: String?
    var body: some View {
        NavigationStack {
            Form {
                Picker("Банк или тип средств", selection: $bank) { ForEach(BankName.allCases) { Text($0.rawValue).tag($0) } }
                TextField("Название счёта", text: $name)
                TextField("Баланс, ₽", text: $balance).keyboardType(.decimalPad)
                Text("Отрицательный баланс можно указать, если счёт в минусе или есть задолженность по карте.")
                    .font(.footnote).foregroundStyle(.secondary)
                Text(bank == .cash
                     ? "Укажи сумму наличных, которую проверил сейчас. Она будет учитываться отдельно от банковских счетов."
                     : "Ручной баланс счёта. Подключение API появится только для официально доступных интеграций.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .navigationTitle("Добавить счёт")
            .saveFailureAlert($saveError)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || balance.isEmpty)
                }
            }
        }
    }
    private func save() {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty, let value = Money.parseRubles(balance) else {
            saveError = "Укажи название счёта и корректный баланс в пределах точного денежного диапазона."
            return
        }
        context.insert(StoredAccount(bank: bank, name: normalizedName, balance: Money(rubles: value)))
        do { try context.save(); dismiss() }
        catch { context.rollback(); saveError = error.localizedDescription }
    }
}

private struct EditAccountView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let account: StoredAccount
    @State private var bank: BankName = .sber
    @State private var name = ""
    @State private var balance = ""
    @State private var balanceConfirmed = false
    @State private var included = true
    @State private var showDeleteAlert = false
    @State private var saveError: String?
    var body: some View {
        Form {
            Picker("Банк или тип средств", selection: $bank) {
                ForEach(BankName.allCases) { Text($0.rawValue).tag($0) }
            }
            TextField("Название", text: $name)
            TextField("Баланс, ₽", text: $balance).keyboardType(.decimalPad)
            Button(balanceConfirmed ? "Баланс подтверждён" : "Подтвердить баланс сейчас") {
                balanceConfirmed = true
            }
            Text("Изменение названия и настроек счёта не обновляет дату баланса.")
                .font(.footnote).foregroundStyle(.secondary)
            Text("Отрицательный баланс можно указать, если счёт в минусе или есть задолженность по карте.")
                .font(.footnote).foregroundStyle(.secondary)
            Toggle("Учитывать в общей сумме", isOn: $included)
            LabeledContent("Последнее обновление", value: account.updatedAt.formatted(date: .abbreviated, time: .shortened))
            Button("Удалить счёт", role: .destructive) { showDeleteAlert = true }
        }
        .navigationTitle("Изменить счёт")
        .saveFailureAlert($saveError)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { save() } } }
        .onAppear {
            bank = account.bank
            name = account.name
            balance = NSDecimalNumber(decimal: Money(kopecks: account.balanceKopecks).decimalRubles).stringValue
            included = account.included
        }
        .onChange(of: balance) { _, _ in balanceConfirmed = false }
        .confirmationDialog("Удалить счёт?", isPresented: $showDeleteAlert, titleVisibility: .visible) {
            Button("Отмена", role: .cancel) { }
            Button("Удалить", role: .destructive) {
                do {
                    let cleanup = try transferPairCleanup(forAccountID: account.id, in: context)
                    try context.transaction {
                        cleanup.transactions.forEach { $0.internalTransfer = false }
                        cleanup.pairs.forEach(context.delete)
                        context.delete(account)
                    }
                    dismiss()
                } catch { context.rollback(); saveError = error.localizedDescription }
            }
        } message: { Text("Операции импорта останутся в общей ленте. Без счёта они не будут участвовать в прогнозе и бюджетах.") }
    }
    private func save() {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty, let value = Money.parseRubles(balance) else {
            saveError = "Укажи название счёта и корректный баланс в пределах точного денежного диапазона."
            return
        }
        do {
            let updatedBalance = Money(rubles: value)
            let balanceChanged = account.balanceKopecks != updatedBalance.kopecks
            guard !BalanceUpdatePolicy.requiresConfirmation(valueChanged: balanceChanged,
                                                             explicitlyConfirmed: balanceConfirmed) else {
                saveError = "После изменения суммы проверь баланс счёта и подтверди его кнопкой выше."
                return
            }
            let cleanup = account.included && !included
                ? try transferPairCleanup(forAccountID: account.id, in: context)
                : TransferPairCleanup(pairs: [], transactions: [])
            try context.transaction {
                cleanup.transactions.forEach { $0.internalTransfer = false }
                cleanup.pairs.forEach(context.delete)
                account.bankRaw = bank.rawValue
                account.name = normalizedName
                account.balanceKopecks = updatedBalance.kopecks
                account.included = included
                account.updatedAt = BalanceUpdatePolicy.updatedAt(
                    previous: account.updatedAt, explicitlyConfirmed: balanceConfirmed, now: .now
                ) ?? account.updatedAt
            }
            dismiss()
        }
        catch { context.rollback(); saveError = error.localizedDescription }
    }
}

private struct ImportPreviewView: View {
    let transactions: [Transaction]
    let accounts: [StoredAccount]
    let existingStatuses: [String: TransactionStatus]
    let existingProviderTransactionsByAccount: [UUID: [ExistingProviderTransaction]]
    let onCancel: () -> Void
    let onConfirm: ([RecurringCandidate], UUID?, PreparedStatementImport) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRecurringIDs: Set<String> = []
    @State private var selectedAccountID: UUID?
    @State private var preparedImport: PreparedStatementImport?
    @State private var recurringCandidates: [RecurringCandidate] = []
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            List {
                Section("Счёт выписки") {
                    Picker("Привязать операции", selection: $selectedAccountID) {
                        Text("Не привязывать").tag(Optional<UUID>.none)
                        ForEach(accounts) { account in
                            Text("\(account.bank.rawValue) · \(account.name)").tag(Optional(account.id))
                        }
                    }
                    if selectedAccountID == nil {
                        Text("Без привязки повторный импорт из другого файла может создать дубликаты. Добавь счёт и выбери его, чтобы безопасно различать источники.")
                            .font(.footnote).foregroundStyle(.orange)
                    } else {
                        Text("Идентификаторы строк будут сформированы в контексте этого счёта. Совпадающие строки из повторной выписки пропустятся; отдельные одинаковые покупки внутри одного файла сохранятся.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Text("Импорт добавляет историю операций, но не меняет остаток и дату его проверки. После сверки выписки обнови баланс счёта отдельно.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if let selectedAccount = accounts.first(where: { $0.id == selectedAccountID }), !selectedAccount.included {
                        Text("Этот счёт выключен из общей суммы. Его операции сохранятся в истории, но не повлияют на прогноз и бюджеты.")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                }
                Section("Найдено операций: \(transactions.count)") {
                    ForEach(transactions.indices, id: \.self) { index in
                        let transaction = transactions[index]
                        HStack {
                            VStack(alignment: .leading) {
                                Text(transaction.merchant).lineLimit(1)
                                Text("\(transaction.date.formatted(date: .abbreviated, time: .omitted)) · \(transaction.category.title)")
                                    .font(.caption).foregroundStyle(.secondary)
                                if preparedImport?.duplicateIndexes.contains(index) == true {
                                    Text("Уже в истории · пропущу при импорте")
                                        .font(.caption2).foregroundStyle(.orange)
                                }
                                if transaction.status == .pending {
                                    Text("Ожидает проведения")
                                        .font(.caption2).foregroundStyle(.orange)
                                }
                                if let refundID = transaction.refundOfProviderTransactionID {
                                    Text("Ссылка возврата из выписки: \(refundID)")
                                        .font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                                }
                            }
                            Spacer()
                            SensitiveAmount(value: "\(transaction.kind.isInflow ? "+" : (transaction.kind.isOutflow ? "−" : ""))\(transaction.amount.formatted)")
                                .font(.subheadline.weight(.medium))
                        }
                    }
                }
                Section("Сводка импорта") {
                    if let preparedImport {
                        LabeledContent("Новые операции", value: "\(preparedImport.transactions.count)")
                        LabeledContent("Совпадения", value: "\(preparedImport.duplicateCount)")
                        LabeledContent("Статус обновится", value: "\(preparedImport.statusUpdates.count)")
                        // Count source rows, not only new rows: a duplicate pending row
                        // is still absent from the forecast until the bank posts it.
                        let pendingCount = transactions.filter { $0.status == .pending }.count
                        if pendingCount > 0 {
                            LabeledContent("Ожидают проведения в выписке", value: "\(pendingCount)")
                            Text("Эти строки пока не входят в прогноз, бюджеты и оценку обычных расходов. Импорт не обновляет остаток: сверь его с доступным балансом банка, особенно если банк уже учёл удержания.")
                                .font(.footnote).foregroundStyle(.orange)
                        }
                        Text(preparedImport.duplicateCount == 0 && preparedImport.statusUpdates.isEmpty
                             ? "Проверь список и подтверди импорт."
                             : "Совпавшие строки будут пропущены, кроме операций, которые теперь проведены: их статус обновится.")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else {
                        ProgressView("Проверяю повторные операции…")
                    }
                }
                if let preparedImport, !preparedImport.providerConflicts.isEmpty {
                    Section("Проверь изменения из банка") {
                        Text("ID совпал с операцией в истории, но сумма, дата, название или тип отличаются. Сохранённая запись не будет перезаписана.")
                            .font(.footnote).foregroundStyle(.orange)
                        ForEach(preparedImport.providerConflicts) { conflict in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Банковский ID: \(conflict.providerTransactionID)")
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                Text("В истории · \(conflict.existingMerchant)")
                                    .font(.subheadline.weight(.medium)).lineLimit(1)
                                Text("\(conflict.existingDate.formatted(date: .abbreviated, time: .omitted)) · \(operationKindTitle(conflict.existingKind))")
                                    .font(.caption).foregroundStyle(.secondary)
                                SensitiveAmount(value: conflict.existingAmount.formatted).font(AppTypography.amount(12))
                                Text("В выписке · \(conflict.importedMerchant)")
                                    .font(.subheadline.weight(.medium)).lineLimit(1)
                                Text("\(conflict.importedDate.formatted(date: .abbreviated, time: .omitted)) · \(operationKindTitle(conflict.importedKind))")
                                    .font(.caption).foregroundStyle(.secondary)
                                SensitiveAmount(value: conflict.importedAmount.formatted).font(AppTypography.amount(12))
                            }
                            .padding(.vertical, 4)
                        }
                        Text("Импортируй остальные новые строки, затем проверь эту операцию во вкладке «Операции» и исправь её вручную, если банк действительно изменил данные.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if !recurringCandidates.isEmpty {
                    Section("Похожие на регулярные траты") {
                        ForEach(recurringCandidates) { candidate in
                            Toggle(isOn: Binding(
                                get: { selectedRecurringIDs.contains(candidate.id) },
                                set: { selected in
                                    if selected { selectedRecurringIDs.insert(candidate.id) }
                                    else { selectedRecurringIDs.remove(candidate.id) }
                                }
                            )) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(candidate.title)
                                    Text("≈ \(candidate.amount.formatted) · \(candidate.recurrence == .weekly ? "еженедельно" : "ежемесячно") · следующая дата \(candidate.nextDate.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption).foregroundStyle(.secondary)
                                    Text("Предложение по истории. Проверь перед добавлением в план.")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Предпросмотр выписки")
            .onChange(of: selectedAccountID) { _, _ in
                preparedImport = nil
                recurringCandidates = []
                selectedRecurringIDs = []
            }
            .task(id: selectedAccountID) {
                let sourceNamespace = selectedAccountID.map { "account:\($0.uuidString)" }
                let rows = transactions
                let knownStatuses = existingStatuses
                let knownProviderTransactions = selectedAccountID.flatMap {
                    existingProviderTransactionsByAccount[$0]
                } ?? []
                let result = await Task.detached(priority: .userInitiated) {
                    let plan = CSVStatementImporter().prepareImport(rows, sourceNamespace: sourceNamespace,
                        existingStatuses: knownStatuses,
                        existingProviderTransactions: knownProviderTransactions)
                    return (plan: plan, candidates: RecurringDetector().detect(plan.transactions))
                }.value
                guard !Task.isCancelled else { return }
                preparedImport = result.plan
                recurringCandidates = result.candidates
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { onCancel(); dismiss() }.disabled(isImporting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isImporting ? "Сохраняю…" : "Импортировать") {
                        guard let preparedImport, !isImporting else { return }
                        isImporting = true
                        Task { @MainActor in
                            let imported = await onConfirm(
                                recurringCandidates.filter { selectedRecurringIDs.contains($0.id) },
                                selectedAccountID, preparedImport)
                            isImporting = false
                            if imported { dismiss() }
                        }
                    }
                    .disabled(preparedImport == nil || isImporting)
                }
            }
        }
    }

    private func operationKindTitle(_ kind: TransactionKind) -> String {
        switch kind {
        case .purchase: "Покупка"
        case .income: "Доход"
        case .transfer: "Исходящий перевод"
        case .incomingTransfer: "Входящий перевод"
        case .refund: "Возврат"
        case .fee: "Комиссия"
        case .adjustment: "Корректировка"
        }
    }
}

private struct AddTransactionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var merchant = ""
    @State private var amount = ""
    @State private var kind: TransactionKind = .purchase
    @State private var category: Category = .other
    @State private var internalTransfer = false
    @State private var incomeSource: IncomeSource = .other
    @State private var note = ""
    @State private var date = Date()
    @State private var saveError: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Операция") {
                    TextField("Название", text: $merchant)
                    TextField("Сумма, ₽", text: $amount).keyboardType(.decimalPad)
                    Picker("Тип", selection: $kind) {
                        Text("Покупка").tag(TransactionKind.purchase)
                        Text("Доход").tag(TransactionKind.income)
                        Text("Перевод").tag(TransactionKind.transfer)
                        Text("Входящий перевод").tag(TransactionKind.incomingTransfer)
                        Text("Возврат").tag(TransactionKind.refund)
                        Text("Комиссия").tag(TransactionKind.fee)
                    }
                    if kind == .purchase {
                        Picker("Категория", selection: $category) {
                            ForEach(Category.allCases.filter(\.supportsPurchaseClassification), id: \.self) {
                                Text($0.title).tag($0)
                            }
                        }
                    } else {
                        LabeledContent("Категория", value: category.title)
                    }
                    if kind == .transfer || kind == .incomingTransfer {
                        Toggle("Перевод между моими счетами", isOn: $internalTransfer)
                        Text("Включай только для перевода между своими счетами. Перевод другому человеку считается расходом.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if kind == .income || kind == .incomingTransfer {
                        Picker(kind == .income ? "Источник дохода" : "Источник перевода", selection: $incomeSource) {
                            ForEach(IncomeSource.allCases) { Text($0.rawValue).tag($0) }
                        }
                        if kind == .incomingTransfer {
                            Text("Источник помогает отличать поддержку от родителей от других переводов; поступление останется переводом, а не заработанным доходом.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    DatePicker("Дата", selection: $date, displayedComponents: .date)
                    TextField("Комментарий", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .onChange(of: kind) { _, newKind in
                internalTransfer = false
                if newKind == .income || newKind == .incomingTransfer {
                    incomeSource = IncomeSource.infer(from: merchant) ?? .other
                }
                if let defaultCategory = newKind.defaultCategory {
                    category = defaultCategory
                } else if !category.supportsPurchaseClassification {
                    category = .other
                }
            }
            .onChange(of: category) { _, newCategory in
                if newCategory != .transfers { internalTransfer = false }
            }
            .navigationTitle("Добавить операцию")
            .saveFailureAlert($saveError)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Сохранить", action: save).disabled(merchant.isEmpty || amount.isEmpty) }
            }
        }
    }
    private func save() {
        guard let rubles = Money.parseRubles(amount), rubles > 0 else {
            saveError = "Сумма операции должна быть корректным положительным числом в пределах точного денежного диапазона."
            return
        }
        let safeCategory = kind == .purchase && !category.supportsPurchaseClassification ? .other : category
        context.insert(StoredTransaction(Transaction(date: date, merchant: merchant,
            amount: Money(rubles: rubles), kind: kind, category: safeCategory,
            incomeSource: kind == .income || kind == .incomingTransfer ? incomeSource : nil,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            isInternalTransfer: internalTransfer)))
        do { try context.save(); dismiss() }
        catch { context.rollback(); saveError = error.localizedDescription }
    }
}

private struct TransferMatchSuggestion: Identifiable {
    let candidate: InternalTransferCandidate
    let counterpart: StoredTransaction
    var id: UUID { counterpart.id }
}

private struct EditTransactionView: View {
    private static let transferCandidateSafetyLimit = 100
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let transaction: StoredTransaction
    let accounts: [StoredAccount]
    @Query private var nearbyTransfers: [StoredTransaction]
    @Query private var planItems: [StoredPlanItem]
    @Query private var settlementTransactions: [StoredTransaction]
    @Query private var settingsRows: [StoredSettings]
    @State private var draft: Transaction
    @State private var amountText: String
    @State private var originalCategoryRaw: String
    @State private var applyCategoryToFuture = false
    @State private var pendingTransferCounterpartID: UUID?
    @State private var selectedPlanItemID: UUID?
    @State private var settlementOccurrenceDate: Date
    @State private var saveError: String?

    init(transaction: StoredTransaction, accounts: [StoredAccount]) {
        self.transaction = transaction
        self.accounts = accounts
        let oppositeKind: TransactionKind? = switch transaction.kind {
        case .transfer: .incomingTransfer
        case .incomingTransfer: .transfer
        default: nil
        }
        let oppositeKindRaw = oppositeKind?.rawValue ?? ""
        let amountKopecks = transaction.amountKopecks
        let earliest = transaction.date.addingTimeInterval(-InternalTransferMatcher.defaultWindow)
        let latest = transaction.date.addingTimeInterval(InternalTransferMatcher.defaultWindow)
        var descriptor = FetchDescriptor<StoredTransaction>(
            predicate: #Predicate<StoredTransaction> { row in
                row.kindRaw == oppositeKindRaw && row.amountKopecks == amountKopecks &&
                row.date >= earliest && row.date <= latest
            },
            sortBy: [SortDescriptor(\.date)]
        )
        // Fetch one extra row to detect truncation; never present a partial candidate
        // list as if it represented all possible transfer matches.
        descriptor.fetchLimit = Self.transferCandidateSafetyLimit + 1
        _nearbyTransfers = Query(descriptor)
        let plansDescriptor = FetchDescriptor<StoredPlanItem>(sortBy: [SortDescriptor(\.dueDate)])
        _planItems = Query(plansDescriptor)
        _settlementTransactions = Query(
            filter: #Predicate<StoredTransaction> { $0.scheduledPlanItemID != nil },
            sort: \StoredTransaction.date,
            order: .reverse
        )
        _selectedPlanItemID = State(initialValue: transaction.scheduledPlanItemID)
        _settlementOccurrenceDate = State(initialValue: transaction.scheduledOccurrenceDate ?? transaction.date)
        _draft = State(initialValue: Transaction(
            id: transaction.id, date: transaction.date, merchant: transaction.merchant,
            amount: transaction.amount, kind: transaction.kind,
            category: transaction.kind == .purchase && !transaction.category.supportsPurchaseClassification ? .other : transaction.category,
            incomeSource: transaction.kind == .income ? transaction.incomeSource :
                (transaction.kind == .incomingTransfer && !transaction.incomeSourceRaw.isEmpty ? transaction.incomeSource : nil),
            note: transaction.note ?? "",
            isInternalTransfer: transaction.internalTransfer, sourceID: transaction.sourceID
        ))
        _amountText = State(initialValue: NSDecimalNumber(decimal: transaction.amount.decimalRubles).stringValue)
        _originalCategoryRaw = State(initialValue: transaction.categoryRaw)
    }

    var body: some View {
        Form {
            Section("Операция") {
                TextField("Название", text: $draft.merchant)
                if transaction.originalMerchant != transaction.merchant,
                   transaction.sourceID != nil || transaction.providerTransactionID != nil {
                    LabeledContent("Исходное описание выписки", value: transaction.originalMerchant)
                }
                Picker("Тип", selection: Binding(get: { draft.kind }, set: updateKind)) {
                    Text("Покупка или расход").tag(TransactionKind.purchase)
                    Text("Доход").tag(TransactionKind.income)
                    Text("Перевод другому или между счетами").tag(TransactionKind.transfer)
                    Text("Входящий перевод").tag(TransactionKind.incomingTransfer)
                    Text("Возврат").tag(TransactionKind.refund)
                    Text("Комиссия").tag(TransactionKind.fee)
                    if draft.kind == .adjustment {
                        Text("Корректировка (сохранённый тип)").tag(TransactionKind.adjustment).disabled(true)
                    }
                }

                if draft.kind == .purchase {
                    Picker("Категория", selection: Binding(get: { draft.category }, set: updateCategory)) {
                        ForEach(Category.allCases.filter(\.supportsPurchaseClassification), id: \.self) {
                            Text($0.title).tag($0)
                        }
                    }
                } else {
                    LabeledContent("Категория", value: draft.category.title)
                }

                if draft.kind == .income || draft.kind == .incomingTransfer {
                    Picker(draft.kind == .income ? "Источник дохода" : "Источник перевода", selection: Binding(
                        get: { draft.incomeSource ?? .other },
                        set: { draft.incomeSource = $0 }
                    )) {
                        ForEach(IncomeSource.allCases) { Text($0.rawValue).tag($0) }
                    }
                    if draft.kind == .incomingTransfer {
                        Text("Перевод сохранится как перевод; источник не прибавляет его к заработанному доходу.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if draft.kind == .transfer || draft.kind == .incomingTransfer || draft.isInternalTransfer ||
                    (draft.kind == .purchase && draft.category == .transfers) {
                    Toggle("Перевод между моими счетами", isOn: $draft.isInternalTransfer)
                    Text("Отметь только если деньги переместились между твоими счетами. Перевод другому человеку остаётся расходом.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if draft.kind == .adjustment {
                    Text("У этой операции неизвестно направление. Она не входит в аналитику расходов и доходов.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                TextField("Сумма, ₽", text: $amountText)
                    .keyboardType(.decimalPad)
                    .disabled(transaction.internalTransfer && draft.isInternalTransfer)
                    .onChange(of: amountText) { _, value in
                        if let rubles = Money.parseRubles(value), rubles > 0 {
                            draft.amount = Money(rubles: rubles)
                        }
                    }
                if transaction.internalTransfer && draft.isInternalTransfer {
                    Text("Чтобы исправить сумму, сначала отключи «Перевод между моими счетами». Обе операции вернутся в обычный учёт.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if draft.kind == transaction.kind && draft.date == transaction.date && draft.amount == transaction.amount,
                   transferMatchCandidatesExceededLimit || !transferMatchSuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        if transferMatchCandidatesExceededLimit {
                            Label("Найдено слишком много похожих операций. Сократил список ради скорости и не показываю частичные совпадения: проверь перевод вручную.",
                                  systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote).foregroundStyle(.orange)
                        } else {
                            Text("Возможная пара переводов")
                                .font(.headline)
                            Text("Совпали точная сумма и близкая дата в выписках разных счетов. Проверь получателя и подтверди только если это перевод между твоими счетами.")
                                .font(.footnote).foregroundStyle(.secondary)
                            ForEach(transferMatchSuggestions) { suggestion in
                                Button {
                                    pendingTransferCounterpartID = suggestion.counterpart.id
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(accountLabel(suggestion.counterpart)) · \(suggestion.counterpart.merchant)")
                                            .foregroundStyle(.primary)
                                        Text("\(suggestion.counterpart.date.formatted(date: .abbreviated, time: .shortened)) · \(suggestion.counterpart.amount.formatted)")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                .disabled(suggestion.counterpart.internalTransfer)
                            }
                        }
                    }
                }
                DatePicker("Дата", selection: $draft.date, displayedComponents: .date)
                TextField("Комментарий", text: $draft.note, axis: .vertical)
                    .lineLimit(2...4)
            }
            Section("Связать с планом") {
                Picker("Плановый платёж", selection: $selectedPlanItemID) {
                    Text("Не связывать").tag(UUID?.none)
                    ForEach(planItems) { plan in
                        Text("\(plan.title) · \(Money(kopecks: plan.amountKopecks).formatted)")
                            .tag(Optional(plan.id))
                    }
                }
                if let selectedPlan = selectedPlanItem {
                    DatePicker("Вхождение плана", selection: $settlementOccurrenceDate,
                               displayedComponents: .date)
                    if !ScheduledRecurrence.isOccurrence(settlementOccurrenceDate, of: selectedPlan.scheduled) {
                        Label("Эта дата не входит в расписание платежа.", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                    Text("Связь изменит прогноз только если операция проведена, дата входит в расписание и баланс подтверждён после операции.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if settlementBalanceUpdatedAt.map({ $0 >= draft.date }) != true {
                        Label("Сначала обнови баланс счёта после этой операции.", systemImage: "arrow.clockwise.circle")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                    let isDebtReceipt = selectedPlan.scheduled.kind == .debtCollection &&
                        (draft.kind == .income || draft.kind == .incomingTransfer)
                    if transaction.status != .posted || (!draft.kind.isOutflow && !isDebtReceipt) || draft.isInternalTransfer {
                        Label("Свяжи проведённый внешний платёж или возврат соответствующего типа.", systemImage: "info.circle")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            if draft.kind == .purchase && draft.category.rawValue != originalCategoryRaw {
                Section("Правило для будущих операций") {
                    Toggle("Запомнить категорию для этого получателя", isOn: $applyCategoryToFuture)
                    Text("Правило применяется только к будущим импортированным операциям с таким же названием.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Изменить операцию")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово", action: save) } }
        .alert("Не удалось сохранить операцию", isPresented: Binding(
            get: { saveError != nil }, set: { if !$0 { saveError = nil } }
        )) {
            Button("Понятно", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "") }
        .confirmationDialog("Подтвердить перевод между своими счетами?", isPresented: Binding(
            get: { pendingTransferCounterpartID != nil },
            set: { if !$0 { pendingTransferCounterpartID = nil } }
        ), titleVisibility: .visible) {
            Button("Пометить обе операции как внутренний перевод", action: confirmTransferPair)
            Button("Отмена", role: .cancel) { pendingTransferCounterpartID = nil }
        } message: {
            Text("Обе операции перестанут учитываться как доход и расход. Делай это только если деньги переместились между твоими счетами.")
        }
    }

    private var transferMatchSuggestions: [TransferMatchSuggestion] {
        guard let accountID = transaction.sourceAccountID,
              let currentAccount = accounts.first(where: { $0.id == accountID }), currentAccount.included,
              (transaction.kind == .transfer || transaction.kind == .incomingTransfer),
              !transferMatchCandidatesExceededLimit else { return [] }
        let records = [transaction] + nearbyTransfers.filter { row in
            guard let rowAccountID = row.sourceAccountID, rowAccountID != accountID,
                  accounts.contains(where: { $0.id == rowAccountID && $0.included }), !row.internalTransfer else { return false }
            return true
        }
        let matches = InternalTransferMatcher.candidates(among: records.map {
            TransferMatchRecord(id: $0.id, accountID: $0.sourceAccountID,
                                accountIncluded: $0.sourceAccountID.flatMap { id in accounts.first(where: { $0.id == id })?.included } ?? false,
                                date: $0.date,
                                amount: $0.amount, kind: $0.kind)
        })
        let matchesForCurrent = matches.filter { $0.outgoingID == transaction.id || $0.incomingID == transaction.id }
        let counterpartIDs = Set(matchesForCurrent.map { match in
            match.outgoingID == transaction.id ? match.incomingID : match.outgoingID
        })
        return matchesForCurrent.compactMap { match in
            let id = match.outgoingID == transaction.id ? match.incomingID : match.outgoingID
            guard counterpartIDs.contains(id), let row = nearbyTransfers.first(where: { $0.id == id }) else { return nil }
            return TransferMatchSuggestion(candidate: match, counterpart: row)
        }
    }

    private var transferMatchCandidatesExceededLimit: Bool {
        guard let accountID = transaction.sourceAccountID,
              accounts.contains(where: { $0.id == accountID && $0.included }),
              transaction.kind == .transfer || transaction.kind == .incomingTransfer else { return false }
        return nearbyTransfers.count > Self.transferCandidateSafetyLimit
    }

    private var selectedPlanItem: StoredPlanItem? {
        guard let selectedPlanItemID else { return nil }
        return planItems.first { $0.id == selectedPlanItemID }
    }

    private var settlementBalanceUpdatedAt: Date? {
        settlementBalanceTimestamp(sourceAccountID: transaction.sourceAccountID, accounts: accounts,
            manualBalanceUpdatedAt: settingsRows.first?.updatedAt)
    }

    private func accountLabel(_ row: StoredTransaction) -> String {
        guard let id = row.sourceAccountID,
              let account = accounts.first(where: { $0.id == id }) else { return "Другой счёт" }
        return "\(account.bank.rawValue) · \(account.name)"
    }

    private func confirmTransferPair() {
        defer { pendingTransferCounterpartID = nil }
        guard let id = pendingTransferCounterpartID,
              let counterpart = nearbyTransfers.first(where: { $0.id == id }),
              transferMatchSuggestions.contains(where: { $0.counterpart.id == id }) else {
            saveError = "Совпадающая операция больше недоступна. Обнови экран и проверь выписки снова."
            return
        }
        do {
            guard try storedTransferPair(for: transaction.id, in: context) == nil,
                  try storedTransferPair(for: counterpart.id, in: context) == nil else {
                saveError = "Одна из операций уже связана с другим переводом. Обнови экран и проверь её отдельно."
                return
            }
            let outgoingID = transaction.kind == .transfer ? transaction.id : counterpart.id
            let incomingID = transaction.kind == .incomingTransfer ? transaction.id : counterpart.id
            try context.transaction {
                context.insert(StoredInternalTransferPair(outgoingTransactionID: outgoingID,
                                                          incomingTransactionID: incomingID))
                transaction.internalTransfer = true
                counterpart.internalTransfer = true
            }
            draft.isInternalTransfer = true
        } catch {
            context.rollback()
            saveError = error.localizedDescription
        }
    }

    private func updateKind(_ kind: TransactionKind) {
        guard kind != .adjustment else { return }
        draft.kind = kind
        draft.isInternalTransfer = false
        draft.incomeSource = kind == .income || kind == .incomingTransfer
            ? (IncomeSource.infer(from: draft.merchant) ?? .other) : nil
        applyCategoryToFuture = false
        if let defaultCategory = kind.defaultCategory {
            draft.category = defaultCategory
        } else if !draft.category.supportsPurchaseClassification {
            draft.category = .other
        }
    }

    private func updateCategory(_ category: Category) {
        draft.category = category
        if category != .transfers { draft.isInternalTransfer = false }
        applyCategoryToFuture = category.rawValue != originalCategoryRaw
    }

    private func save() {
        guard !draft.merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            saveError = "Укажи название операции."
            return
        }
        guard let rubles = Money.parseRubles(amountText), rubles > 0 else {
            saveError = "Сумма операции должна быть корректной положительной суммой с точностью до копейки."
            return
        }
        draft.amount = Money(rubles: rubles)
        var newSettlement: ScheduledSettlement?
        if let selectedPlanItemID {
            guard let plan = planItems.first(where: { $0.id == selectedPlanItemID }) else {
                saveError = "Выбранный план больше недоступен. Обнови экран и выбери другой план."
                return
            }
            guard ScheduledRecurrence.isOccurrence(settlementOccurrenceDate, of: plan.scheduled) else {
                saveError = "Выбранная дата не входит в расписание плана."
                return
            }
            guard let balanceDate = settlementBalanceUpdatedAt, balanceDate >= draft.date else {
                saveError = "Сначала обнови баланс счёта после этой операции, затем подтверди оплату."
                return
            }
            var settlementTransaction = draft
            settlementTransaction.status = transaction.status
            let existingSettlements = validatedScheduledSettlements(transactions: settlementTransactions,
                plans: planItems, accounts: accounts, settings: settingsRows.first,
                excludingTransactionID: transaction.id)
            guard let settlement = ScheduledSettlementPolicy.makeSettlement(
                transaction: settlementTransaction, item: plan.scheduled,
                occurrenceDate: settlementOccurrenceDate, settlements: existingSettlements) else {
                saveError = "Эту операцию нельзя связать с планом: проверь статус, направление и оставшуюся сумму платежа."
                return
            }
            newSettlement = settlement
        }
        do {
            let confirmedPair = try storedTransferPair(for: transaction.id, in: context)
            let counterpartID = confirmedPair.map {
                $0.outgoingTransactionID == transaction.id ? $0.incomingTransactionID : $0.outgoingTransactionID
            }
            let confirmedCounterpart = try counterpartID.flatMap { try storedTransaction(for: $0, in: context) }
            let transactionID = transaction.id
            let linkedRefunds = try context.fetch(FetchDescriptor<StoredTransaction>(
                predicate: #Predicate { $0.refundOfTransactionID == transactionID }
            ))
            let original = Transaction(date: transaction.date, merchant: transaction.merchant,
                amount: transaction.amount, kind: transaction.kind, category: transaction.category,
                note: transaction.note ?? "",
                isInternalTransfer: transaction.internalTransfer, sourceID: transaction.sourceID,
                status: transaction.status, providerTransactionID: transaction.providerTransactionID,
                refundOfProviderTransactionID: transaction.refundOfProviderTransactionID,
                refundOfTransactionID: transaction.refundOfTransactionID)
            let breaksConfirmedPair = confirmedPair != nil &&
                InternalTransferPairPolicy.shouldDetach(original: original, edited: draft)
            if breaksConfirmedPair { draft.isInternalTransfer = false }
            try context.transaction {
                if breaksConfirmedPair {
                    confirmedCounterpart?.internalTransfer = false
                    if let confirmedPair { context.delete(confirmedPair) }
                }
                if !draft.kind.isOutflow || draft.isInternalTransfer {
                    linkedRefunds.forEach { $0.refundOfTransactionID = nil }
                }
                transaction.merchant = draft.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanedNote = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
                transaction.note = cleanedNote.isEmpty ? nil : cleanedNote
                transaction.date = draft.date
                transaction.amountKopecks = draft.amount.kopecks
                transaction.kindRaw = draft.kind.rawValue
                transaction.categoryRaw = draft.category.rawValue
                transaction.incomeSourceRaw = draft.kind == .income || draft.kind == .incomingTransfer
                    ? (draft.incomeSource ?? .other).rawValue : ""
                transaction.internalTransfer = draft.isInternalTransfer
                if draft.kind != .refund { transaction.refundOfTransactionID = nil }
                transaction.scheduledPlanItemID = newSettlement?.scheduledItemID
                transaction.scheduledOccurrenceDate = newSettlement?.occurrenceDate

                if applyCategoryToFuture && draft.kind == .purchase {
                    let key = normalizedMerchantKey(draft.merchant)
                    if !key.isEmpty {
                        let rules = try context.fetch(FetchDescriptor<StoredMerchantRule>())
                        let matchingRules = rules.filter { $0.merchantKey == key }
                        if let existing = matchingRules.max(by: {
                            if $0.updatedAt != $1.updatedAt { return $0.updatedAt < $1.updatedAt }
                            return $0.categoryRaw < $1.categoryRaw
                        }) {
                            existing.categoryRaw = draft.category.rawValue
                            existing.updatedAt = .now
                            matchingRules.filter { $0 !== existing }.forEach(context.delete)
                        } else {
                            context.insert(StoredMerchantRule(merchantKey: key, category: draft.category))
                        }
                    }
                }
            }
            dismiss()
        } catch {
            context.rollback()
            saveError = error.localizedDescription
        }
    }
}

private struct EditPlanItemView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let item: StoredPlanItem
    @State private var title = ""
    @State private var amount = ""
    @State private var dueDate = Date()
    @State private var kind: ScheduledItem.Kind = .obligation
    @State private var confirmedInForecast = true
    @State private var recurrence: ScheduledItem.Recurrence = .none
    @State private var reminderDays = 0
    @State private var storedKindWasUnrecognized = false
    @State private var storedRecurrenceWasUnrecognized = false
    @State private var userChoseKind = false
    @State private var userChoseRecurrence = false
    @State private var saveError: String?
    var body: some View {
        Form {
            TextField("Название", text: $title)
            TextField("Сумма, ₽", text: $amount).keyboardType(.decimalPad)
            DatePicker("Дата", selection: $dueDate, displayedComponents: .date)
            Picker("Тип", selection: Binding(get: { kind }, set: { value in
                kind = value
                userChoseKind = true
                confirmedInForecast = value != .debtCollection
            })) {
                Text("Обязательство").tag(ScheduledItem.Kind.obligation)
                Text("Взнос в цель").tag(ScheduledItem.Kind.goalContribution)
                Text("Возврат долга").tag(ScheduledItem.Kind.debtRepayment)
                Text("Ожидаемый возврат долга").tag(ScheduledItem.Kind.debtCollection)
                Text("Подписка").tag(ScheduledItem.Kind.subscription)
            }
            if kind == .debtCollection {
                Toggle("Подтверждено для прогноза", isOn: $confirmedInForecast)
                Text("Не включай ожидаемый возврат в расчёт, пока дата поступления не согласована.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if storedKindWasUnrecognized {
                Text("Сохранённый тип не распознан. Выбери подходящий тип вручную, чтобы исправить план.")
                    .font(.footnote).foregroundStyle(.orange)
            }
            Picker("Повтор", selection: Binding(get: { recurrence }, set: { recurrence = $0; userChoseRecurrence = true })) {
                Text("Один раз").tag(ScheduledItem.Recurrence.none)
                Text("Каждую неделю").tag(ScheduledItem.Recurrence.weekly)
                Text("Каждый месяц").tag(ScheduledItem.Recurrence.monthly)
                Text("Каждый год").tag(ScheduledItem.Recurrence.yearly)
            }
            if storedRecurrenceWasUnrecognized {
                Text("Периодичность сохранённого плана не распознана. Выбери подходящий повтор вручную.")
                    .font(.footnote).foregroundStyle(.orange)
            }
            Picker("Напомнить заранее", selection: $reminderDays) {
                Text("Не напоминать").tag(0)
                Text("За день").tag(1)
                Text("За два дня").tag(2)
            }
        }
        .navigationTitle("Изменить план")
        .saveFailureAlert($saveError)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Сохранить") {
            guard (!storedKindWasUnrecognized || userChoseKind) &&
                  (!storedRecurrenceWasUnrecognized || userChoseRecurrence) else {
                saveError = "Выбери распознанный тип и периодичность плана, чтобы сохранить исправление."
                return
            }
            let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedTitle.isEmpty, let value = Money.parseRubles(amount), value > 0 else {
                saveError = "Укажи название и корректную положительную сумму в пределах точного денежного диапазона."
                return
            }
            let proposedPlan = ScheduledItem(id: item.id, title: normalizedTitle,
                amount: Money(rubles: value), dueDate: dueDate,
                isConfirmed: kind == .debtCollection ? confirmedInForecast : item.isConfirmed,
                kind: kind, recurrence: recurrence, occurrencesRemaining: item.occurrencesRemaining)
            let canPreserveSettlements: Bool
            do { canPreserveSettlements = try canPreserveUpcomingSettlements(for: proposedPlan, in: context) }
            catch { saveError = error.localizedDescription; return }
            guard canPreserveSettlements else {
                saveError = "Изменение нарушит привязку уже подтверждённого будущего платежа. Сначала проверь или отвяжи эту операцию в истории."
                return
            }
            do {
                try context.transaction {
                    item.title = normalizedTitle
                    item.amountKopecks = Money(rubles: value).kopecks
                    item.finalOccurrenceKopecks = nil
                    item.dueDate = dueDate
                    item.kindRaw = kind.rawValue
                    item.isConfirmed = kind == .debtCollection ? confirmedInForecast : item.isConfirmed
                    item.recurrenceRaw = recurrence.rawValue
                    item.reminderDays = reminderDays
                }
                dismiss()
            } catch {
                context.rollback()
                saveError = error.localizedDescription
            }
        } } }
        .onAppear {
            title = item.title
            amount = NSDecimalNumber(decimal: Money(kopecks: item.amountKopecks).decimalRubles).stringValue
            dueDate = item.dueDate
            let storedKind = ScheduledItem.Kind(rawValue: item.kindRaw)
            let storedRecurrence = ScheduledItem.Recurrence(rawValue: item.recurrenceRaw)
            storedKindWasUnrecognized = storedKind == nil
            storedRecurrenceWasUnrecognized = storedRecurrence == nil
            kind = storedKind ?? .obligation
            confirmedInForecast = item.isConfirmed
            recurrence = storedRecurrence ?? .none
            reminderDays = item.reminderDays
        }
    }
}

private struct AddBudgetView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var budgets: [StoredBudget]
    @State private var category: Category = .groceries
    @State private var amount = ""
    @State private var saveError: String?
    private var currentMonthStart: Date {
        Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    }
    private var matchingBudgets: [StoredBudget] {
        guard let month = Calendar.current.dateInterval(of: .month, for: currentMonthStart) else { return [] }
        return budgets.filter { $0.category == category && month.contains($0.periodStart) }
    }
    var body: some View {
        Form {
            Picker("Категория", selection: $category) {
                ForEach(Category.allCases.filter(\.supportsPurchaseClassification)) { Text($0.title).tag($0) }
            }
            TextField("Лимит на месяц, ₽", text: $amount).keyboardType(.decimalPad)
            if !matchingBudgets.isEmpty {
                Text("Для этой категории уже есть бюджет. Сохранение заменит его лимит на этот месяц.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(matchingBudgets.isEmpty ? "Новый бюджет" : "Изменить бюджет")
        .saveFailureAlert($saveError)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { save() }.disabled(amount.isEmpty) } }
    }
    private func save() {
        guard let value = Money.parseRubles(amount), value > 0 else {
            saveError = "Лимит бюджета должен быть корректным положительным числом в пределах точного денежного диапазона."
            return
        }
        let limit = Money(rubles: value)
        let existing = matchingBudgets
        do {
            try context.transaction {
                if let budget = existing.first {
                    budget.limitKopecks = limit.kopecks
                    existing.dropFirst().forEach(context.delete)
                } else {
                    context.insert(StoredBudget(category: category, limit: limit, periodStart: currentMonthStart))
                }
            }
            dismiss()
        }
        catch { context.rollback(); saveError = error.localizedDescription }
    }
}

private struct PurchaseCheckView: View {
    private struct GoalPlanShiftProposal {
        let goal: StoredGoal
        let plan: StoredPlanItem
        let originalNextDate: Date
        let shiftedFirstDate: Date
        let originalTargetDate: Date
        let originalPlanDate: Date
        let originalPlanAmount: Int64
        let originalPlanOccurrenceCount: Int?
        let originalPlanFinalContribution: Int64?
        let originalMonthlyContribution: Int64
        let originalSavedAmount: Int64
        let shiftedTargetDate: Date
        let shiftedOccurrenceCount: Int
        let shiftedFinalContribution: Money?
        let option: PurchaseOption
    }

    let snapshot: FinanceSnapshot
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var budgets: [StoredBudget]
    @Query private var accounts: [StoredAccount]
    @Query private var goals: [StoredGoal]
    @Query private var planItems: [StoredPlanItem]
    @State private var amount = ""
    @State private var category: Category = .other
    @State private var purchaseDate = Date.now
    @State private var isPlanned = false
    @State private var result: PurchaseVerdict?
    @State private var budgetNote: String?
    @State private var purchaseScenarioOptions: [PurchaseOption] = []
    @State private var selectedPurchaseScenarioID = "direct"
    @State private var pendingGoalShiftProposal: GoalPlanShiftProposal?
    @State private var isConfirmingGoalShift = false
    @State private var didSaveGoalShift = false
    @State private var saveError: String?
    private var parsedAmount: Money? { Money.parseRubles(amount).map { Money(rubles: $0) } }
    var body: some View {
        Form {
            Section("Покупка") {
                TextField("Сумма в рублях", text: $amount).keyboardType(.decimalPad)
                Picker("Категория", selection: $category) {
                    ForEach(Category.allCases.filter(\.supportsPurchaseClassification)) { Text($0.title).tag($0) }
                }
                DatePicker("Когда планируешь", selection: $purchaseDate, in: Date()..., displayedComponents: .date)
                Toggle("Покупка заранее запланирована", isOn: $isPlanned)
                Text("Запланированность не делает покупку автоматически безопасной или плохой. Проверка всегда считает резерв и обязательства.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Проверить") { checkPurchase() }
                    .disabled(amount.isEmpty)
            }
            if let result {
                Section("Результат") {
                    LabeledContent("Категория", value: category.title)
                    LabeledContent("Планирование", value: isPlanned ? "Запланирована заранее" : "Не была запланирована")
                    if selectedPurchaseScenarioID != "direct" {
                        Text("Условный пересчёт: план пока не изменён, покупка не записана. После изменения плана проверь покупку ещё раз.")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                    if let budgetNote { Text(budgetNote).font(.footnote).foregroundStyle(.secondary) }
                    purchaseVerdictView(selectedPurchaseScenario?.verdict ?? result)
                }
                if purchaseScenarioOptions.contains(where: { $0.id != "direct" }) {
                    Section("Проверить с изменением плана") {
                        ForEach(purchaseScenarioOptions.filter { $0.id != "direct" }) { option in
                            Button {
                                selectedPurchaseScenarioID = option.id
                            } label: {
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(option.title).font(.subheadline.weight(.semibold))
                                        Text(verdictText(option.verdict)).font(.caption).foregroundStyle(.secondary)
                                        if option.changedGoalContribution > .zero {
                                            Text("Взносы, перенесённые за горизонт: \(option.changedGoalContribution.formatted)")
                                                .font(.caption2).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if selectedPurchaseScenarioID == option.id {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(AppPalette.accent)
                                    }
                                }
                                .foregroundStyle(.primary)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selectedPurchaseScenarioID == option.id ? .isSelected : [])
                        }
                    }
                }
                if let proposal = selectedGoalPlanShift {
                    Section("Изменение плана цели") {
                        LabeledContent("Ближайший взнос", value: proposal.originalNextDate.formatted(date: .abbreviated, time: .omitted))
                        LabeledContent("После переноса", value: proposal.shiftedFirstDate.formatted(date: .abbreviated, time: .omitted))
                        LabeledContent("Новый срок цели", value: proposal.shiftedTargetDate.formatted(date: .abbreviated, time: .omitted))
                        Text("Сдвигается весь ежемесячный график этой цели, а не только один платёж. Прогноз выше уже пересчитан по новому графику.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button("Сдвинуть график и срок цели") {
                            pendingGoalShiftProposal = proposal
                            isConfirmingGoalShift = true
                        }
                    }
                }
            }
        }
        .navigationTitle("Проверка покупки")
        .saveFailureAlert($saveError)
        .confirmationDialog("Подтвердить изменение плана цели?", isPresented: $isConfirmingGoalShift,
                            titleVisibility: .visible) {
            Button("Подтвердить перенос", action: applyGoalShift)
            Button("Отмена", role: .cancel) { pendingGoalShiftProposal = nil }
        } message: {
            if let proposal = pendingGoalShiftProposal {
                Text("Срок цели изменится с \(proposal.originalTargetDate.formatted(date: .abbreviated, time: .omitted)) на \(proposal.shiftedTargetDate.formatted(date: .abbreviated, time: .omitted)). После переноса покупка: \(verdictText(proposal.option.verdict)).")
            }
        }
        .alert("График цели обновлён", isPresented: $didSaveGoalShift) {
            Button("Понятно") { dismiss() }
        } message: {
            Text("Цель и расписание сохранены. Открой проверку покупки ещё раз, чтобы получить расчёт по обновлённому плану.")
        }
        .onChange(of: amount) { _, _ in resetCheck() }
        .onChange(of: category) { _, _ in resetCheck() }
        .onChange(of: purchaseDate) { _, _ in resetCheck() }
        .onChange(of: isPlanned) { _, _ in resetCheck() }
    }

    private var selectedPurchaseScenario: PurchaseOption? {
        purchaseScenarioOptions.first { $0.id == selectedPurchaseScenarioID }
    }

    private var selectedGoalPlanShift: GoalPlanShiftProposal? {
        guard selectedPurchaseScenarioID.hasPrefix("goal-"), let parsedAmount,
              let goal = goals.first(where: { "goal-\($0.id.uuidString)" == selectedPurchaseScenarioID }),
              let planID = goal.planItemID,
              let plan = planItems.first(where: { $0.id == planID }) else { return nil }
        return goalPlanShiftProposal(goal: goal, plan: plan, purchase: parsedAmount)
    }

    @ViewBuilder
    private func purchaseVerdictView(_ verdict: PurchaseVerdict) -> some View {
        switch verdict {
        case .canBuy(let minimum):
            Label(selectedPurchaseScenarioID == "direct"
                ? "Можно. Минимум после трат: \(minimum.formatted)"
                : "В этом сценарии прогнозный минимум: \(minimum.formatted)",
                systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .canBuyWithChanges(_, let shortfall):
            Label("Сначала измени план. Нужно высвободить \(shortfall.formatted).",
                systemImage: "arrow.triangle.2.circlepath").foregroundStyle(.orange)
        case .unsafe(let shortfall, let date):
            Label("Не покупай сейчас: в худшей точке прогноза не хватит \(shortfall.formatted)\(date.map { " к \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "").",
                systemImage: "xmark.octagon.fill").foregroundStyle(.red)
        case .insufficientData(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
    }

    private func resetCheck() {
        result = nil
        budgetNote = nil
        purchaseScenarioOptions = []
        selectedPurchaseScenarioID = "direct"
    }

    private func checkPurchase() {
        guard let parsedAmount, parsedAmount > .zero else {
            result = .insufficientData("Укажи корректную сумму больше нуля, которая помещается в точный денежный диапазон.")
            budgetNote = nil
            return
        }
        purchaseScenarioOptions = makePurchaseOptions(for: parsedAmount)
        selectedPurchaseScenarioID = "direct"
        result = purchaseScenarioOptions.first(where: { $0.id == "direct" })?.verdict
        budgetNote = categoryBudgetStatus(for: parsedAmount)
    }

    /// Offer one clearly scoped schedule-shift what-if per linked goal.
    private func makePurchaseOptions(for purchase: Money) -> [PurchaseOption] {
        let engine = FinanceEngine()
        let allOptions = engine.purchaseOptions(purchase, on: purchaseDate, snapshot: snapshot)
        var options = allOptions.filter { $0.id == "direct" || $0.id == "later" }
        let linkedGoals = goals.compactMap { goal -> (StoredGoal, StoredPlanItem)? in
            guard let planID = goal.planItemID,
                  let plan = planItems.first(where: { $0.id == planID }),
                  plan.kindRaw == ScheduledItem.Kind.goalContribution.rawValue else { return nil }
            return (goal, plan)
        }
        for (goal, plan) in linkedGoals {
            if let proposal = goalPlanShiftProposal(goal: goal, plan: plan, purchase: purchase) {
                options.append(proposal.option)
            }
        }
        return options
    }

    private func goalPlanShiftProposal(goal: StoredGoal, plan: StoredPlanItem,
                                       purchase: Money) -> GoalPlanShiftProposal? {
        guard goal.planItemID == plan.id, goal.hasValidFinancialData,
              plan.hasValidFinancialData,
              let targetIncomeDate = snapshot.nextIncomeDate,
              plan.kindRaw == ScheduledItem.Kind.goalContribution.rawValue,
              plan.recurrenceRaw == ScheduledItem.Recurrence.monthly.rawValue else { return nil }
        let engine = FinanceEngine()
        guard let nextOccurrence = engine.upcomingOccurrences(snapshot, from: .now, through: targetIncomeDate)
            .first(where: { $0.planID == plan.id }),
              let shiftedFirstDate = ScheduledRecurrence.nextDate(after: nextOccurrence.date,
                  anchoredAt: plan.dueDate, recurrence: .monthly),
              let shiftedTargetDate = GoalContributionPlan.shiftedDeadlineAfterOneMonth(goal.targetDate,
                  firstContributionDate: shiftedFirstDate) else { return nil }
        let target = Money(kopecks: goal.targetKopecks)
        let saved = Money(kopecks: goal.savedKopecks)
        let monthly = Money(kopecks: goal.monthlyContributionKopecks)
        let shiftedCount = GoalContributionPlan.occurrencesNeeded(target: target, saved: saved,
            monthlyContribution: monthly, firstDate: shiftedFirstDate, targetDate: shiftedTargetDate)
        guard shiftedCount > 0 else { return nil }
        let shiftedFinal = GoalContributionPlan.finalContributionAmount(target: target, saved: saved,
            monthlyContribution: monthly, occurrenceCount: shiftedCount)
        guard let option = engine.goalContributionShiftPurchaseOption(
            purchase, on: purchaseDate, snapshot: snapshot, planID: plan.id, goalTitle: goal.title,
            shiftedFirstDate: shiftedFirstDate, shiftedOccurrenceCount: shiftedCount,
            shiftedFinalContribution: shiftedFinal) else { return nil }
        return GoalPlanShiftProposal(goal: goal, plan: plan, originalNextDate: nextOccurrence.date,
            shiftedFirstDate: shiftedFirstDate, originalTargetDate: goal.targetDate,
            originalPlanDate: plan.dueDate, originalPlanAmount: plan.amountKopecks,
            originalPlanOccurrenceCount: plan.occurrencesRemaining,
            originalPlanFinalContribution: plan.finalOccurrenceKopecks,
            originalMonthlyContribution: goal.monthlyContributionKopecks,
            originalSavedAmount: goal.savedKopecks,
            shiftedTargetDate: shiftedTargetDate, shiftedOccurrenceCount: shiftedCount,
            shiftedFinalContribution: shiftedFinal, option: option)
    }

    private func applyGoalShift() {
        guard let proposal = pendingGoalShiftProposal,
              FinanceDataFreshness.isFresh(snapshot.dataUpdatedAt, asOf: .now),
              proposal.goal.planItemID == proposal.plan.id,
              proposal.goal.targetDate == proposal.originalTargetDate,
              proposal.plan.dueDate == proposal.originalPlanDate,
              proposal.plan.amountKopecks == proposal.originalPlanAmount,
              proposal.plan.occurrencesRemaining == proposal.originalPlanOccurrenceCount,
              proposal.plan.finalOccurrenceKopecks == proposal.originalPlanFinalContribution,
              proposal.goal.monthlyContributionKopecks == proposal.originalMonthlyContribution,
              proposal.goal.savedKopecks == proposal.originalSavedAmount,
              proposal.plan.kindRaw == ScheduledItem.Kind.goalContribution.rawValue,
              proposal.plan.recurrenceRaw == ScheduledItem.Recurrence.monthly.rawValue else {
            pendingGoalShiftProposal = nil
            saveError = "План или свежесть баланса изменились. Проверь покупку заново, прежде чем переносить цель."
            return
        }
        do {
            try context.transaction {
                proposal.goal.targetDate = proposal.shiftedTargetDate
                proposal.plan.dueDate = proposal.shiftedFirstDate
                proposal.plan.occurrencesRemaining = proposal.shiftedOccurrenceCount
                proposal.plan.finalOccurrenceKopecks = proposal.shiftedFinalContribution?.kopecks
            }
            pendingGoalShiftProposal = nil
            didSaveGoalShift = true
        } catch {
            context.rollback()
            pendingGoalShiftProposal = nil
            saveError = error.localizedDescription
        }
    }

    private func categoryBudgetStatus(for purchaseAmount: Money) -> String? {
        let calendar = Calendar.current
        guard let month = calendar.dateInterval(of: .month, for: purchaseDate) else { return nil }
        let monthStart = month.start
        let monthEnd = month.end
        let descriptor = FetchDescriptor<StoredTransaction>(
            predicate: #Predicate { $0.date >= monthStart && $0.date < monthEnd }
        )
        let monthTransactions: [StoredTransaction]
        do {
            monthTransactions = try context.fetch(descriptor)
        } catch {
            return "Не удалось проверить бюджет категории. Общий финансовый план проверен отдельно."
        }
        let includedAccountIDs = Set(accounts.filter(\.included).map(\.id))
        let includedTransactions = monthTransactions.filter {
            ScheduledSettlementPolicy.sourceAccountIsIncluded(
                $0.sourceAccountID, includedAccountIDs: includedAccountIDs)
        }
        guard includedTransactions.allSatisfy(\.hasValidCategory) else {
            return "В истории есть операция с неизвестной категорией. Исправь её, чтобы проверить лимит категории; общий финансовый план проверен отдельно."
        }
        let currentMonthBudgets = budgets.filter { month.contains($0.periodStart) }
        guard currentMonthBudgets.allSatisfy(\.hasValidBudget) else {
            return "В месячном бюджете есть неверная категория или лимит. Исправь бюджет, чтобы проверить лимит; общий финансовый план проверен отдельно."
        }
        let matchingBudgets = currentMonthBudgets.filter { $0.category == category }
        guard matchingBudgets.count <= 1 else {
            return "Для этой категории задано несколько бюджетов на месяц. Сохрани лимит заново в разделе «Обзор», чтобы исправить дубликаты."
        }
        guard let budget = matchingBudgets.first else {
            return "На категорию «\(category.title)» нет бюджета на этот месяц; общий план всё равно проверен."
        }
        let eligibleTransactions = includedTransactions.map { transaction in
            Transaction(id: transaction.id, date: transaction.date, merchant: transaction.merchant,
                        amount: transaction.amount, kind: transaction.kind, category: transaction.category,
                        isInternalTransfer: transaction.internalTransfer, sourceID: transaction.sourceID,
                        status: transaction.status, providerTransactionID: transaction.providerTransactionID,
                        refundOfProviderTransactionID: transaction.refundOfProviderTransactionID,
                        refundOfTransactionID: transaction.refundOfTransactionID)
        }
        let usedKopecks = SpendingAnalytics.totalOutflow(
            eligibleTransactions, from: monthStart, to: monthEnd, category: category, asOf: purchaseDate
        ).kopecks
        let remaining = max(0, budget.limitKopecks - usedKopecks)
        if purchaseAmount.kopecks <= remaining {
            return "В бюджете категории останется \(Money(kopecks: remaining - purchaseAmount.kopecks).formatted)."
        }
        return "Покупка превысит бюджет категории на \(Money(kopecks: purchaseAmount.kopecks - remaining).formatted). Это отдельный лимит, не оценка покупки как плохой."
    }

    private func verdictText(_ verdict: PurchaseVerdict) -> String {
        switch verdict {
        case .canBuy(let balance), .canBuyWithChanges(let balance, _): "Прогнозный минимум: \(balance.formatted)"
        case .unsafe(let gap, _): "Дефицит: \(gap.formatted)"
        case .insufficientData(let text): text
        }
    }
}

private struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var settings: StoredSettings
    @AppStorage("moneywise.doubleFlipHideAmountsEnabled") private var doubleFlipHideAmountsEnabled = false
    @Query private var accounts: [StoredAccount]
    @State private var balanceText = ""
    @State private var balanceConfirmed = false
    @State private var reserveText = ""
    @State private var incomeText = ""
    @State private var incomeDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var incomeConfirmed = false
    @State private var didLoadSettings = false
    @State private var lockEnabled = false
    @State private var lockSetupUnavailable = false
    @State private var firstDeleteConfirmation = false
    @State private var finalDeleteConfirmation = false
    @State private var deleteError: String?
    @State private var didDeleteData = false
    @State private var saveError: String?
    @State private var notificationPermissionSummary = "Проверяю…"
    @State private var scheduledReminderCount = 0
    @State private var failedReminderScheduleCount = 0
    @State private var notificationRefreshGeneration = 0
    @State private var notificationSettingsError: String?
    @State private var isRequestingNotifications = false
    private var canConfirmIncome: Bool {
        guard let amount = Money.parseRubles(incomeText) else { return false }
        return ExpectedIncomeConfirmation.canConfirm(amount: Money(rubles: amount), date: incomeDate, asOf: .now)
    }
    private var hasPositiveExpectedIncomeToday: Bool {
        guard let amount = Money.parseRubles(incomeText) else { return false }
        return Money(rubles: amount) > .zero && Calendar.current.isDateInToday(incomeDate)
    }
    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                currentBalanceSection
                minimumReserveSection
                expectedIncomeSection
                notificationSection
                protectionSection
                dataLimitsSection
                expectedIncomeNoteSection
            }
            .navigationTitle("Настройки")
            .alert("Подготовить удаление?", isPresented: $firstDeleteConfirmation) {
                Button("Отмена", role: .cancel) { }
                Button("Продолжить", role: .destructive) { finalDeleteConfirmation = true }
            } message: { Text("Данные приложения на этом iPhone будут удалены. Ранее созданные резервные копии устройства и физические следы в памяти этим действием не удаляются.") }
            .alert(deleteError == nil ? "Удалить данные?" : "Не удалось удалить данные", isPresented: Binding(
                get: { finalDeleteConfirmation || deleteError != nil },
                set: { if !$0 { finalDeleteConfirmation = false; deleteError = nil } }
            )) {
                if deleteError != nil {
                    Button("Понятно", role: .cancel) {
                        deleteError = nil
                        if didDeleteData { dismiss() }
                    }
                } else {
                    Button("Отмена", role: .cancel) { finalDeleteConfirmation = false }
                    Button("Удалить всё", role: .destructive, action: deleteAllData)
                }
            } message: {
                Text(deleteError ?? "Будут удалены операции, счета, бюджеты, планы платежей, долги, цели, защищённые суммы, правила категорий, настройки и напоминания. Данные приложения на этом iPhone будут очищены. Резервные копии iPhone в iCloud или на компьютере и физические следы в памяти этим действием не удаляются.")
            }
            .saveFailureAlert($saveError)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { save() } }
            }
            .onAppear {
                balanceText = NSDecimalNumber(decimal: Money(kopecks: settings.balanceKopecks).decimalRubles).stringValue
                reserveText = NSDecimalNumber(decimal: Money(kopecks: settings.reserveKopecks).decimalRubles).stringValue
                incomeText = NSDecimalNumber(decimal: Money(kopecks: settings.nextIncomeKopecks).decimalRubles).stringValue
                incomeDate = settings.nextIncomeDate ?? incomeDate
                incomeConfirmed = settings.hasConfirmedFutureIncome
                lockEnabled = settings.lockEnabled
                Task { @MainActor in
                    await Task.yield()
                    didLoadSettings = true
                }
            }
            .task { await refreshNotificationSettings() }
            .onReceive(NotificationCenter.default.publisher(for: PaymentReminderScheduler.stateDidChange)) { _ in
                Task { await refreshNotificationSettings() }
            }
            .onChange(of: scenePhase) { _, phase in
                handleScenePhaseChange(phase)
            }
            .onChange(of: incomeText) { _, _ in
                if didLoadSettings { incomeConfirmed = false }
            }
            .onChange(of: incomeDate) { _, _ in
                if didLoadSettings { incomeConfirmed = false }
            }
            .onChange(of: balanceText) { _, _ in balanceConfirmed = false }
        }
    }
    private var appearanceSection: some View {
        Section("Внешний вид") {
            NavigationLink {
                AppAppearanceView()
            } label: {
                Label("Внешний вид", systemImage: "paintpalette")
            }
        }
    }

    private var minimumReserveSection: some View {
        Section("Минимальный остаток") {
            TextField("Не опускаться ниже, ₽", text: $reserveText).keyboardType(.decimalPad)
            Text("Это общий защитный порог. Отдельные суммы с названиями настраиваются в разделе «Обзор → Защищённые суммы».")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var expectedIncomeSection: some View {
        Section("Следующее поступление") {
            TextField("Сумма, ₽", text: $incomeText).keyboardType(.decimalPad)
            DatePicker("Дата", selection: $incomeDate, in: Date()..., displayedComponents: .date)
            Toggle("Подтверждено для прогноза", isOn: $incomeConfirmed)
                .disabled(!canConfirmIncome)
            if hasPositiveExpectedIncomeToday {
                Text("Поступление, ожидаемое сегодня, не считается доступным до зачисления. Выбери будущую дату или обнови баланс после получения денег.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Text("Поступление не прибавляется к балансу до зачисления. Подтверди сумму и дату, чтобы приложение могло рассчитать безопасный горизонт расходов.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var protectionSection: some View {
        Section(header: Text("Защита и данные"), footer: dataProtectionFooter) {
            Toggle("Запрашивать Face ID или код", isOn: lockEnabledBinding)
            if lockSetupUnavailable {
                Label("Защита не включена", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                Text("Чтобы включить блокировку MoneyWise, сначала настрой код-пароль iPhone в системных настройках. Затем можно использовать Face ID или код.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Toggle("Скрывать суммы двойным переворотом", isOn: $doubleFlipHideAmountsEnabled)
            Text("Когда приложение открыто, переверни iPhone экраном вниз два раза за 3 секунды. Повторный жест снова покажет суммы. Жест работает, когда телефон лежит горизонтально.")
                .font(.footnote).foregroundStyle(.secondary)
            Button("Удалить все данные на этом iPhone", role: .destructive) { firstDeleteConfirmation = true }
        }
    }

    private var lockEnabledBinding: Binding<Bool> {
        Binding(
            get: { lockEnabled },
            set: { enabled in
                if enabled {
                    let authenticationContext = LAContext()
                    var authenticationError: NSError?
                    guard authenticationContext.canEvaluatePolicy(
                        .deviceOwnerAuthentication, error: &authenticationError
                    ) else {
                        lockSetupUnavailable = true
                        return
                    }
                }
                lockSetupUnavailable = false
                lockEnabled = enabled
            }
        )
    }

    private var dataLimitsSection: some View {
        Section {
            Text("Баланс может быть отрицательным, если отражает овердрафт или задолженность. Резерв и ожидаемый доход должны быть неотрицательными.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var expectedIncomeNoteSection: some View {
        Section {
            Text("Ожидаемое поступление показывается в прогнозе, но не прибавляется к деньгам до фактического зачисления.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var currentBalanceSection: some View {
        Section("Текущий баланс по счетам") {
            if accounts.isEmpty {
                TextField("Баланс, ₽", text: $balanceText).keyboardType(.decimalPad)
                Button(balanceConfirmed ? "Баланс подтверждён" : "Подтвердить баланс сейчас") {
                    balanceConfirmed = true
                }
                Text("Резерв и дата поступления не обновляют отметку времени баланса. Подтверди сумму после проверки остатка.")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                Text("Сумма из настроек не прибавляется к отдельным счетам, чтобы не посчитать общий остаток дважды. Для наличных используй отдельный счёт «Наличные».")
                    .font(.footnote).foregroundStyle(.secondary)
                if settings.hasManualBalance {
                    HStack {
                        Text("Сохранённый ручной остаток")
                        Spacer()
                        SensitiveAmount(value: Money(kopecks: settings.balanceKopecks).formatted)
                    }
                    if settings.balanceKopecks >= 0 {
                        if accounts.contains(where: { $0.bank == .cash }) {
                            Text("Счёт наличных уже есть. Перенос ручного остатка может посчитать эти деньги дважды — обнови существующий счёт.")
                                .font(.footnote).foregroundStyle(.orange)
                        } else {
                            Button("Перенести ручной баланс в счёт наличных", action: addManualBalanceAsCash)
                        }
                    } else {
                        Text("Отрицательный остаток нельзя перенести как наличные. Создай отдельный счёт с тем типом задолженности, который он отражает.")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    private var notificationSection: some View {
        Section("Напоминания") {
            LabeledContent("Разрешение iPhone", value: notificationPermissionSummary)
            LabeledContent("Ожидает отправки", value: String(scheduledReminderCount))
            if failedReminderScheduleCount > 0 {
                failedReminderScheduleNotice
            }
            if notificationPermissionSummary == "Запрещены" ||
                notificationPermissionSummary == "Разрешены, оповещения выключены" {
                Button("Открыть настройки уведомлений iPhone", action: openNotificationSettings)
            } else if notificationPermissionSummary == "Не запрошены" {
                Button("Разрешить уведомления", action: requestNotificationPermission)
                    .disabled(isRequestingNotifications)
            }
            notificationHelpText
            notificationSettingsErrorNotice
        }
    }

    @MainActor
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        guard phase == .active else { return }
        Task { await refreshNotificationSettings() }
    }

    private var notificationHelpText: some View {
        Text("Для каждого плана с напоминанием приложение ставит ближайшее уведомление и обновляет его при открытии.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private var failedReminderScheduleNotice: some View {
        Text("iPhone не принял напоминания для \(failedReminderScheduleCount) планов. Проверь настройки уведомлений; MoneyWise повторит попытку при следующем открытии приложения.")
            .font(.footnote)
            .foregroundStyle(.red)
    }

    @ViewBuilder
    private var notificationSettingsErrorNotice: some View {
        if let notificationSettingsError {
            Text(notificationSettingsError)
                .font(.footnote)
                .foregroundStyle(.red)
        }
    }

    private var dataProtectionFooter: some View {
        Text("Файлы базы используют системную защиту iOS и исключены из резервных копий устройства. Экран блокировки приложения — дополнительная защита интерфейса. Удаление очистит данные внутри приложения на этом iPhone, но не удалит уже созданные копии всего устройства из iCloud или с компьютера и не гарантирует физическое стирание следов в памяти. Проверь и при необходимости удали резервную копию в настройках iCloud или Finder/Apple Devices.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    @MainActor
    private func refreshNotificationSettings() async {
        notificationRefreshGeneration &+= 1
        let refreshGeneration = notificationRefreshGeneration
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let requests = await center.pendingNotificationRequests()
        guard refreshGeneration == notificationRefreshGeneration else { return }
        switch settings.authorizationStatus {
        case .notDetermined: notificationPermissionSummary = "Не запрошены"
        case .denied: notificationPermissionSummary = "Запрещены"
        case .authorized:
            notificationPermissionSummary = settings.alertSetting == .enabled
                ? "Разрешены" : "Разрешены, оповещения выключены"
        case .provisional: notificationPermissionSummary = "Разрешены тихо"
        case .ephemeral: notificationPermissionSummary = "Временно разрешены"
        @unknown default: notificationPermissionSummary = "Неизвестный статус"
        }
        scheduledReminderCount = requests.filter { $0.identifier.hasPrefix("payment-") }.count
        failedReminderScheduleCount = PaymentReminderScheduler.failedScheduleCount
    }

    @MainActor
    private func requestNotificationPermission() {
        guard !isRequestingNotifications else { return }
        isRequestingNotifications = true
        notificationSettingsError = nil
        Task {
            defer { isRequestingNotifications = false }
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                await refreshNotificationSettings()
                if !granted && notificationPermissionSummary == "Не запрошены" {
                    notificationSettingsError = "iPhone не предоставил разрешение на уведомления."
                }
            } catch {
                notificationSettingsError = "Не удалось запросить разрешение: \(error.localizedDescription)"
                await refreshNotificationSettings()
            }
        }
    }

    private func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
    private func save() {
        guard let balance = Money.parseRubles(balanceText), let reserve = Money.parseRubles(reserveText),
              let income = Money.parseRubles(incomeText), reserve >= 0, income >= 0 else {
            saveError = "Укажи корректный баланс; резерв и ожидаемый доход должны быть неотрицательными суммами в пределах точного денежного диапазона."
            return
        }
        let updatedBalance = Money(rubles: balance)
        let balanceChanged = settings.balanceKopecks != updatedBalance.kopecks
        guard !BalanceUpdatePolicy.requiresConfirmation(valueChanged: balanceChanged,
                                                         explicitlyConfirmed: balanceConfirmed) else {
            saveError = "После изменения суммы проверь баланс и подтверди его кнопкой выше."
            return
        }
        if settings.hasManualBalance || balanceChanged || balanceConfirmed {
            settings.balanceKopecks = updatedBalance.kopecks
            settings.hasManualBalance = true
            settings.updatedAt = BalanceUpdatePolicy.updatedAt(
                previous: settings.updatedAt, explicitlyConfirmed: balanceConfirmed, now: .now
            )
        }
        settings.reserveKopecks = Money(rubles: reserve).kopecks
        settings.nextIncomeKopecks = Money(rubles: income).kopecks
        settings.nextIncomeDate = incomeDate
        settings.nextIncomeConfirmed = ExpectedIncomeConfirmation.isConfirmed(explicitlyConfirmed: incomeConfirmed,
            amount: Money(kopecks: Money(rubles: income).kopecks), date: incomeDate, asOf: .now)
        settings.lockEnabled = lockEnabled
        do { try context.save(); dismiss() }
        catch { context.rollback(); saveError = error.localizedDescription }
    }
    private func addManualBalanceAsCash() {
        guard settings.hasManualBalance, settings.balanceKopecks >= 0 else { return }
        do {
            let existingAccounts = try context.fetch(FetchDescriptor<StoredAccount>())
            guard !existingAccounts.contains(where: { $0.bank == .cash }) else {
                saveError = "Счёт наличных уже есть. Обнови его вручную; перенос не выполнен, чтобы не удвоить баланс."
                return
            }
            let cashAccount = StoredAccount(bank: .cash, name: "Наличные",
                                            balance: Money(kopecks: settings.balanceKopecks))
            try context.transaction {
                context.insert(cashAccount)
                settings.hasManualBalance = false
                settings.updatedAt = nil
            }
        } catch {
            context.rollback()
            saveError = error.localizedDescription
        }
    }
    private func deleteAllData() {
        do {
            // Fetch everything before mutating the context so a failed fetch cannot
            // produce a partial in-memory deletion that looks successful.
            let transactions = try context.fetch(FetchDescriptor<StoredTransaction>())
            let planItems = try context.fetch(FetchDescriptor<StoredPlanItem>())
            let budgets = try context.fetch(FetchDescriptor<StoredBudget>())
            let debts = try context.fetch(FetchDescriptor<StoredDebt>())
            let accounts = try context.fetch(FetchDescriptor<StoredAccount>())
            let goals = try context.fetch(FetchDescriptor<StoredGoal>())
            let protectedReserves = try context.fetch(FetchDescriptor<StoredProtectedReserve>())
            let merchantRules = try context.fetch(FetchDescriptor<StoredMerchantRule>())
            let transferPairs = try context.fetch(FetchDescriptor<StoredInternalTransferPair>())
            let storedSettings = try context.fetch(FetchDescriptor<StoredSettings>())

            try context.transaction {
                transactions.forEach(context.delete)
                planItems.forEach(context.delete)
                budgets.forEach(context.delete)
                debts.forEach(context.delete)
                accounts.forEach(context.delete)
                goals.forEach(context.delete)
                protectedReserves.forEach(context.delete)
                merchantRules.forEach(context.delete)
                transferPairs.forEach(context.delete)
                // The app normally has one settings row, but old or damaged stores
                // may contain duplicates. Keep the active object for the open view,
                // reset it, and remove every other persisted copy of personal data.
                storedSettings.filter { $0 !== settings }.forEach(context.delete)
                settings.balanceKopecks = 0
                settings.reserveKopecks = 0
                settings.nextIncomeDate = nil
                settings.nextIncomeKopecks = 0
                settings.nextIncomeConfirmed = false
                settings.updatedAt = nil
                settings.lockEnabled = false
                settings.hasManualBalance = false
            }
            PaymentReminderScheduler.cancelAll()
            UserDefaults.standard.removeObject(forKey: "moneywise.hideAmounts")
            UserDefaults.standard.removeObject(forKey: "moneywise.doubleFlipHideAmountsEnabled")
            UserDefaults.standard.removeObject(forKey: "okaneyan.selectedAppIcon")
            UserDefaults.standard.removeObject(forKey: "okaneyan.appearanceMode")
            UserDefaults.standard.removeObject(forKey: "okaneyan.hasShownIntro")
            didDeleteData = true
            if UIApplication.shared.alternateIconName != nil {
                UIApplication.shared.setAlternateIconName(nil) { error in
                    DispatchQueue.main.async {
                        if let error {
                            deleteError = "Данные удалены, но системную иконку не удалось вернуть к исходной: \(error.localizedDescription)"
                        } else {
                            dismiss()
                        }
                    }
                }
            } else {
                dismiss()
            }
        } catch {
            context.rollback()
            deleteError = "Не удалось надёжно сохранить удаление. Данные не подтверждены как удалённые. Ошибка: \(error.localizedDescription)"
        }
    }
}

private struct AppAppearanceView: View {
    @AppStorage("okaneyan.selectedAppIcon") private var storedIconName = "original"
    @AppStorage("okaneyan.appearanceMode") private var appearanceMode = "dark"

    private var selectedVariant: AppIconVariant {
        AppIconVariant(rawValue: storedIconName) ?? .original
    }

    var body: some View {
        Form {
            Section("Цветовая тема") {
                Picker("Оформление", selection: $appearanceMode) {
                    Text("Тёмная").tag("dark")
                    Text("Светлая").tag("light")
                    Text("Системная").tag("system")
                }
                .pickerStyle(.segmented)
            }
            Section("Бренд") {
                BrandLockup()
                    .padding(.vertical, 6)
            }
            Section("Иконка приложения") {
                NavigationLink {
                    AppIconPickerView()
                } label: {
                    HStack {
                        Label("Выбрать иконку", systemImage: "app")
                        Spacer()
                        Text(selectedVariant.title)
                            .foregroundStyle(.secondary)
                        Image(selectedVariant.assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 34, height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                }
                Text("Изменение устанавливает системную иконку iOS. Выбор хранится системой и подтверждается приложением после ответа iOS.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("О приложении") {
                LabeledContent("Название", value: "okaneyan.")
                LabeledContent("Назначение", value: "Personal Finance")
            }
        }
        .navigationTitle("Внешний вид")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            storedIconName = AppIconVariant.from(systemName: UIApplication.shared.alternateIconName).rawValue
        }
    }
}

private struct AppIconPickerView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("okaneyan.selectedAppIcon") private var storedIconName = "original"
    @State private var selectedVariant: AppIconVariant = .original
    @State private var isApplying = false
    @State private var showingError = false
    @State private var errorMessage = ""

    private let columns = [GridItem(.adaptive(minimum: 142), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Выбери знак, который будет виден на экране iPhone. Слово okaneyan. остаётся отдельным фирменным написанием.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !UIApplication.shared.supportsAlternateIcons {
                    Label("На этом устройстве системная смена иконки недоступна. Текущая иконка останется без изменений.", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppPalette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(AppIconVariant.allCases) { variant in
                        iconCard(variant)
                    }
                }

                if isApplying {
                    HStack(spacing: 9) {
                        ProgressView()
                        Text("Обновляем системную иконку…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)
                }
            }
            .padding(16)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(AppPalette.canvas)
        .navigationTitle("Иконка приложения")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refreshSystemSelection)
        .alert("Не удалось изменить иконку", isPresented: $showingError) {
            Button("Понятно", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func iconCard(_ variant: AppIconVariant) -> some View {
        let isSelected = selectedVariant == variant
        return Button { apply(variant) } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    Image(variant.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 92, height: 92)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppPalette.line.opacity(0.7), lineWidth: 1))
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, AppPalette.accent)
                            .padding(4)
                            .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 3) {
                    Text(variant.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(variant.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if isSelected {
                        Text("Выбрана")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppPalette.accent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 178, alignment: .top)
            .background(AppPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(isSelected ? AppPalette.accent : AppPalette.line, lineWidth: isSelected ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isApplying || !UIApplication.shared.supportsAlternateIcons)
        .accessibilityLabel(variant.title)
        .accessibilityValue(isSelected ? "Выбрана" : "Не выбрана")
        .accessibilityHint("Двойное нажатие установит эту системную иконку")
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.82), value: selectedVariant)
    }

    private func refreshSystemSelection() {
        selectedVariant = AppIconVariant.from(systemName: UIApplication.shared.alternateIconName)
        storedIconName = selectedVariant.rawValue
    }

    private func apply(_ variant: AppIconVariant) {
        guard UIApplication.shared.supportsAlternateIcons else {
            errorMessage = "iOS не разрешает менять иконку на этом устройстве. Текущий вариант не изменён."
            showingError = true
            return
        }
        guard variant.systemName != UIApplication.shared.alternateIconName else {
            selectedVariant = variant
            storedIconName = variant.rawValue
            return
        }

        isApplying = true
        UIApplication.shared.setAlternateIconName(variant.systemName) { error in
            DispatchQueue.main.async {
                isApplying = false
                let actualVariant = AppIconVariant.from(systemName: UIApplication.shared.alternateIconName)
                guard error == nil, actualVariant == variant else {
                    selectedVariant = actualVariant
                    storedIconName = actualVariant.rawValue
                    errorMessage = error.map {
                        "iOS не подтвердила замену. Оставлена текущая иконка «\(actualVariant.title)». \($0.localizedDescription)"
                    } ?? "iOS не подтвердила выбранный вариант. Оставлена текущая иконка «\(actualVariant.title)»."
                    showingError = true
                    return
                }
                selectedVariant = actualVariant
                storedIconName = actualVariant.rawValue
            }
        }
    }
}

private enum AppIconVariant: String, CaseIterable, Identifiable {
    case original
    case light
    case monochrome
    case glass

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original: "Original"
        case .light: "Light"
        case .monochrome: "Monochrome"
        case .glass: "Glass"
        }
    }

    var detail: String {
        switch self {
        case .original: "Основной знак на матовом чёрном фоне."
        case .light: "Тёмный знак на мягком розовом фоне."
        case .monochrome: "Спокойный монохромный вариант."
        case .glass: "Деликатная глубина и стеклянный блик."
        }
    }

    var assetName: String {
        switch self {
        case .original: "OkaneyanOriginal"
        case .light: "OkaneyanLight"
        case .monochrome: "OkaneyanMonochrome"
        case .glass: "OkaneyanGlass"
        }
    }

    var systemName: String? {
        switch self {
        case .original: nil
        case .light: "AppIconLight"
        case .monochrome: "AppIconMonochrome"
        case .glass: "AppIconGlass"
        }
    }

    static func from(systemName: String?) -> AppIconVariant {
        allCases.first { $0.systemName == systemName } ?? .original
    }
}

private struct BrandLockup: View {
    var body: some View {
        HStack(spacing: 13) {
            Image("OkaneyanOriginal")
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 0) {
                    Text("okaneyan")
                    Text(".").foregroundStyle(AppPalette.accent)
                }
                .font(.system(size: 21, weight: .medium))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("okaneyan.")
                Text("PERSONAL FINANCE")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(2.2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 60)
    }
}

@MainActor
private enum PaymentReminderScheduler {
    static let stateDidChange = Notification.Name("MoneyWiseReminderScheduleStateDidChange")
    private static var scheduleGenerations: [UUID: UUID] = [:]
    private static var failedScheduleIDs = Set<UUID>()

    static var failedScheduleCount: Int { failedScheduleIDs.count }

    private static func publishStateChange() {
        NotificationCenter.default.post(name: stateDidChange, object: nil)
    }

    static func schedule(title: String, dueDate: Date, amount: Money, daysBefore: Int, recurrence: ScheduledItem.Recurrence,
                         occurrencesRemaining: Int? = nil, finalOccurrenceAmount: Money? = nil,
                         settlements: [ScheduledSettlement] = [], kind: ScheduledItem.Kind = .obligation, id: UUID) {
        let generation = UUID()
        scheduleGenerations[id] = generation
        failedScheduleIDs.remove(id)
        publishStateChange()
        let center = UNUserNotificationCenter.current()
        let identifier = "payment-\(id.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            Task { @MainActor in
                guard scheduleGenerations[id] == generation else { return }
                guard granted else {
                    failedScheduleIDs.remove(id)
                    publishStateChange()
                    return
                }
                let now = Date.now
                let calendar = Calendar.current
                guard let minimumDueDate = calendar.date(byAdding: .day, value: daysBefore, to: now) else { return }
                let item = ScheduledItem(id: id, title: title, amount: amount, dueDate: dueDate,
                    kind: kind, recurrence: recurrence, occurrencesRemaining: occurrencesRemaining,
                    finalOccurrenceAmount: finalOccurrenceAmount)
                guard var nextDue = ScheduledSettlementPolicy.firstUnsettledOccurrence(onOrAfter: minimumDueDate,
                        of: item, settlements: settlements, calendar: calendar) else { return }
                var reminderDate = calendar.date(byAdding: .day, value: -daysBefore, to: nextDue)
                // A same-day reminder may already have passed by the time the app becomes active.
                if reminderDate.map({ $0 <= now }) == true {
                    guard let advanced = ScheduledSettlementPolicy.firstUnsettledOccurrence(
                        onOrAfter: Calendar.current.date(byAdding: .day, value: 1, to: nextDue) ?? nextDue,
                        of: item, settlements: settlements, calendar: calendar) else { return }
                    nextDue = advanced
                    reminderDate = calendar.date(byAdding: .day, value: -daysBefore, to: nextDue)
                }
                guard let reminderDate, reminderDate > now else { return }
                let content = UNMutableNotificationContent()
                if kind == .debtCollection {
                    content.title = "Скоро ожидаемый возврат"
                    content.body = "Открой приложение и проверь план поступления."
                } else {
                    content.title = "Скоро запланированный платёж"
                    content.body = "Открой приложение и проверь план расходов."
                }
                content.sound = .default
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)) { error in
                    Task { @MainActor in
                        guard scheduleGenerations[id] == generation else { return }
                        if error == nil {
                            failedScheduleIDs.remove(id)
                        } else {
                            failedScheduleIDs.insert(id)
                        }
                        publishStateChange()
                    }
                }
            }
        }
    }

    static func cancel(id: UUID) {
        scheduleGenerations[id] = UUID()
        failedScheduleIDs.remove(id)
        let center = UNUserNotificationCenter.current()
        let identifier = "payment-\(id.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        publishStateChange()
    }

    static func cancelAll() {
        scheduleGenerations.removeAll()
        failedScheduleIDs.removeAll()
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        publishStateChange()
    }

}

private struct AddDebtView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var creditor = ""
    @State private var direction: DebtDirection = .owedByMe
    @State private var confirmedInForecast = false
    @State private var balance = ""
    @State private var payment = ""
    @State private var firstPaymentDate = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now
    @State private var reminderDays = 0
    @State private var saveError: String?
    var body: some View {
        Form {
            Section("Долг") {
                Picker("Направление", selection: Binding(get: { direction }, set: { value in
                    direction = value
                    confirmedInForecast = value == .owedByMe
                })) {
                    ForEach(DebtDirection.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                TextField(direction == .owedByMe ? "Кому должен" : "Кто должен тебе", text: $creditor)
                TextField(direction == .owedByMe ? "Остаток моего долга, ₽" : "Остаток долга мне, ₽", text: $balance).keyboardType(.decimalPad)
                TextField("Платёж в месяц, ₽", text: $payment).keyboardType(.decimalPad)
                DatePicker("Первый платёж", selection: $firstPaymentDate, in: Date()..., displayedComponents: .date)
                Picker("Напомнить заранее", selection: $reminderDays) {
                    Text("Не напоминать").tag(0)
                    Text("За день").tag(1)
                    Text("За два дня").tag(2)
                }
                if direction == .owedToMe {
                    Toggle("Подтверждено для прогноза", isOn: $confirmedInForecast)
                    Text("Не включай возврат в расчёт, пока дата поступления не согласована.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section {
                Text(direction == .owedByMe
                     ? "Остаток моего долга не уменьшается сам по календарю. После фактического платежа обнови его вручную; будущий платёж уменьшит прогноз."
                     : "Остаток долга тебе не уменьшается сам по календарю. После фактического возврата обнови его вручную; подтверждённая дата возврата увеличит прогноз, но не текущий баланс.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Добавить долг")
        .saveFailureAlert($saveError)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Сохранить", action: save).disabled(creditor.isEmpty || balance.isEmpty || payment.isEmpty) } }
    }
    private func save() {
        guard let debtBalanceRubles = Money.parseRubles(balance), let monthlyRubles = Money.parseRubles(payment),
              debtBalanceRubles > 0, monthlyRubles > 0 else {
            saveError = "Остаток долга и ежемесячный платёж должны быть корректными положительными суммами."
            return
        }
        let debtBalance = Money(rubles: debtBalanceRubles), monthly = Money(rubles: monthlyRubles)
        let reservedInstallment = DebtRepaymentSchedule.reservedInstallment(balance: debtBalance, payment: monthly) ?? monthly
        let planKind: ScheduledItem.Kind = direction == .owedByMe ? .debtRepayment : .debtCollection
        let planTitle = direction == .owedByMe ? "Погашение долга: \(creditor)" : "Возврат долга: \(creditor)"
        let plan = StoredPlanItem(title: planTitle, amount: reservedInstallment, dueDate: firstPaymentDate,
                                  kind: planKind, recurrence: .monthly)
        plan.isConfirmed = direction == .owedByMe || confirmedInForecast
        context.insert(plan)
        context.insert(StoredDebt(creditor: creditor, balance: debtBalance, payment: monthly,
                                  firstPaymentDate: firstPaymentDate, planItemID: plan.id, direction: direction))
        plan.reminderDays = reminderDays
        do {
            try context.save()
            dismiss()
        }
        catch { context.rollback(); saveError = error.localizedDescription }
    }
}

private struct EditDebtView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var debt: StoredDebt
    let plan: StoredPlanItem?
    @State private var creditor = ""
    @State private var direction: DebtDirection = .owedByMe
    @State private var confirmedInForecast = false
    @State private var balance = ""
    @State private var payment = ""
    @State private var nextPaymentDate = Date()
    @State private var reminderDays = 0
    @State private var saveError: String?

    var body: some View {
        Form {
            Section("Долг") {
                Picker("Направление", selection: Binding(get: { direction }, set: { value in
                    direction = value
                    confirmedInForecast = value == .owedByMe
                })) {
                    ForEach(DebtDirection.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                TextField(direction == .owedByMe ? "Кому должен" : "Кто должен тебе", text: $creditor)
                TextField(direction == .owedByMe ? "Подтверждённый долг, ₽" : "Подтверждённый долг тебе, ₽", text: $balance).keyboardType(.decimalPad)
                TextField("Платёж в месяц, ₽", text: $payment).keyboardType(.decimalPad)
                DatePicker("Следующий платёж", selection: $nextPaymentDate, in: Date()..., displayedComponents: .date)
                Picker("Напомнить заранее", selection: $reminderDays) {
                    Text("Не напоминать").tag(0)
                    Text("За день").tag(1)
                    Text("За два дня").tag(2)
                }
                if direction == .owedToMe {
                    Toggle("Подтверждено для прогноза", isOn: $confirmedInForecast)
                    Text("Включай только согласованную дату возврата; это будущее поступление, не деньги на счёте сейчас.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section {
                Text("Остаток должен соответствовать последней фактической информации от кредитора. Проценты и внесённые платежи автоматически не рассчитываются.")
                    .font(.footnote).foregroundStyle(.secondary)
                Text(debt.direction == .owedByMe
                    ? "При нулевом остатке регулярный платёж перестанет резервироваться."
                    : "При нулевом остатке ожидаемый возврат перестанет учитываться в прогнозе.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Изменить долг")
        .saveFailureAlert($saveError)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Сохранить", action: save) } }
        .onAppear {
            creditor = debt.creditor
            direction = debt.direction
            balance = NSDecimalNumber(decimal: Money(kopecks: debt.balanceKopecks).decimalRubles).stringValue
            payment = NSDecimalNumber(decimal: Money(kopecks: debt.paymentKopecks).decimalRubles).stringValue
            nextPaymentDate = max(debt.firstPaymentDate, .now)
            reminderDays = plan?.reminderDays ?? 0
            confirmedInForecast = plan?.isConfirmed ?? false
        }
    }

    private func save() {
        guard !creditor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let balanceRubles = Money.parseRubles(balance), balanceRubles >= 0,
              let paymentRubles = Money.parseRubles(payment), paymentRubles > 0 else {
            saveError = "Укажи получателя, неотрицательный остаток и корректный положительный ежемесячный платёж."
            return
        }
        let debtBalance = Money(rubles: balanceRubles)
        let monthly = Money(rubles: paymentRubles)
        let reservedInstallment = DebtRepaymentSchedule.reservedInstallment(balance: debtBalance, payment: monthly)
        let planKind: ScheduledItem.Kind = direction == .owedByMe ? .debtRepayment : .debtCollection
        let planTitle = direction == .owedByMe ? "Погашение долга: \(creditor)" : "Возврат долга: \(creditor)"
        if let plan {
            if direction != debt.direction {
                do {
                    let planID = plan.id
                    let linkedTransactions = try context.fetch(FetchDescriptor<StoredTransaction>(
                        predicate: #Predicate { $0.scheduledPlanItemID == planID }
                    ))
                    let incompatibleLink = linkedTransactions.contains { row in
                        let isReceipt = row.kind == .income || row.kind == .incomingTransfer
                        return direction == .owedToMe ? !isReceipt : !row.kind.isOutflow
                    }
                    guard !incompatibleLink else {
                        saveError = "Нельзя изменить направление долга, пока к его плану привязаны операции другого типа. Сначала отвяжи их в истории операций."
                        return
                    }
                } catch {
                    saveError = error.localizedDescription
                    return
                }
            }
            let proposedPlan = ScheduledItem(id: plan.id, title: planTitle,
                amount: reservedInstallment ?? monthly, dueDate: nextPaymentDate,
                isConfirmed: direction == .owedByMe || confirmedInForecast,
                kind: planKind, recurrence: .monthly,
                occurrencesRemaining: debtBalance == .zero ? 0 : nil)
            let canPreserveSettlements: Bool
            do { canPreserveSettlements = try canPreserveUpcomingSettlements(for: proposedPlan, in: context) }
            catch { saveError = error.localizedDescription; return }
            guard canPreserveSettlements else {
                saveError = "Изменение графика нарушит привязку уже подтверждённого будущего платежа. Сначала проверь или отвяжи эту операцию в истории."
                return
            }
        }
        debt.creditor = creditor.trimmingCharacters(in: .whitespacesAndNewlines)
        debt.directionRaw = direction.rawValue
        debt.balanceKopecks = debtBalance.kopecks
        debt.paymentKopecks = monthly.kopecks
        debt.firstPaymentDate = nextPaymentDate

        let planItem: StoredPlanItem
        if let plan {
            planItem = plan
        } else {
            planItem = StoredPlanItem(title: planTitle, amount: monthly,
                                      dueDate: nextPaymentDate, kind: planKind, recurrence: .monthly)
            planItem.isConfirmed = direction == .owedByMe || confirmedInForecast
            debt.planItemID = planItem.id
            context.insert(planItem)
        }
        planItem.title = planTitle
        planItem.amountKopecks = reservedInstallment?.kopecks ?? monthly.kopecks
        planItem.dueDate = nextPaymentDate
        planItem.kindRaw = planKind.rawValue
        planItem.isConfirmed = direction == .owedByMe || confirmedInForecast
        planItem.recurrenceRaw = ScheduledItem.Recurrence.monthly.rawValue
        planItem.reminderDays = reminderDays
        planItem.occurrencesRemaining = debtBalance == .zero ? 0 : nil
        planItem.finalOccurrenceKopecks = nil

        do {
            try context.save()
            dismiss()
        } catch {
            context.rollback()
            saveError = error.localizedDescription
        }
    }
}

private struct AddPlanItemView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var amount = ""
    @State private var date = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    @State private var kind: ScheduledItem.Kind = .obligation
    @State private var confirmedInForecast = false
    @State private var recurrence: ScheduledItem.Recurrence = .none
    @State private var reminderDays = 0
    @State private var saveError: String?
    var body: some View {
        Form {
            Section(kind == .debtCollection ? "Ожидаемое поступление" : "Запланированное событие") {
                TextField("Например: дорога или возврат долга", text: $title)
                TextField("Сумма, ₽", text: $amount).keyboardType(.decimalPad)
                DatePicker("Дата", selection: $date, in: Date()..., displayedComponents: .date)
                Picker("Тип", selection: Binding(get: { kind }, set: { value in
                    kind = value
                    confirmedInForecast = value != .debtCollection
                })) {
                    Text("Обязательство").tag(ScheduledItem.Kind.obligation)
                    Text("Взнос в цель").tag(ScheduledItem.Kind.goalContribution)
                    Text("Возврат долга").tag(ScheduledItem.Kind.debtRepayment)
                    Text("Ожидаемый возврат долга").tag(ScheduledItem.Kind.debtCollection)
                    Text("Подписка").tag(ScheduledItem.Kind.subscription)
                }
                if kind == .debtCollection {
                    Toggle("Подтверждено для прогноза", isOn: $confirmedInForecast)
                    Text("Не включай ожидаемый возврат в расчёт, пока дата поступления не согласована.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Picker("Повтор", selection: $recurrence) {
                    Text("Один раз").tag(ScheduledItem.Recurrence.none)
                    Text("Каждую неделю").tag(ScheduledItem.Recurrence.weekly)
                    Text("Каждый месяц").tag(ScheduledItem.Recurrence.monthly)
                    Text("Каждый год").tag(ScheduledItem.Recurrence.yearly)
                }
                Picker("Напомнить заранее", selection: $reminderDays) {
                    Text("Не напоминать").tag(0)
                    Text("За день").tag(1)
                    Text("За два дня").tag(2)
                }
            }
            Section { Text("Взносы в цели можно временно перенести при проверке покупки. Обязательства, подписки и долги защищают расчёт.").font(.footnote).foregroundStyle(.secondary) }
        }
        .navigationTitle("Добавить в план")
        .saveFailureAlert($saveError)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { save() }.disabled(title.isEmpty || amount.isEmpty) } }
    }
    private func save() {
        guard let parsed = Money.parseRubles(amount), parsed > 0 else {
            saveError = "Сумма должна быть корректным положительным числом в пределах точного денежного диапазона."
            return
        }
        let item = StoredPlanItem(title: title, amount: Money(rubles: parsed), dueDate: date,
                                  kind: kind, recurrence: recurrence, reminderDays: reminderDays)
        item.isConfirmed = kind != .debtCollection || confirmedInForecast
        context.insert(item)
        do {
            try context.save()
            dismiss()
        } catch { context.rollback(); saveError = error.localizedDescription }
    }
}
