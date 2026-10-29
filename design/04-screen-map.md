# Screen map and canonical ownership

## Product/navigation facts

- Platform and persistence owner: iOS SwiftUI + SwiftData; minimum iOS 17.0. No parallel web shipping app.
- Root owner: `RootView` in `iOSApp/MoneyWiseApp.swift`, existing three tabs `Обзор`, `Операции`, `План`; keep ownership and extend, do not create duplicate root navigation.
- Shared theme/type owner: `AppPalette` / `AppTypography` in `iOSApp/AppTypography.swift`; semantic canvas, surface, raised-surface, line, hero and accent tokens support system light/dark appearance. Screen coverage and contrast still need native runtime audit.
- Domain source: `Sources/MoneyCore/FinanceEngine.swift`, `Models.swift`, `SpendingForecaster.swift`, `SpendingAnalytics.swift`, `CSVStatementImporter.swift`. UI renders domain verdicts and must not implement parallel money math.
- Browser preview owner: `preview/index.html`, explicit demo data only. Its controls are not app/API/persistence integrations.
- `DESIGN.md` and the `design/` contracts now record the approved direction. No generic motion helper is needed yet; SwiftUI controls/NavigationStack/sheets remain canonical where they satisfy accessibility and product behavior.

## Inventory, existing entry points, and visual pass

| Flow/screen | Current canonical entry point | Design stage | Key state/guard |
|---|---|---|---|
| Lock / Face ID | `RootView` lock gate, `AppLockView` | Preserve; polish after flagship | locked, auth fail, background relock |
| Overview | `RootView.home` | **G2 flagship** | no data, stale data, reliable history, hidden amounts, reserve/obligations |
| Purchase check | `PurchaseCheckView` via overview NavigationLink | After G2; high risk | four `PurchaseVerdict` outcomes, explicit recalculation, date/amount |
| Operations list | `transactionsView` | Stage 6 | empty, filtered/list, edit, delete |
| Transaction add/edit | `AddTransactionView`, `EditTransactionView`, sheet/detail | Stage 6 | validation, save/cancel, category and income source |
| CSV picker/preview | `fileImporter` → `ImportPreviewView` | Stage 6 | denied/empty/oversized/duplicates/partial errors/cancel/confirm |
| Plan | `planView` | Stage 6 | upcoming income vs commitments; never forecast income as current balance |
| Plan item add/edit | `AddPlanItemView`, `EditPlanItemView` | Stage 6 | recurrence/reminders, no double count |
| Budgets | `AddBudgetView`, plan list | Stage 6 | empty/progress and period |
| Goals | `AddGoalView`, overview/plan | Stage 6 | saved/target, reserve not counted twice |
| Debts | `AddDebtView`, plan | Stage 6 | borrowed debt not income, due status |
| Accounts/manual balances | `AddAccountView`, `EditAccountView`, overview | Stage 6 | included/excluded, timestamp, unknown vs stale |
| Settings/privacy | `SettingsView`, toolbar eye button | Stage 6 | lock, hide, reminders, destructive double-confirm delete |

## State and motion ownership

- Root selection: current `TabView` + `selectedTab` in `RootView` (M-01).
- Overview hero and its details: `AvailableBalanceCard` under `RootView.home` keeps one source for summary + detail identity; its amount uses `matchedGeometryEffect` (M-02).
- Purchase check: domain owner is `FinanceEngine.checkPurchase`; UI owner remains `PurchaseCheckView`; do not duplicate verdict arithmetic (M-03).
- Lists/details/forms: existing SwiftUI `List`, `NavigationLink`, `sheet` and form controls remain canonical; motion must follow native navigation and not reimplement gestures (M-04/05).
- Reduced motion: honor `accessibilityReduceMotion` for every custom animation; native platform-owned transitions retain their platform accessibility behavior.

## Staging

Approved Soft Matte direction → G2 implement Overview in native SwiftUI and mirror only review states in the demo preview → screenshot on iPhone Simulator/device when full Xcode exists; browser viewport review at 390/768/1440 → re-test finance invariants → only then scale to sibling screens.
