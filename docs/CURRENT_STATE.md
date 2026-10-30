# MoneyWise current state

**Snapshot:** 2026-10-30, after UI/Orbit integration; commit hash will be filled after delivery.

## Git

- Main checkout `/Users/yan/Documents/ChatGPT/ян грамотные траты`: branch `codex/moneywise-native-ui`, starting checkpoint `ad0696f89fc68e5e5e8049924094825ecf73117b`; currently contains the UI/Orbit integration changes described below, not yet committed.
- UI worktree `/Users/yan/.codex/worktrees/moneywise-native-ui/ян грамотные траты`: branch `codex/moneywise-native-ui-work`, HEAD `46be9681879f7d69120193ad6652022e9d53521f`; six tracked diffs and 30 untracked status entries.
- Orbit worktree `/Users/yan/.codex/worktrees/okaneyan-orbit-o/ян грамотные траты`: branch `codex/okaneyan-orbit-o`, HEAD `72d8e89ca6e8b642a4a473c3d80e38e1a56b2061`; clean.
- The two remaining worktrees were compared against the checkpoint. The UI worktree remains dirty with its research and uncommitted materials; Orbit worktree remains clean. No source-worktree changes were overwritten, reset, merged, or discarded. Only the specific UI fixes and Orbit component/assets were copied into the main checkout.

## Confirmed from this checkout

- Main UI source contains accessible Overview entry points, account/plan screens, purchase checking, local settings, CSV preview, and SwiftData save paths.
- The current uncommitted `MoneyWiseApp.swift` change concerns the Face ID setup warning and clears stale warning state after successful capability checking. The corresponding UI test asserts lock-screen coverage; a prior focused Simulator run passed.
- Historical project checkpoint reports 380 MoneyCore checks and selected Simulator flows, including account/purchase and CSV persistence. These are historical evidence, not a run against this present dirty state.
- Xcode 27.1 and iOS 27 Simulator are installed, but `xcode-select` points to Command Line Tools. Setting `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` exposes `xcodebuild` and `simctl`; the current Debug Simulator build succeeded in `/tmp/MoneyWiseDerivedData`.

## Product blockers and next action

- Automatic bank sync without backend/intermediary remains blocked pending explicit bank approval for direct iOS access.
- Main P0 purchase/forecast/persistence scenario passed a targeted end-to-end UI test on a clean temporary iPhone 17e Simulator on 2026-10-30.
- Fresh verification: `swift run moneywise-checks` passed 380 checks; Swift source parsing, `plutil -lint MoneyWise.xcodeproj/project.pbxproj`, and `git diff --check` passed. `xcodebuild build` for iOS Simulator succeeded.
- UI verification: account + transaction creation and save/relaunch passed on iPhone 17 Simulator (1/1); purchase-check screen access and fail-closed empty-data verdict passed on a clean iPhone 18 Pro Simulator (1/1); enabling app lock and covering Overview passed on the dedicated MoneyWise-Lock-Diagnostic Simulator (1/1).
- Combined P0 flow: passed on a clean temporary iPhone 17e Simulator. A gated synthetic fixture supplied a 10,000₽ account, 5,000₽ confirmed expected income dated seven days ahead, and 10 historical transactions. The UI created a 500₽ obligation, confirmed the income remains separate from current cash, received safe/unsafe purchase verdicts, and verified obligation and income-confirmation persistence after relaunch. This exposed and fixed a settings-load bug: SwiftUI `.onChange` cleared the confirmation during programmatic field population. The fixture requires an explicit test launch flag and an empty Simulator store. The temporary simulator was deleted; existing simulator data was preserved.
- Test-state note: a second isolated purchase-check run on iPhone 17 failed because the prior UI test had left its newly created account/transaction in that Simulator's persistent store. The same purchase check passed on a clean Simulator. This is test-state coupling, not evidence of a calculation defect. Avoid clearing existing simulator data wholesale.
- GitHub delivery: SSH push was blocked by host-key verification; the branch was successfully created through HTTPS and the complete work is being prepared as a follow-up commit.
- Xcode emits non-blocking UserNotifications async/Sendable warnings and OS build-version logging warnings. These were not changed because they are unrelated to the user flow.
- UI integration: Horizon, Reserves, Gravity, Purchase, accounts, operations, and planning remain native routes backed by existing MoneyCore/SwiftData. Missing account/spend estimates no longer display as 0 ₽; privacy hiding now covers relevant VoiceOver labels; reserve validation is reachable while the save guard still prevents invalid mutation.
- Orbit integration: app target uses the supplied readiness-aware `OkaneyanLaunchIntro`; root readiness drives dismissal, the root stays mounted behind it, and there is no artificial delay. Master SVG, preview raster, and motion spec are in `design/brand/okaneyan-orbit-o/Design/`.
- Fresh verification: integrated Debug app target builds for iOS Simulator; launch was captured on a temporary iPhone 17e Simulator. Existing account/transaction persistence, goals/budgets/debts persistence, and CSV import/deduplication flows passed focused Simulator runs (CSV with its fixture installed in the temporary simulator). The existing Horizon test passed before adding assertions for the empty-balance/estimate copy; its rerun stalled in Xcode's test runner and produced no valid result. A combined CSV run without its fixture failed at fixture lookup. The combined P0 flow was not repeated.
- The two new assertions in the existing Horizon UI test remain unverified. Integrated animation-frame fidelity, physical iPhone, VoiceOver, Reduce Motion interaction, Dynamic Type, and independent design critique remain unverified.
- Remaining product limitations: automatic bank sync is externally blocked; data is local/manual/CSV-based. Simulator launch is not physical-iPhone acceptance, and design requirements are not all complete.
- GitHub delivery: SSH host-key verification fails; HTTPS push is available for `codex/moneywise-native-ui`. Next: inspect final diff/status, commit only this checkout's intended changes, and push that branch. Do not merge `main`.

See [requirements status](REQUIREMENTS_STATUS.md), [decisions](DECISIONS.md), and [implementation roadmap](../.agent/tasks/moneywise-integration-and-delivery.md).
