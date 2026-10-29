# okaneyan. radical product UI redesign

## Objective and constraints
- Create three materially different, interactive browser concepts for the existing iOS personal-finance product, then let the user select one before committing a direction to native UI.
- Preserve FinanceEngine results, source freshness/uncertainty, privacy controls, accessibility, Russian and RUB, Orbit O brand assets, local-only product boundary, and reduced-motion behavior.
- Browser is a demo preview. Do not invent or mutate financial data, call banks, claim persistence, or perform financial actions.
- Research real 2025–2026 design work and the user's Sumeria, Fuse, Phantom, Orizon, and Nixtio references before implementation. Do not copy any one reference.

## Existing implementation state
- Native application: SwiftUI `RootView`, three-tab `TabView`, real `FinanceEngine`, `AvailableBalanceCard`, obligation/goal/budget/debt flows, local-first demo.
- Browser preview: one responsive HTML page with demo-only values and working tabs, amount masking, theme toggle, expandable calculation, and demo forms. A recent anti-template pass removed dashboard chrome, but it is still only a single concept and does not satisfy this radical redesign brief.
- CoFo font binaries are not present in the repository; Cyrillic-capable system fonts currently back the selected CoFo names.

## Milestones and dependencies
1. Research: inspect the five named references, recent experimental/editorial product work, Refero visual styles, and concrete iOS money screens.
2. Synthesize: produce a source-backed reference lock, constraints, three concept definitions, and decision ledger before coding.
3. Prototype: create three interactive, responsive browser versions of the same overview screen using the same demo data and actions.
4. Review: capture desktop/mobile screenshots, critique each direction against UX/accessibility/financial clarity, and document at least one corrective iteration per concept.
5. Handoff: expose the three previews in the browser, compare them clearly, preserve all existing functionality, and ask the user to choose. Apply three focused critique/improvement cycles to the chosen direction before native integration.
6. Apply the selected A · Editorial visual system to the existing SwiftUI app without changing FinanceEngine behavior; verify with the available iOS build/simulator tools.

## Acceptance criteria
- Three distinct concepts: Editorial Punk, Financial Zine, and Precision & Vandalism, each shown on desktop and phone.
- Shared numbers and content across concepts; no alternative design may alter domain calculations.
- At least three product-specific visual/interaction patterns, original cash-flow/available-money visualization, and motion with Reduce Motion fallback.
- The main navigation, hide-amounts control, theme, calculation expansion, and demo actions remain usable.
- No horizontal overflow at 320/390/430/768/1440px; touch targets and text contrast are checked.
- Required research, art direction, anti-pattern audit, concept comparison, motion language, visual review, and six screenshots are saved.

## Verification methods
- Refero style and iOS screen research; direct inspection of publicly available official reference pages where available.
- Browser inspection at desktop and mobile sizes; screenshots for A/B/C.
- Interaction checks for navigation, expanded calculation, privacy mask, theme, demo add/check action, and keyboard/reduced-motion/accessibility states.
- JavaScript syntax, DOM/overflow checks, browser console and failed requests, `git diff --check`.
- Native iOS build is separately marked unverified if Xcode/iOS SDK is unavailable; web prototype verification is not native verification.

## Current progress
- After the user noted the overview felt too sparse, compared it to `RootView.home` and added preview counterparts for forecast/daily-limit status, expense analytics, purchase check, accounts, and a fourth recent operation. The web demo labels non-integrated calculations and account split explicitly. Chrome checks at 1440/390 passed with privacy masking and interaction coverage.
- User selected A · Editorial («а»). Three post-selection critique/improvement cycles are complete and recorded in `design/iteration-report.md`; the latest desktop/mobile renders are in `outputs/okaneyan-editorial-cycle-3-1440.png` and `outputs/okaneyan-editorial-cycle-3-390.png`.
- Read the new brief and confirmed the project remains native iOS with a web preview and a deterministic finance calculation owner.
- Recent visual pass is still a single design and was explicitly called out as too template-like in the attached spec.
- Refero style and iOS screen queries returned `NO_SUBSCRIPTION`; public sources were read directly and limitations recorded. Morrow (2025 concept), Finaura (2025 author concept), official Sumeria/Fuse/Phantom, and prior Orizon/Nixtio evidence are documented in `design/creative-research.md`.
- Root cause of identical variants fixed: selector was hidden by a late CSS override; latest CSS had collapsed concepts back to one system. Three truly different responsive compositions are now selectable in the browser.
- Mobile B amount wrapping and A/C metric wrapping were fixed after actual Chrome captures. C doubled section rules removed. Six viewport captures are in `outputs/`.
- Browser verification via Playwright using installed Google Chrome: 320/390/430/768/1440 widths with all concepts produced no horizontal overflow; expansion, tabs, privacy mask, theme, demo form and reduced-motion behavior were inspected. Console/page errors: none in completed render pass. Demo add clears on reload as expected.
- Native SwiftUI/FinanceEngine source remains unchanged; native runtime was not verified.
- Artifacts now include research, anti-pattern audit, art direction, concepts, motion, iteration report and visual review.
- Added a matte Okaneyan account summary card to selected concept A, replacing the redundant first metric while keeping the reserve metric and detailed account section. The card shows the existing manual demo balance, is clearly labeled as a planning account, and links to balance sources; it does not imply payment-card issuance.
- Browser interaction checks passed for card-to-accounts navigation, amount masking, theme toggle persistence across reload, and light-mode contrast in the collapsed balance. Responsive overflow checks at 320/390/430/768/1440 px all reported document width equal to viewport width.
- Light theme contrast was corrected for the editorial balance and expanded calculation total. The browser preview was returned to dark mode after review.
- Conformance audit found and fixed a privacy masking gap: all 42 monetary nodes, including a newly added demo row, stay redacted while hiding is active. The current browser at 1280×720 also exposed a horizon label under the fixed nav; compact short-height spacing now measures 640 px content bottom vs 654 px nav top.
- The conformance audit is saved at `design/requirements-conformance-audit.md`. Risk register updated to 39 VERIFIED / 22 NOT_APPLICABLE / 119 UNTESTED: landscape overlap is left open until a final viewport retest.
- Found the approved standalone Orbit O cinematic prototype and readiness spec in the user's `outputs/okaneyan-orbit-animation` deliverable. It is not yet connected to SwiftUI app startup; `LaunchScreen.storyboard` remains static. The full Xcode build cannot run with the installed Command Line Tools-only setup.
- Native CoFo font binaries remain absent; the fallback now uses system sans with Cyrillic support instead of monospaced digits.

## Next actionable step
- Integrate the approved Orbit O sequence into SwiftUI startup and gate the handoff on actual SwiftData readiness, preserving the static system launch screen and Reduce Motion path. Then run the final landscape viewport retest and native iOS Simulator/device checks when full Xcode is available. Keep the browser page as the review surface.
