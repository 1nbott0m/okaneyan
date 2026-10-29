# MoneyWise current state

**Snapshot:** 2026-10-30. This file is a checkpoint, not a command log.

## Git

- Main checkout `/Users/yan/Documents/ChatGPT/ян грамотные траты`: branch `codex/moneywise-native-ui`, HEAD `d7c206dc7cb6e1744a003608e03e0adc88f1216a`; modified `.gitignore`, `MoneyWiseUITests/MoneyWiseUserFlowTests.swift`, `README.md`, `design/02-art-direction.md`, `iOSApp/MoneyWiseApp.swift`; untracked `.github/`, `CONTRIBUTING.md`, `docs/` additions, and a simulator evidence PNG.
- UI worktree `/Users/yan/.codex/worktrees/moneywise-native-ui/ян грамотные траты`: branch `codex/moneywise-native-ui-work`, HEAD `46be9681879f7d69120193ad6652022e9d53521f`; six tracked diffs and 30 untracked status entries.
- Orbit worktree `/Users/yan/.codex/worktrees/okaneyan-orbit-o/ян грамотные траты`: branch `codex/okaneyan-orbit-o`, HEAD `72d8e89ca6e8b642a4a473c3d80e38e1a56b2061`; clean.
- No merge, reset, cherry-pick, or cleanup has been performed. Do not overwrite or discard these changes.

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
- Next: commit and push the verified working-tree changes. Physical-device and bank-sync acceptance remain separate.

See [requirements status](REQUIREMENTS_STATUS.md), [decisions](DECISIONS.md), and [implementation roadmap](../.agent/tasks/moneywise-integration-and-delivery.md).
