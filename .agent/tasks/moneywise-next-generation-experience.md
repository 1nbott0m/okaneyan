# MoneyWise — next generation financial experience

## Objective and constraints
Implement the supplied MoneyWise specification in the existing native iOS app. Keep SwiftUI as the navigation owner, reuse `MoneyCore` and SwiftData data, preserve local records and current visual direction, and keep hypothetical scenarios out of persisted transactions. This is a local planning aid, not a bank lock or financial transaction system.

## Existing state
- The app already has a shared `FinanceSnapshot`/`FinanceEngine`, balances, a global protected floor, goal reserves, recurring obligations, income date, daily spend estimate, purchase checks, dark theme and an expandable balance card.
- The global minimum reserve is distinct from named earmarked reserves; do not count it twice.
- The launch cinematic is integrated in the root app, unrelated to the new feature motion.
- Tests are executable checks (`moneywise-checks`), not XCTest. `xcodebuild` is unavailable in the current host toolchain; SwiftUI runtime/simulator validation is therefore limited.

## Milestones and dependencies
1. Extend shared financial core with daily horizon and reversible purchase scenario; add regression checks.
2. Add native horizon and scenario UI that reads the same snapshot, with uncertainty states and accessibility.
3. Add named protected reserves as local persisted allocations, including partial release and warnings; integrate them once into availability.
4. Add data-bound Financial Gravity with a plain list fallback.
5. Apply restrained shared-element/spring transitions and Reduce Motion behavior across the new flows.
6. Run core and available syntax/build checks; inspect desktop/mobile preview and report simulator limitations.

## Acceptance criteria
- Forecast supports 1/7/14/30/90 days and presents dated balance projections, confirmed income/obligations, reserves, and uncertainty.
- Hypothetical purchase affects projections only and can be changed/removed without creating a transaction.
- Named protected amounts persist locally, allow partial release, and do not replace or double-count the existing minimum balance floor or goal allocation.
- Gravity uses existing financial data; every visual state has a readable alternative.
- Navigation, theme, existing transaction/balance flows, local persistence, and reduced-motion/accessibility behavior remain intact.

## Verification
- Extend and run `swift run moneywise-checks` for core calculations and scenario isolation.
- Run Swift parser checks on changed Swift source. Attempt package build if supported by installed toolchain.
- Inspect app source for all navigation, empty/error states, persistence and accessibility paths. Simulator/UI runtime and 60 FPS are unverified if Xcode remains unavailable.

## Progress
- Stage 0 source audit complete; this roadmap replaces no existing product decisions.
- Stage 1 complete: shared daily forecast, confirmed-event filtering, and isolated hypothetical purchase; core regression coverage added.
- Stages 2–5 implemented in source: native horizon/scenario, SwiftData named reserves with undo, financial gravity with list alternative, and Reduce Motion-aware shared transitions.
- Stage 6: `swift run moneywise-checks` passed 188 checks; Swift parser and Xcode project plist syntax passed. Desktop preview interactions for horizon, reserve partial release/undo, and gravity list were checked in Chromium.
- The preview’s stale reserve-summary rendering defect was fixed and rechecked after reload.
- Native typecheck, simulator/device behavior, app-store migration behavior, physical mobile viewport, and 60 FPS remain unverified because full Xcode is unavailable.

## Next action
When a full Xcode installation is available, build and run the iOS app, verify additive SwiftData migration, VoiceOver/Dynamic Type, Reduce Motion, and phone/landscape layouts; repeat mobile web preview checks at narrow viewport sizes.
