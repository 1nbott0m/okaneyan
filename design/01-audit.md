# Этап 1 — исходный аудит интерфейса

**Статус:** source audit completed; browser/device visual capture not run in this turn.

## Контекст и владельцы

- Native UI: `iOSApp/MoneyWiseApp.swift`, SwiftUI + SwiftData, iOS 17, русский язык, 3 root tabs.
- Shared palette/typography: `iOSApp/AppTypography.swift` (`AppPalette`, `AppTypography`).
- Financial calculations and verdicts: `Sources/MoneyCore`; UI must render these results rather than compute a second formula.
- Browser review preview: `preview/index.html`, fixed demo data and browser-local interactions. Not production app, service, or persistence evidence.
- No maintained `DESIGN.md`/`UX-CONTRACT.md` existed at audit start; `DESIGN.md` now documents actual current owners and distinguishes G1 proposals.

## Findings

| ID | Priority | Finding | Evidence | Requirement / action |
|---|---|---|---|---|
| AUD-001 | P1 | **Initial baseline finding:** native code had only tab spring + selection haptic and amount-hide transition; no shared-element/card expansion choreography. The native flagship now contains matched-geometry card expansion in source; runtime recheck remains unavailable. | `MoneyWiseApp.swift` `RootView` and `AvailableBalanceCard`; see `03-motion-spec.md`. | REQ-007 / M-02 added to native source with Reduce Motion fallback; verify on an iOS runtime when available. |
| AUD-002 | P1 | iOS build/runtime screenshot could not be produced: `xcodebuild` resolves CommandLineTools and `simctl` is missing. | Environment probe 2026-10-29. | AC-014 = NOT RUN; verify on full Xcode/iOS Simulator later. |
| AUD-003 | RESOLVED IN SOURCE/WEB; NATIVE RUNTIME OPEN | Earlier code referenced CoFo without bundled binaries, causing system fallback. Owner-selected Oswald/Onest/Golos files are now pinned, licensed, included and loaded in web preview; the iOS target references them. Native app build/render and Dynamic Type remain unverified. | `design/asset-provenance.md`; `outputs/moneywise-typography-report.json`; `AppTypography.swift`; Xcode resource phase. | No CoFo files; run native build and font/glyph QA when full Xcode is available. |
| AUD-004 | P2 | Browser preview is a one-file adaptation with demo numbers and subset flows; some actions are toast/demo-only. | `preview/index.html` UI and handlers. | Keep visible preview disclaimer; do not treat as native UX or persistence proof. |
| AUD-005 | P2 | Current palette is already matte-ish, but hero takes a simple dark rounded card; no clear visual device connects available money with dated commitments. | `AppPalette`, `RootView.home`. | Explore money-horizon signature in three G1 concepts. |
| AUD-006 | P1 | Auto-sync aspirations in product spec remain unverified for a standalone direct native bank API; no fake connected/updated state is safe. | `.agent/bank-api-eligibility.md` and `ios-mvp-roadmap.md`. | UI must visibly distinguish local/manual/CSV data and freshness. |
| AUD-007 | RESOLVED IN WEB; NATIVE WEIGHT MAPPING OPEN | The previous split fallback roles are superseded by explicit Onest/Oswald/Golos APIs. Browser confirms computed roles and Cyrillic text; native variable-axis appearance is unverified. | `AppTypography.swift`; `design/asset-provenance.md`; type comparison captures. | Verify in built iOS app on full Xcode/Simulator. |

## Severity definitions

P1 here means blocks design verification or risks materially misleading UX; P2 means polish/consistency gap. No runtime defect is asserted from this static audit. Native simulator and browser screen captures are **NOT RUN**, not PASS.
