# iOS MVP roadmap

## Release checkpoint — 2026-10-29

- Follow-up verification: `testGoalBudgetAndDebtCreationPersistAfterRelaunch` passed on iPhone 17 Simulator. It created a 12,000 ₽ savings goal with a 1,500 ₽ monthly contribution, a 5,000 ₽ groceries budget, and a debt with 3,000 ₽ balance / 500 ₽ monthly payment; all three remained visible after terminating and relaunching the app. Independent SQLite reads confirmed one goal, budget, and debt, with two linked plan items and exact kopeck values. The subsequent two-confirmation delete-all UI test passed (1/1); independent SQLite counts showed 0 accounts, transactions, plans, budgets, debts, and goals. This verifies create + persistence + logical deletion for these records on Simulator, not edit flows, physical erase, or notification behavior.
- Follow-up verification: added `testDeleteAllDataRequiresTwoConfirmationsAndRemovesFinancialRecords`. On the iPhone 17 Simulator, it created an account, confirmed cancelling the final destructive step left the settings screen and data intact, then completed the two-step delete and returned to Overview. The test passed. An independent SQLite read of the app's live SwiftData store then showed 0 accounts, transactions, plans, budgets, debts, and goals. This verifies app-local logical deletion and UI confirmation on Simulator; physical erasure, backup removal, notification delivery/cancellation, and device-only protection remain outside this result.
- Follow-up verification: `testCSVImportAndRepeatedStatementDeduplication` passed on iPhone 17 Simulator. A simulator-only launch-environment fixture feeds a local CSV URL into the real `importCSV` path, then verifies parsing, preview, `ImportWriter` persistence, visibility after relaunch, and duplicate recognition on a second import. An independent SQLite read showed exactly one transaction (`CSV тест операция`, 12,345 kopecks) and no accounts/plans/budgets/debts/goals. The full-data deletion UI test then passed again; a second SQLite read showed zero records in all six collections. The synthetic CSV was removed. The system picker selection itself remains unverified by automation; the hook bypasses only picker file selection, not parsing or persistence. It is compiled only for Debug or Simulator targets and is inactive unless the explicit test environment key is present.
- A direct Xcode Release build for `generic/platform=iOS` succeeded with code signing disabled. This confirms device-SDK compilation, not signing, archive export, installation, or a physical-device run. Existing concurrency warnings from the local notification scheduler remain visible during build.

