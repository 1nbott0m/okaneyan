# MoneyWise integration and delivery roadmap

## Objective and constraints

Deliver a coherent, usable native iPhone MoneyWise flow for account balance, dated obligations, forecast, purchase checking, local persistence, and relaunch. Preserve local-only storage and exact-money behavior. Automatic bank sync remains blocked unless a bank confirms a permitted direct iOS route; no backend, intermediary, aggregator, scraping, or credential collection. Keep the existing three worktrees and all dirty/untracked work intact. The web preview remains synthetic review data.

## Existing state

- Main checkout: `codex/moneywise-native-ui`, HEAD `d7c206dc7cb6e1744a003608e03e0adc88f1216a`, dirty in five tracked files plus untracked workflow/docs/evidence.
- UI worktree: `codex/moneywise-native-ui-work`, HEAD `46be9681879f7d69120193ad6652022e9d53521f`, six tracked diffs and 30 untracked status entries.
- Orbit worktree: `codex/okaneyan-orbit-o`, HEAD `72d8e89ca6e8b642a4a473c3d80e38e1a56b2061`, clean.
- MoneyCore and extensive SwiftUI flows exist. Historical checkpoint reports 380 core checks and selected simulator persistence scenarios. These are not a fresh verification of the current dirty checkout.
- Xcode 27.1 and iOS 27 simulators are installed. `xcode-select` points to Command Line Tools, so native commands must set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` rather than changing global developer selection.

## Milestones and dependencies

1. **Consolidate truth and preserve state** — map three histories, Git states, shared-file conflicts, and requirement statuses. Do not merge/reset/cherry-pick.
2. **P0 user flow** — validate current source and available core behavior for balance → obligation → forecast → purchase check → save/relaunch; repair only a concrete gap in that flow.
3. **P1 daily use** — close highest-value import, transaction editing, plans/debts, goals/budgets, notification, and privacy flows without repeating broad audits.
4. **P2 visual integration** — reconcile the UI worktree incrementally against current approved design rules and preserve financial behavior. Integrate Orbit only when its app-ready contract and exact visual asset are reviewed.
5. **Release acceptance** — use full Xcode/Simulator for current-sha build and focused persistence/accessibility checks; physical-device and bank access remain separately reported.

## Acceptance criteria

- The main scenario is reachable from the actual native UI and uses one local store.
- Balances, reserves, obligations, and forecast are coherent; expected income is not represented as current cash; insufficient/stale data fails closed.
- A purchase produces a specific, deterministic result and any scenario edit is explicit and does not create a transaction unintentionally.
- Changes persist after relaunch; import is previewed and repeated imports do not silently duplicate rows.
- No synthetic preview data is presented as real data; no bank lock or unsupported sync is claimed.
- Every criterion is marked with evidence as `TODO`, `IN_PROGRESS`, `BLOCKED`, `IMPLEMENTED_UNVERIFIED`, `DONE_VERIFIED`, or `DEFERRED`.

## Verification methods

- Focused MoneyCore checks and package build for changed calculations.
- Swift parser/project lint where applicable.
- Full Xcode build and targeted UI/persistence flow only on a host with Xcode/iOS SDK.
- Simulator evidence is not physical-device evidence. Historical results are labeled historical, not freshly rerun.

## Current progress and next action

- **Continuation from `97d28c5`:** inspected repository memory, requirement registry, and integration roadmap; preserved all other worktrees. Stage A source already rejects unsafe purchase advice when balance freshness/history/plan confidence is inadequate. Account rows did not expose balance age, so they now show the manual check timestamp and stale/future status. Existing account/transaction UI flow passed once (1/1) with the freshness label on iPhone 18 Pro Simulator; screenshot: `design/research/evidence/2026-10-30/ios-account-balance-freshness-iphone18pro.png`. A later attempt to exercise scrolling at the largest Dynamic Type category hit a long-running XCTest/simulator runner after accumulated test data. It was stopped without clearing simulator data; scroll inset has compiled but still needs focused confirmation on a clean simulator. Next: finish P0-01/P0-06 evidence on a responsive clean simulator, then proceed in order through P1 user paths.

- Milestone 1: complete. Current Git states captured; three source handoffs consolidated into `docs/HANDOFFS/`; product vision, decisions, design rules, requirement registry and current checkpoint added. Dirty worktrees and their changes remain intact.
- Milestone 2: P0 flow verified in a targeted clean iPhone 17e Simulator UI run. On 2026-10-30, Debug Simulator build succeeded; `swift run moneywise-checks` passed 380; Swift parse, project lint and diff whitespace check passed. UI account/transaction save-and-relaunch passed on iPhone 17 Simulator; purchase-check route with empty data passed on a clean iPhone 18 Pro Simulator; Face ID lock coverage passed on the dedicated diagnostic Simulator. The combined flow created a 500₽ obligation, retained a confirmed future 5,000₽ income separately from current cash, produced safe and unsafe purchase verdicts, and verified obligation/income persistence after relaunch. A bug that cleared income confirmation while SwiftUI populated saved settings on open was fixed. Only temporary simulator state was used and the test fixture is compile-time simulator-only and gated by an explicit launch flag.
- Delivery: push the current documented and verified checkpoint to `origin/codex/moneywise-native-ui`; preserve the separate UI and Orbit worktrees. The GitHub repository was initially empty; local SSH host verification failed, so HTTPS was used to establish the branch.
- **Continuation from checkpoint `ad0696f`:** inspected the actual UI and Orbit worktrees and preserved their states. The UI worktree remains dirty; the Orbit worktree remains clean. Integrated the existing native Horizon/Reserves/Gravity surfaces and their focused display/privacy/validation corrections without changing MoneyCore calculations. Replaced the previous app intro with the supplied readiness-aware Orbit O component and copied its master assets/spec into the main app repo. UI routes remain connected to existing local MoneyCore/SwiftData behavior.
- **Current verification:** Simulator app-target build and launch succeeded; empty Overview before/after screenshots recorded. Existing account/transaction, goal/budget/debt, and CSV import/dedup flows passed focused Simulator checks (the CSV fixture was staged only in the temporary simulator). The Horizon test passed before adding concrete assertions for the newly corrected empty-value states; a subsequent runner stalled and has no result. No P0 scenario was repeated. `docs/CURRENT_STATE.md` and `design/research/visual-gap-audit.md` record these boundaries.
- **Follow-up verification/fix:** live Simulator evidence exposed the Overview recent-operations heading/rows under the floating tab bar. An 18-point inset did not provide enough clearance; 96 points plus an explicit drag in the existing account/transaction persistence flow resolves it. That existing flow now passes (1/1), with a retained screenshot showing all five rows clear of the tab bar. The existing Horizon empty-data/range test now also passes (1/1) with “Нет баланса”/“Нет оценки” assertions. No P0 scenario was repeated.
- **Not complete:** integrated animation fidelity, VoiceOver, Reduce Motion, Dynamic Type, independent critique, and physical-device readiness. Commit/push this follow-up to the task branch. Never merge `main` without explicit approval.
- Known non-blockers: Xcode emits UserNotifications async/Sendable warnings and environment build-version logging warnings. Physical-device and bank-sync acceptance remain unverified/blocked externally.