- Integration was based on `e1365eb2604a2f447fdb89ae216a915b519c371b` on `codex/moneywise-native-ui`; the Horizon presentation and focused verification are now committed. Separate design-document/screenshot changes remain preserved and uncommitted. The project was originally imported as a baseline commit, so this SHA is a repository snapshot, not evidence that prior work was reviewed or released.
- Xcode 27.1 (27A9275) is available when commands explicitly use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; the default `xcode-select` still points at Command Line Tools. iOS 27.1 Simulator runtime is installed.
- Xcode 27.1 Debug and Release Simulator builds succeeded. The integrated arm64 Release app was installed and launched on iPhone 17 Simulator; executable SHA-256: `b3168fe7594ec4f192125d1af0b79d04d339e4cf10b23dbbe5b3adfc636cfae6`. The Horizon presentation patch from the isolated UI branch is integrated in `iOSApp/FinancialHorizonView.swift`: it adds a collapsed daily-value list, respects hidden-amount privacy in the chart VoiceOver label, and separates invalid/zero purchase amounts from dates outside the selected range. The shared Xcode UI-test target covers account/purchase persistence after relaunch and no-history Horizon behavior.
- SwiftData created and reopened the simulator store (`Library/Application Support/MoneyWise/MoneyWise.store`). `MoneyWiseUserFlowTests.testAccountAndTransactionPersistAfterRelaunch` passed twice on iPhone 17 Simulator. The test waits for the refreshed account count, creates an account and purchase, terminates/relaunches the app, and verifies both remain visible. Independent SQLite reads found 1 account/1 transaction after run one and 2/2 after run two. Test data was then removed by uninstalling/reinstalling the app; the re-created SwiftData store was independently confirmed empty.
- `swift run moneywise-checks` passes 380 checks. Three core UI flows passed together previously; the CSV import/deduplication UI flow and delete-all UI flow have each also passed individually on iPhone 17 Simulator. Independent SQLite checks verified one imported transaction, then zero records after cleanup. The device-SDK Release build succeeded unsigned. The system picker selection, daily disclosure with reliable history, hidden-amount VoiceOver traversal, budgets/goals/debts CRUD, purchase-check UI, notification delivery/cancellation, privacy lock, and personal-history calibration remain unverified. Data-protection attributes, Face ID, signing/archive, installation, and physical-device behavior remain unverified. iPhone 12 performance is outside the current verification scope; the user selected Simulator-only checks.
- CSV picker automation was attempted with a temporary synthetic CSV in the simulator app Documents folder. The system file picker opened, but its File Provider controls ran in a remote UI process that was not interactable through the MoneyWise-targeted XCUI queries; the import flow did not reach preview or persistence. This is a test-harness limitation, not a reproduced product defect. The experiment was removed, no project setting was changed, and the clean Release build was restored afterward.
- SMS/Shortcuts feasibility evidence: Apple documents that Message personal automations can trigger on sender/message text and can run without asking. App Intents support foreground/background execution. Apple’s public docs do not establish that a Message trigger passes the received body to the action as shortcut input, nor were such an automation and the app intent exercised on a physical iPhone. Therefore this is a promising prototype path, not verified automatic SMS ingestion; do not integrate it as a working feature yet. SMS filtering extensions only receive eligible unknown-sender SMS/MMS and are not a general inbox reader. References: [Message automation trigger](https://support.apple.com/en-ae/guide/shortcuts/apdd711f9dff/ios), [automation without asking](https://support.apple.com/en-euro/guide/shortcuts/-apd602971e63/ios), [App Intents runtime](https://developer.apple.com/documentation/appintents/configuring-the-runtime-behavior-of-your-app-intents), [SMS filtering limits](https://developer.apple.com/documentation/identitylookup/sms-and-mms-message-filtering).
- Release state: **NOT READY**. Account and purchase persistence is verified on Simulator. Remaining app flows include import/deduplication, planning CRUD, notification authorization/delivery, purchase-check UI, data deletion/privacy, and SMS trigger/body-input proof before a separate minimal App Intent prototype. The simulator is clean after the test run; no synthetic user records remain. Do not claim the simulator verifies physical-device-only behavior.

## Objective and constraints

Build a personal Russian-ruble iPhone finance planner from `PRODUCT_SPEC.md`. Local-first, no account/cloud, no card payments. Bank access only through a direct official API explicitly permitting this iOS client. Any backend/server, intermediary, or bank-data aggregator is excluded. CSV is a fallback where direct access is unavailable. External AI is deferred.

## Existing implementation state

- `MoneyCore` builds. It contains kopeck-safe money values, purchase checks, scheduled-item expansion, CSV parsing, recurring-payment suggestions, and a spending-history estimator.
- `swift run moneywise-checks` passes 380 behavior checks; `swift run moneywise-demo` demonstrates an unsafe purchase result.
- SwiftUI source includes overview, purchase check, transaction add/edit, CSV preview/import, opt-in recurring suggestions, manually maintained accounts/balances, budgets, debts, goals, plan items, reminders, Face ID/passcode lock, amount hiding, and local deletion.
- CSV does not update a bank balance. Importing a statement only adds transactions; balance must be entered separately.
- Category corrections can be explicitly saved as a local normalized-merchant rule and are applied to future purchases only; dedicated income/refund/transfer/fee categories are rejected for purchases, and refunds, income, and transfers retain semantic categories. Legacy invalid merchant rules are ignored. Rules are included in full local data deletion.
- If legacy data contains duplicate category rules for one normalized merchant, imports now choose the rule with the latest `updatedAt` (with a deterministic category tie-break). Saving a correction updates the newest rule and deletes stale duplicates in the same SwiftData transaction.
- Income source is preserved: manual income supports parent support/general income; CSV marks parent support only for explicit family wording, and otherwise uses general income.
- Dashboard has a color-and-text plan status. Without a sufficiently reliable variable-spending estimate, the status and purchase check report insufficient data.
- Dashboard includes weekly, monthly, since-last-income, and custom date-range spending totals, daily/category charts, and comparable-period comparisons where loaded history permits. Custom ranges are bounded to the existing 120-day query; no comparison is invented if the complete prior interval is unavailable.
- Savings goals can now be edited: title, target, confirmed saved amount, monthly contribution, first contribution date, and target date are saved together with the linked plan. Contribution count uses exact kopeck arithmetic and the available monthly horizon; a fully funded goal schedules no additional contributions.
- Finite goal plans support an exact final occurrence amount, so a goal of 1,000 ₽ with 300 ₽ monthly contributions reserves three 300 ₽ payments and one 100 ₽ payment rather than 1,200 ₽.
- Long-lived weekly, monthly, and yearly plans jump directly to the first relevant calendar occurrence instead of replaying every historical recurrence; finite plans still account for elapsed occurrences when deciding whether they are exhausted.
- Forecast expansion and local payment reminders use the same anchored recurrence-date function, so reminders preserve month-end and leap-day schedules consistently with financial projections.
- Purchase check accepts category, planned status, and date, compares the category budget against included-account month-to-date outflows, and includes the selected date in the forecast. Dates before today or at/after expected income return insufficient-data guidance. Planned status is explanatory only and never weakens the cash-flow check.
- No direct API adapter, bank OAuth, account aggregation, external/local AI, backup export/restore, OFX/QFX, or bank-specific CSV profile is implemented. The user has clarified that automatic bank sync is required for the MVP and daily CSV upload is not acceptable.
- Rechecked official bank documentation on 2026-10-29. Sber statement API needs SberBusiness ID, user consent, and the `GET_STATEMENT_ACCOUNT` scope; its official scenario is explicitly for a company user and account access is consent-scoped, so eligibility for the user's personal retail account remains unproven ([statement API](https://developers.sber.ru/docs/ru/sber-api/specifications/statement/transactions), [official scenario](https://developers.sber.ru/docs/ru/sber-api/scenarios/rko/statements/overview)). Alfa documents individual-customer account and operation endpoints, but activating Alfa API requires signing the IT interaction agreement in Alfa-Business and assigning developer access; current terms do not establish that this standalone personal iOS app can register without that business integration ([Alfa API onboarding](https://developers.alfabank.ru/products/alfa-api/documentation/articles/connection/articles/onboarding/onboarding), [operations endpoint](https://developers.alfabank.ru/products/alfa-api/documentation/articles/operations-history/articles/operation-details/v1/operation-details)). No public consumer transaction-history API for Ozon Bank was found in its official developer/help catalog; this is an evidence gap, not proof that no private offering exists ([Ozon developer/help catalog](https://docs.ozon.ru/main/)). Do not enable any adapter until bank confirms this exact personal native-client use case and no-server token flow.
- CSV import now rejects files over 20 MiB, statements over 100,000 rows, over 100 columns, and fields over 10,000 characters; it checks file size before reading and parses off the UI thread. Logical-record scanning walks the String's UTF-8 view rather than allocating a byte or `Character` array for the whole file. Import preview can scope source IDs to a chosen local account; without a selected account, IDs remain tied to the selected file. Explicit provider transaction IDs suppress duplicates within the selected account, while stable row fingerprints remain the fallback. Changed provider data is surfaced as a preview conflict and is never silently written over an existing record. CSV remains a fallback, not automatic sync.
- Confirming a CSV import now writes transactions and selected recurring plans from one app-wide SwiftData model actor with one explicit save; account existence and current source IDs are rechecked before insertion, so stale previews across app windows do not duplicate rows. Recurring suggestions are recalculated against rows that remain new. The preview shows a saving state while writes run off the UI actor. Actor persistence and UI responsiveness still need full iOS runtime verification.
- `MoneyWise.xcodeproj` is syntactically valid and the iOS source parses, but no Xcode/iOS SDK is installed here; iOS type-check/build/simulator/device flows are unverified.
- App files use the iOS default-data-protection entitlement set to `NSFileProtectionComplete`; the store directory and existing files are assigned complete protection and excluded from backups before SwiftData opens them. The entitlement is not signed/validated in this environment. The LAContext screen lock remains a convenience UI barrier rather than cryptographic database encryption.
- When the optional Face ID/passcode lock is enabled, the app now clears its unlocked state on both `inactive` and `background`, then authenticates on return to `active`; this is intended to cover the finance screen before the app-switcher snapshot. Scene lifecycle ordering and snapshot behavior still require iPhone verification.
- SwiftData startup errors now produce a retry screen instead of terminating with `fatalError`; the failure/retry interaction remains unverified until a full iOS build/runtime is available.
- Full-data deletion now also removes delivered notifications and app-local display preferences; it attempts to restore the original app icon and keeps the settings screen open with a separate message if that cosmetic reset fails after data deletion.
- The home query is now bounded to recent transactions, while the full operations history is paged in batches of 100 with account/category filters, merchant search, and edit/delete preserved. CSV duplicate-ID lookup runs in a dedicated SwiftData model actor with an import-preparation indicator rather than materializing all rows in the root screen.
- The cinematic brand intro is persisted as a one-time first-launch experience; later cold launches open the finance screen immediately and proceed directly to the configured app lock. Full data deletion clears this presentation preference too.
- Account freshness uses the oldest enabled account. Account/transaction/plan/settings edit forms stage changes locally and commit only from their explicit save action; cancellation no longer writes the bound model.
- Settings balance is a fallback source only when no separate accounts exist, so it cannot be added twice to account totals. The account type list now includes cash; when accounts exist and a saved fallback balance remains, Settings explains that it is excluded and offers an explicit transactional conversion to a confirmed “Наличные” account.
- A goal-linked scheduled payment routes to the goal editor, keeping goal metadata, contribution schedule, and exact final payment synchronized.
- Deleting a linked payment detaches and clears that contribution on the goal while preserving the goal; deleting the goal itself still removes its linked plan.

## Goal audit (2026-10-29)

| Priority | Status | Evidence / remaining acceptance |
|---|---|---|
| P0 — financial correctness | **PARTIAL** | MoneyCore builds and 380 deterministic behavior checks pass, including end-of-day expected-income forecasting, rejection of purchases on the expected-income day, money bounds, forecasts, reserve accounting, transfer handling, account inclusion, settlement links, and import parsing. New CSV fingerprints preserve date-only and offset-free wall-clock identity across device timezones while ISO-8601 rows use their absolute instant. Older persisted timestamp-only fingerprints still cannot reveal the timezone used when imported; cross-timezone reconciliation for those pre-update rows remains unresolved. SwiftData-backed end-to-end calculations remain unverified. |
| P1 — native app behavior | **PARTIAL** | Debug/Release Simulator builds and an unsigned iOS-device Release build succeeded. UI tests passed for account/purchase persistence, no-history Horizon, two-step deletion, CSV import/deduplication, and create/persist/relaunch for a goal, budget, and debt (the latter three ran individually). SQLite confirmed imported data, planning records and linked plans, and a clean store after user-flow deletion. CSV picker file selection, planning edit flows, purchase-check UI, notification delivery/cancellation, privacy lock, signing/archive/install, and physical-device checks remain unverified. |
| P2 — bank access | **BLOCKED** | The user requires automatic sync and rejects daily CSV, while excluding all servers/intermediaries. Current official Sber onboarding requires a SberBusiness user and production mTLS certificate installed on a server; Alfa onboarding requires Alfa-Business, an organization agreement, a production TLS certificate and secret/API Key; no Ozon personal transaction API is publicly confirmed. No bank has confirmed a personal direct-iOS route. CSV exists as a fallback but does not satisfy the required daily experience. The blocker can clear only after a bank confirms the required native/on-device route or the user changes the no-server constraint. No license conclusion has been made. See `.agent/bank-api-eligibility.md`. |
| P3 — finance features | **PARTIAL** | Budgets, goals, debts, recurring payments, purchase checks, analytics, and reminders exist in source. Goal/budget/debt creation, linked-plan persistence after relaunch, and logical deletion are VERIFIED on Simulator; edit flows, purchase-check UI, and personal-history calibration remain unverified. |
| P4 — privacy/security | **PARTIAL** | Local-only/no-account architecture, privacy controls, deletion flow, and file-protection configuration exist. Signed entitlements, actual store attributes, device-lock behavior, erase/backup behavior, and a complete security review remain unverified. |
| P5 — AI helper | **DEFERRED** | User chose to defer external AI; local model exploration is future work. |
| P6 — performance/accessibility | **PARTIAL / UNVERIFIED** | Bounded UI queries and memory-aware CSV parsing exist, but VoiceOver and one-handed runtime usability have not been measured. Physical iPhone/iPhone 12 performance checks are outside the current Simulator-only scope. |

## Milestones and dependencies

1. Keep calculation/import model hardened with behavioral checks. (Current: implemented.)
2. Complete and review local iOS user flows and persistence behavior. (Current: account/purchase persistence, CSV parse/import/deduplication, goal/budget/debt creation and persistence, and two-step logical deletion VERIFIED on simulator; system picker selection, planning edits, notification, privacy-lock, and purchase-check flows remain UNVERIFIED.)
3. Build and run the Xcode project on iOS Simulator. (Debug UI flows and integrated Release Simulator launch are VERIFIED; unsigned device-SDK Release compilation is VERIFIED; broader acceptance remains in progress. Physical-device verification is outside current scope.)
4. Confirm a technically and contractually permitted **direct iOS-to-bank** route for each requested personal account (Sber, Alfa, Ozon, VTB, OTP Russia). Official public onboarding now demonstrates server/business prerequisites for Sber and organization prerequisites for Alfa; a personal Ozon API remains unconfirmed. No direct no-server route is verified. Do not count CSV as satisfying automatic sync or impose daily CSV as the product expectation.
5. Do not introduce any server, OAuth intermediary, or aggregator, regardless of consent or price. If a bank requires one, mark that bank unavailable for auto-sync and retain CSV/manual import as its fallback.
6. Add a real-bank adapter only after the bank confirms native-client OAuth, on-device token handling, scopes, history, and polling are allowed. Never ship a placeholder as a working connection.

## Acceptance criteria

- Purchase check does not count expected future income as spendable and accounts for dated recurring obligations, reserve, variable spend, debt repayments, and goals.
- Unconfirmed, missing, past, or zero-amount next-income data cannot define the safe spending or purchase-check horizon; return insufficient-data guidance instead of a confident estimate.
- The main screen's average daily spending limit preserves the reserve and goals across confirmed dated obligations and refuses stale/missing balance data; its label identifies it as an average based on the entered plan, not a guarantee against unplanned expenses.
- CSV import previews before persistence, avoids marking the account balance fresh, and does not auto-convert ambiguous transfers into internal transfers.
- User can maintain transaction categories, plans, budgets, debts, goals, and account assumptions locally.
- A corrected category is applied to future imported transactions with the same normalized merchant name only after the user enables the rule.
- Dashboard status is color-coded and does not call a plan safe when ordinary spending history is insufficient.
- Financial-horizon engine and screen do not expose an exact balance line, point estimate, or purchase scenario unless balance freshness and variable-spending history are reliable; dated events remain visible.
- Parent support is distinguishable from other income after explicit description detection or user selection.
- Probable recurring expenses are suggestions and become plan entries only after explicit selection.
- Core checks pass. iOS build and device behavior must be verified when Xcode is available.
- No deployed or bank-connected claim without live evidence.

## Verification methods

- `swift build --target MoneyCore`
- `swift run moneywise-checks`
- `swift run moneywise-demo`
- `swiftc -frontend -parse iOSApp/MoneyWiseApp.swift Sources/MoneyCore/*.swift Tests/MoneyCoreTests/*.swift`
- `xcodebuild` build/simulator UI flows only when full Xcode is installed.

## Progress / next action

As of the 2026-10-29 local pass, MoneyCore builds and all 380 behavior checks pass. Swift parser and Xcode project/entitlement lint pass; existing Command Line Tools linker search-path warnings remain. Implemented local flows include CSV preview/import, account-scoped deduplication, explicit internal-transfer pairing, budgets, debts, goals, subscriptions/plan reminders, purchase checks, weekly/monthly/since-income analytics, privacy controls, and deletion. The main screen calculates a maximum average daily outflow from fresh balances and dated obligations. Recent P0 fixes also isolate each goal's reserve, unify category outflow totals, reject malformed CSV amount grouping, non-ruble currencies, and ambiguous date/amount/currency columns, preserve deduplication for merchant descriptions containing fingerprint delimiters and previous transaction classifications, aggregate signed account balances without order-dependent intermediate saturation, keep non-balance edits from refreshing balance freshness, align the projection horizon with the exact requested day count, tie deficit dates to the matching lowest projected balance, apply cash-flow events exactly at their dated horizon point, place date-only expected income at the end of the selected day, reject purchases on that expected-income day until actual credit, classify bank fee rows separately from purchases and transfers, preserve confirmed transfer-pair accounting when edited, block confident spending estimates when next-income confirmation is missing or zero and when ordinary spend history is insufficient, suppress numeric horizon points from the core API itself when balance freshness or spend-history confidence is missing, hide `availableNow` when balance freshness is stale, and keep dedicated transaction categories from being assigned to ordinary purchases or budgets. The horizon screen now computes this projection once per body evaluation and passes the result to its child views. Full Xcode Release build succeeded, was installed and launched on iPhone 17 Simulator. The account/purchase SwiftData persistence flow is VERIFIED. Other simulator flows remain UNVERIFIED; physical iPhone/iPhone 12 performance checks are outside the current scope.

## Checkpoint 2026-10-29 — Reject malformed CSV amount grouping

- The amount parser previously removed every repeated comma/dot and every internal space, so malformed input such as `1,2,3` or `1 2 3` could be silently converted into a different bank amount. It now validates integer grouping widths, permits recognized decimal and thousands separators (including Russian spaces/NBSP and apostrophes), accepts currency markers only as suffixes, and rejects misplaced/mixed separators rather than guessing.
- Added regression checks for malformed comma/dot/grouped-space formats and embedded currency markers, plus valid apostrophe, ruble-suffix, and multi-group values. All 142 behavior checks pass; MoneyCore build, demo, Swift parsing, project/entitlement lint, and whitespace scan pass.
- This closes only parser-level correctness. Persistence and preview behavior still require iOS runtime testing. Full Xcode/iOS SDK remains unavailable; bank syncing remains constrained to explicitly permitted direct native APIs.
- Next: continue the P0 audit for other bank-data transformations and monetary sign normalization, then validate the import preview/save/reopen path in Xcode when available.

## Checkpoint 2026-10-29 — Preserve unbound deduplication for delimiter-containing descriptions

- Legacy classification fingerprint parsing assumed a fixed seven-field split. A valid merchant description containing `|` adds components and could prevent an unbound re-import from matching a previously imported row when its type is corrected (for example, income to incoming transfer).
- Fingerprints now validate and rewrite the fixed trailing fields from the end, leaving the variable merchant portion intact. Added a regression check with a multi-delimiter merchant and matching account namespace. All 143 MoneyCore behavior checks pass.
- Next: continue checking transaction fingerprint stability and import-to-dashboard transformations; full SwiftData persistence and iOS runtime remain UNVERIFIED without Xcode.

## Checkpoint 2026-10-29 — Resolve duplicate learned-category rules deterministically

- The import path converted all merchant rules to a dictionary with “newest wins,” but the `@Query` order was unspecified and the reducer actually kept the later array element. If legacy state had conflicting duplicate rules, an imported purchase could receive an arbitrary category and affect the wrong budget.
- Import now chooses the rule with greatest `updatedAt`, using category raw value as a stable tie-break. When the user saves a new merchant correction, the newest matching rule is updated and extra matches are removed in the same SwiftData transaction.
- All 143 core checks and Swift syntax parsing pass. The change is in the iOS-only SwiftData path; type-check, duplicate cleanup, rollback, and persistence still require Xcode/iOS runtime and are UNVERIFIED here.
- Next: continue examining bank-data normalization and locally persisted import integrity, then verify saved rules and imported categories through restart on an iOS simulator.

## Checkpoint 2026-10-29 — Make combined account balance order-independent

- `FinanceSnapshot.currentBalance` previously reduced signed account balances with saturating `Money.+`. Saturation is not associative: for `[Int64.max, Int64.max, -Int64.max]` kopecks it returned zero, although the true net is `Int64.max`. This could make a combined balance depend on account ordering when extreme/corrupt values occur.
- Added `Money.sum`, which accumulates signed values in `Decimal` and clamps only the final result; `FinanceSnapshot.currentBalance` uses it. Added regression checks for permutation invariance and genuine positive/negative final overflow.
- All 145 MoneyCore checks pass. The full iOS target is still not type-checked or run because Xcode is absent; account UI persistence and device behavior remain unverified.
- Next: continue P0 auditing of aggregate money calculations and keep the iOS runtime gate open until Xcode is available.

## Checkpoint 2026-10-29 — Do not refresh stale balances from unrelated edits

- Account edit saved `updatedAt = now` even when the user only renamed the account or changed whether it participates in planning. Settings also refreshed the manual balance timestamp whenever reserve, expected-income date, or lock preference changed. Those actions could make a stale balance appear fresh and enable an overconfident purchase verdict.
- Added a tested `BalanceUpdatePolicy`: the timestamp changes only when the amount changes or the user explicitly confirms the displayed balance. Account and settings UI now offer that explicit confirmation; unrelated edits preserve the prior timestamp. The first-time empty/manual-balance state remains unconfigured unless the amount is changed or explicitly confirmed.
- All 147 core checks pass. Swift syntax parsing is available, but the iOS-only UI/SwiftData integration and actual persistence remain UNVERIFIED without Xcode.
- Next: continue the P0 audit of all paths that update account balances/timestamps; then verify manual and account balances stay stale after unrelated edits and refresh only after explicit confirmation on simulator.

## Checkpoint 2026-10-29 — Make fallback balance versus cash accounts explicit

- The main snapshot uses a settings balance only when there are no account records at all. With one or more accounts, even a saved manual amount is excluded. Settings previously kept showing that amount under “current account balance” without telling the user it was ignored, which could understate spendable cash.
- Settings now states the rule when accounts exist, protects the displayed saved amount with the hide-amounts view, and offers an explicit one-step transaction to move it into a separate included “Наличные” account. The action clears the fallback flag/date only in the same successful transaction; the new account timestamp is refreshed because the button explicitly asks the user to confirm the sum. Repeated invocation is guarded. The account-type picker includes “Наличные” for future balances and manual cash tracking.
- Updated PRODUCT_SPEC with the non-duplication rule. Swift source syntax parses; MoneyCore remains at 147 passing behavioral checks. SwiftData transaction, UI state refresh, and account persistence require iOS runtime and remain UNVERIFIED without Xcode.
- Next: verify cash-account creation and fallback clearing after successful save/relaunch on iOS; keep auditing for cases where excluded accounts or unbound transactions could be omitted from available-money calculations.

## Checkpoint 2026-10-29 — Keep the spending forecast exact above Int64 totals

- `SpendingForecaster` summed historical outflows into saturating `Money` and then divided/multiplied via `Double`. If the 30-day transaction total exceeded `Int64.max`, the saturation occurred before division and could sharply understate the daily estimate; `Double` also loses individual kopecks at large values.
- The forecaster now accumulates positive kopecks in `Decimal`, divides by covered calendar days, applies the configured decimal multiplier, and rounds upward once at the end. It saturates only when the final estimate cannot fit in `Int64`.
- Added a regression with ten large entries whose exact total exceeds `Int64.max` but whose per-day estimate still fits. All 148 core checks pass; MoneyCore builds, Swift parsing, and project/entitlement lint pass. iOS runtime remains unverified without Xcode.
- Next: continue auditing deterministic cash-flow calculations for any other saturation-before-normalization or floating-point rounding paths.

Unverified/blocked: full iOS target compilation, SwiftData migration/persistence, simulator/device interactions, Face ID, notifications, and performance on iPhone 12 cannot be established without full Xcode/iOS SDK. No direct API for personal accounts is authorized/verified for the requested banks; the user excludes any server, intermediary, aggregator, scraping, and credential collection. The questionnaire is at `.agent/bank-api-eligibility.md`; do not implement an adapter until a bank explicitly approves native iOS access. CSV is the working local fallback, not automatic synchronization. External AI remains deferred by user choice.

Next: continue P0 audit of bank-data normalization and the import-to-dashboard path; then run the complete iOS build and persisted-store/device scenarios in an environment with Xcode. Reassess bank integration only after an official response or new public documentation establishes a permitted direct route.

## Checkpoint 2026-10-29 — Balance freshness and bank constraints

- A P0 audit found that `checkPurchase` allowed a confident verdict when `dataUpdatedAt` was missing or in the future; the main-card freshness gate likewise accepted future timestamps. Added shared `FinanceDataFreshness.isFresh` validation (present, finite age, not future, at most 72 hours) and applied it to purchase checks, daily limits, and the main-card availability. Missing/future balance timestamps now fail closed.
- Added boundary checks for exact 72-hour freshness, absent/future timestamps, invalid freshness windows, fractional-kopeck values, impossible calendar dates, and zero-value transactions. Another CSV audit found that a debit and credit value were rejected as contradictory only when both were positive; signed conflicting rows could silently take one side. The importer now rejects any row with nonzero values in both columns, regardless of signs. Manual and imported ruble amounts now reject values that would be rounded to kopecks; extra decimal zeros remain accepted. CSV dates use a strict Gregorian formatter, and zero-value entries stay neutral instead of counting as income. The core suite now passes 134 checks. `swift build --target MoneyCore`, demo, Swift syntax parsing, project/entitlement lint, and whitespace scan pass after the final change.
- Rechecked the import persistence route in source: statement parsing and duplicate lookup happen before preview; account-scoped IDs are planned on account selection; imported rows and user-selected recurring suggestions are saved together; the preview closes only after save succeeds, and the context rolls back on error. This is source inspection only; SwiftData runtime persistence remains UNVERIFIED without Xcode.
- Rechecked bank materials and recorded details in `PRODUCT_SPEC.md`: Sber API is oriented to organization/partner integration; Alfa documents personal-account transaction methods but its documented onboarding requires Alfa-Business and an IT-interaction agreement; no published Ozon personal-account read API was found; VTB material found covers test data/business H2H rather than verified personal-account sync; no public OTP Russia personal-transaction API was found. This does not establish a blanket licensing conclusion. A permitted standalone iOS flow remains unverified, so no bank adapter is claimed or fabricated.
- `xcodebuild -version` confirms the selected developer directory is Command Line Tools and full Xcode is unavailable. No iOS type-check, migration, simulator, device, Face ID, notification delivery, or iPhone 12 performance claim is made.
- Next: audit budget/analytics aggregation and import-to-dashboard correctness. Ask each bank only if written access terms can establish direct iOS permission and credential/token handling. Full iOS runtime verification remains the primary engineering gate.

## Checkpoint 2026-10-29 — Unique category budget per month

- Found that the UI allowed multiple budgets for one category/month, while purchase advice selected the first matching record; duplicate budgets could make the displayed and purchase-check limits disagree or depend on unspecified fetch order.
- Saving a category budget now updates the existing current-month limit and removes duplicates in one SwiftData transaction. Purchase checking reports a clear data-integrity message instead of choosing an arbitrary limit when legacy duplicates are detected.
- Verification available here: Swift source syntax parse, core tests/build, and project lint. SwiftUI type-check and SwiftData duplicate cleanup/persistence require the unavailable full Xcode/iOS runtime and remain UNVERIFIED.
- Next: continue aggregation audit across budgets, analytics, included accounts and same-month boundaries; verify duplicate cleanup end-to-end in Xcode.

## Checkpoint 2026-10-29 — Show only active monthly budgets

- Found a month-boundary presentation mismatch: the section titled “Бюджеты на этот месяц” displayed every historical budget, while its used amount always came from the current calendar month. The budget section now filters records to the current month; its empty state refers explicitly to the current month, and swipe deletion resolves offsets against the same filtered array.
- This aligns the dashboard display with current-month spending and prevents deleting a different historical row due to indexing different collections.
- Swift syntax parse and core checks/build pass; SwiftUI/SwiftData behavior remains UNVERIFIED without full Xcode/runtime.
- Next: continue auditing monthly period comparisons and account filters across analytics and purchase advice; verify display period transitions and deletion on simulator/device once Xcode is available.

## Update 2026-10-29

- Hardened CSV processing with a 20 MiB byte limit checked before file read, 100,000-row, 100-column, and 10,000-character-field limits; parsing runs on a detached user-initiated task and uses mapped file reads.
- Added behavior checks for each limit and for separate-source deduplication. Core checks now total 30; MoneyCore build, demo, and Swift syntax parse pass. Full iOS build remains unverified because Xcode/iOS SDK is unavailable.
- Refreshed official-source research: Sber API documentation requires SberBusiness ID / SberBusiness integration for its API workflows; Alfa advertises personal-account information for partner clients, while its documented integrations are partner-oriented; Bank of Russia describes Open API data exchange as between organizations and participants subject to eligibility requirements. Public pages found for Ozon were seller/business API or 1C/business flows; no personal-account read API was found for Ozon or OTP, and VTB public material located does not establish a direct personal-account iOS API. This is not proof that none exists; each bank must explicitly approve standalone native iOS access without backend/partner credentials.
- Next actionable step: proceed with remaining local MVP gaps and treat auto-sync as blocked pending written bank confirmation; do not add scraping, notification parsing, undocumented endpoints, backend, or aggregator.
- Project-local Codex skill set installed via `skills-lock.json` on 2026-10-29 (21 iOS/Swift skills: architecture, SwiftUI, SwiftData, concurrency, security, charts, accessibility, tests, simulator, performance, localization, and on-device AI). Use relevant `SKILL.md` guidance, but gate APIs against this project's iOS 17 deployment target / Swift tools 6.0; the package examples may target newer OS/toolchains.

## Update 2026-10-29 — Dashboard spending analytics

- Added tested MoneyCore analytics for purchases by day and category over a half-open date interval. It excludes income, confirmed internal transfers, zero-amount entries, and transactions outside the interval; it fills days without spending with zero values.
- Added a weekly/monthly selector, daily bar chart, category donut chart, totals, and empty/privacy states to the home dashboard using Swift Charts APIs available on the iOS 17 deployment target. The chart query is limited to the current month plus a one-week buffer.
- Added the new core file to both SwiftPM and the explicit Xcode project source phase. Updated PRODUCT_SPEC current-state notes.
- `swift build --target MoneyCore`, all 37 `moneywise-checks`, `swiftc -frontend -parse iOSApp/MoneyWiseApp.swift`, `plutil -lint MoneyWise.xcodeproj/project.pbxproj`, and `git diff --check` pass. Full Xcode compile, simulator, dynamic type, and VoiceOver remain unverified because Xcode is unavailable.
- Remaining analytics gap: custom date ranges. Since-last-income analytics now uses actual posted income cycles; the expected future income date still controls forecast cards, not historical analytics. Next: continue tightening import/transaction data correctness, then revisit purchase planning flow; bank auto-sync remains gated on direct bank permission.
- Added purchase-date behavior checks: same-day midnight selection is counted from the present moment, past dates are rejected, and a purchase on/after expected income requires a later recheck. Core suite now has 37 passing checks. Category-budget UI uses a date-filtered SwiftData fetch; full UI persistence and type-check remain unverified until Xcode is available.
- Delete-all now fetches all model collections before mutation, deletes them in one SwiftData transaction, reports a failed fetch/save instead of claiming success, rolls back the context on failure, and cancels local payment reminders only after a successful commit. Physical erasure/backup sidecar behavior is still a device-level verification item.

## Update 2026-10-29 — Persistence error handling

- Replaced silent `try?` saves in account, transaction, goal, budget, debt, plan-item, and settings forms with explicit error presentation. A failed save keeps the editor open and displays the persistence error.
- Plan-item reminders are now scheduled/cancelled only after the associated persistence operation succeeds. Failed delete operations in the transaction, goals, budgets, debts, and plan lists are rolled back and surfaced through an app-level alert.
- Settings now saves its balance/reserve/income edits before dismissing rather than relying on implicit SwiftData autosave.
- Verified: `swift build --target MoneyCore`, all 37 `swift run moneywise-checks`, `swift run moneywise-demo`, `swiftc -frontend -parse iOSApp/MoneyWiseApp.swift`, `plutil -lint MoneyWise.xcodeproj/project.pbxproj`, and `git diff --check` passed. No silent `try? context.save()` remains.
- Full SwiftUI/SwiftData type-check, persistence-failure simulation, and device notifications remain unverified without full Xcode/iOS SDK.
- Next: close remaining core planning gaps and make a real iOS build/device verification the release gate; direct bank sync is still blocked on written bank permission and cannot be substituted with a server/aggregator.

## Update 2026-10-29 — CSV amount formats

- CSV amount parsing now handles ordinary, nonbreaking, and narrow nonbreaking spaces in grouped ruble values; Russian and English decimal/thousands separator combinations; Unicode minus; and accounting parentheses for negative values.
- Added three behavior checks covering six import formats. `swift run moneywise-checks` now passes 40 checks; MoneyCore build, demo, Swift syntax parse, and `git diff --check` pass.
- This improves statement ingestion but does not establish bank sync, bank-specific CSV compatibility, or imported-balance accuracy. CSV still never updates a manually maintained account balance.
- Next: inspect the CSV import review flow for category/transfer ambiguity and duplicate-import clarity; require a full Xcode build before treating iOS behavior as verified.

## Update 2026-10-29 — Money overflow safety

- Audited integer/decimal arithmetic in MoneyCore. Found Decimal-to-Int64 conversion could wrap a too-large positive currency amount into a negative value; transaction aggregation and forecast conversion also had unchecked overflow paths.
- `Money(rubles:)` now saturates at Int64 bounds instead of sign-wrapping, `Money.canRepresent(rubles:)` lets import reject out-of-range values with a row-specific error, and addition/subtraction/negation use overflow-safe saturation. The finance projection, daily forecaster, and dashboard analytics use the safe money operations and guarded floating-point conversion.
- Added seven behavior checks for exact bounds, positive/negative conversion overflow, addition/subtraction/negation overflow, out-of-range CSV rejection, and analytics overflow. Current suite after manual-input parsing checks: 50 passing checks.
- Verified `swift run moneywise-checks`, `swift build --target MoneyCore`, `swift run moneywise-demo`, Swift syntax parse across app/core/tests, Xcode project lint, and `git diff --check`.
- Manual financial fields now share the tested `Money.parseRubles` parser, reject malformed/out-of-range amounts, and show an explicit error. Debt payment count uses integer ceiling division instead of `Double` conversion.
- CSV confirmation now closes only after the import transaction saves successfully. On failure the SwiftData context rolls back, an error is shown, and the preview stays available to retry.
- Manual amount parsing lives in tested MoneyCore; malformed, localized, or out-of-range text is rejected by the money entry forms. Same-timestamp forecast events are deterministic and process outflows before uncertain-time inflows; a regression check confirms a required bill cannot be made safe by assumed same-day income ordering.
- Limitation: saturation prevents wraparound and crashes but does not carry an overflow flag to the UI for extreme/corrupt already-stored values. Full iOS build/device verification remains outstanding.
- Next: continue P0 audit with account-scoped transaction deduplication and purchase projection edge cases; verify UI compile and persistence flows in full Xcode. `xcodebuild -version` confirms the installed developer directory is Command Line Tools only, so a full iOS build cannot run in this environment.

## Update 2026-10-29 — Account-scoped CSV idempotency

- Import preview now lets the user choose an existing local account as the statement source. The selected account UUID is hashed into row source IDs, so moving/renaming the same statement file does not defeat deduplication. Unbound import remains possible but warns that files from a different path can duplicate rows.
- Exact repeated rows inside a statement retain occurrence indices, so two legitimate identical purchases remain separate while overlapping re-imports from the same source can be skipped.
- Added four core behavior checks for path-independent IDs, distinct IDs across accounts, preserving repeated same-file rows, and normalizing case/whitespace in merchant names. Current check count: 54.
- Verified `swift run moneywise-checks` (54 passing), `swift build --target MoneyCore`, Swift syntax parse, Xcode project lint, and `git diff --check`.
- Limitation: source IDs are conservative row fingerprints (timestamp/date, normalized merchant text, amount, and kind) rather than provider transaction IDs. Bank export wording/time differences can still evade matching; no explicit transaction-account relation or transaction filters are persisted yet. Full UI build and import persistence flow remain unverified until full Xcode is available.
- Next: improve import duplicate review/reporting and consider robust account association only with a verified SwiftData migration; continue purchase projection edge tests.

## Update 2026-10-29 — Import duplicate review

- `PreparedStatementImport` now returns new transactions and duplicate row indexes/counts using the same account-scoped identifiers used by persistence, including a compatibility check for the same file previously imported without account binding.
- CSV preview now marks matching rows, summarizes new versus skipped rows, and disables confirmation while duplicate analysis is running. Choosing another source account clears the old result and recalculates in a detached user-initiated task.
- Recurring payment suggestions are now generated from only the rows that will actually be inserted, preventing a repeated statement from proposing the same subscription again. Both duplicate matching and recurring detection run off the UI thread.
- Added six core checks for first-import counts, moved-file duplicate counts, account isolation, duplicate repeated rows, legacy same-path binding, and no repeated recurring suggestions. Current suite: 60 checks.
- Verified: 60 `moneywise-checks`, MoneyCore build, demo, Swift syntax parse, Xcode project lint, and `git diff --check` all pass. Full SwiftUI type checking, the app's live import UI, SwiftData failure handling, and scrolling/performance for a 100k-row preview remain unverified without full Xcode/device runtime.
- Next: bind imported transactions to account IDs in persistent storage only after planning and testing a lightweight SwiftData migration; continue edge-case tests for purchase projections and CSV dialects.


## Update 2026-10-29 — Monthly recurrence correctness

- Fixed monthly obligations drifting after a short month. Recurrence now derives each next month from the current occurrence's day-of-month rather than chaining a clamped date; e.g. Jan 31 → Feb 28/29 → Mar 31. Calendar expansion uses Gregorian calendar in the device time zone for stable finance dates.
- A negative `occurrencesRemaining` value is treated as exhausted instead of creating an unbounded recurring reserve.
- Added four financial behavior checks: day-31 return after February, leap-year February 29, a one-occurrence series expiring, and negative occurrence count. `swift run moneywise-checks` passes 65 checks. `swift build --target MoneyCore`, `swift run moneywise-demo`, Swift syntax parsing for app/core/tests, `plutil -lint MoneyWise.xcodeproj/project.pbxproj`, and `git diff --check` pass. Demo still reports 1,000 RUB free and a 200 RUB shortfall for the unsafe purchase.
- Full iOS build and live SwiftData/UI scenarios remain unverified: active developer directory is Command Line Tools and `xcodebuild -version` reports that full Xcode is required.
- Next: inspect transaction direction/transfer pairing and projection boundaries, then continue toward actual Xcode/device verification. Direct bank sync remains unverified and is still blocked by the user's no-server rule unless a bank confirms a permitted native client.


## Update 2026-10-29 — Sign validation in financial projections

- Hardened finance projections against malformed signed planning inputs. Negative protected/goal reserve, obligation amount, or daily variable-spend estimate is clamped to zero, preventing sign inversion from manufacturing spendable cash. Negative bank balances remain intact because they can represent actual debt/overdraft.
- Added two regression checks: available balance cannot be inflated by negative planning inputs, and a purchase that breaches the positive reserve remains unsafe under those malformed values. Core suite passes 67 checks.
- Verified `swift build --target MoneyCore`, `swift run moneywise-checks` (67 PASS), `swift run moneywise-demo`, syntax parse across iOS/core/tests, Xcode project lint, and `git diff --check`. Demo continues to show 1,000 RUB free and 200 RUB shortfall.
- Full iOS type-check/build, SwiftData persistence and device flows remain unverified because only Command Line Tools are installed; `xcodebuild` requires full Xcode.
- Next: audit transaction/account ownership and transfer matching so confirmed internal movements neither distort spending analytics nor disappear from individual account balances.


## Update 2026-10-29 — Persist imported account ownership

- CSV confirmation now persists the selected local account UUID on each imported transaction. The transaction list has an account filter and rows show the bank/account name. Transactions on disabled/deleted accounts are excluded from variable-spend forecasts, spending dashboard and category budgets; manual/unbound operations remain included. Deleting an account leaves history in the all-transactions feed and labels the now-unlinked account as removed.
- This adds an optional SwiftData model attribute (`sourceAccountID`) to an existing store. Existing transactions should remain nil; actual lightweight migration and launch against a pre-change store are UNVERIFIED because the environment has no full Xcode/iOS SDK. Do not treat source parsing as migration proof; this remains a required iOS gate.
- Verified in this environment: Swift source syntax parse, project plist lint, core test suite currently 67, and `git diff --check`. SwiftUI type-check, filter interaction, persistence across relaunch, deletion behavior, and migration are UNVERIFIED.
- Next: test this schema change against a copied pre-change store on iOS; test account filtering and forecast/budget behavior; then add transaction correction controls for direction/internal-transfer confirmation and verify those changes affect analytics without changing bank balances.


## Update 2026-10-29 — Count outgoing transfers and fees

- Confirmed that the edit screen already had a control for marking transfer-category operations as internal; corrected the previous progress note which assumed it was missing. The actual gap was that manually entered `.transfer` records were absent from analytics and variable-spend estimates, which only counted `.purchase`.
- Added `TransactionKind.isOutflow` for purchases, outgoing transfers, and fees. Analytics, daily spend estimation, and category budgets now include external transfers and fees while excluding confirmed internal transfers. Manual transfer entry defaults its category to transfers and requires explicit confirmation before treating it as internal; changing category clears that flag.
- Updated behavioral checks for external transfer, fee, and internal transfer cases. `swift run moneywise-checks` passes 67 checks. Swift source parse, MoneyCore build, demo, Xcode project lint and diff check still required after this UI/core change.
- Next: verify full iOS compile and transfer editing on simulator; then audit refunds/income and transaction status handling. SwiftData account-field migration remains a separate unverified gate.


## Update 2026-10-29 — Separate statement refunds from income

- Positive CSV rows with explicit refund/reimbursement wording (`возврат`, `возмещение`, `refund`, `reversal`) now become `.refund` / category `refunds`, not general income. Refunds remain excluded from income and expense analytics so they do not inflate recurring income or erase the original purchase from historical spend. The manual transaction form also offers a refund type and displays the amount as an inflow.
- Added compatibility matching for rows previously imported as `.income`: re-importing after the new classification skips the old row for both account-bound and unbound CSV flows.
- Added three checks for classification and both deduplication paths. `swift run moneywise-checks` prints 70 passing checks; MoneyCore build, demo, Swift parsing, project lint, and `git diff --check` pass. Demo continues to show 1,000 RUB free and a 200 RUB unsafe-purchase shortfall.
- Full iOS type-check, SwiftData migration, and UI interaction remain unverified without full Xcode.
- Next: audit refund-to-purchase linking and income categorization confidence; ensure manual transaction kind/category combinations cannot be contradictory.


## Update 2026-10-29 — Parse multiline quoted CSV records

- Replaced physical-line splitting with a quote-aware logical record scanner. Delimited fields may now contain semicolons and line breaks without creating phantom transactions; CRLF is handled as a single line break, including when Swift represents it as one `Character`. Unterminated quotes report the starting physical row as a dedicated import error.
- Added two behavior checks for a quoted multiline description followed by another transaction and for an unclosed quoted field. `swift run moneywise-checks` now prints 72 passing checks. `swift build --target MoneyCore`, demo, Swift syntax parse, Xcode project lint, and `git diff --check` pass. Demo remains 1,000 RUB available and 200 RUB shortfall for the sample unsafe purchase.
- Parser still uses a bounded in-memory character array for files up to the existing 20 MiB import limit; import remains off the UI thread. Full iOS type-check and runtime import flow are unverified without Xcode.
- Next: continue transaction status/reversal handling; refund-to-purchase linking should remain manual unless provider data offers a reliable original transaction identifier.


## Update 2026-10-29 — Transaction type correction controls

- Add/edit transaction forms support purchase, income, transfer, refund, and fee. Changing kind clears incompatible category and internal-transfer flags; only purchases can store learned merchant-category rules. Legacy adjustments remain explicitly unknown-direction and are not labeled as income/outflow.
- Verified: `swift run moneywise-checks` emits 74 passing checks; `swift build --target MoneyCore`, `swift run moneywise-demo`, Swift syntax parse across app/core/tests, `plutil -lint MoneyWise.xcodeproj/project.pbxproj`, and `git diff --check` pass. Demo reports 1,000 RUB available and blocks a sample purchase with a 200 RUB shortfall.
- Remaining: full SwiftUI type-check/build, SwiftData persistence/migration, bank API eligibility, and device UI flows are UNVERIFIED/BLOCKED by missing full Xcode and bank authorization.
- Next: continue P0 edge-case review of event ordering, reserve checks, and unreliable/ambiguous transaction data; then pursue full Xcode verification when available.

## Update 2026-10-29 — Anchor monthly recurrence to the original date

- A closer regression review found that the earlier Jan 31 → Feb 28 → Mar 31 assertion only counted two occurrences before Apr 1, so the buggy Feb 28 → Mar 28 sequence passed accidentally. Monthly expansion now retains the scheduled item's original day-of-month as its anchor. A bounded test through Mar 29 proves the March 31 payment is not reserved early. The core suite remains 74 checks, including the corrected regression.
- Verified after the fix: 74 checks pass, MoneyCore builds, demo shows the expected 1,000 RUB available and 200 RUB shortfall, all Swift files parse, project lint passes, and `git diff --check` passes.
- Full iOS build/runtime remains blocked by missing Xcode; only Command Line Tools are installed.


## Update 2026-10-29 — Anchor annual recurrence dates

- Reproduced a yearly recurrence drift: Foundation normalizes Feb 29 to Mar 1 when constructing a non-leap-year date, which could permanently move the series. Annual expansion now anchors to the scheduled month/day and clamps to the target month length; Feb 29 becomes Feb 28 in non-leap years and returns to Feb 29 in leap years.
- Added two boundary checks for the non-leap occurrence and return to the leap day. The suite now passes 76 checks. `swift build --target MoneyCore`, demo (1,000 RUB available; sample purchase shortfall 200 RUB), syntax parse, project lint, and diff check pass.
- Full iOS build/runtime remains unverified because full Xcode/iOS SDK is unavailable.


## Historical attempt — debt balance calendar estimate (superseded)

A calendar-based remaining-balance projection was briefly added, but it assumed every due installment had actually been paid and ignored interest. It was also absent from the explicit iOS Xcode source phase, so it was never a valid compiled app feature. The helper and its four checks were removed. Current behavior stores the last user-confirmed debt balance and requires manual update after actual payments.


## Update 2026-10-29 — Preserve negative account balances

- Manual account and fallback balance forms previously rejected negative values even though MoneyCore correctly represents overdraft/debt as negative balances. This could make a user enter zero and receive an overstated cash position. Forms now accept signed balances and explain negative values; reserve and expected income remain non-negative.
- Added checks that negative account balance yields zero currently spendable cash and an unsafe verdict even for a small purchase. All 82 core checks pass; build, demo, syntax parse, project lint and diff check pass.
- Full SwiftUI type-check and iOS interaction remain unverified without full Xcode.


## Update 2026-10-29 — Reserve obligations on the income date

- The home-screen available-cash calculation used a strict `< nextIncomeDate` cutoff, while purchase projection included same-date obligations and ordered outflows before uncertain-time income. It could therefore show money as spendable that the purchase checker correctly considered committed. The available-cash calculation now includes confirmed obligations due exactly at the next-income timestamp.
- Added a regression with a same-date obligation and expected income; the app reserves the outflow and does not add the expected deposit. All 83 core checks pass; MoneyCore build, demo, Swift parse, project lint, and diff check pass.
- Full iOS UI/runtime remains unverified without full Xcode.


## Update 2026-10-29 — Refresh direct bank API eligibility research

- Rechecked current official CBR, Sber, Alfa, and Ozon materials. CBR has Open API standards for consent/account information concerning individual accounts, while its FAQ frames the exchange as organization-to-organization and limits participants to organizations meeting criteria. This does not prove a standalone personal app is forbidden or establish that a license is required; the project's participant eligibility and bank approval remain unanswered.
- Sber API OAuth documentation says requests are made on behalf of a SberBusiness user. Alfa production onboarding lists integration registration, TLS certificate, and client_secret/API Key; no permission for an independent iOS public client with on-device PKCE was found. Ozon's official statement help describes exports through consumer channels, not a personal-account API. VTB's official Integration Bank-Client page requires a business settlement account/Business Platform and certificate, so it does not establish a retail API.
- No direct adapter was added. It would be unsafe and unsupported to assume that user consent alone authorizes this app or to embed a confidential client secret. Written bank confirmation is still needed for each personal-account API. Existing local CSV/manual functionality remains the fallback, and the no-server/no-aggregator requirement is unchanged.


## Update 2026-10-29 — Keep debt balances user-confirmed

- Replaced the automatic debt balance reduction by due date. The old approach assumed every scheduled payment was actually made and ignored missed installments/interest, so it could falsely report a lower debt. The stored balance now remains the last value entered by the user; a new edit screen updates balance, payment, and next due date after a real payment.
- Debt repayment plans now repeat monthly without an estimated payoff count while the confirmed balance is positive; entering zero stops the reserve. The UI explains that the user must update the confirmed balance and that interest is not calculated.
- Removed the unused `DebtBalanceProjection` helper and its four checks: it had only been in the Swift package and was not in the explicit iOS Xcode source phase. This removes a misleading estimate rather than treating a calendar assumption as a verified balance. The core suite now has 79 checks; all pass. MoneyCore build, demo, Swift parse, project lint, and diff check pass.
- Full iOS type-check and SwiftData edit/persistence flow remain unverified; `xcodebuild -version` confirms that only Command Line Tools are available.


## Update 2026-10-29 — Edit savings goals and recalculate contributions

- Added a goal editor to the existing goal rows. Saving updates target, manually confirmed saved amount, monthly contribution and dates, then updates or creates the linked monthly plan item so the reserve follows the edited goal. Reaching the target stops future reserved contributions; the user is told to update saved funds after an actual deposit.
- Moved contribution-count calculation into `MoneyCore/GoalContributionPlan.swift`; it uses integer kopecks and limits occurrences to monthly dates available before the target date. Added four boundary checks (already funded, round-up, deadline horizon, and first date after deadline). All 83 core checks pass.
- `swift build --target MoneyCore`, demo, Swift syntax parsing, project lint, and `git diff --check` pass. Full iOS compilation and SwiftData/UI persistence remain unverified because full Xcode/iOS SDK is not installed.


## Update 2026-10-29 — Prevent goal plans from reserving an excess final payment

- The prior finite recurrence reserved the full monthly amount on every occurrence, so a 1,000 ₽ goal with 300 ₽ payments could reserve 1,200 ₽. Scheduled items now carry an optional final-occurrence amount; MoneyCore applies it to the last finite recurrence, and the goal editor stores the exact remainder when the target is reachable by the deadline. If the deadline horizon is too short, the schedule retains the requested monthly amount and does not claim the goal is fully funded.
- Added checks for exact remainder math, exact totals/unreachable horizons, and the effect on spendable cash. All 86 core checks passed for this stage; core build, demo, Swift parse, project lint, and whitespace checks were run. iOS/SwiftData schema migration remains unverified without full Xcode and a device runtime.


## Update 2026-10-29 — Match goal deadlines to calendar recurrence dates

- Replaced whole-month-difference counting with an anchored calendar-date calculation. A 31 January schedule now correctly includes 28 February when that is the selected deadline, while a 27 February deadline does not include it. The anchor day is restored after short months to match FinanceEngine recurrence expansion.
- Final occurrence amounts are clamped to the regular non-negative monthly amount inside FinanceEngine so malformed stored values cannot increase a scheduled payment. Core suite passes 89 checks; MoneyCore build, demo, Swift parsing, project lint, and whitespace checks pass. Full iOS model migration/runtime remains unverified without Xcode.


## Update 2026-10-29 — Apply iOS data protection to the local store

- Added the app's default data protection entitlement at `NSFileProtectionComplete`. Startup now applies complete protection and backup exclusion to the store directory and existing regular database/sidecar files before SwiftData opens the store. The settings copy distinguishes this system file protection from the optional `LAContext` screen gate, which is only an additional UI barrier.
- Full entitlement signing, database open under file protection, locked-device behavior, and backup verification need a physical iPhone/full Xcode. This security change is implemented in source but not device-verified; no secrets or bank credentials are stored.
- Replaced the startup `fatalError` for container-creation failures with an explanatory retry screen that preserves the store and points the user to unlock the device. Swift parsing passes; runtime recovery remains unverified.


## Update 2026-10-29 — Complete local data deletion cleanup

- After the SwiftData deletion transaction succeeds, the app now removes both pending and already-delivered local notifications, clears its two app-local `UserDefaults` preferences, and attempts to reset the alternate app icon. If the system rejects the icon reset, the settings screen reports that app data is already deleted and remains open until the user acknowledges the partial cosmetic failure.
- Swift parsing, project/entitlement plist validation, all 89 core checks, and whitespace checks pass. The notification-center and app-icon behavior must still be exercised on an iPhone/full Xcode; SwiftData physical page/sidecar erasure is not claimed.


## Update 2026-10-29 — Bound transaction history work

- Removed the root view's unbounded transaction query. The overview reads the most recent 30 days; the operations tab requests up to 101 rows at a time, shows 100, and uses the extra row to determine whether another page exists. Account filtering, editing, and deletion remain available across pages.
- Added a category filter composed into the SwiftData descriptor, so it searches all matching history while still fetching only one page. Account and category filters can be combined.
- Added locale-aware merchant/recipient search to the same bounded descriptor. It composes with account/category filters and resets pagination as the query changes. Pending/posted status remains unavailable because no status field or reliable pending-status import exists yet; refunds remain an operation kind.
- CSV duplicate source IDs are fetched in a dedicated `@ModelActor`, and a progress indicator is shown while parsing and duplicate lookup run.
- Verified: Swift parser accepts app/core/test sources; 93 MoneyCore behavior checks pass; MoneyCore builds; Xcode project and entitlements pass `plutil -lint`; a targeted trailing-whitespace scan found none. Full Xcode type-check, actual SwiftData query behavior, large-history scrolling, and iPhone responsiveness remain UNVERIFIED. The workspace files are currently untracked, so `git diff --check` does not cover them.
- Next: model transaction status only when an import/API source can provide it, then obtain full Xcode/iOS SDK for compile/runtime verification and profile large-history/import behavior. Automatic bank sync remains blocked by the strict no-server rule until a bank confirms direct native iOS access.


## Update 2026-10-29 — Use conservative freshness for combined balances

- Found a false-freshness condition: the combined balance used the newest included account timestamp. A recent refresh on one account could hide another account older than the 72-hour confidence limit.
- Added `FinanceDataFreshness.oldestUpdateDate` and wired the snapshot to use the oldest included-account timestamp (manual-balance fallback remains limited to the no-accounts case). Added four checks: oldest-source selection, stale-source rejection despite another fresh account, acceptance when all sources are fresh, and preservation of the manual-balance fallback.
- Verified: 93 core checks pass, MoneyCore builds, Swift sources parse, and project/entitlements pass `plutil -lint`. Full app type-check and multi-account SwiftData persistence/UI behavior remain UNVERIFIED because full Xcode is not installed.
- Next: audit input validation and cross-account balance handling, then continue iOS integration verification when Xcode is available.


## Update 2026-10-29 — Keep edit screens transactional

- Found that several `@Bindable` fields in edit screens wrote to the SwiftData model while the user was still editing, before tapping Save. Leaving the screen could therefore persist changes the user intended to cancel.
- Account, transaction, scheduled-payment, and settings forms now stage editable values in local SwiftUI state. Save applies the staged values transactionally; category rules and reminders are changed only as part of/after a successful save. Required names are validated before commit.
- Verified: 93 MoneyCore checks pass, MoneyCore builds, app/core/test syntax parsing passes, and project/entitlement plists validate. UI cancel/persistence behavior and iOS compilation remain UNVERIFIED without full Xcode/runtime.
- Next: inspect save/cancel behavior in other model editors, then continue correctness and device integration checks.


## Update 2026-10-29 — Keep linked goal and payment edits consistent

- Found that a goal contribution appeared in the generic plan-payment list and could be edited independently. The generic editor clears the exact final installment and does not update the linked goal, allowing the schedule and target to diverge.
- Linked goal payments now open `EditGoalView`; its existing transactional save updates target/saved amounts, dates, monthly contribution, and linked plan/final installment together. Unlinked plan items continue to use the generic editor.
- Deleting a goal contribution from the plan list now atomically clears `monthlyContributionKopecks` and `planItemID` on the retained goal, then cancels its reminder after save. Deleting the goal from its own section remains a full goal-and-plan deletion.
- Verified: 93 MoneyCore checks pass, app/core/test sources parse, and project/entitlement plists validate. The SwiftUI navigation and persistence flow still need a full iOS build/runtime check.

## Update 2026-10-29 — Classify incoming and outgoing statement transfers

- CSV rows with transfer wording now parse as `.transfer` for outflows and `.incomingTransfer` for inflows, both in the transfers category. Incoming transfers no longer inflate earned-income totals or ask for an income source; outgoing transfers remain counted as cash outflow until the user confirms they are between owned accounts.
- Import deduplication recognizes the previous `.purchase` / `.income` classification for these rows, including unbound legacy IDs, so re-import after the classification correction does not create duplicate operations.
- Manual add/edit forms can represent an incoming transfer, and it is shown with the correct inflow direction. This does not automatically match or confirm the two sides of an internal transfer.
- Added four core checks for incoming transfer direction/category, outgoing classification, and old ID compatibility. Current suite: 97 checks.
- Verification in this update: `swift build --target MoneyCore`, `swift run moneywise-checks` (97 PASS), `swift run moneywise-demo`, Swift syntax parse for app/core/tests, project and entitlement `plutil -lint`, and targeted trailing-whitespace scan pass. Full iOS build and UI type-check remain UNVERIFIED because full Xcode/iOS SDK is unavailable.
- Next: audit cancellation, deletion, and orphaned goal-plan behavior; then continue with transaction matching and the remaining bank/API gates.

## Update 2026-10-29 — Protect debt reservations and cancel deleted reminders

- Deleting a plan row tied to an outstanding debt now shows a blocking explanation instead of removing the repayment reserve while retaining the debt. The user must edit the debt plan or confirm the balance is zero after actual repayment.
- Deleting a debt now requires a separate destructive confirmation that explains the repayment plan and reserved cash will also disappear.
- Deleting a goal or debt still removes its linked plan atomically; after the save succeeds, the app now also cancels the linked pending/delivered reminder. A failed save keeps notifications intact.
- Reminder cancellation now removes both pending and already delivered notifications with the payment's identifier, preventing stale delivered reminders from lingering in Notification Center.
- Verification: MoneyCore builds, all 97 core checks pass, the demo runs, app/core/test Swift syntax parse passes, Xcode project and entitlements lint, and the whitespace scan is clean. Full iOS type-check and runtime deletion/notification behavior are UNVERIFIED without Xcode/iOS runtime.
- Next: run the full available core and static checks, then audit transaction/internal-transfer matching and import semantics.

## Update 2026-10-29 — Suggest possible internal-transfer pairs

- Added a deterministic value-only matcher that proposes exact-amount outgoing/incoming transfer pairs across distinct account IDs within 72 hours. It retains all ambiguous matches, rejects missing/same accounts and invalid amounts/windows, and never mutates a transaction itself.
- Transaction editing now fetches a bounded set of nearby opposite-direction rows from SwiftData, labels candidate accounts, and asks for explicit confirmation before marking both sides internal. Suggestions are shown only for imported operations linked to existing, distinct accounts; manual/unbound rows stay unchanged.
- Added six core behavior checks for candidate identification, disqualification conditions, account inclusion, ambiguous candidates, deterministic ordering, and invalid matching windows. The core suite now has 103 checks.
- Verification: MoneyCore build/checks, demo, Swift source parse, Xcode project and entitlement lint, and whitespace scan pass. The SwiftUI/SwiftData type-check, query execution, pair-confirmation persistence, and device behavior remain UNVERIFIED because full Xcode/iOS SDK is unavailable.
- Next: install/use full Xcode to compile and exercise pair confirmation and deletion flows; then audit pair consistency if one side is edited or removed.

## Update 2026-10-29 — Preserve confirmed transfer-pair identity

- Added a separate local SwiftData `StoredInternalTransferPair` record for the confirmed outgoing/incoming transaction IDs. This avoids reconstructing a confirmed pair from ambiguous amount/date matches later.
- Editing a paired operation's date/type or removing its internal-transfer flag now clears the exact counterpart and deletes the pair in the same transaction. Deleting one operation does the same; disabling or deleting a linked account unpairs affected history; full local deletion removes pair records too.
- Existing individual internal-transfer flags without a pair record remain valid and are not guessed into a pair.
- Verification in this stage: Swift parser, MoneyCore checks (103 PASS), MoneyCore build, demo, project/entitlement lint, and whitespace scan pass. Adding the new model relies on SwiftData's compatible automatic schema migration and needs a real existing-store upgrade test; app compilation, migration, and all SwiftData persistence effects remain UNVERIFIED without full Xcode/iOS runtime.
- Next: validate the automatic schema migration and pair lifecycle on a copied pre-change store in Xcode, then continue the remaining iOS runtime and direct-bank API acceptance gates.

## Update 2026-10-29 — Detect recurring outgoing transfers safely

- Recurring suggestions now consider all positive external outflows, including transfers and fees, so a rent payment sent by bank transfer can be proposed for the plan. Confirmed internal transfers, zero amounts, and negative malformed outflows are excluded.
- Added checks for a recurring rent transfer, rejecting non-positive rows, and keeping an end-of-month schedule on the next month's final day (Jan 31 / Feb 28 / Mar 31 → Apr 30).
- The suite now passes 106 checks; MoneyCore builds, demo runs, app/core/test syntax parsing passes, and project/entitlement lint passes. Full iOS build and SwiftData migration/runtime remain UNVERIFIED without Xcode/iOS SDK.
- Next: review financial-history estimates for calendar coverage and robustness, then complete Xcode migration and UI/runtime checks when the SDK is available.

## Update 2026-10-29 — Keep category budgets consistent

- The purchase-check budget note previously counted only purchase transactions and could include rows from disabled/deleted accounts, while the budget dashboard counts all included-account outflows (including fees/external transfers) and excludes confirmed internal transfers. Unified the check with the dashboard's rules; unbound manual operations remain included.
- The dashboard's recent-transaction query previously began exactly 30 days ago, which could omit part of the first day of a 31-day month and understate its monthly budget use. It now begins at the earlier of current-month start and the 30-day history boundary. This keeps the full calendar-month budget and the 30-day variable-spend estimate complete at month boundaries while retaining a bounded query.
- Updated `PRODUCT_SPEC.md`. Static Swift parsing and a real iOS type-check are still required; Xcode/iOS SDK availability is unresolved in this environment.
- Next: run static parsing and core checks, audit spend-estimator calendar coverage, and continue to record the full Xcode limitation.

## Update 2026-10-29 — Bound the spending estimate by calendar days

- Variable-spending coverage now counts calendar-day boundaries instead of dividing elapsed seconds by 86,400, avoiding daylight-saving/time-of-day drift. Invalid estimator configurations (nonpositive windows/counts, coverage longer than its window, or a non-finite/under-1 safety multiplier) now return insufficient data rather than an invalid or understated estimate.
- The 30-day transaction query continues to cover both the complete current month and the estimator's full lookback at month boundaries.
- Added a core check for invalid confidence parameters. The suite now has 107 passing checks. MoneyCore build, demo, Swift parse, and Xcode project/entitlement lint pass; full iOS type-check and runtime remain UNVERIFIED because Xcode is unavailable.
- Next: continue the high-risk core review and obtain full Xcode/device verification when the toolchain is available; direct bank sync still requires each bank's permission for this no-server native app.

## Update 2026-10-29 — Calculate a safe average daily spending limit

- Added a deterministic MoneyCore calculation for the maximum constant average daily outflow through the next expected income. It simulates confirmed dated obligations and protects both the user's reserve and goal reserve. It does not add expected income to today's balance; invalid, missing, or stale balance/income data returns insufficient data. If the plan fails even with zero discretionary spending, it reports the existing shortfall and date.
- The dashboard now surfaces this amount and its assumptions in the main money-horizon card. The amount respects the existing hide-amounts privacy setting.
- Added checks for the exact safe daily limit, an unavoidable obligation shortfall, and rejection of stale/missing balance or income-date data. The suite now has 113 passing checks. Full SwiftUI compile and device behavior remain UNVERIFIED without Xcode/iOS SDK.
- Next: validate daily-limit behavior across calendar boundaries and then resume the remaining P0 projection/import audit; full Xcode/device verification remains required.

## Update 2026-10-29 — Use exact conservative prorating in projections

- Replaced `Double` multiplication of daily kopecks by elapsed seconds with overflow-checked integer decomposition. Partial days round up conservatively to the next kopeck; unrepresentable durations saturate instead of wrapping.
- Added a large-value half-day regression to prove the calculation does not lose kopecks or overflow. The suite now passes 113 checks; MoneyCore build, demo, Swift parse, and project/entitlement lint pass.
- This is arithmetic-level verification only. Full iOS type-check, SwiftData persistence, and on-device behavior remain UNVERIFIED without full Xcode/iOS SDK.

## Update 2026-10-29 — Isolate each goal's protected reserve

- The app previously clamped the combined goal reserve only after summing each goal's `min(target, saved)`. A malformed negative saved/target value could therefore cancel a different valid goal's reserve. Added a tested per-goal `reservedAmount` rule: invalid/nonpositive values reserve zero, and saved value is capped at the positive target before aggregation.
- Added three checks for a valid reserve, target cap, and malformed negative values. The suite now passes 116 checks; MoneyCore build, Swift parse, and project/entitlement lint pass. SwiftUI integration and persisted-data behavior remain UNVERIFIED without Xcode/iOS runtime.
- Next: continue P0 audit of plan/budget aggregation and the import-to-dashboard path, then close the full iOS runtime gate when a full Xcode installation is available.

## Update 2026-10-29 — Reuse the forecast timeline during daily-limit search

- The daily-limit binary search previously rebuilt scheduled occurrences and sorted cash-flow events on each kopeck search iteration. It now builds the timeline once and reuses it for each projected limit and the reserve-breach check, preserving the same event ordering (outflows before inflows at equal timestamps).
- All 116 MoneyCore checks pass after the refactor; the MoneyCore target builds and app/core/test Swift syntax parses. Xcode type-check and device performance profiling remain UNVERIFIED.

## Update 2026-10-29 — Prevent silent CSV row loss

- CSV import now strips a UTF-8 BOM before reading headers, recognizes Russian `Дебет`/`Кредит` columns, and safely handles omitted empty trailing columns. A nonblank row missing its required date/description/amount now fails with a row-number error instead of being silently skipped. Rows with both debit and credit set are rejected as contradictory.
- Added five checks for BOM, omitted trailing amount columns, debit-only row with omitted credit, short-row rejection, and contradictory debit/credit rejection. The suite now passes 121 checks; MoneyCore build, demo, syntax parse, and project/entitlement lint pass. UI import persistence remains UNVERIFIED without iOS runtime.
- Next: continue CSV source/amount and account aggregation audit, then verify the import preview-to-persistent-history path in full Xcode.

## Update 2026-10-29 — Preserve parent-support provenance on incoming transfers

- A positive bank row with transfer wording from a parent was correctly classified as an incoming transfer (so it did not inflate earned income), but its parent-support source was discarded. CSV and manual transaction forms now retain/select that source while keeping the transaction kind as `incomingTransfer`; the row label makes the distinction explicit and editing preserves it.
- Added a core check that explicit parent wording marks the incoming transfer as support, plus a check that an ordinary incoming transfer remains unmarked. All 122 core checks pass; Swift syntax parse and MoneyCore build pass. SwiftData persistence and form behavior remain UNVERIFIED without full Xcode/iOS runtime.

## Checkpoint 2026-10-29 — Unify outflow totals in dashboards and budget checks

- Extracted `SpendingAnalytics.totalOutflow` so monthly category budgets and the purchase-check budget note use the same rules as analytics: count positive purchases, external transfers, and fees in `[start, end)`; exclude income, refunds, and confirmed internal transfers.
- Added checks that shared totals match the analytics summary and correctly filter a category. The suite passes 136 checks; MoneyCore build, demo, Swift parsing, and project/entitlement lint pass. Whitespace scan is clean.
- Current limitations are unchanged: full iOS/Xcode type-check, SwiftData persistence, UI interaction, and on-device performance are UNVERIFIED because this environment has no full Xcode/iOS SDK. Bank syncing remains unimplemented until a bank explicitly permits direct native API access; no intermediary is allowed.
- Next: continue auditing account filtering and dashboard/budget consistency; obtain full Xcode to run simulator and persistence checks before calling the iOS product ready.

## Checkpoint 2026-10-29 — Keep debt reserves conservative and reminders editable

- Rejected the earlier finite debt schedule: allowing it to expire by calendar would assume unpaid installments were actually paid and could overstate free money. Debt plans now reserve the lesser of the confirmed balance and installment every month until the user updates the actual balance to zero. The amount never auto-decreases; interest is not estimated.
- Debt creation/edit now exposes a reminder choice. Reminder scheduling accepts a finite occurrence limit for finite plans and does not schedule beyond their remaining occurrences. Debt reminders remain recurring until the confirmed balance reaches zero; zero-balance debt plans no longer recreate notifications on app launch.
- Debt plan rows route to the debt editor so the linked balance/payment/plan cannot drift through the generic plan editor. Added two core checks for installment capping and zero/invalid values; 150 core checks pass.
- Next: continue the P0 review of transaction import persistence and bank-data transformation, then perform SwiftData and notification flows in full Xcode. Those iOS runtime flows remain UNVERIFIED here.

## Checkpoint 2026-10-29 — Recheck direct bank API eligibility

- Rechecked official Sber, Alfa and Ozon materials. Sber's documented statement flow is for SberBusiness companies; Ozon's discovered 1C DirectBank flow is a business accounting integration; Alfa's Open Banking documentation still does not establish that a personal user may connect this standalone iOS app without a backend or partner status.
- Recorded links and limits in `.agent/bank-api-eligibility.md` and `PRODUCT_SPEC.md`. This is not proof that personal APIs do not exist; direct access remains UNCONFIRMED until the banks answer for this exact app architecture. No adapter or connected-state UI was fabricated.
- Next: continue P0 review of import persistence/classification, then validate SwiftData and reminders using full Xcode/iOS runtime. `xcodebuild` is present only through Command Line Tools and reports that full Xcode is required.

## Checkpoint 2026-10-29 — Keep learned merchant rules scoped to purchases

- Import previously applied a saved merchant-category rule to every row with the same merchant text, including refunds and transfers. Learned rules now relabel purchases only, preserving semantic categories such as `refunds` and `transfers`.
- Added a core regression covering purchase correction and refund/transfer preservation. `swift run moneywise-checks` now passes 151 checks. The actual SwiftData import transaction remains unverified without full Xcode/iOS runtime.
- Next: continue the import transformation audit, then validate import preview → save → reopen and duplicate suppression on iOS.

## Checkpoint 2026-10-29 — Reject explicit non-ruble CSV rows

- When a CSV includes a currency column, the importer now accepts known RUB/RUR/643/ruble labels and fails the whole import on foreign or unknown currency. It does not silently treat 10 USD as 10 ₽ or perform a guessed conversion. Files without a currency column retain the existing RUB assumption and are not currency-verified.
- Added passing checks for explicit RUB acceptance and USD rejection; the suite now passes 153 checks. Full import preview/save/persistence remains UNVERIFIED without full Xcode.
- Next: audit multi-amount bank exports and require a clear amount mapping where operation and account-currency totals coexist.

## Checkpoint 2026-10-29 — Resolve multi-currency amount columns safely

- CSV header matching no longer blindly takes the first column containing «сумма». It prefers a single column explicitly labelled RUB/RUR/руб; otherwise, multiple amount columns require a clear debit/credit mapping and multiple currency columns are rejected. A single amount paired with a currency column is validated row-by-row. The importer selects an explicit ruble settlement amount over a foreign operation amount when present. The case is grounded by the official [Alfa statement API example](https://developers.alfabank.ru/products/alfa-api/documentation/articles/transactions/articles/statement/v1/statement), which shows a transaction amount in USD alongside its RUR equivalent.
- Added three regression checks: selecting a ruble settlement amount, rejecting ambiguous amount columns, and rejecting ambiguous currency columns. Combined with RUB acceptance and USD rejection, `swift run moneywise-checks` passes 156 checks.
- Next: verify real bank-export headers against sample statements from the user's banks; without samples and full Xcode, source format coverage and persistence remain UNVERIFIED.

## Checkpoint 2026-10-29 — Prefer operation dates and common Russian CSV headers

- The parser now recognizes payment-purpose and counterparty headers in Russian/English. If multiple date columns exist, it chooses a unique operation/transaction date; if no date is clearly the transaction date, it rejects the file instead of silently using a statement or settlement date.
- Added checks for Russian `Дата операции / Назначение платежа / Дебет / Кредит` headers, choosing an operation date over a statement date, rejecting unresolved multiple dates, and rejecting a value date without a transaction date. The suite passes 160 checks.
- No real Sber/Alfa/Ozon CSV samples are present in the workspace. Header compatibility with actual exports and SwiftData persistence remain UNVERIFIED; next action is to validate redacted sample headers, then perform full Xcode import/save/reopen flows.

## Checkpoint 2026-10-29 — Parse timezone-aware CSV timestamps

- Added ISO-8601 parsing with explicit offsets and fractional seconds before the existing local date formats, preserving the bank's actual timestamp instead of interpreting it in the device's current timezone.
- Added a regression with `+03:00` and fractional-UTC timestamps. The suite passes 161 checks; MoneyCore builds. Real export compatibility and full iOS persistence remain UNVERIFIED without bank samples and Xcode.

## Checkpoint 2026-10-29 — Lock finance UI before app-switcher capture

- The optional screen lock now clears the unlocked state when the app becomes `inactive` as well as `background`, and still re-authenticates on `active`. This targets app-switcher snapshot exposure; it does not encrypt the SwiftData store.
- `swiftc -frontend -parse` passes; MoneyCore and all 161 behavior checks remain green. The actual iOS lifecycle ordering and snapshot result are UNVERIFIED because full Xcode and an iPhone runtime are unavailable.
- Next: continue reviewing account/import invariants and validate the lock and persistent flows on a full Xcode simulator/device.

## Checkpoint 2026-10-29 — Reduce peak memory while scanning CSV

- Replaced whole-file `[Character]` scanning with iteration over the String's UTF-8 view for CSV quote/newline syntax. This avoids a whole-file character/byte array at the supported 20 MiB limit while preserving Unicode field bytes, quoted multiline fields, CRLF, and malformed-quote line reporting.
- Existing behavior checks include Russian multiline text, CRLF, quoted separators, and unterminated quotes; all 161 checks pass after the parser change, as do MoneyCore build, Swift parsing, and project/entitlement lint. Device peak memory and latency still need measurement on iPhone 12.
- Next: audit import/account persistence and acquire redacted real-bank CSV samples for format verification.

## Checkpoint 2026-10-29 — Persist large CSV imports away from the UI actor

- Moved transaction and user-selected recurring-plan insertion into a model actor shared by all `WindowGroup` scenes. It validates the selected account, rechecks source IDs after the preview, recalculates selected recurring suggestions from newly accepted rows, applies saved category rules, saves once, and rolls back on failure. The preview disables repeat confirmation and cancellation while saving.
- Core behavior checks do not cover SwiftData, and this environment lacks full Xcode; therefore actor type-checking, persistence atomicity, and UI responsiveness remain UNVERIFIED despite syntax parsing.
- Next: obtain full Xcode and run import preview → save → reopen, duplicate suppression, and failure recovery against a disposable local store.

## Checkpoint 2026-10-29 — Recheck stale CSV previews before saving

- The statement writer is now created once with the app's `ModelContainer` and shared across every `WindowGroup` scene, serializing import writes within the app process. Immediately before saving, it reads current source IDs and removes rows imported since the preview; selected recurring suggestions are recalculated from the remaining new rows.
- Added core regressions for a stale preview containing repeated identical transactions, manual rows without source IDs, and an operation concurrently stored under its former transaction classification. MoneyCore now passes 164 behavior checks. App actor persistence and multi-window UI behavior remain UNVERIFIED without full Xcode/iOS runtime.
- Checked whether Command Line Tools could type-check the SwiftData actor as a fallback: macOS SDK exposes SwiftData declarations, but the `SwiftDataMacros` compiler plugin is absent, so even an isolated actor harness cannot expand `@Model`/`@ModelActor`. Full Xcode remains necessary for authoritative type-checking.
- Next: verify the shared writer, import/save/reopen, and failure rollback on a simulator/device; then continue the P0 account/import audit.

## Checkpoint 2026-10-29 — Audit account inclusion across planning and analytics

- Traced included-account balances and freshness, the recent-history spend estimator, dashboard/category outflows, and purchase-check budgets. They use the same enabled-account rule; source-less legacy/manual entries remain included, while transactions attached to disabled/deleted accounts do not enter planning or analytics. No correctness change was indicated by this audit.
- Re-ran `swift run moneywise-checks` (all 164 checks passed), `swift build --target MoneyCore`, Swift frontend parsing for app/core/tests, and `plutil -lint` for the Xcode project and entitlements. MoneyCore build emits an existing missing Command Line Tools framework search-path warning; it still succeeds.
- Full iOS build, SwiftData import persistence, notifications, lifecycle, and device performance remain UNVERIFIED: `xcodebuild -version` confirms full Xcode is unavailable. Next: install/point to full Xcode and verify CSV preview → save → reopen, stale duplicate suppression, rollback, and app flows; then use redacted real-bank export samples to validate CSV profiles. Automatic bank sync remains gated on each bank explicitly permitting a direct native client with no intermediary.

## Checkpoint 2026-10-29 — Static security review of local finance-data surfaces

- Completed Codex Security scan `361e1809-e046-4ac3-af1f-5da704354a5e` against snapshot digest `codex-security-snapshot/v1:sha256:9f19532b0d3826a7df6da41174e23f9f605d46952b762591a4f3acfe3f5c336c`. It found zero reportable source issues in the reviewed local-store, CSV-import, and local-data-flow surfaces. The report is explicitly `partial`; it excludes local browser/build/design artifacts and defers broader source coverage and device/runtime validation. The workbench also warned that the target became unavailable during the scan and results belong to the original snapshot.
- Static evidence reviewed: local-only SwiftData configuration with CloudKit disabled; file-protection and backup-exclusion setup; optional device-owner screen lock; security-scoped CSV access and importer resource limits; generic notification content; full-delete transaction and no product-source network/API clients or embedded app credentials. Credential-pattern hits in bundled development references were code examples, not app credentials.
- No signing, SwiftData sidecar/migration, Face ID lifecycle, or app-switcher claim is treated as verified. Full Xcode/iOS runtime remains the next release gate; the app goal remains open.

## Checkpoint 2026-10-29 — Compare dashboard spending periods

- Added shared MoneyCore period comparison and showed the result on the spending dashboard: selected week against the preceding seven days; month-to-date against the previous month through the matching calendar day. The dashboard query is bounded to 120 days for income-cycle detection. Empty current periods still show a useful comparison caption.
- Added calendar regressions for Jan 31 → December and Mar 31 → leap February; the suite now has 181 passing behavior checks. `swift build --target MoneyCore` and Swift frontend parsing for app/core/tests pass. Existing Command Line Tools linker search-path warnings persist.
- iOS SwiftUI/SwiftData predicate macro type-check, runtime rendering, and screen-reader behavior remain UNVERIFIED because full Xcode/iOS SDK is unavailable. Income-cycle analytics implementation is present but the iOS screen is not runtime-verified; custom-date analytics remain open.
- Next: obtain full Xcode and validate dashboard rendering on iPhone 12/simulator, especially the three-option period picker, no-income/one-income states, and long cycles capped by the 120-day query.

## Checkpoint 2026-10-29 — Add income-cycle analytics and fix projection horizon

- Added a «С поступления» dashboard mode. It finds positive posted income/external incoming transfers in the latest 120 days, groups multiple deposits on the same calendar date, excludes refunds and confirmed internal transfers as cycle boundaries, and compares the elapsed current cycle with the same duration of the preceding cycle capped at the next actual income. It never invents a comparison with only one income event.
- Corrected `FinanceEngine.horizon`: N days now means exactly N calendar days from the calculation timestamp, with one initial balance point and no duplicated final point. Hypothetical spending remains projection-only.
- `swift run moneywise-checks` passes 181 checks; `swift build --target MoneyCore`, Swift parse for changed app/core/tests, and `plutil -lint` for project/entitlements pass. `git diff --check` passes for tracked changes; the workspace files are untracked. The existing Command Line Tools linker search-path warning remains.
- Full Xcode/iOS type-check, SwiftData predicate macro validation, simulator/device runtime, and visual/accessibility checks remain UNVERIFIED. Custom date ranges remain unimplemented.
- Next: obtain full Xcode/iOS SDK and run build plus dashboard/import/persistence/lifecycle flows on simulator and iPhone 12; continue the P0 financial-data correctness audit before release.

## Checkpoint 2026-10-29 — Refresh official bank API eligibility evidence

- Rechecked current official Bank of Russia, Sber, Alfa, and Ozon pages. CBR publishes Open API methods/standards for natural-person accounts, but describes data exchange as organization-to-organization and participants as organizations meeting eligibility criteria; its consent platform is still in pilot. This confirms standardized retail-data scenarios, not eligibility of this personal standalone app or a licensing conclusion. See [CBR Open API and participant criteria](https://www.cbr.ru/fintech/api) and [CBR standards index](https://www.cbr.ru/fintech/api/prikladnye-standarty/).
- Sber's current authorization page says requests are made on behalf of a SberBusiness user; [Sber statement API](https://developers.sber.ru/docs/ru/sber-api/specifications/statement/statement-overview) alone does not authorize retail card access from a standalone iPhone app. Alfa's public catalog describes personal-account data in client/partner integration contexts. Ozon public developer materials show Seller/partner and business APIs, while consumer statements are available through its own app/site; no permitted personal-account native-client API was confirmed.
- Updated `PRODUCT_SPEC.md` with this distinction and preserved the user's no-server/no-intermediary rule. No API adapter was implemented or presented as connected. Public-source review does not replace written bank approval for this exact client architecture.
- Next: request written native-client eligibility from each bank if the user decides to pursue direct sync; meanwhile validate the local statement-import flow in a real Xcode simulator/device.

## Checkpoint 2026-10-29 — Match reserve deficit amounts to their dates

- The purchase and daily-limit calculations previously paired the deepest projected deficit with the first date the reserve was crossed. With multiple future obligations, the amount and displayed date could refer to different points. The engine now carries the minimum projected balance and its date together; both checks report the deficit at that same lowest point.
- Updated purchase/forecast wording to describe the worst projected point rather than claiming the deficit occurs before a specific obligation.
- Added regressions with sequential payments where the second creates the deepest deficit, goal-contribution deferral that fails to cover a later obligation, and exact rechecking of the goal-change option. Fixed an invalid optional-map expression in the same test file. `swift run moneywise-checks` passes 188 checks; `swift build --target MoneyCore`, Swift parse for app/core/tests, and `plutil -lint` for project/entitlements pass. Existing linker search-path warnings persist.
- Full iOS build/runtime and UI wording verification remain UNVERIFIED without Xcode. Next: continue the P0 cash-flow audit and run simulator/device acceptance when full Xcode is available.

## Checkpoint 2026-10-29 — Clear the remaining local appearance preference on deletion

- A source audit found that full-data deletion cleared hidden-amount and app-icon preferences but left `okaneyan.appearanceMode` in `UserDefaults`, despite the deletion flow and roadmap promising to clear app-local display preferences. Deletion now removes this final appearance preference too; removing the key restores the documented default theme.
- Rechecked the current official bank boundary: CBR says Open API exchange is between organizations meeting participant criteria; Sber's statement API requires `GET_STATEMENT_ACCOUNT` and its OAuth/access flow is explicitly SberBusiness-oriented. Alfa's personal-account and Open Banking APIs are presented in partner/TPP contexts, but public material does not establish an allowed direct standalone iOS flow. Ozon consumer help documents manual statement retrieval, not a public personal-account API. This does not establish that a license is definitely required; no direct adapter can be marked permitted without each bank's answer. Sources: [CBR Open API participant criteria](https://www.cbr.ru/fintech/api), [Sber statement API](https://developers.sber.ru/docs/ru/sber-api/specifications/statement/transactions), [Alfa API catalog](https://developers.alfabank.ru/), [Alfa statement API](https://developers.alfabank.ru/products/alfa-api/documentation/articles/transactions/articles/statement-ob/v1/statement-ob), [Ozon statement help](https://docs.ozon.ru/common/oplata/bank-statements/).
- `xcodebuild -version` still fails because the selected developer directory is Command Line Tools, so the iOS deletion flow and settings persistence remain UNVERIFIED. Next: continue P0 review of import/account invariants and perform full Xcode simulator/device acceptance when the iOS toolchain is available.

## Checkpoint 2026-10-29 — Show the real free balance in the money map

- The “Куда направлены деньги” orbit center contradicted its caption: it rendered total account balance while claiming to show free cash. The view now displays the calculated `availableNow` amount in the center, matching the list mode and surrounding explanation.
- The route previously calculated and presented free cash without the overview's freshness/history/date guard. It now passes no amount unless balance, forecast history, next-income date, and freshness are sufficient; both orbit and list views show an em dash with the specific reason instead of a potentially overstated number.
- This is an iOS UI/logic change. MoneyCore checks can verify underlying calculations, and Swift parsing can detect syntax errors, but SwiftUI type-check and the two rendered states remain UNVERIFIED until a full Xcode/iOS simulator is available. Next: run simulator assertions for fresh/reliable versus stale/insufficient data, and continue P0 import and account invariants.

## Checkpoint 2026-10-29 — Apply horizon events on exact day boundaries

- `FinanceEngine.horizon` previously consumed events only when `event.date < boundary`. A scheduled item or inflow at precisely the timestamp of a daily projection point was deferred to the next day's point, shifting the displayed cash flow and balance by one day. The horizon now includes events with `event.date <= boundary` in that point.
- Added a deterministic regression with an obligation exactly at the first daily boundary; it verifies both that day's `confirmedOutflows` and its projected ending balance. `swift run moneywise-checks` passes 189 checks, including the new regression.
- This fixes point-in-time projection alignment; calendar/UI rendering still needs simulator verification. Next: continue reviewing date-boundary and import/account invariants, and validate the graph with full Xcode when available.

## Checkpoint 2026-10-29 — Classify imported bank fees as fees

- Negative CSV rows whose descriptions identify a commission/service fee were previously imported as ordinary purchases or transfers, usually categorized as “Другое” or “Переводы”. This distorted fee analytics and category budgets. The importer now classifies outgoing fee rows as `.fee`/`fees`, including a transfer commission; refund wording still takes precedence for positive returned fees.
- Added a regression covering service fee, SBP transfer fee, and returned commission. `swift run moneywise-checks` passes 190 checks.
- Next: continue testing real bank statement header/description variants and verify import preview → save → history on iOS; no real bank samples or full Xcode runtime are currently available.

## Checkpoint 2026-10-29 — Keep fee re-imports idempotent across reclassification

- Fee rows now change classification from the previous `.purchase` result, and source fingerprints include transaction kind. Without compatibility handling, re-importing a bank statement after this update could add the old fee again. Scoped and unbound duplicate checks now map a new `.fee` fingerprint back to the previous purchase fingerprint; preparation and persistence-time duplicate exclusion share this compatibility rule.
- Added regressions for both account-scoped and unbound re-imports, plus an integrated check that imported fees affect total/category analytics while returned fees do not. All 193 MoneyCore checks pass.
- Next: verify import preview → save → reopen and duplicate suppression in a full Xcode simulator, then test against redacted exports from the user's banks. Those artifacts are not available in this environment.

## Checkpoint 2026-10-29 — Allow amount corrections without corrupting paired transfers

- Operation edit previously displayed the amount read-only, preventing correction of a misparsed or mistaken bank row. It now accepts exact positive ruble input using the same kopeck-safe parser as manual entry and persists the edited amount without changing the original import source ID, so re-import deduplication remains stable.
- A confirmed internal-transfer pair cannot have one side silently changed: the amount field stays disabled until the user explicitly unpairs it. Core `InternalTransferPairPolicy` also detaches a pair after an amount, date, direction, or internal-status change; both records then return to ordinary spending/income treatment. Added regression checks for unchanged and detached pair decisions. All 195 MoneyCore checks pass.
- SwiftUI form type-check, SwiftData persistence, confirmation behavior, and visual interaction remain UNVERIFIED because full Xcode/iOS runtime is unavailable. Next: verify edit/save/reopen and paired-transfer breakup on simulator, then continue core and persistence audit.

## Checkpoint 2026-10-29 — Require confirmation before using the income horizon

- The iOS snapshot always passed the configured next-income date to the finance engine, even when the amount/date pair was not confirmed. Although unconfirmed income was excluded from projected inflows, that earlier date shortened the planning horizon and could make “Свободно до поступления” too high by reserving fewer days of ordinary spending and obligations.
- `FinanceSnapshot` now carries explicit confirmation state (default false), the iOS layer only passes it as confirmed for a positive future amount and date, the overview hides the free-to-income figure until confirmation, and purchase checks/daily limits return insufficient-data guidance until the user confirms. The low-level available amount returns zero without a confirmed horizon. The plan screen uses the same positive/future/confirmed rule so its status cannot contradict the calculation. Settings explain why confirmation is needed. Regression coverage proves these safeguards.
- Verification: 198 MoneyCore behavior checks pass; MoneyCore build, demo, Swift parser, Xcode project/entitlement lint, and whitespace check pass. Existing Command Line Tools linker search-path warnings remain.
- Next: continue the P0 review of the forecast and ensure dashboard charts clearly distinguish confirmed inflows from assumptions. iOS type-check/runtime and device behavior remain UNVERIFIED without full Xcode.

## Checkpoint 2026-10-29 — Require reliable history for a point spending limit

- `safeDailySpendingLimit` used to calculate a number even when spending history was insufficient; the app supplies a zero placeholder in that state, which could make the estimated daily allowance look higher than reality. `availableNow` had the same failure mode when called directly.
- Both APIs now fail closed without a reliable ordinary-spend estimate. The UI already represents the daily limit as a result state; the free-to-income amount remains hidden behind the corresponding reliability gate. Added two regressions proving no-history returns insufficient-data/zero instead of a point estimate.
- Verification: 200 MoneyCore checks pass; MoneyCore build, demo, Swift parse, project/entitlements lint, and whitespace check pass. Existing Command Line Tools linker warnings remain; full iOS build/runtime remains unverified because Xcode is absent.
- Next: continue the P0 audit of forecast assumptions and ensure projection charts label confirmed versus uncertain values consistently; then pursue Xcode simulator/device acceptance when available.

## Checkpoint 2026-10-29 — Hide false precision in the financial horizon

- `FinanceEngine.horizon` correctly labeled projections uncertain when history or freshness was insufficient, but the iOS screen still rendered its exact balance line and final point estimate. The screen now suppresses the line, final amount, and purchase scenario controls unless the projection confidence is reliable. It explains what is missing and continues to show known balances, reserves, and dated events separately.
- Verification: all 203 MoneyCore checks pass; MoneyCore builds, demo runs, app/core/test sources parse, project and entitlements pass `plutil -lint`, and `git diff --check` is clean. The updated SwiftUI view cannot be type-checked or rendered without full Xcode/iOS runtime.
- Next: continue P0 audit for assumptions in projections and confirm that the main and horizon cards use the same reliability/freshness rules; then run the iOS build and UI states when Xcode is available.

## Checkpoint 2026-10-29 — Fail closed in the horizon API

- UI suppression alone did not protect other consumers of `FinanceEngine.horizon`; it still returned a full series and hypothetical-purchase result when the balance was stale or variable-spend history was insufficient, merely attaching an uncertain confidence label.
- The engine now validates balance freshness and reliable spend history before calculating any point series. Missing/stale inputs return an uncertain confidence, no points, and no hypothetical purchase. Added regressions for both stale balance and missing spend history.
- Verification: 203 MoneyCore behavior checks pass; MoneyCore builds, demo runs, Swift parsing, project/entitlement lint, and whitespace check pass. Full iOS type-check/rendering remains unverified without Xcode.
- Next: continue cross-screen reliability audit, then run simulator/device acceptance once full Xcode is available.

## Checkpoint 2026-10-29 — Compute the horizon once per view update

- `FinancialHorizonView` accessed a computed projection from confidence, chart, amount, date labels, and accessibility text. That could rerun the complete forecast several times during one SwiftUI body evaluation. The view now calculates one horizon value in `body` and passes it into confidence/chart/accessibility helpers.
- Verification: all 203 MoneyCore checks pass; MoneyCore builds, demo runs, app/core/test sources parse, project and entitlements lint, and whitespace scan passes. The SwiftUI refactor is not type-checked or profiled on device because full Xcode/iOS runtime is unavailable.
- Next: continue the cross-screen reliability and responsiveness review; measure on iPhone 12 after the iOS toolchain becomes available.

## Checkpoint 2026-10-29 — Reject stale balances in the available-amount API

- The overview and money-map screens guarded `availableNow` with freshness checks, but `FinanceEngine.availableNow` itself could still return a point amount from stale balance data. The core API now returns zero unless the balance timestamp passes the same 72-hour freshness policy used by purchase checks and daily limits.
- Added a regression proving a stale balance cannot produce an available-to-spend amount. All 204 behavior checks pass; MoneyCore build, demo, Swift parsing, project/entitlement lint, and whitespace scan pass.
- Next: continue auditing the boundary between source data and decision APIs; iOS runtime verification still needs full Xcode.

## Checkpoint 2026-10-29 — Keep transaction types and purchase categories consistent

- Manual forms and old merchant rules could assign income, refunds, transfers, or fees to an ordinary purchase. This left the operation counted as an outflow but misfiled it in category dashboards; some of those categories could not be budgeted at all.
- Added a core category eligibility rule used by merchant corrections and by add/edit/budget/purchase-check pickers. Invalid legacy purchase categories are normalized to “Другое” when edited, and incompatible saved merchant rules no longer relabel future imports. The edit screen still exposes the unpair control for any legacy transaction already marked as internal.
- Verification: all 204 MoneyCore checks pass, including the valid/invalid category correction regression; MoneyCore build, demo, Swift parsing, project/entitlement lint, and whitespace scan pass. SwiftUI/SwiftData type-check and persisted legacy-rule behavior remain UNVERIFIED without full Xcode.
- Next: continue P0 category/import consistency review and validate rule migration/import/save on an iOS simulator when available.

## Checkpoint 2026-10-29 — Preserve pending and posted operation status

- Added backward-compatible optional status to core and SwiftData transaction records; old rows with no stored status continue to behave as posted. CSV now reads Russian/English status headers, maps known pending/completed terms, defaults files without a status column to posted, and rejects unknown or ambiguous status values rather than guessing.
- Re-import preview now identifies a pending-to-posted transition, and the local writer applies that promotion to the existing source row transactionally without inserting a duplicate. Status promotion also resolves the prior fingerprint when the bank reclassifies an operation. The history view supports pending/posted filters and labels pending rows. Pending spending is excluded from posted analytics, forecasts, recurring detection, and income-cycle boundaries.
- Verification: all 214 MoneyCore checks pass, including status parsing, unknown-status rejection, backward-compatible decode, direct and legacy-fingerprint promotion, and analytics/forecast exclusions; app/core/test sources pass Swift syntax parsing; Xcode project and entitlements pass `plutil -lint`. Full Xcode type-check, actual SwiftData migration and persistence, and simulator/device behavior remain UNVERIFIED because this machine has Command Line Tools but no full Xcode or iOS SDK. An isolated migration attempt was also blocked because the SwiftData macro plugin is absent from Command Line Tools.
- Next: obtain Xcode for real iOS compile/migration acceptance; meanwhile continue reviewing import persistence, data deletion, and backup handling. Automatic direct bank APIs remain unverified and no server or intermediary is permitted.

## Update 2026-10-29 — Validate pending-status compatibility and toolchain limits

- Added regressions for CSV rows without a status column (treated as posted), older serialized transactions missing the new optional status, recurring-payment detection excluding pending rows, and promotion through a previous transaction fingerprint when a bank reclassifies the operation. The suite now passes 214 checks.
- Attempted an isolated SwiftData lightweight-migration and query test on macOS. The installed Command Line Tools expose the SwiftData API but do not include the `SwiftDataMacros` plugin required for `@Model`; the test cannot compile. This does not validate migration behavior. iOS and simulator SDKs are also absent, as are full Xcode tools.
- Official bank API recheck is recorded above. Sber's documented account statement scenario requires SberBusiness ID and is for company accounts; Alfa has individual-customer operation endpoints but its onboarding requires an Alfa-Business IT-integration contract; no official Ozon consumer account-history endpoint was located. These findings do not authorize an adapter; seek direct bank confirmation before implementing any connection.
- Next: continue static security/data-lifecycle audit and improve import correctness; iOS build, database migration on the actual app schema, and device acceptance remain blocked until full Xcode/iOS SDK is available.

## Checkpoint 2026-10-29 — Add optional double-flip amount privacy

- Implemented the privacy gesture already specified in the product requirements: an opt-in Settings toggle watches iPhone orientation only while the app is active, and two separated face-down transitions within 3 seconds toggle amount hiding. Repeated sensor events do not count as separate flips; the gesture resets when monitoring stops. A short haptic confirms the toggle, and full local-data deletion clears the new preference.
- Extracted the event-window state machine to `DoubleFlipPrivacyGesture` in MoneyCore and added checks for two flips, repeated orientation events, reset, and expiry. The suite passes 216 checks; Swift syntax parsing, project/entitlement lint, and modified-file whitespace scan pass.
- Device orientation delivery, haptics, iOS SwiftUI type-check, and iPhone 12 battery/performance are not verified without Xcode/iOS SDK. The feature is opt-in and the on-screen toggle and button remain available.
- Next: continue on-device-sensitive privacy and persistence work where meaningful, while retaining the Xcode/macro-plugin blocker as an explicit iOS acceptance gate.

## Checkpoint 2026-10-29 — Prevent substring collisions in CSV classification

- CSV transfer/refund/fee/category heuristics now tokenize case- and diacritic-insensitively and match complete words or phrases. This avoids false decisions such as `Метрополь` being categorized as transit, `Кафельный дом` as a cafe, or `Переводчик` as a bank transfer, while retaining explicit known merchant aliases. Phrase dictionaries are normalized once per process instead of for each transaction row.
- Added regression coverage for both collision cases and positive matches for Yandex Taxi, a coffee shop, and Yandex Plus. All 217 MoneyCore checks pass; app/core/test sources parse and project/entitlements pass lint. Performance improvement is based on reducing repeated normalization work; no before/after import benchmark has been measured.
- This remains deterministic heuristic classification; bank-specific profiles, category confidence/review marking, official bank synchronization, and full iOS runtime verification remain incomplete. Continue improving source-specific import reliability without inferring operation links from amount/merchant coincidence.

## Checkpoint 2026-10-29 — Resolve explicit refund links without heuristics

- CSV now accepts a bounded set of explicit Russian/English provider-operation ID headers and original-operation ID headers. Aliases and input headers go through the same case/diacritic-insensitive normalizer; ambiguous matching columns fail the import. IDs remain metadata and do not change the existing CSV deduplication fingerprint.
- Imported refunds resolve to a local transaction only when the source account is selected and exactly one same-account, non-internal outflow has the referenced provider ID. Missing/duplicate/cross-account candidates remain unlinked. Unresolved refunds are retried against local history after future imports; if a later import makes the match ambiguous, the local link is removed. The UI distinguishes an explicit source reference from a successfully resolved local link. Deleting the original operation or changing it into an inflow/internal transfer clears local links.
- Added parser checks for explicit identifiers and ambiguous headers plus core resolver checks for exact, same-account, unique matches and safe no-link cases. `swift run moneywise-checks` passes 227 checks; Swift syntax parse, project/entitlement lint, and modified-file whitespace checks pass.
- Actual bank exports do not yet confirm which headers these banks use. SwiftData optional-field migration, UI compilation and deletion/edit persistence, full Xcode build, and iPhone runtime remain UNVERIFIED because this environment lacks full Xcode and the iOS SDK. Next: verify the additive schema migration and transaction deletion/edit flows in full Xcode, then validate redacted Sber/Alfa/Ozon exports before claiming bank-profile compatibility.

## Checkpoint 2026-10-29 — Detect CSV and TSV delimiters safely

- Text imports now test comma, semicolon, and tab-separated header parses, selecting a unique widest result. If multiple delimiters yield the same multi-column header, the importer reports an explicit ambiguity instead of silently splitting data incorrectly. Quoted delimiters remain field content. The iOS picker already allows plain-text files.
- Added regression checks for a tab-separated row containing quoted commas/semicolons and an ambiguous header. `swift run moneywise-checks` passes 229 checks; Swift syntax parse, project/entitlement lint, and modified-file whitespace scan pass.
- Official Alfa help pages describe CSV statement export, but the pages found do not document a stable header schema; an older Alfa Click help article also documents CSV download. Search in official Sber/Ozon materials during this pass did not locate personal-account CSV header specifications. This is a search result gap, not evidence that exports are unavailable. Sources: [Alfa Click statement formats](https://click.alfabank.ru/cs/groups/public/documents/document/alfa_help10_01.html), [Alfa file formats](https://alfabank.ru/help/t/sme/alfaclick/vipiska/vipiska/v-kakom-formate-mozhno-skachat-vipisku/), [Ozon Bank 1C DirectBank overview](https://finance.ozon.ru/blog/b2b/article/kak-podklyuchit-1c-direct-bank). Real redacted export fixtures are still needed to claim bank-specific compatibility; app/device verification remains blocked by missing Xcode/iOS SDK.

## Checkpoint 2026-10-29 — Reject CSV rows with extra fields

- A comma-delimited row containing an unquoted decimal-comma amount such as `-95,50` could previously split into extra fields while the parser consumed only the expected columns, silently recording `95 ₽` and dropping 50 kopecks. Rows with more fields than the header are now rejected with their row number. Correctly quoted decimal-comma values continue to parse exactly.
- Added regressions for both the correctly quoted amount and rejection of the unquoted form. All 231 checks pass; `swift build --target MoneyCore`, Swift source parsing, project/entitlement lint, and modified-file whitespace checks pass. Full iOS type-check and SwiftData runtime remain unverified without Xcode.

## Checkpoint 2026-10-29 — Deduplicate imports by explicit provider ID

- When a user binds a statement to a local account, preview and persistence-time duplicate checks now include an explicitly imported provider transaction ID. The ID is scoped to the selected account; account-less imports continue to use the stable file/fingerprint fallback and never join records across sources.
- A uniquely matched pending row is promoted to posted when a later statement reports it as posted, even if the bank changed merchant text or amount and the CSV fingerprint therefore changed. The write actor rechecks this at save time, including a pending row inserted after the preview was opened. Ambiguous duplicate provider IDs are suppressed as duplicates but are not status-updated.
- Added core regressions for changed-fingerprint duplicate suppression, pending-to-posted promotion by provider ID, stale-preview duplicate recheck, and conflict preservation of both old/imported merchant, amount, date, and kind. A unique provider-ID match with changed data is surfaced in the import preview; the stored row is never overwritten, and the user is directed to review/correct it manually after import. `swift run moneywise-checks` passes 234 checks; the demo, Swift parsing, project/entitlement lint, and modified-file whitespace checks pass. iOS/SwiftData actor type-check and actual persistence remain UNVERIFIED without Xcode/iOS SDK.
- Next: verify writer actor, schema migration, preview, and save/reopen on an iOS runtime. Automatic source reconciliation and real bank CSV compatibility need separate validation with redacted bank exports. Full Xcode/iOS SDK is not installed in the current environment.

## Checkpoint 2026-10-29 — Bound historical recurrence work

- Forecasting a recurring plan previously advanced one week/month/year at a time from its original due date to today. Long-lived or malformed old plans could therefore add unnecessary calendar work to purchase checks and dashboard forecasts. The engine now estimates the calendar index, jumps to the nearest candidate occurrence, and adjusts around the requested start date before expanding only occurrences inside the forecast horizon.
- Added checks showing an old weekly plan reserves only near-term occurrences, old finite plans whose occurrences have elapsed reserve nothing, and old monthly/annual schedules preserve month-end and leap-day dates. `swift run moneywise-checks` passes 238 checks. The complexity reduction follows from the bounded jump plus horizon expansion; no device benchmark has been run.
- Next: continue P0 correctness review and verify the native project, recurring schedules, and save/reopen behavior in full Xcode. The current environment still has no Xcode/iOS SDK, so those iOS runtime checks remain UNVERIFIED.

## Checkpoint 2026-10-29 — Skip the cinematic intro after first launch

- The branded intro was recreated on every app process start and blocked the finance screen for its full animation and exit transition. It now runs once, records that completion locally, and is skipped on later launches; configured Face ID/passcode behavior remains active because the root view receives the completed-intro state. Full data deletion clears the intro preference.
- Swift source parsing passes. This SwiftUI lifecycle change cannot be type-checked or measured on iPhone without full Xcode/iOS SDK; cold-launch timing and lock-screen ordering remain UNVERIFIED.
- Next: continue functional and privacy audits, then verify first launch, subsequent launch, lock, and deletion on an iOS simulator/device.

## Checkpoint 2026-10-29 — Scale the daily spending limit to the remaining horizon

- `safeDailySpendingLimit` previously capped its search at the current account balance, even though its result is a per-day rate over the exact time until income. This understated the limit when less than one day remained. It now expands an integer-kopeck upper bound until the projection breaches the protected plan, then binary-searches the safe rate; overflow is avoided by saturating the upper bound at `Int64.max`.
- Added regressions for a 12-hour horizon with a 1,000 ₽ balance (2,000 ₽/day maximum) and a confirmed 300 ₽ bill at the six-hour boundary (1,400 ₽/day maximum). All 240 checks pass; the direct built check executable completed in 0.30 seconds. Swift parsing, project/entitlement lint, and whitespace checks pass.
- Next: continue P0 cash-flow boundary review and check UI wording against the per-day rate definition. Full Xcode type-check, SwiftData integration, and device behavior remain UNVERIFIED.

## Checkpoint 2026-10-29 — Include date-only obligations due today

- Plan forms select calendar dates, but the engine compared a due date such as today at 00:00 against the current clock time. A payment due today could disappear from available-money and purchase calculations after midnight. One-time and recurring occurrences on the current calendar day are now retained and clamped to the current instant if their stored time has passed; future same-day times remain unchanged.
- Added regressions covering a one-time due-today reservation, purchase denial with its shortfall, the horizon's first daily outflow, and a recurring due-today payment. All 244 checks pass. SwiftUI and SwiftData behavior remain unverified until full Xcode is available.
- Next: continue P0 date-boundary and transaction/plan reconciliation review; verify the native forecast and import flows on a simulator/device when Xcode becomes available.

## Checkpoint 2026-10-29 — Share recurrence dates with reminders

- The forecast and notification scheduler had separate calendar arithmetic. Adding one month directly to a clamped 28 February date caused a 31st-of-month reminder to drift to 28 March even though the financial forecast correctly returned to 31 March. Added `ScheduledRecurrence.nextDate`, used by both MoneyCore expansion and the iOS reminder scheduler.
- Added a regression proving a January 31 anchor advances through February 28 and returns to March 31. All 245 MoneyCore checks pass; full iOS type-check and notification scheduling remain UNVERIFIED without Xcode/iOS runtime.
- The recurring-transaction detector now uses this same anchored calculation. A separate test covers inferred history of 31 December, 31 January, and 28 February producing a 31 March suggestion. All 246 MoneyCore checks pass.
- P0 lifecycle review found that posted imported transactions do not settle a matching planned obligation; the plan UI only edits or deletes a plan. Do not auto-settle by amount/date alone. Add an explicit user-confirmed reconciliation path with unambiguous transaction selection, accounting semantics, and safe persistence before treating actual payments as settled.
- Verification this turn: `swift build --target MoneyCore` and `swift build --product moneywise-checks` succeeded; `swift run moneywise-checks` exited 0 and printed PASS for the new regression; Swift frontend parse, project/entitlement lint, and `git diff --check` succeeded. Linker emitted existing Command Line Tools path warnings. `xcode-select -p` resolves to `/Library/Developer/CommandLineTools`; simulator, SwiftData migration/runtime and iPhone performance remain UNVERIFIED.
- Added a deterministic MoneyCore settlement policy and integrated the settlement ledger into `FinanceSnapshot` and all forecast occurrence paths: available-money, purchase checks/options, and horizon projections reserve only the unpaid amount. Fully settled occurrences are omitted. Snapshot decoding treats a missing legacy ledger key as empty. Tests cover partial/full settlement, duplicate and ambiguous IDs, pending/internal/overpayment rejection, forecast changes, and old JSON compatibility; all 254 checks pass.
- Follow-up decoder review found that defaulting a missing forecast-confidence bit to `true` would fail open for incomplete snapshot JSON. It now defaults to `false`, with a regression test; valid legacy snapshots that explicitly contain the bit preserve their saved value. All 255 checks pass.
- Added optional plan ID and scheduled-occurrence date to each stored transaction. The transaction editor now requires explicit selection of a plan and a date in that plan's recurrence. On save it rejects unposted/non-outflow/internal transactions, non-occurrence dates, stale account balances, duplicate use, and payments exceeding the unpaid occurrence. Clearing the plan selection removes the link; deleting a transaction removes it with its source row.
- Root snapshot loads only linked operations and revalidates the plan, occurrence, transaction status/direction, account-balance update time, duplicate links, and remaining amount before passing settlements to MoneyCore. Missing/deleted plans and invalid links are ignored safely. No automatic matching by merchant/date/amount was introduced.
- Added constant-time recurrence-date validation for weekly/monthly/yearly schedules and four regressions for recurrence, finite limits, and leap years. All 259 MoneyCore checks pass.
- Added a defensive ledger test: even a malformed stored settlement on a date outside the plan recurrence cannot reduce the obligation. The settlement occurrence calculation validates dates in constant time, and all 260 MoneyCore checks pass. The transaction editor now also prompts when the balance update time is missing, rather than showing that warning only for an older timestamp.
- For an unbound transaction, settlement freshness now uses the oldest timestamp among included account balances (or the manual-balance timestamp when no included accounts exist), matching the dashboard's combined-balance freshness rule. Full checks still pass at 260; Swift source parse, project/entitlement lint, and whitespace checks pass.
- SwiftData now has two optional attributes on an existing model, a shape intended for automatic migration; however the actual app schema migration, iOS type-check, editor interactions, and save/reopen have NOT BEEN VERIFIED. This environment has no full Xcode or iOS Simulator SDK, and its SwiftData macro plugin is missing. Do not claim persistence/migration acceptance until run against a copy of the existing store in full Xcode.
- Next: verify the additive SwiftData migration on an isolated copy of an existing store; test manual linking/unlinking, stale-balance rejection, edit/delete cleanup, recurring/partial payments, and forecast reload on simulator/device. If iOS type-check identifies API incompatibilities, fix them before proceeding.
- Plan, goal, and debt deletion now clear linked settlement fields in the same `ModelContext.transaction` as deleting the plan. Removing an account preserves its operation links; if the transaction's source account is gone, validation falls back to the oldest updated timestamp among the remaining included balances (or manual total), and still rejects links whose balance evidence predates the transaction. Account deletion therefore does not leave an invalid orphan relation.

## Continuation check 2026-10-29 — Reconfirm current verification and deletion coverage

- Re-read the product objective and current source rather than relying only on this checkpoint. Confirmed the active project target is iOS 17+, and the full-data deletion fetch/delete set covers all nine `@Model` entities; it also resets every persisted `StoredSettings` field and app-local UserDefaults preferences, cancels reminders, and restores the original app icon when possible.
- Current verification on this checkout: `swift run moneywise-checks` exits 0 with 260 PASS checks; `swiftc -frontend -parse` accepts app/core/test sources; `plutil -lint` accepts the Xcode project and entitlements; `git diff --check` is clean. These establish core behavior and source/config syntax only.
- Rechecked toolchain discovery: `/Applications` contains no `Xcode.app` or beta, Spotlight finds no Xcode bundle, `xcodebuild` requires full Xcode, and `simctl`/iOS Simulator SDK are unavailable. Consequently app type-check/build, SwiftData schema migration, persistence after relaunch, device UX, and iPhone 12 performance remain UNVERIFIED; no code-only check is substituted for them.
- Next: obtain/use a full Xcode installation and run the iOS acceptance matrix against both a clean store and a copy of the prior SwiftData store. Until then, continue only changes that have meaningful core-level evidence; automatic bank sync remains unavailable unless a bank permits the no-server native client.

## Checkpoint 2026-10-29 — Reject malformed populated debit/credit cells

- P0 CSV review found that separate debit/credit cells used `parseAmount(...) ?? 0`, so malformed non-empty values could be silently treated as blank and the opposite-side value imported with the wrong direction. Added strict parsing for populated cells and row-specific rejection. Blank cells remain zero, valid credit-only rows still import as income, and exporters that omit only the final empty credit cell remain compatible; missing non-trailing cells are rejected.
- Added core checks for valid credit with blank debit and for malformed debit and credit values. `swift run moneywise-checks` passes 263 checks; Swift parser, project/entitlement lint and `git diff --check` pass.
- Full iOS type-check, SwiftData import persistence and device behavior remain UNVERIFIED without full Xcode/iOS SDK. Next: continue the P0 import-sign/normalization review, then run the complete app acceptance matrix when the native toolchain is available.

## Follow-up 2026-10-29 — Reject ambiguous debit/credit headers

- Continued P0 review of CSV column matching. Duplicate debit or credit columns are now rejected as ambiguous instead of silently selecting the first. Credit detection no longer treats a `Кредитный лимит` column as an incoming-amount column.
- Added regressions for both duplicate directions and a credit-limit header. `swift run moneywise-checks` passes 266 checks; Swift parsing, project/entitlement lint and `git diff --check` pass.
- Full app/SwiftData runtime acceptance is still UNVERIFIED without Xcode/iOS SDK. Next: continue P0 statement interpretation review and then verify imports against redacted real bank exports; no bank-specific compatibility is claimed from synthetic fixtures.

## Follow-up 2026-10-29 — Treat explicit refund references as authoritative

- Import review found that a positive transaction with an explicit original-operation ID could still be classified as earned income when the description lacked refund keywords. The importer now reads the explicitly labeled reference before classification and treats a positive row with that reference as a refund. This keeps it out of earned-income and income-cycle calculations even when merchant text is generic.
- Added a synthetic regression with a generic merchant description and explicit original operation ID. `swift run moneywise-checks` passes 267 checks; Swift parsing, project/entitlement lint, and `git diff --check` pass.
- Real bank headers/semantics and SwiftData persistence remain unverified; no bank-format support claim is made from this fixture. Next: keep auditing P0 import classifications, then exercise the import/save/reopen path with redacted real statements and full Xcode.

## Follow-up 2026-10-29 — Classify from operation text when counterparty comes first

- A statement can contain both a counterparty and a detailed operation description, with the counterparty column first. Previously its name alone could hide transfer/refund/fee wording in the later operation description and misclassify a positive parent transfer as earned income. Classification and income-source inference now use the available operation-description/purpose/details fields; the displayed merchant and its source fingerprint remain unchanged for compatibility.
- Added a regression where `Контрагент` precedes `Описание операции`; the imported row retains the counterparty while classifying parent support as an incoming transfer. `swift run moneywise-checks` passes 268 checks; Swift parsing, project/entitlement lint and `git diff --check` pass.
- This is synthetic format coverage only. Real bank CSV column semantics, app type-check, SwiftData persistence and device behavior remain UNVERIFIED. Next: continue audit of transaction interpretation, then validate with redacted statements and full Xcode.

## Follow-up 2026-10-29 — Reject invalid CSV quote placement

- P0 parser review found that quote characters were toggled permissively, so quotes embedded in an unquoted amount or text appended after a closing quote could be silently removed and change the parsed value. Field parsing now uses explicit start/unquoted/quoted/after-quote states and rejects invalid placement with the logical row number, while accepting escaped double quotes and whitespace around quoted cells.
- Added regressions for quote-in-number, trailing text after a closing quote, and escaped quotes. `swift run moneywise-checks` passes 271 checks; Swift syntax parsing, project/entitlement lint and `git diff --check` pass.
- iOS build, SwiftData runtime import, and real bank statement compatibility remain UNVERIFIED. Next: continue P0 reconciliation/input validation, then run end-to-end import/save/reopen against real redacted statements in Xcode.

## Follow-up 2026-10-29 — Avoid whole-record Character-array copies

- Performance review found `splitCSV` materialized `Array(line)` before checking the 10,000-character field limit. A large quoted record therefore incurred a full Character-array allocation before the importer rejected it. The scanner now traverses `String.Index` values directly, preserving escaped quotes and strict quote placement without copying the entire record into an array.
- Added a multiline quoted-field over-limit regression. All 272 MoneyCore behavior checks pass; Swift source parsing, project/entitlement lint, and `git diff --check` pass. This establishes bounded field rejection but is not a device memory benchmark.
- iOS type-check/runtime, real import/save/reopen, and iPhone 12 memory/performance remain UNVERIFIED without Xcode/device access. Next: continue core correctness work, then benchmark the full import path on the target device.

## Follow-up 2026-10-29 — Preserve recurring payment time anchors

- P0 cash-flow review found that a recurring occurrence due today was shifted to `now` for forecasting, and the next occurrence was then advanced from that shifted timestamp. For date-only plans this moved future installments from midnight to the current clock time; a same-date expected income could consequently be applied before an obligation that should be ordered first at the shared timestamp.
- Expansion now keeps the scheduled recurrence timestamp separate from the effective current-day reservation timestamp and advances from the original schedule. Added a regression where the next monthly obligation and confirmed income share a date; the model catches the pre-income deficit. `swift run moneywise-checks` passes 273 checks; Swift parsing, project/entitlement lint and `git diff --check` pass.
- iOS type-check, persistence and device behavior remain UNVERIFIED without full Xcode/iOS SDK. Next: continue checking cash-flow event ordering and perform end-to-end app acceptance in Xcode when available.

## Follow-up 2026-10-29 — Use populated descriptions and reject empty required fields

- CSV field audit found that a blank first text column (for example, `Контрагент`) caused a valid row to be rejected even when a later `Описание операции` field was populated. The imported display text now uses the first non-empty recognized description field; classification still uses the operation-description fields where present.
- Added regressions for blank counterparty with populated operation text and for missing date, all description fields, single amount, or both debit/credit values. `swift run moneywise-checks` passes 278 checks; Swift parsing, project/entitlement lint and `git diff --check` pass.
- App/SwiftData integration, actual bank file compatibility and full iOS build remain UNVERIFIED. Next: continue core financial correctness, then validate with redacted real statements and full Xcode/device acceptance.

## Follow-up 2026-10-29 — Reject repeated provider IDs within a statement

- P0 deduplication review found that provider transaction IDs were checked against stored history, but duplicate IDs within the same CSV file could pass preview as separate new rows. The parser now rejects the later row with a row-specific error, whether it is identical or conflicts in date/merchant/amount; it never guesses which in-file version is authoritative.
- Added regressions for identical duplicate rows and conflicting rows sharing an ID. `swift run moneywise-checks` passes 280 checks; Swift parsing, project/entitlement lint and `git diff --check` pass.
- This assumes explicit provider transaction IDs are unique within one statement source, consistent with their existing use as deduplication keys; actual bank statement semantics still need redacted fixtures. SwiftData persistence and full iOS runtime remain UNVERIFIED.

## Follow-up 2026-10-29 — Index existing provider IDs during import

- Performance review found the provider-ID duplicate/conflict lookup scanned the entire saved provider history for every imported row, and status promotion performed another full scan per row. Both paths now build one dictionary grouped by provider ID and use constant-time lookups thereafter, reducing matching work from O(import rows × stored rows) to O(import rows + stored rows), apart from the unavoidable number of displayed conflicts.
- Added a regression ensuring ambiguous repeated IDs already stored remain suppressed without selecting an arbitrary conflict row or promoting an arbitrary pending operation. `swift run moneywise-checks` passes 281 checks; Swift parsing, project/entitlement lint and `git diff --check` pass.
- No device import benchmark was available; this is an algorithmic complexity improvement, not measured iPhone throughput. Next: benchmark end-to-end import on the target device after full Xcode is available.

## Follow-up 2026-10-29 — Keep status-update overlap checks linear

- The indexed provider lookup still had one quadratic overlap check: for each provider status promotion it searched all source-ID status updates. Built a set of source IDs already scheduled for promotion and now performs constant-time overlap checks. This retains one update per stored transaction when both identity forms are available.
- Added a regression ensuring a pending operation matched by both source ID and provider ID receives exactly one source-ID update. `swift run moneywise-checks` passes 282 checks; Swift parsing, project/entitlement lint and `git diff --check` pass.
- Full iOS import actor type-check/persistence and device profiling remain UNVERIFIED. The provider match phase is now linear by construction; end-to-end iPhone throughput still needs measurement.

## Follow-up 2026-10-29 — Require review before promoting conflicting pending rows

- Reconciliation review found that a posted bank row could have the same provider ID as a pending local transaction but a different amount/date/kind. The preview already displayed the conflict and preserved the stored row, yet the separate status-update plan could still mark that stale-value row as posted. Status promotions are now suppressed for every conflicted row until the user reviews it.
- Added a regression with a pending 100 ₽ row and conflicting posted 125 ₽ row; it asserts the conflict is surfaced, no transaction is inserted, and no automatic status update occurs. `swift run moneywise-checks` passes 283 checks; Swift parsing and `git diff --check` pass.
- Full Xcode/iOS type-check, transactional SwiftData save/reopen, and actual bank CSV fixtures remain UNVERIFIED. Next: audit the stale-preview persistence recheck so it also rejects status changes when stored data changed after preview.

## Follow-up 2026-10-29 — Revalidate pending-row snapshots at persistence

- The persistence actor now receives expected merchant/amount/date/kind values with each pending-to-posted update and compares them to the latest stored row before changing status. This catches edits made after import preview; missing expectations fail closed. Removed a second provider-ID promotion loop that bypassed this validation and could promote a row created concurrently after preview.
- Core regressions verify expected snapshots are attached and reject changed financial values; `swift run moneywise-checks` passes 283 checks. Swift parsing, project/entitlement lint, and `git diff --check` pass.
- The actual SwiftData writer could not be type-checked or exercised because full Xcode/iOS SDK is unavailable. End-to-end persistence, multi-window race behavior, and real bank CSV semantics remain UNVERIFIED. Next: inspect remaining import-writer mutations and transaction editing paths for similar stale-state assumptions.

## Follow-up 2026-10-29 — Fail closed on ambiguous source IDs

- Writer audit found source-ID status updates used a dictionary that silently kept the first row if corrupted/duplicated IDs existed. It now groups all matches and updates only when exactly one row exists; source-ID promotions must also still belong to the selected account. Provider-ID promotions already use the same unique-match rule and account scope.
- `swift run moneywise-checks` passes 283 checks; Swift syntax parsing, project/entitlement lint, and `git diff --check` pass. The SwiftData writer remains syntax-checked only because full Xcode/iOS SDK is unavailable.
- Next: continue reviewing transaction editor/delete flows and account reassignment for effects on import identity and duplicate detection.

## Follow-up 2026-10-29 — Check manual transaction edits against import identity

- Reviewed the transaction list, edit, and deletion paths. Editing an imported operation changes bank-visible fields but retains its source/provider identifiers, so the next import surfaces a provider conflict for review rather than inserting a duplicate or overwriting the user's correction. The writer's expected-value guard now also prevents a stale pending-status promotion after such an edit. The editor does not reassign an operation to another account; source-ID promotions require the original selected account and a unique stored row. Deletion removes the source row, so a later import can re-add it intentionally.
- This is static code-path evidence; UI flows and SwiftData persistence remain UNVERIFIED without full Xcode/iOS SDK. Core 283 checks and syntax/project lint remain green. Next: continue import-flow end-to-end review, including user-visible feedback when a stale preview is skipped at save time.

## Follow-up 2026-10-29 — Report actual import persistence results

- The writer now returns committed counts for inserted transactions, duplicates (including rows that became duplicates after preview), applied/skipped status updates, provider conflicts, and created recurring reminders. After a successful save the app shows a Russian summary; a stale or already-processed status update is explicitly reported instead of silently disappearing. Save errors still use the existing error alert.
- `swift run moneywise-checks` passes 283 checks; Swift source parsing, project/entitlement lint, and `git diff --check` pass. Full SwiftUI/SwiftData type-check and runtime presentation remain UNVERIFIED without Xcode/iOS SDK.
- Next: continue verifying transaction-to-plan settlement and repeated-import behavior through actual SwiftData save/reopen on an iOS runtime.

## Follow-up 2026-10-29 — Avoid duplicate subscription plans on overlapping imports

- Recurring candidates were detected from newly imported rows and saved as subscription plan items without checking existing plans. A later overlapping statement could therefore offer and create another plan for the same service. Added a pure matcher using normalized merchant title, recurrence, and the detector's 10%/10 ₽ amount tolerance; the writer filters candidates against persisted plan items and reports how many repeated suggestions were skipped.
- Added positive and negative matcher regressions for normalized title/nearby amount, recurrence mismatch, merchant mismatch, and amount outside tolerance. `swift run moneywise-checks` passes 287 checks; Swift parsing, project/entitlement lint, and `git diff --check` pass.
- SwiftData plan lookup/save and UI result remain syntax-checked only without full Xcode/iOS SDK. Next: audit recurring plan identity edge cases and verify transaction-to-plan settlement paths.

## Follow-up 2026-10-29 — Validate subscription amount mismatch boundary

- Extended recurring-plan matcher coverage to assert that a matching merchant and cadence do not suppress a separate plan when its amount falls outside the detector's tolerance. Reviewed explicit transaction-to-plan linking: only posted, external outflows can settle a valid scheduled occurrence; duplicate transaction links, overpayments, stale balance confirmations, and invalid recurrence dates are rejected by the core policy and app validation path.
- Core checks pass (287); Swift syntax parsing, project/entitlement lint, and `git diff --check` pass. UI and SwiftData settlement flow remain UNVERIFIED without full Xcode/iOS SDK. Next: inspect bank synchronization/export architecture requirements and continue end-to-end gaps.

## Follow-up 2026-10-29 — Clarify current Open API status for individual accounts

- Rechecked current CBR standards and FAQ. Published recommended Open API specs now explicitly cover individual account consent and reads (accounts, balances, cards, transactions); the individual data flow lists authorization-code OAuth, while the consent methods require client credentials and JWS. CBR FAQ still describes Open API exchange as organization-to-organization and participants as organizations meeting criteria. Therefore the standards establish a technical profile for consumer data, but do not establish access for this private standalone iOS client, approval for its no-server token flow, or a licensing conclusion.
- Updated `PRODUCT_SPEC.md`, `README.md`, and `.agent/bank-api-eligibility.md` to avoid saying a personal-data API standard does not exist and to keep the unresolved bank permission explicit. Official references include the [CBR Open API standards index](https://www.cbr.ru/fintech/api/prikladnye-standarty/), [individual-account methods](https://www.cbr.ru/Content/Document/File/185573/20251219_od_2894.pdf), [individual consent methods](https://www.cbr.ru/Content/Document/File/185572/20251219_od_2892.pdf), and [CBR participant FAQ](https://www.cbr.ru/fintech/api/).
- No adapter was added: no bank approved this app's direct iOS client registration, credentials/signing-key handling, or token refresh. `xcodebuild` remains unavailable because only Command Line Tools are selected; full iOS compilation/device acceptance is still unverified. Next: continue available P0/P1 work; bank-specific automatic sync requires official bank eligibility evidence.

## Follow-up 2026-10-29 — Do not show truncated internal-transfer matches as complete

- The transaction editor previously fetched at most 100 opposite-direction transactions with the same amount and nearby date, then presented the matches without detecting truncation. If more than 100 existed, the UI could show an incomplete candidate list and imply the ambiguity had been fully reviewed. The query now fetches one overflow sentinel; above 100, the editor suppresses candidate buttons and clearly tells the user to check manually. A single imported transfer side remains an external inflow/outflow until both sides are explicitly paired; existing core checks cover this conservative rule.
- Core checks pass (287); Swift parsing, project/entitlement lint, and `git diff --check` pass. The SwiftUI query behavior remains unverified at runtime without full Xcode/iOS SDK. Next: continue the P0 import and analytics audit.

## Follow-up 2026-10-29 — Reconcile CSV amount with debit/credit columns

- The parser previously trusted a `Сумма` column and silently ignored populated `Дебет`/`Кредит` columns. It now parses those direction columns when present, rejects rows with both sides populated or a magnitude mismatch, and uses the explicit debit/credit direction when magnitudes agree. Rows that omit the entire trailing direction group continue to import from `Сумма`.
- Added regression coverage for matching unsigned amount plus debit/credit, contradictory magnitude, both sides populated, and a negative refund reversal remaining an outflow. `swift run moneywise-checks` passes 291 checks; targeted Swift parsing, project/entitlement lint, and `git diff --check` pass.
- The full iOS build, SwiftData import/save/reopen, and bank-specific CSV compatibility remain UNVERIFIED without full Xcode/iOS SDK and redacted real statements. The checkout is entirely untracked, so a Git diff cannot establish a baseline; no unrelated files were cleaned. Next: continue the P0 import/account audit and pursue simulator/device verification when the native toolchain is available.

## Follow-up 2026-10-29 — Bound long income forecasts

- A manually selected next-income date had no maximum horizon. The purchase checker, daily-limit calculation, and free-to-spend amount could expand every weekly/monthly plan until that date and linearly extrapolate recent variable spending for an unbounded period. Added a two-year calendar-date cap for these safety decisions; longer horizons now fail closed with a clear explanation, and purchase-option generation avoids expanding repeated events when the cap is exceeded. The visual horizon remains independently capped at 90 days.
- Kept established month/year recurrence behavior inside the supported range; the boundary treats the entire final calendar date as valid because income dates are selected by day. Added checks for the exact two-year boundary, just beyond it, suppressed free-to-spend and purchase verdicts, and avoided long-horizon option expansion. `swift run moneywise-checks` passes 294 checks; Swift parsing, project/entitlement lint, and `git diff --check` pass. Updated README and product spec with the current limit/count.
- Full iOS type-check/runtime and device performance remain UNVERIFIED without full Xcode/iOS SDK. Next: continue P0 account/import correctness, then perform native simulator/device acceptance when the iOS toolchain is available.

## Follow-up 2026-10-29 — Surface duplicate reserve-entry risk

- Audited the combined reserve calculation and found that named reserves, saved-goal amounts, and scheduled obligations are separate records with no explicit relationship. The calculation adds them independently; if a user records the same planned money in more than one place, free-to-spend is understated. Added direct warnings in reserve creation/review and documented that these entries are not automatically reconciled.
- This is a mitigation, not closure of the P0 invariant. Automatic prevention needs explicit reserve-to-goal/obligation relationships and a persistence migration plus save/reopen verification; name/amount heuristics would guess incorrectly. Next: design that explicit relation and migration path before changing the financial aggregation.

## Design checkpoint 2026-10-29 — Explicit reserve allocations

- Keep old reserve rows unchanged by default: new optional goal/plan-occurrence IDs migrate as `nil`, which means the existing reserve remains independent. Do not auto-link old rows by title or amount. Let the user explicitly link a reserve to one goal or one exact scheduled occurrence; deleting the target clears the link and preserves the reserve as independent.
- Aggregation rule: for a linked goal, protect `max(goal's saved amount, total linked envelope amount)` rather than summing both. For a linked confirmed plan occurrence inside the current forecast interval, protect the obligation plus only any envelope amount above its remaining obligation. Subtract posted settlements from both the remaining occurrence and its linked envelope. Outside the active interval, retain the full envelope reserve. Missing, invalid, or unconfirmed targets fall back to a standalone reserve.
- Acceptance: tests for standalone and legacy records, linked goal overlap/excess, repeated envelopes on one target, plan occurrence overlap/excess, partial/full settlement, final shortened installment, recurrence/date mismatch, horizon boundaries, target deletion preserving standalone funds, and JSON backwards compatibility. Add optional SwiftData attributes using the container's migration support; a real store upgrade/save/reopen on iOS remains a required gate.

## Follow-up 2026-10-29 — Implement explicit reserve linking

- Added optional goal ID, planned-item ID, and occurrence date to local protected-reserve records. Existing records default to no link; there is no fuzzy matching. Deleting a target clears its links and leaves the envelope independent.
- The reserve editor now supports independent, goal-linked, and exact payment-occurrence allocations. The list describes each target, and undo restores relationship fields as well as title and amount. Dashboard, reserve screen, purchase calculations, and financial-horizon summary now consume the same effective allocation totals.
- Core tests cover linked goal overlap, multiple envelopes, payment excess, partial and full settlement, shortened final payment, out-of-window fallback, unconfirmed/invalid occurrence fallback, deleted/missing goal fallback, and legacy JSON snapshots. `swift run moneywise-checks` passes 304 checks; Swift parsing and Xcode project/entitlement lint pass.
- The reserve composition chart now shows reconciled aggregate amounts instead of rendering linked reserve rows again beside their linked goal.
- Remaining acceptance: verify old SwiftData store migration, edit/delete/undo save-reopen, and UI behavior in full Xcode/Simulator. This host has Command Line Tools only, so native type-check and runtime are UNVERIFIED. Next: continue the P0 audit, and keep the iOS verification gate open.

## Follow-up 2026-10-29 — Apply protection to newly created SwiftData files

- Startup already set the Data Protection entitlement and protected the store directory/existing SQLite files before opening SwiftData. A new store and its initial sidecars can be created during container initialization, after that first file scan. Startup now reapplies file protection and backup exclusion after the container opens and before the store is exposed to app views.
- Apple documents that unspecified files receive the default protection class and that complete protection makes files unavailable while the device is locked; the project entitlement requests complete protection. Sources: [Encrypting Your App's Files](https://developer.apple.com/documentation/uikit/encrypting-your-app-s-files?changes=lat_5), [Data Protection entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.default-data-protection?language=objc).
- Swift parsing and property-list lint pass. Full code-sign entitlement inspection, file-attribute inspection on a newly created and migrated store, locked-device behavior, and backup behavior remain UNVERIFIED without Xcode/device. Next: continue privacy and data-deletion audit; do not claim forensic erasure or removal from historical backups.

## Follow-up 2026-10-29 — Remove duplicate settings during local wipe

- Audited local-data deletion and found it reset only the first active `StoredSettings` row. Although normal startup creates one row, damaged/legacy stores could contain duplicates with old balance, expected-income, or lock state. The confirmed wipe now fetches settings before mutation, resets the active row, and deletes every other persisted settings row in the same SwiftData transaction.
- Static code review confirms all current SwiftData entities are fetched and deleted/reset, local privacy/appearance preferences are cleared, and pending/delivered notifications are cancelled after successful persistence. New-store file protection now runs both before container opening and after SwiftData can create its initial database/sidecars.
- Verified: 304 MoneyCore checks pass; all Swift source files parse; project and entitlements pass `plutil`; static search found no network/session APIs, bank credentials, or token/key strings in app/core source. This is not a complete security review. Native deletion rollback, duplicate-row wipe, signed entitlement, database/sidecar attributes, filesystem remanence, and device-backup behavior remain UNVERIFIED without Xcode/device.
- Next: continue the requirement audit. Obtain full Xcode/device verification before claiming P1/P4 completion; do not describe logical row deletion as forensic secure erase or as revoking pre-existing backups.

## Follow-up 2026-10-29 — Exclude future-dated income from current analytics

- Income-cycle discovery used the end of the current calendar day as its timestamp bound. A malformed or future-dated `posted` row later today could move the cycle boundary into the future and hide current spending. It now accepts only income with timestamp `<= asOf`.
- Added regressions for a future-only income row and a future row alongside a real prior income. `swift run moneywise-checks` passes 306 checks; Swift parsing and project/entitlement lint pass.
- Next: continue P0 analytics/import audit. Native SwiftData validation remains unavailable without full Xcode.

## Follow-up 2026-10-29 — Apply an as-of cutoff to spending analytics

- The dashboard's calendar-day interval ended at tomorrow's midnight and previously included a posted transaction timestamped later today than the current time. This can happen through manually entered or malformed imported data and made today's actual-spend chart look ahead.
- Added an optional `asOf` cutoff to analytics totals, summaries, and period comparisons. The dashboard supplies the current time, keeping the generic historical-interval APIs usable without a cutoff. Tests verify future-timestamped outflows are excluded from daily summaries and today's comparison while same-time rows remain included.
- `swift run moneywise-checks` passes 308 checks; Swift parsing and project/entitlement lint pass. Next: continue review of current-day and import timestamp semantics; native UI remains unverified without full Xcode.

## Follow-up 2026-10-29 — End the income-cycle interval at the actual calculation time

- Review of the new current-time cutoff found the income-cycle API still returned a current interval through tomorrow midnight. The dashboard masked that mismatch by passing `asOf`, but the API itself did not represent the actual elapsed cycle. It now ends at `asOf`; the previous comparison interval uses that exact elapsed duration, capped at the next real income boundary.
- Regression coverage asserts that a future same-day income neither moves the cycle boundary nor extends the current interval, and the previous comparable period matches the elapsed `asOf` duration. `swift run moneywise-checks` passes 308 checks; Swift parsing and Xcode project/entitlement lint pass.
- Next: continue the P0 audit of forecasting inputs and import behavior. Full Xcode/iOS behavior remains UNVERIFIED.

## Follow-up 2026-10-29 — Avoid counting settled plan payments as variable spend

- The 30-day variable-spend estimate included posted transactions already explicitly linked to scheduled-payment occurrences. Future projection separately subtracts those scheduled obligations, which could count a linked recurring payment both in the historical daily estimate and again as a dated future outflow.
- The app now derives validated settlements before its spending estimate and passes their transaction IDs as exclusions. MoneyCore filters only those explicit IDs; it does not guess from merchant, amount, or date. Added a regression for the core filter.
- Verified: `swift run moneywise-checks` passes 309 behavior checks; `swiftc -frontend -parse` accepts the app/core/test sources; project and entitlement pass `plutil -lint`. Command Line Tools emit existing linker search-path warnings. SwiftData link validity, native iOS type-check/build, and runtime remain UNVERIFIED without full Xcode.
- Next: continue the P0 audit of forecasting assumptions and bank import correctness.

## Follow-up 2026-10-29 — Exclude disabled-account payments from plan settlements

- A linked transaction from an excluded or deleted account could still reduce its scheduled obligation even though that account's balance and transactions were excluded from the active financial snapshot. That made the plan internally inconsistent and could overstate safe-to-spend cash.
- Added one shared account-inclusion rule. Snapshot settlement validation, spending-history forecasting, dashboard analytics, and purchase-category budgets now all use it; linked payments from accounts outside the included-account set cannot settle obligations, and unbound manual transactions remain included. Added core policy checks for included, excluded, and manual account sources.
- Verified: `swift run moneywise-checks` passes 314 behavior checks; Swift app/core/test parsing and `plutil -lint` pass. Full iOS type-check, SwiftData behavior, and runtime still require Xcode, which is not installed (active developer directory is Command Line Tools; `xcodebuild` and `simctl` unavailable).
- Next: continue P0 review, especially date-only CSV fingerprint compatibility; avoid changing persisted IDs without a migration-compatible deduplication path.
- Follow-up review confirmed the same account policy is now used by dashboard charts and purchase-category budget checks, not only balance snapshots, forecast history, and plan settlements. MoneyCore checks still pass (314), and all Swift sources parse after this UI integration; full SwiftUI type-check/runtime remains unverified.

## Follow-up 2026-10-29 — Stabilize CSV date fingerprints across timezones

- Parsed date-only and offset-free CSV timestamps now retain a normalized wall-clock identity in the transaction model; ISO-8601 values with explicit offsets retain an absolute-instant identity. Account-scoped fingerprints use that identity so the same statement row stays stable if the device timezone changes.
- Old timestamp-based fingerprints are checked as a compatibility fallback in preview, status promotion, and persistence-time duplicate recheck. Legacy classification migration remains supported for account-bound and unbound imports. The old stored epoch does not contain its originating timezone, so a pre-update row already imported under a different zone cannot be reliably reconstructed; that narrow historical case remains unresolved.
- Added regressions for wall-clock/instant identity, timezone-shifted date-only reimport, prior timestamp-ID compatibility, and old classification behavior. `swift run moneywise-checks` passes 316 checks; Swift parsing and project/entitlement lint pass.

## Follow-up 2026-10-29 — Read CSV import history once

- CSV preview previously made two independent full SwiftData transaction fetches: one to build source-ID statuses, then another to collect provider transaction IDs by account. The import writer now reads the rows once and derives both maps from that single result. Rows without provider metadata still contribute their source status and are skipped only for provider matching.
- Verified: `swiftc -frontend -parse` passes for app, core, and tests; `plutil -lint` passes for the Xcode project and entitlements; `swift run moneywise-checks` passes 316 checks; static search confirms the old two fetch methods/call sites are gone.
- This removes one full database fetch from CSV preview, but no latency or memory benchmark was possible. `xcodebuild -version` confirms the host has Command Line Tools without full Xcode, so SwiftData actor type-check/runtime, iOS build, and device performance remain UNVERIFIED.
- Next: continue the P0 correctness review, then validate the import path with a full Xcode/Simulator build and a representative large statement on iPhone.

## Follow-up 2026-10-29 — Include transfer matcher in the iOS target

- Xcode project audit found `Sources/MoneyCore/InternalTransferMatcher.swift` in SwiftPM and referenced by `MoneyWiseApp.swift`, but absent from the explicit Xcode source phase. The app target would therefore fail to resolve `InternalTransferMatcher` even though `swift build --target MoneyCore` succeeds.
- Added the file reference to the MoneyCore group and the app target's Sources phase. Verified the project property list parses, all Swift files parse, MoneyCore builds, and all 316 core behavior checks pass. A source-phase inventory confirms all 13 Swift files under `iOSApp/` and `Sources/MoneyCore/` are now present in the Xcode app target.
- Full Xcode target compilation is still UNVERIFIED because this machine has Command Line Tools only; this change fixes the confirmed missing source entry but does not substitute for the native build.
- A follow-up source-phase inventory confirmed all 13 Swift files under `iOSApp/` and `Sources/MoneyCore/` are included in the target. Next: continue P0 correctness review, then obtain a full Xcode/iOS build and simulator acceptance.

## Follow-up 2026-10-29 — Clarify local deletion and device backups

- The deletion action clears SwiftData records and app-local preferences/reminders, while the database is excluded from device backups. The Settings copy did not explain that a previously created whole-device backup is managed by iOS and is outside the app's deletion action; it also did not distinguish logical app-data deletion from physical erasure of SQLite/flash remnants.
- Updated the Settings footer and both confirmation steps to state these limits, and updated the product spec. Apple documents backup exclusion as a per-file flag and directs users to iCloud/Finder device-backup controls for deleting stored copies ([backup exclusion](https://developer.apple.com/documentation/foundation/urlresourcekey/isexcludedfrombackupkey?changes=_3), [manage iCloud backups](https://support.apple.com/en-us/108922)).
- Confirmed the deletion path also clears amount-visibility, appearance, icon, and intro preferences. Swift source parsing and `plutil -lint` pass after the copy change.
- This is a transparency improvement, not proof of device deletion behavior. SwiftData row deletion, backup exclusion attributes on device, and any filesystem remanence remain unverified without Xcode/device testing.
- Next: continue P0 review and prioritize a full Xcode/device acceptance path; retain the backup/physical-erasure caveat in user-facing copy.

## Follow-up 2026-10-29 — Use one timezone for horizon dates and recurring events

- The financial-horizon API accepts a calendar, and its daily points/reserve accounting used that calendar, but recurring cash-flow expansion silently used the device's current timezone. Around a DST transition, a monthly event could land in the prior daily projection bucket.
- The horizon now passes its calendar through cash-flow construction to recurring occurrence expansion. That expansion remains Gregorian but uses the supplied calendar's timezone, preserving production behavior when the UI supplies the current calendar while making projections internally consistent.
- Added a Los Angeles DST regression: a monthly charge at December 1 00:00 must appear on the second projected day when the horizon starts November 29 23:30. The check fails if the horizon omits the supplied calendar and passes with the fix. All 317 MoneyCore checks pass; Swift source parse and Xcode project/entitlement lint pass.
- Native iOS type-check and runtime remain UNVERIFIED because full Xcode/Simulator is unavailable. Next: continue auditing deterministic forecast/event ordering and then run the native acceptance matrix when Xcode is available.

## Follow-up 2026-10-29 — Audit internal-transfer pair lifecycle

- Reviewed candidate generation and confirmation, pair-breaking edits, transaction deletion, account deletion/exclusion, and local-data wipe. Suggestions require exact amount, opposite direction, different included accounts, and a bounded timestamp window; ambiguous suggestions remain explicit choices. Editing amount/date/direction or unpairing detaches both sides, while deleting/excluding an account removes pair state and restores the surviving transaction's normal classification. No correctness defect was found in the reviewed lifecycle.
- Verified the full MoneyCore behavior suite: 317 checks pass. This is core logic verification, not native SwiftData/UI verification. The host still has Command Line Tools without full Xcode, so simulator behavior, persisted pair cleanup, and iPhone performance remain UNVERIFIED.
- Next: continue the requirement audit and seek a full Xcode/iPhone acceptance run; keep direct bank sync explicitly unimplemented until a bank documents and permits a no-server native-client flow.


## Follow-up 2026-10-29 — Keep dashboard transaction query current during a session

- RootView's recent-transaction query captured an upper timestamp when the app launched. A transaction entered or imported later with a current date could fall outside that frozen predicate and remain absent from dashboard recents, spending estimates, and category budgets until the app recreated the view.
- Removed the frozen query upper bound and filter the dashboard's rolling transaction set against the current time at evaluation. Newly inserted current-dated rows can now enter the dashboard in the same session; explicitly future-dated rows stay out of historical analytics.
- Verified Swift parsing for app/core/check sources, project and entitlement property-list lint, and all 317 MoneyCore checks. The fix is in the SwiftUI/SwiftData query path; native iOS type-check, query invalidation, and same-session persistence remain UNVERIFIED because full Xcode is unavailable. README's reported check count is synchronized to 317.
- Next: continue P0/UI source audit and complete native build/runtime validation when full Xcode is available.


## Follow-up 2026-10-29 — Fail closed on unknown persisted transaction statuses

- StoredTransaction previously mapped any unrecognized non-nil `statusRaw` to `.posted`. A damaged store or a future enum value could therefore enter spending totals, settlements, and forecast history as a completed operation. Legacy records with no status remain posted for compatibility; unknown non-nil values now restore as pending. The history status filter follows the same rule and shows unknown values under pending.
- Added a MoneyCore regression for legacy nil, both known statuses, and an unknown persisted value. Verified 318 core checks, Swift parsing, and project/entitlement lint. The app-side SwiftData predicate and persistence behavior remain UNVERIFIED without full Xcode.
- Next: continue import/data-integrity audit and validate native persistence/query behavior on a simulator or iPhone when full Xcode is available.


## Follow-up 2026-10-29 — Fail closed on unknown persisted transaction kinds

- StoredTransaction previously mapped an unrecognized `kindRaw` to `.purchase`, which silently classified unknown/future/corrupt rows as outflows and could distort spending estimates and budgets. Unknown kinds now restore as neutral `.adjustment`; known kinds are unchanged. This complements the prior status rule where missing legacy status remains posted but unknown non-nil status fails closed as pending.
- Added core regressions for known kinds and a future unknown kind, including the invariant that the unknown row is neither inflow nor outflow. Verified 319 core checks, Swift parsing, and project/entitlement lint.
- A targeted SwiftData predicate type-check attempt cannot run in this CLT-only toolchain: the SwiftData macro implementation plugin (`SwiftDataMacros`) is unavailable. The iOS app's SwiftData predicate/persistence and simulator behavior remain UNVERIFIED until full Xcode is available.
- Next: continue P0 data-integrity review and obtain native Xcode/iPhone verification.


## Follow-up 2026-10-29 — Validate grouped amounts in manual ruble input

- `Money.parseRubles` previously removed all whitespace before parsing. A pasted malformed value such as `1 2 3` therefore became `123`, which could silently alter account balances, budgets, debt amounts, goals, or manually added transactions.
- Manual parsing now accepts plain digits with an optional decimal comma or dot and validates supported space/NBSP/narrow-NBSP thousands groups (first group 1–3 digits, following groups exactly 3). Mixed decimal separators, malformed group widths, repeated/mixed grouping spaces, spaces adjacent to the decimal separator, non-ASCII digits, and sub-kopeck values are rejected. Valid grouped values and exact trailing-zero precision remain supported.
- Added regression coverage for valid multi-group input and malformed/mixed grouping. Verified 320 core checks and Swift parsing; project/entitlement lint also passes.
- Next: continue P0 audit of user-entered numeric values and complete native form validation on iPhone once full Xcode is available.


## Follow-up 2026-10-29 — Preserve exact debt amounts when opening the editor

- EditDebtView reconstructed rubles through `Double(kopecks) / 100`. Binary floating point can lose kopeck precision for large stored balances/payments, so opening and saving an unchanged debt could alter its value or make it unparseable. It now formats the stored kopecks through `Decimal`/`NSDecimalNumber`, consistent with the goal and account editors.
- Added a maximum-Int64 kopeck round-trip regression using the same decimal-string conversion. Verified 321 MoneyCore checks, Swift parsing, and project/entitlement lint. UI form behavior itself remains UNVERIFIED without full Xcode/iPhone.
- Next: continue the audit of persistence/edit paths and verify forms on a native simulator/device when Xcode is available.


## Follow-up 2026-10-29 — Block confident planning when saved recurrence data is unknown

- Stored plan kind/recurrence getters default unknown raw values to a one-time obligation. If a newer/corrupt recurrence were read by this build, recurring cash flows could disappear while purchase checks continued to look confident. RootView now validates every persisted kind and recurrence and carries the result into FinanceSnapshot. FinanceEngine withholds available cash, daily limit, purchase verdicts/options, and numeric horizon points until plan data is interpretable.
- EditPlanItemView surfaces an explicit warning and requires the user to choose a valid kind and recurrence before replacing unknown stored values; merely changing the title or amount cannot silently erase schedule meaning. Startup also skips local reminder scheduling for an unrecognized recurrence instead of degrading it to a one-time notification.
- Added core checks for the invalid-plan fail-closed behavior and backward Codable compatibility. Verified 326 MoneyCore checks, Swift parsing, and project/entitlement lint. Native SwiftData queries, edit flow, and simulator/device behavior remain UNVERIFIED without full Xcode.
- Next: continue auditing persisted raw-value fallbacks and complete native save/reopen verification on an iOS simulator/device when full Xcode is available.

## Checkpoint 2026-10-29 — Unknown categories in purchase budget advice

- Found that persisted transaction or monthly-budget category values unknown to this app version silently restored as `other`, which could understate a selected category's spent amount or attach an unrelated limit to “Другое”.
- Category budget advice now checks all included-account transactions in the purchase month and all monthly budget records for known categories before computing the category result. If any are unknown, it withholds that category-specific conclusion and tells the user to repair the data; the overall FinanceEngine purchase check remains a separate result.
- Verified 326 MoneyCore behavior checks, Swift frontend parsing for app/core/check sources, Xcode project and entitlements plist lint, and `git diff --check`. SwiftData macro/type-check and UI interaction remain UNVERIFIED because full Xcode is unavailable.
- Next: continue auditing transaction and budget integrity paths, then run native build and persistence acceptance on Xcode/iOS Simulator.

## Checkpoint 2026-10-29 — Validate saved plan amounts and recurrence metadata

- Extended persisted plan validation beyond enum decoding: negative base/final amounts, negative remaining occurrences, and non-finite due dates now invalidate the financial plan snapshot, which already makes the engine withhold spending limits and purchase verdicts.
- The same validation now prevents startup from scheduling reminders for malformed plan rows; reminder lead time must also be one of the two supported values (one or two days).
- Updated financial-engine messages to say saved plan data may be unknown or damaged. Verified 326 MoneyCore checks, Swift parsing, project/entitlements lint, and whitespace checks. The app-side SwiftData macro/type-check and notification behavior remain UNVERIFIED without Xcode.
- Next: inspect other persisted reserve/goal inputs for silent omission or unsafe clamping, then complete iOS runtime verification when a full Xcode environment is available.

## Checkpoint 2026-10-29 — Validate saved goals and protected reserves

- Extended the persisted-finance validity gate to goal target/saved/contribution amounts and target date, named reserve amounts and dates, and the main reserve value. Invalid entries can no longer be silently clamped or omitted and then produce an optimistic purchase verdict or daily limit.
- Engine guidance now identifies plans, goals, and reserves as the data that may need repair. Verification: 326 MoneyCore behavior checks, Swift parsing, project/entitlement plist lint, and whitespace scan pass. SwiftData macro/type-check and persistence/runtime remain UNVERIFIED without full Xcode.
- Next: audit account balances and settings/income validation at the SwiftData boundary, then complete device acceptance when full Xcode is available.

## Checkpoint 2026-10-29 — Unknown saved transactions cannot authorize spend

- Found a critical path: unknown persisted transaction kinds restore as neutral adjustments and unknown statuses restore as pending. Either could silently remove a real outflow from the 30-day spending estimate while the finance engine still returned a confident purchase answer.
- Added stored-transaction validation for known kind/status values, nonnegative amount, and finite date. Included-account history is checked before calculating variable spending; invalid rows make the snapshot financial-data flag false, which withholds numeric horizon results, available cash, daily limit, purchase verdicts, and alternatives. Guidance now names transactions as a repair source.
- Existing MoneyCore fail-closed checks exercise the snapshot gate; verified all 326 behavior checks, Swift parsing, project/entitlement lint, and whitespace scan. SwiftData runtime and migration behavior remain UNVERIFIED without full Xcode.
- Next: continue checking account/settings and import status transitions for paths that can create or preserve malformed transaction values; then complete device persistence and purchase-check acceptance.

## Checkpoint 2026-10-29 — Duplicate settings rows fail closed

- The settings model has no explicit uniqueness constraint, while the app reads `settingsRows.first` for balance, reserve, and future-income assumptions. If a damaged/migrated store contains duplicates, the chosen financial assumptions could depend on unspecified query order.
- Snapshot financial-data validity now requires at most one settings row. Multiple rows therefore withhold numeric forecasts and purchase verdicts instead of selecting an arbitrary one.
- Verification: rerun 326 MoneyCore checks, Swift parsing, project/entitlement lint, and whitespace validation. SwiftData duplicate-store simulation remains UNVERIFIED without full Xcode.
- Next: inspect transaction import classification/status transitions and duplicate account semantics; then native persistence and import acceptance on iOS.

## Checkpoint 2026-10-29 — Import cannot promote an unknown stored status

- Statement status reconciliation previously checked the restored enum. Since unknown raw statuses restore as `.pending`, a later statement could promote an ambiguous/corrupt row to posted if the other fields matched.
- Added an explicit raw-value policy: only the stored string `pending` can be promoted. Legacy nil (posted) and unknown values are not eligible. Both source-ID and provider-ID update paths use this policy.
- Added four behavior assertions for nil/posted/pending/unknown and verified the full MoneyCore checker, Swift parsing, project/entitlement lint, and whitespace scan. Actual SwiftData actor persistence remains UNVERIFIED without Xcode.
- Next: inspect the import actor's transaction/save rollback guarantees and exercise conflict, duplicate, and status-update flows in native runtime when available.

## Checkpoint 2026-10-29 — Unknown category rules do not rewrite imports

- Import review found that a corrupt or future `StoredMerchantRule.categoryRaw` restored as `.other` and could overwrite the CSV importer's classification on newly imported rows.
- Import now applies a learned merchant category only when the stored raw value maps to a known category. The latest unknown rule is ignored, preserving the importer result instead of guessing.
- Verified 327 MoneyCore checks (including raw status promotion policy), Swift parsing, project/entitlements plist lint, and `git diff --check`. SwiftData actor persistence remains UNVERIFIED without full Xcode.
- Next: continue import-path audit and native runtime verification; revalidate that UI feedback accurately reports status updates skipped for ambiguous rows.

## Checkpoint 2026-10-29 — Cancel stale reminders for invalid plans

- Startup already avoided scheduling reminders from plan rows with unknown or invalid financial data, but a notification scheduled during an earlier valid state could remain pending or delivered after the plan became invalid, disabled, or fully repaid.
- Startup now reconciles every plan: it reschedules only valid plans with supported one/two-day reminders and remaining occurrences; otherwise it cancels that plan's pending and delivered notification.
- Transfer review found no mismatch in current core calculation rules: confirmed transfer pairs mark both rows and spending analytics/forecaster exclude internal transfers. UI pairing is explicit and changes detach both sides.
- Verification: run the full checks, app/core Swift parse, project/entitlement lint, and whitespace scan. Actual UserNotifications lifecycle still needs simulator/device verification in full Xcode.
- Next: audit financial settings and account entry constraints, then return to import acceptance and native app build.

## Checkpoint 2026-10-29 — Balance confirmation is scoped to the edited value

- Settings and account-edit forms set the balance timestamp fresh after explicit confirmation or value change. The confirmation flag previously remained true if the user confirmed and then edited the amount; edits now reset confirmation in both forms.
- A concrete compile defect was also found: `EditAccountView` referenced `balanceConfirmed` without declaring its state. The state is now declared in the correct view; an unused similarly named state was removed from `AddAccountView`.
- Verified 327 core checks, Swift parsing, project/entitlement lint, and whitespace scan. `xcodebuild -version` confirms full Xcode is unavailable, so SwiftUI type-check and form behavior still need native verification.
- Next: continue account/settings integrity review and look for additional app-target type-check issues; then perform full Xcode build and device flow when environment permits.

## Checkpoint 2026-10-29 — Require confirmation after changing a balance

- Follow-up review found the earlier confirmation-reset behavior was insufficient: the timestamp policy still marked any changed amount fresh even after the form reset the confirmation state. Account/settings save paths now reject a changed balance until the user confirms after editing. Only explicit confirmation advances the timestamp; unrelated configuration edits preserve it.
- Fixed the missing `balanceConfirmed` state in `EditAccountView`, added core behavior checks for when confirmation is required, and aligned README/Product Spec counts and semantics.
- Verified 328 MoneyCore checks, Swift parsing, project/entitlement lint, and whitespace scan. Full SwiftUI type-check and native form interaction remain UNVERIFIED because Xcode is unavailable.
- Next: continue audit of account and settings recovery paths, then perform full Xcode build and the manual-confirmation scenarios on simulator/iPhone.

## Checkpoint 2026-10-29 — Prevent duplicate cash balance migration

- Settings can migrate an old manually entered balance into a new cash account. If a cash account already existed, the old action could create a second account with the same amount.
- The migration action is now unavailable when any cash account already exists, with guidance to update that account. The save path also refetches and checks for a cash account before changing the store, then inserts the new account and clears the legacy manual-balance flag in one transaction.
- Verification: run MoneyCore checks, Swift parsing, project/entitlement lint, and whitespace validation. SwiftData concurrency and persistence remain UNVERIFIED without Xcode.
- Next: continue verifying first-account/manual-balance transitions and account inclusion behavior on a native simulator/device.

## Checkpoint 2026-10-29 — Normalize new account names

- New account creation now trims leading/trailing whitespace and refuses an empty name; the Save button mirrors that validation. This prevents unusable blank account labels in transaction selection and balance management.
- Rechecked the legacy manual-balance transition: snapshots use the manual balance only while there are no account records, and migrating it to cash clears the legacy flag in the same transaction that inserts the account; existing cash accounts block migration.
- Verification: 328 MoneyCore checks, Swift parsing, project/entitlement lint, and whitespace scan.
- Next: continue reviewing account inclusion and settings recovery, then complete native end-to-end acceptance when Xcode is available.

## Checkpoint 2026-10-29 — Make final deletion confirmation complete

- Rechecked delete-all against the SwiftData schema and local preferences: it clears transactions, accounts, plans, budgets, debts, goals, named reserves, merchant rules, transfer pairs, all settings values, reminders, and app-specific preferences. iCloud/Finder device backups and physical memory erasure are explicitly outside the app's control.
- The final destructive confirmation previously listed only operations/accounts/budgets/plans/notifications. It now names all deleted finance data classes and states the backup limitation.
- Verification: run 328 MoneyCore checks, Swift parsing, project/entitlement lint, and whitespace scan. Actual SwiftData erase/relaunch remains UNVERIFIED without Xcode/device.
- Next: continue remaining end-to-end acceptance review, especially persistence recovery and secure local data behavior.

## Checkpoint 2026-10-29 — Avoid enabling an unusable app lock

- Settings previously allowed enabling the local lock without first checking whether iOS could evaluate device-owner authentication; on a device without a passcode, the next app launch could leave the finance UI inaccessible. The toggle now checks `LAContext.canEvaluatePolicy(.deviceOwnerAuthentication)` and explains that a device passcode must be configured if unavailable.
- When the saved lock setting changes to enabled, RootView now immediately sets itself locked and requests Face ID/passcode rather than waiting until the next background/foreground transition. Disabling the setting restores the open state.
- Source audit confirms the settings sheet is only reachable through the guarded root content, and inactive/background events cover the root with AppLockView before the app-switcher snapshot; store files are assigned complete protection and excluded from device backups before and after SwiftData opens them.
- Verification: run 328 MoneyCore checks, Swift parsing, project/entitlement lint, and whitespace scan. LAContext, lifecycle timing, actual file attributes, and iOS screenshot behavior remain UNVERIFIED without Xcode/device.
- Next: continue security audit of protected-file behavior and local-auth lifecycle; then execute the device security matrix when full Xcode/device access exists.

## Checkpoint 2026-10-29 — Serialize app-lock authentication attempts

- Audited cancellation/rapid taps: a canceled LocalAuthentication request leaves `isUnlocked` false, but startup, scene activation, and repeated taps could start concurrent authentication prompts.
- Added an in-progress guard, suppressing concurrent evaluations; the lock button shows “Проверяем…” and is disabled until the callback returns. The callback unlocks only on success while the lock remains enabled; cancellation/failure leaves finance content hidden.
- Verification: run 328 MoneyCore checks, app/core/test Swift parsing, project/entitlement lint, and whitespace scan. LAContext callback timing and cancel/retry behavior remain UNVERIFIED without an iOS device/simulator.
- Next: device-test initial launch, cancel, rapid retry, face-ID failure/code fallback, app background/foreground, and lock-toggle activation.

## Checkpoint 2026-10-29 — Make authentication attempts lifecycle-safe

- Added a UUID per LocalAuthentication attempt and retains its `LAContext`. A background transition invalidates the context and clears only that attempt; a late callback from it cannot unlock or clear a newer prompt. On return, a fresh attempt can start.
- Kept inactive/background transitions covering the finance UI, but invalidate the authentication context only on actual background: the system authentication sheet itself may temporarily make the scene inactive. If system authentication becomes unavailable after setup (for example, the device passcode was removed), the lock screen now explains how to restore the passcode.
- Verified source parsing, 328 MoneyCore checks, Xcode project/entitlement lint, and whitespace scan. Native lifecycle event ordering, passcode-removal recovery, and context invalidation still need simulator/device testing.
- Next: run the local-auth lifecycle matrix on device when available; continue auditing remaining P0 financial and persistence flows meanwhile.

## Checkpoint 2026-10-29 — Recheck local-auth lifecycle and current verification

- Re-read the project objective and the current lock implementation. The lock covers the financial UI on inactive/background, invalidates and replaces an authentication attempt after backgrounding, ignores a callback whose attempt ID is stale, serializes prompts, and keeps finance data hidden on failure/cancel. When device authentication becomes unavailable, the lock view explains that the iPhone passcode must be restored.
- Verification this pass: 328/328 MoneyCore behavior checks pass; `swiftc -frontend -parse` passes for app/core/test Swift sources; `plutil -lint` passes for the Xcode project and entitlements; `git diff --check` passes.
- Verification limits: lock lifecycle ordering, LocalAuthentication cancellation/invalidation callback timing, passcode-removal recovery, SwiftUI type-check/build, persistent store protection at runtime, and iPhone behavior are UNVERIFIED because only Command Line Tools are available (no full Xcode/iOS SDK/device runtime).
- Security boundary: this is an optional screen privacy lock backed by iOS device-owner authentication. It does not encrypt the SwiftData database behind a separate app secret; complete file protection still depends on iOS/device state.
- Next: continue P0 review of persisted financial input and recovery paths; obtain full-Xcode/device validation before treating native acceptance as complete.

## Checkpoint 2026-10-29 — Fail closed on a broken debt-payment link

- P0 audit found that a persisted `StoredDebt` could be orphaned from its recurring plan, or point to a mismatched/unconfirmed plan. The forecast consumes plan items and did not independently verify debt-to-plan integrity; in that state it could omit a real debt payment while still presenting a spend limit.
- Root financial-data validation now rejects debt rows with invalid negative/zero fields, non-finite first-payment dates, missing/duplicate plan matches, unconfirmed plans, non-debt or non-monthly plans, date/amount mismatch, or an occurrence count inconsistent with whether the debt balance is zero. `FinanceEngine` already withholds reliable safe-to-spend results when `hasValidPlanData` is false; the overview explanation now identifies debt/payment-link corruption.
- Verification: 328/328 MoneyCore checks pass; Swift app/core/test syntax parsing passes; Xcode project/entitlement lint and whitespace validation pass. This environment cannot type-check the SwiftUI target, so the new RootView validation has not been compiled by full Xcode. SwiftData corruption/recovery and rendered warning remain unverified on device.
- Next: audit goal-to-contribution-plan integrity and whether missing/ambiguous links can similarly omit actual planned outflows; then complete native Xcode simulator/device acceptance when available.

## Checkpoint 2026-10-29 — Fail closed on a broken goal-contribution plan

- Continued the P0 persistence audit and confirmed future goal contributions are cash-flow events, while the protected goal allocation covers already saved money. A missing or malformed recurring contribution could therefore disappear from the forecast.
- Root validation now checks each goal's linked contribution plan is unique, confirmed, monthly, and for the configured amount; it verifies the stored occurrence count and final installment against the goal and schedule. If a future contribution schedule is needed but missing, the financial plan is invalidated, so the core withholds a safe-to-spend amount. Ambiguous/shared plan links also fail closed.
- Verification: 328/328 MoneyCore checks pass; Swift syntax parse passes for app/core/tests; `plutil -lint` passes for project and entitlements; `git diff --check` passes. Current environment confirmation: `xcodebuild` requires full Xcode, while active developer directory is Command Line Tools. Thus SwiftUI type-check/build, SwiftData fixture corruption and rendered recovery message remain unverified.
- Next: review related goal/debt settlement behavior and account inclusion/freshness boundaries, then perform native simulator/device acceptance when full Xcode is available.

## Checkpoint 2026-10-29 — Make goal schedule integrity independently testable

- Extracted the goal-to-contribution schedule consistency rule into `MoneyCore.GoalContributionPlan.matchesSchedule`, so it can be verified without SwiftUI or SwiftData. RootView still checks unique ownership, confirmation, kind, monthly recurrence, and configured amount before applying the pure calculation check.
- Added behavior checks for a matching schedule, a missing/understated required schedule, and a fully funded goal with no schedule.
- Verification: 331/331 MoneyCore checks pass (three new checks); app/core/test Swift syntax parse passes; Xcode project and entitlements lint pass; `git diff --check` passes. `xcodebuild -version` still confirms full Xcode is not installed/selected, so native target type-check and simulator/device behavior remain unverified.
- Next: continue account freshness and scheduled-settlement audit, then do full native integration verification once an Xcode/iOS runtime is available.

## Checkpoint 2026-10-29 — Re-audit account freshness and payment settlement boundaries

- Re-read the active objective and traced edited transaction → explicit planned occurrence → stored link → snapshot settlement → forecast.
- Existing guards reject unposted/internal/overpayment links, non-occurrence dates, duplicate transaction use, links from excluded/deleted accounts, and any payment not followed by a confirmed fresh account balance. Manual rows without an account use the oldest included account timestamp. Editing without a plan clears the prior settlement link; deleting a plan clears transaction and reserve links transactionally. Current MoneyCore checks cover partial payment, duplicate use, ambiguous duplicate ledger entries, excluded accounts and stale balance behavior.
- No additional settlement/account-freshness defect was confirmed in this source pass; no code change was made. The last verified suite remains 331/331, and the recent source syntax/lint checks passed. Native SwiftData persistence and UI flows remain UNVERIFIED without full Xcode/device execution.
- Next: inspect snapshot balance assembly, negative/empty/mixed-account states, and forecast behavior at arithmetic/date boundaries; make changes only for a reproducible safety or correctness gap.

## Checkpoint 2026-10-29 — Recheck balance assembly and forecast boundaries

- Reviewed native snapshot assembly: included account balances alone form the combined balance whenever account records exist, so a stale legacy manual balance is not added again; excluded accounts are omitted; if records exist but none are included, the balance list is empty and safe-to-spend remains unavailable. Negative included balances reduce the combined balance and existing core checks confirm they cannot create spendable money. Freshness comes from the oldest included account and future/missing timestamps are rejected.
- No unsafe balance assembly path was confirmed. Existing regression coverage includes empty/missing balances, negative balances, overflow-safe summation, mixed fresh/stale accounts, disabled-account settlement exclusion, and no double counting between the legacy manual balance and account records.
- Reverified current state: 331/331 MoneyCore checks pass; Swift syntax parsing passes; project/entitlement lint and `git diff --check` pass. Native persistence/UI behavior still needs full Xcode and device validation.
- Next: continue the requirement-by-requirement audit against `PRODUCT_SPEC.md`, prioritizing actual gaps over additional static rechecks; native build and device acceptance remain the major evidence gap.

## Checkpoint 2026-10-29 — Show actual upcoming recurring payments on the dashboard

- Product-spec audit found a visible correctness gap: the expanded balance card and 30-day financial-gravity summary filtered plan rows by their original `dueDate`. Monthly/weekly plans anchored in the past therefore disappeared from both dashboard sections even though the forecast generated their next occurrences.
- Added `FinanceEngine.upcomingOccurrences`, which reuses the projection's recurrence and settlement rules and returns stable, occurrence-specific rows with partial payments deducted. The balance card now shows concrete future occurrences through confirmed next income (or a bounded 90-day lookahead when income is unconfirmed/missing); the 30-day total uses actual occurrences rather than plan anchors.
- Added a core regression check for an old monthly plan, its current partial payment, the next full occurrence, and exclusion of an unconfirmed one-off plan.
- Verification: 332/332 MoneyCore checks pass (one new scenario); Swift syntax parse passes for app/core/tests; Xcode project/entitlement lint and `git diff --check` pass. Full SwiftUI type-check, rendered dashboard behavior and device performance remain UNVERIFIED without full Xcode/simulator.
- Next: continue checking dashboard projections and warning copy against the product spec, then address any reproducible functional gap found.

## Checkpoint 2026-10-29 — Explain an unconfirmed income horizon accurately

- Main-screen audit found a mismatch: the free-to-spend amount correctly stays unavailable until the next income date and amount are confirmed, but its explanatory text could fall through to “с учётом резервов…” and imply a completed calculation.
- Added an explicit confirmation guard to the explanation, matching the same preconditions used by `hasAvailableNowData` and `FinanceEngine`.
- Verification: current MoneyCore checks remain 332/332 passing; Swift syntax parsing, Xcode project/entitlement lint, and `git diff --check` pass. The SwiftUI view has not been fully type-checked/rendered because full Xcode/iOS SDK is unavailable.
- Next: continue auditing dashboard status consistency and user-facing error paths against actual calculation gates.

## Checkpoint 2026-10-29 — Align dashboard empty-state copy with its date range

- When next income is unconfirmed or missing, the dashboard now lists confirmed scheduled occurrences over a bounded 90-day period. Its empty-state text previously claimed there were no payments “before the next income”, which incorrectly treated an unconfirmed date as the actual active horizon.
- Changed the message to say there are no confirmed payments in the near-term period; the horizon remains bounded and the calculation still requires confirmed income.
- Verification: 332/332 MoneyCore checks pass; Swift syntax parsing, project/entitlement lint, and whitespace scan pass. Visual behavior remains unverified without full Xcode/simulator.
- Next: continue auditing requirement-to-screen consistency and validate high-priority MVP paths; retain the full native launch, persistence, and device-acceptance gap.

## Checkpoint 2026-10-29 — Clarify CSV import effects on balances and excluded accounts

- Import-flow review confirmed CSV persistence stores transactions against the selected account but deliberately leaves its manually confirmed balance and balance timestamp untouched. The preview did not make this consequence visible, which could lead a user to mistake an old balance for one updated by the imported statement.
- The preview now explicitly says import adds history only and asks the user to reconcile/update the account balance separately. When the selected account is excluded from the plan, the preview explains that its rows remain in history but do not affect forecasts or budgets.
- Verification: 332/332 MoneyCore checks pass; Swift syntax parse passes; Xcode project/entitlement lint and `git diff --check` pass. Native preview rendering and persistence behavior remain unverified without full Xcode/iOS runtime.
- Next: validate real bank statement compatibility with redacted fixtures; until such files are available, parser support for specific Sber/Alfa/Ozon export variants remains unverified.

## Checkpoint 2026-10-29 — Scope purchase what-if to one goal

- The purchase screen previously exposed MoneyCore's aggregate "move goal contribution" option, which removed every goal-contribution plan from the forecast at once. That was broader than a user-selected change and could imply a single goal adjustment was enough.
- Purchase options in the iOS screen are now built per linked goal plan. Each what-if removes only that plan from the temporary snapshot, computes the affected contribution total using concrete occurrence dates through the confirmed income horizon, and rechecks the purchase against the full forecast. The existing disclosure makes clear this is a simulation; it saves neither a purchase nor a plan change.
- Verification: all 332 MoneyCore checks pass; `swiftc -frontend -parse` passes for app/core/tests; project and entitlements pass `plutil -lint`; `git diff --check` passes. Full SwiftUI type-check and iOS runtime remain UNVERIFIED because the environment has Command Line Tools but no full Xcode.
- Remaining: selecting a scenario does not yet open a confirmed goal-edit action or persist an adjusted schedule. The what-if excludes all contributions of that one goal within the forecast horizon, not a single installment. Complete that workflow after implementing explicit occurrence-level schedule adjustments with a verified SwiftData migration; do not convert this simulation into an implicit save.

## Checkpoint 2026-10-29 — Test scoped purchase what-if in MoneyCore

- Extracted the per-goal purchase simulation into `FinanceEngine.goalContributionPurchaseOption`. It validates the selected plan is a confirmed goal contribution, sums only that plan's concrete occurrences through the confirmed income date, removes only that plan from a temporary snapshot, and rechecks the purchase across the full horizon.
- Removed the former aggregate goal option from generic `purchaseOptions`; generic callers can no longer receive an option that silently removes every goal. Added a check for this contract and updated README's core-check count to 334.
- Added a regression with two goal plans and a required bill. It verifies the selected contribution total is scoped to one plan and the other goal plus required bill still affect the resulting verdict.
- Verification: `swift run moneywise-checks` passes 334 checks (two added); Swift syntax parsing passes for app/core/tests; Xcode project and entitlements pass `plutil -lint`; `git diff --check` passes. The SwiftUI target has not been type-checked or run in Xcode.
- Remaining: the scenario is read-only and removes every occurrence of the selected goal within the current forecast. Persisting a single deferred occurrence needs a deliberate schedule-exception model and verified SwiftData migration, then an explicit preview/confirmation/save flow. Full native build and runtime acceptance remain unverified because full Xcode is unavailable.

## Checkpoint 2026-10-29 — Fail closed on unconfirmed goal scenarios

- The scoped goal what-if required a supported horizon and fresh data but did not explicitly require confirmed next income or a reliable spending estimate before offering the option. Although the nested purchase check remained guarded, surfacing a plan-change option with an unconfirmed horizon was confusing.
- The core helper now requires valid plan data, a reliable spend forecast, confirmed next income, fresh balance data, and a supported forecast window before returning a goal option. Added a regression proving unconfirmed income yields no option. Generic `purchaseOptions` no longer removes all goals; the UI only offers a per-goal simulation.
- Updated PRODUCT_SPEC with the exact implemented/partial status and README's count. Verification: 335 MoneyCore checks pass; Swift syntax parsing, project/entitlements lint, and `git diff --check` pass. Xcode build and device QA remain UNVERIFIED.

## Checkpoint 2026-10-29 — Explain pending statement rows

- P0 audit confirmed pending rows are excluded by MoneyCore from spending analytics and the variable-spend estimate, and pending transactions cannot settle planned obligations. The import preview showed per-row pending status but did not explain this calculation boundary or separately count new pending rows.
- Import summary now counts pending new operations and explains they do not enter forecasts, budgets, or ordinary-spend estimates; it also reminds users that import leaves the account balance unchanged and asks them to reconcile the bank's available balance. Transaction history/dashboard rows label pending items as excluded from the forecast until posted.
- PRODUCT_SPEC records this behavior. Verification: 335 MoneyCore checks pass; Swift source syntax parse, Xcode project/entitlements lint, and `git diff --check` pass. SwiftUI type-check/rendering and the native import flow remain UNVERIFIED without full Xcode.

## Follow-up 2026-10-29 — Count pending rows even on repeated imports

- Rechecking the pending-row summary showed it counted only new prepared records. A repeated pending row can be skipped as a duplicate while still remaining unposted, so the summary could misleadingly show zero.
- The preview now counts pending rows from the parsed statement itself (including duplicates) and labels the count as applying to the statement.
- Verification: all 335 MoneyCore checks pass; Swift syntax parsing, Xcode project/entitlements lint, and `git diff --check` pass. This SwiftUI change is not type-checked or rendered without full Xcode.

## Checkpoint 2026-10-29 — Keep recurring local reminders current

- Reminder scheduling previously replayed at most 24 occurrences from the plan anchor and only scheduled one reminder, with no refresh when the user returned to the app. Old weekly/monthly plans could therefore fail to find a future date, and an already delivered reminder did not advance to the next occurrence.
- Added `ScheduledRecurrence.firstOccurrence(onOrAfter:of:)`, which jumps directly to the next weekly/monthly/yearly occurrence while respecting month-end/leap-day anchors and finite occurrence counts. The local scheduler uses it and RootView refreshes the next reminder on app activation/appearance.
- Added three regressions for old weekly jumps, anchored month-end behavior, and exhausted finite plans. Verification: 338 MoneyCore checks pass; Swift parsing, project/entitlements lint, and `git diff --check` pass. Full Xcode/iOS notification delivery and background behavior remain UNVERIFIED.

## Checkpoint 2026-10-29 — Expose notification permission and queue status

- Plan creation requested notification permission but settings had no way to confirm whether iOS granted it, whether alerts were disabled, or whether a payment reminder was actually pending. Added a settings section showing authorization state and pending payment-reminder count, an explicit permission request when not yet asked, and a link to iOS Settings when denied/alerts are disabled. Status refreshes on entry and when the app returns active.
- Followed the project Swift Concurrency guidance: the settings UI reads UserNotifications through async APIs, updates view state on MainActor, and surfaces request errors.
- Verification: 338 MoneyCore behavior checks pass; app/core/test Swift syntax parsing, project/entitlements lint, and whitespace scan pass. Full SwiftUI type-check, actual system settings handoff, permission prompt, and notification delivery remain UNVERIFIED because full Xcode/simulator/device are unavailable.

## Checkpoint 2026-10-29 — Add bounded custom spending dates

- Closed the documented custom-date analytics gap. The dashboard now offers arbitrary start/end dates within its existing 120-day history query, preserves half-open date boundaries, and compares the selected range with the immediately prior interval of the same calendar-day length only when that whole interval is loaded.
- Extracted equal-length comparison interval selection into MoneyCore and added checks for both a valid previous interval and the unavailable-history case. Updated PRODUCT_SPEC and the roadmap state; README now reflects 340 checks.
- Verification: all 340 MoneyCore checks pass; Swift syntax parsing, project/entitlements lint, and `git diff --check` pass. Full SwiftUI type-check, date-picker rendering/accessibility, and simulator/device use remain UNVERIFIED without Xcode.

## Checkpoint 2026-10-29 — Confirmed goal schedule shift for purchase scenarios

- Replaced the obsolete per-goal “remove a contribution” what-if with a full monthly schedule shift. The UI preview explicitly states that the whole selected goal schedule and target date move one month; the core recomputes the purchase against the shifted recurring plan while preserving other goals and obligations.
- The save action requires explicit confirmation, refuses a partially settled next occurrence, updates the linked goal and plan together, and refreshes a local reminder. Before save it checks balance freshness and compares captured goal/plan fields to current values to avoid overwriting intervening edits. `PRODUCT_SPEC.md` now distinguishes implemented source behavior from unverified iOS persistence.
- Updated core checks to exercise the new scoped shift scenario, unconfirmed-income rejection, and refusal to move a partially settled occurrence. All 341 MoneyCore checks pass. Swift syntax parsing, Xcode project/entitlement lint, and `git diff --check` pass.
- Remaining: SwiftUI type checking and real SwiftData transaction/rollback, reminder update, and screen dismissal have not been runtime-verified. `xcodebuild -version` fails because only Command Line Tools are installed.

## Follow-up 2026-10-29 — Preserve month-end goal schedule anchor

- Review found the goal-shift date was calculated from the upcoming occurrence rather than the plan's original anchor. A Jan 31 schedule therefore shifted Feb 28 to Mar 28 and would keep drifting away from month end.
- The UI proposal and MoneyCore validation now calculate the moved date using the original plan anchor. Added checks that accept Mar 31 and reject Mar 28 when moving a Jan 31 → Feb 28 schedule.
- Verification: 343 MoneyCore checks pass; Swift syntax parse, project/entitlements lint, and `git diff --check` pass. README count updated. iOS runtime persistence remains unavailable without full Xcode.

## Follow-up 2026-10-29 — Keep shifted goal deadline after its contribution

- A second calendar edge case remained: preserving a Jan 31 schedule moves Feb 28's contribution to Mar 31, but a Feb 28 target date shifted by one month becomes Mar 28. That would leave the final contribution after the declared goal deadline and make an otherwise valid shift disappear.
- Added `GoalContributionPlan.shiftedDeadlineAfterOneMonth`, which preserves the target's monthly date when possible and clamps the new deadline to at least the shifted first contribution date. The purchase-check proposal uses this tested core rule.
- Verification: 345 MoneyCore checks pass, including deadlines both clamped to Mar 31 and unchanged at Mar 28 when the contribution fits. Swift syntax parse, Xcode project/entitlement lint, and `git diff --check` pass. README count updated; iOS persistence remains unverified without Xcode.

## Follow-up 2026-10-29 — Preserve future goal payment reconciliations

- A whole-schedule shift could invalidate settlement links for a later future contribution even when the nearest contribution was unpaid. The shift option now fails closed if any positive settlement is linked to the selected plan on or after its next upcoming occurrence.
- Added a regression case for a payment reconciled to a later occurrence; the shift is declined. Product spec now documents the full restriction, not just partial payment on the next occurrence.
- Verification: 346 MoneyCore checks pass; Swift syntax parse, project/entitlement lint, and `git diff --check` pass. README updated. Full SwiftData and iOS flow remain unverified without Xcode.

## Follow-up 2026-10-29 — Reconfirm no-server bank API boundary

- Rechecked official bank materials while resuming the P2 audit. Sber's statement use case remains explicitly for companies with a SberBusiness profile, and its OAuth FAQ describes a server-side authorization-code exchange. Alfa's public portal documents customer-account products but does not establish self-service access to one's own retail account from a standalone iOS client. Ozon's official help describes manual statement retrieval; its public docs catalog does not expose a consumer account-history API.
- Updated `.agent/bank-api-eligibility.md` with dated evidence and careful limits: absence from public docs is not proof no private API exists, and no legal claim about needing a license is made. User's no-server/no-intermediary constraint remains in force, so no bank adapter can be truthfully marked available absent explicit bank confirmation of native client access.
- Sources: [Sber statements](https://developers.sber.ru/docs/ru/sber-api/scenarios/rko/statements/overview), [Sber OAuth FAQ](https://developers.sber.ru/docs/ru/sber-api/faq/overview), [Alfa developer portal](https://developers.alfabank.ru/), [Ozon statement help](https://docs.ozon.ru/common/oplata/bank-statements/), [Ozon developer catalog](https://docs.ozon.kz/main/).

## Checkpoint 2026-10-29 — Show the next due date in the plan list

- Plan rows displayed the saved `dueDate` directly, which is only the recurrence anchor. For an old monthly subscription this exposed a date in the past instead of the next charge, making the otherwise working reminder/forecast schedule hard to understand.
- Plan rows now show the recognized entry type, next computed occurrence for recurring items, overdue date for a past one-off, completed state for exhausted schedules, forecast inclusion status, and configured reminder lead time. The existing anchored recurrence helper computes the upcoming date without replaying the entire history.
- Updated PRODUCT_SPEC. Verification: all 346 MoneyCore checks pass; full app/core/test Swift syntax parse, Xcode project/entitlement lint, and `git diff --check` pass. SwiftUI type-check and rendered screen remain unverified without full Xcode/device.

## Follow-up 2026-10-29 — Skip fully settled payments in reminders

- Local reminder scheduling previously selected the next date from recurrence alone. The forecast already removed fully settled occurrences, so notifications could still remind about a payment recorded as complete.
- Added a bounded MoneyCore search for the next occurrence with a positive remaining amount. Partial settlements keep the current occurrence eligible; full settlement advances recurring schedules, and a fully settled one-off schedule produces no reminder. Reminder scheduling now uses the plan's actual regular and final occurrence amounts and receives validated settlements when initialized/refreshed by the dashboard. Existing notifications are cleared before permission handling so a denied/revoked permission cannot leave a stale scheduled reminder active.
- Added five behavior checks for fully settled recurring payments, partial payments, a fully settled one-off, reduced final goal contributions, and expiration after the reduced final contribution settles. `swift run moneywise-checks` passes all 351 checks; full Swift syntax parsing and `git diff --check` pass.
- Native notification delivery, SwiftUI type-check, and settlement query behavior remain UNVERIFIED without full Xcode and iPhone/simulator. A follow-up below centralizes scheduling after committed plan/settlement changes; device lifecycle and delivery still need runtime verification.

## Checkpoint 2026-10-29 — P4 local privacy source review

- Re-read the project's Swift security review guidance and inspected the app startup/store policy, authentication gate, settings disclosure, and all app/core logging call sites. No credentials/tokens are stored (none are required by the local-only build), and no app/core `print`, `NSLog`, or `Logger` calls expose financial data. Personal SwiftData records are local-only; the store directory and files are marked `NSFileProtectionComplete` and excluded from future device backups before/after opening the store.
- Confirmed the UI correctly describes Face ID/passcode as an additional interface lock, not cryptographic database encryption. The two-step delete disclosure correctly states that it clears app records and notifications on this device but cannot delete pre-existing whole-device backups or guarantee physical erasure of SQLite remnants. These are explicit product limitations, not verified secure erasure.
- This was a source inspection only, not a binary review, jailbreak/runtime test, backup-restore test, or device data-remanence test. Those remain UNVERIFIED; full iOS build/device audit remains blocked by missing Xcode/iOS SDK in the current environment. No security completion claim is made.
- Verification baseline remains 351 MoneyCore checks, with Swift syntax/project/entitlement lint and `git diff --check` available. Next: continue P0/P1 requirement audit and seek native integration evidence when a full Xcode environment is available.

## Checkpoint 2026-10-29 — Recheck home-card and safe-daily-limit gates

- Compared dashboard amount visibility and explanatory copy with `availableNow`, `safeDailySpendingLimit`, and their existing regression coverage. The card hides its amount when balance, next-income confirmation/date, freshness, plan validity, or reliable spend-history gates fail; the displayed explanation has a corresponding state. Future income is not included in current spendable cash and is only used as a confirmed forecast event; purchase scenarios are refused on/after its date pending a fresh check after deposit.
- Existing tests cover missing/stale/future balance timestamps, missing balance/income/history, unconfirmed income, current-day obligations, future-income non-spendability, and same-time outflow-before-inflow ordering. No reproducible source-level mismatch was found in this pass; no code change.
- This does not prove SwiftUI rendering, view-model synchronization, or runtime persistence. `git diff --check` passes. Next: pursue end-to-end native verification; do not repeat this source-only check absent new evidence.

## Follow-up 2026-10-29 — Refresh reminders from committed plan state

- Review found plan editors could schedule a notification directly without the validated settlement ledger; goal editing could change a plan without refreshing its existing reminder. Direct and root-triggered scheduling could also race with stale captured values.
- Removed per-form scheduling and centralized refresh in RootView, driven by changes to plan fields, linked transaction settlement fields, account inclusion/freshness, and the balance-settings timestamp. Refresh cancels reminders for disabled, invalid, or exhausted plans and schedules eligible ones with the latest validated settlement snapshot, including reduced final goal contributions. Added a per-plan generation token so an asynchronous notification-authorization callback from an older schedule/cancel request cannot restore a stale reminder.
- Verified Swift syntax parsing, Xcode project/entitlement plist lint, and `git diff --check`. The last MoneyCore run remains 351 passing checks; this change is in SwiftUI/SwiftData observation and UserNotifications scheduling.
- UNVERIFIED: whether the installed SwiftData `@Query` emits all expected updates for child-view edits, Swift concurrency type-checks the main-actor scheduler as intended, and notifications are delivered in actual iOS runtime. Full Xcode and device/simulator acceptance remain required.

## Checkpoint 2026-10-29 — Recheck CSV import failure boundaries and native toolchain

- Rechecked CSV parser and persistence paths against existing regression coverage: encoding, strict dates/currency, amount and direction ambiguity, malformed quoting, duplicate/provider conflicts, pending-to-posted promotion, file/row/column/field limits, and atomic writer rollback are represented in the current implementation/tests. No new silent-value conversion or reproducible persistence defect was confirmed in this pass.
- `swift run moneywise-checks` passes all 351 checks. `xcode-select -p` resolves to `/Library/Developer/CommandLineTools`; `xcodebuild -version` fails because full Xcode is not selected/installed, and `xcrun simctl` is unavailable. Native app type-check, simulator launch, SwiftData relaunch/persistence, and iPhone/device acceptance cannot be performed in this environment.
- This is a source/core test audit, not bank-export compatibility evidence: no real, redacted Sber/Alfa/Ozon/VTB/OTP statement fixture is present. Continue app-level implementation and core checks; obtain native toolchain and representative sanitized statement fixtures before claiming those acceptance items.

## Follow-up 2026-10-29 — Show payments due on income day

- Found a mismatch between forecast and the main-screen upcoming-payment list: the forecast conservatively processes a same-day obligation before expected income, but the dashboard applied a strict `< incomeDate` filter and hid that payment.
- Removed the redundant exclusive filter; the list now uses the same bounded, inclusive occurrence range as MoneyCore. Added a regression assertion for an occurrence exactly at the selected horizon/income boundary.
- `swift run moneywise-checks` passes all 352 checks; Swift syntax parsing, project/entitlement lint, and `git diff --check` pass. Rendering and SwiftUI list behavior remain UNVERIFIED without Xcode/device runtime.

## Follow-up 2026-10-29 — Reconcile linked payment reserves with obligations

- Confirmed the correct behavior is to keep an unpaid scheduled payment visible on its due date, while subtracting a linked envelope only for any amount exceeding the remaining scheduled obligation. Hiding the dated payment would obscure a real cash-flow event.
- Added end-to-end MoneyCore checks that a 1,300 ₽ reserve linked to a 1,000 ₽ payment leaves 300 ₽ of extra protected cash after the 1,000 ₽ cash-flow reserve, while the payment itself remains in the upcoming list at its full 1,000 ₽ amount.
- `swift run moneywise-checks` passes all 354 checks. SwiftUI rendering remains unverified without full Xcode/device.

## Follow-up 2026-10-29 — Preserve reconciliations when editing schedules

- Editing a plan, goal contribution schedule, or debt repayment schedule now checks already-confirmed future transaction links before saving. A changed date or amount that would orphan a settlement or exceed the revised occurrence is rejected with a recovery instruction to review or unlink the history entry first.
- Added three deterministic MoneyCore checks for preserving a valid partial settlement and rejecting a shifted occurrence or a reduced amount below the confirmed settlement.
- Verified: 357 `moneywise-checks` pass; app/core/test Swift syntax parsing passes; Xcode project and entitlements pass `plutil -lint`; `git diff --check` passes.
- Still UNVERIFIED: SwiftUI type-check, SwiftData fetch behavior inside editors, and actual save/rollback behavior require full Xcode and iOS runtime. Current developer directory contains Command Line Tools only.
- Rechecked the native-toolchain blocker on 2026-10-29: `xcodebuild -version` still reports Command Line Tools, `xcrun simctl` is unavailable, and no `Xcode.app` exists in `/Applications` or `~/Applications`. Do not claim native build, simulator, or iPhone acceptance until the toolchain or a device environment changes.

## Follow-up 2026-10-29 — Validate category budget records

- Found that the category budget review checked only whether the category raw value existed. A corrupt zero/negative limit could still be presented as a normal budget and produce a misleading category-limit warning.
- Added deterministic MoneyCore validation for supported expense categories, positive limits, and finite calendar dates. The dashboard now labels invalid legacy rows for repair and purchase-check messaging fails closed when any current-month budget row is invalid.
- Verified: all 362 `moneywise-checks` pass; Swift syntax parsing, Xcode project/entitlement lint, and `git diff --check` pass. Full SwiftUI type-check/rendering and SwiftData behavior remain UNVERIFIED without Xcode.

## Follow-up 2026-10-29 — Bound category spending by its as-of date

- The overview's monthly category total and the purchase-check category warning previously included any posted operation dated later in the current month. Both now use an explicit as-of cutoff: now for the dashboard and the planned purchase date for a future purchase scenario.
- Added a MoneyCore regression proving `totalOutflow` excludes posted transactions after its as-of date. Refunds remain separate from gross expenses by the documented product rule.
- Verified: all 363 `moneywise-checks` pass; Swift syntax parsing, project/entitlement lint, and `git diff --check` pass. The view behavior remains UNVERIFIED without an iOS runtime.

## Follow-up 2026-10-29 — Reject shared debt repayment plans

- Source review found that each debt checked its linked plan's amount and schedule, but did not reject a plan shared by multiple debts. The projection expands that plan only once, so shared links could understate required repayments.
- Extracted a deterministic MoneyCore debt-plan integrity rule and wired the SwiftData validation through it, including a count of debts referencing the same plan. Added checks for one valid outstanding debt, a shared plan, an understated installment, and an exhausted plan at confirmed zero balance.
- Verified: all 367 `moneywise-checks` pass; app/core/test Swift syntax parsing, Xcode project/entitlement lint, and `git diff --check` pass. SwiftData link loading and iOS type-check remain UNVERIFIED without full Xcode.

## Follow-up 2026-10-29 — Validate debt-plan cardinality and terms in MoneyCore

- The shared-plan check was previously expressed in the SwiftData view layer, so its financial invariant could not be exercised directly by the core suite. Moved the complete debt-to-schedule contract into `DebtRepaymentSchedule.matchesPlan` and made the view layer provide the count of debt records referencing the plan.
- The core contract now checks nonnegative balance, positive payment, unique linkage, confirmed monthly debt-repayment kind, matching first date and installment, and exhaustion at zero confirmed balance.
- Verified: all 367 `moneywise-checks` pass; app/core/test Swift syntax parsing, project/entitlement lint, and `git diff --check` pass. Native SwiftData integration remains UNVERIFIED without Xcode.

## Follow-up 2026-10-29 — Verify goal-plan linkage in MoneyCore

- Moved the goal-to-plan contract from the SwiftData view helper into `GoalContributionPlan.matchesLinkedPlan`. The contract covers link presence, a unique owning goal, confirmation, contribution type, monthly recurrence, matching amount/date, and the already-tested target/deadline/count/final-installment schedule.
- Added core checks for a valid linked plan, shared-plan rejection, wrong plan kind, and unconfirmed plan rejection. The view helper now supplies persisted link evidence to the domain policy.
- Verified: all 371 `moneywise-checks` pass; app/core/test Swift syntax parsing, project/entitlement lint, and `git diff --check` pass. Actual SwiftData fetch and app type-check remain UNVERIFIED without Xcode.

## Follow-up 2026-10-29 — Fail closed on duplicate account and goal IDs

- Duplicate account IDs could make one identity represent multiple balances and let transactions from an excluded duplicate account appear included. The root financial-data gate now requires unique account and goal identifiers, and the dashboard hides the combined account balance if account IDs are duplicated.
- Reserve accounting previously ignored saved-goal allocations when multiple allocations shared an ID. It now preserves each ambiguous saved amount independently and leaves linked envelopes separate, avoiding accidental release of protected cash.
- Verified: all 373 `moneywise-checks` pass, including unique-ID and duplicate-goal-reserve cases; Swift parsing, project/entitlement lint, and `git diff --check` pass. SwiftData corrupted-store presentation and iOS runtime remain UNVERIFIED without Xcode.

## Follow-up 2026-10-29 — Purchase at the next-income payment boundary

- Extended the existing income-day ordering regression to include a hypothetical purchase before the next payment cycle. It asserts that the current-day installment, the payment due at the expected-income timestamp, and the hypothetical purchase are all applied before the same-time income can raise the balance.
- Verified: all 374 `moneywise-checks` pass; app/core/test Swift syntax parsing, project/entitlement lint, and `git diff --check` pass. Native presentation and iOS runtime remain UNVERIFIED without full Xcode.

## Follow-up 2026-10-29 — Recheck forecast arithmetic and evidence baseline

- Re-read the goal and current roadmap against the repository. Audited the forecast's chronological event ordering, dated variable-spend prorating, saturating money arithmetic, and daily-limit binary search; this source pass did not establish a new correctness defect, so no financial behavior was changed.
- Re-ran `swift run moneywise-checks` successfully (374 checks), parsed the app/core/test Swift sources, linted the Xcode project and entitlements, and ran `git diff --check` successfully.
- These checks establish core behavior and source/project syntax only. They do not verify SwiftUI type-checking, SwiftData persistence, notifications, or device performance; full Xcode/iOS runtime acceptance remains UNVERIFIED and is the next major engineering gate.

## Checkpoint 2026-10-29 — Local privacy and reminder failure-path source pass

- Re-read the goal and inspected the current startup/store protection, lock lifecycle, full-data deletion, UserDefaults keys, and local notification payloads. The notification body contains no transaction names or amounts, and the app displays permission and pending-request counts in Settings.
- Fixed the identified failure path: `UNUserNotificationCenter.add` completion errors now track affected plan IDs in memory, Settings displays the count without persisting financial details, and a later successful scheduling attempt or plan deletion clears the failure state. The queue count is reread after each scheduling result; overlapping asynchronous refreshes use a generation guard so an older response cannot overwrite newer notification state. Full data deletion clears all scheduled failure state along with local notifications.
- Verification: Swift source parsing, 374 MoneyCore checks, project/entitlement lint, and a trailing-whitespace scan of the edited files pass. Native type-check, a forced notification-enqueue failure, and user-visible refresh behavior remain UNVERIFIED without Xcode/iOS runtime.
- This was a source inspection, not a completed Codex Security scan or runtime security assessment. The security plugin's required capability preflight was not available in the exposed tools, so no scan/report was launched or claimed.

## Follow-up 2026-10-29 — Do not confirm income dated today before credit

- The date-only picker stores today's choice at midnight, while forecast confirmation correctly requires a timestamp later than now. The form nevertheless let the user turn on a confirmation that would be silently discarded at save.
- Centralized expected-income eligibility in MoneyCore. A positive amount and strictly future date are now required both when settings are saved and when persisted settings are read; the confirmation control is disabled for today's date and explains that same-day expected funds are excluded until credited.
- Added three deterministic checks for same-day rejection, future-date confirmation, and explicit/positive-amount requirements. Verification: `swift run moneywise-checks` passes 377 checks, Swift source parsing and project/entitlement lint pass, and edited files have no trailing whitespace.
- Native SwiftUI type-check and picker/toggle interaction remain UNVERIFIED without full Xcode/iOS runtime.

## Follow-up 2026-10-29 — Date-only expected income arrives after same-day spending

- Normalized a selected expected-income date to the final second of that local calendar day when constructing the finance snapshot. The persisted DatePicker value remains date-only and unchanged.
- Purchase checks now return insufficient data for a purchase on the expected-income day, requiring a fresh check after actual credit. The Settings explanation identifies same-day funds as unavailable until credited.
- Added three checks for later-today rejection, end-of-day forecast boundary, and same-day purchase rejection. `swift run moneywise-checks` passes 380 behavior checks. Command Line Tools emit existing missing Xcode framework search-path warnings. Native Xcode/iOS runtime remains UNVERIFIED.
