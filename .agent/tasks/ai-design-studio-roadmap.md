# AI Design Studio — roadmap

## Objective and constraints

Bring the current MoneyWise interface through a studio-style requirements, audit, research, art direction, design-system, flagship, motion and QA process. The submitted task specification makes G0 approval a blocking gate. User approved the full Requirements Baseline on 2026-10-29; implementation is authorized within its scope.

Preserve `PRODUCT_SPEC.md` invariants: local-first iOS app, no server/aggregator/cloud account, no payments, no fabricated bank synchronization, and no unsafe purchase verdict when data is insufficient. Preserve current financial functionality and persistence unless a separately approved Change Request says otherwise.

## Existing state

- Product: personal RUB finance planner, Russian UI, local SwiftData persistence, SwiftUI.
- Xcode project targets iPhone, minimum iOS 17.0. Full Xcode/iOS Simulator is unavailable in this environment; native runtime acceptance is currently not verifiable here.
- Source UI has three root tabs: Overview, Operations, Plan; supporting flows include purchase check, CSV import preview, accounts, transaction add/edit, plans, budgets, goals, debts and settings/lock.
- Existing browser file `preview/index.html` is an illustrative, demo-data web adaptation; it is not the actual native UI and cannot prove app persistence, bank access or native motion.
- Approved direction: Soft Matte Fintech, composition A «Тихий горизонт». User likes CoFo Drifter/Glassier/Kak, but licensed font files are not present; native app uses a Cyrillic-capable system fallback meanwhile.
- Source documentation: `PRODUCT_SPEC.md`, `README.md`, `DESIGN.md`, `design/`, existing `.agent/tasks/ios-mvp-roadmap.md`.

## Milestones and dependencies

1. **G0 — Requirements Baseline (complete).** User approved baseline v1.0 on 2026-10-29. Native iPhone app; web-only responsive preview.
2. **Stage 1 — Audit (complete, source-level).** Source/UI inventory captured in `design/04-screen-map.md`; Xcode and Simulator unavailable from active developer directory, so native runtime is not run.
3. **Stage 2 — Reference research (complete).** Public-source observations and typographic caveats captured in `design/01-reference-research.md`.
4. **G1 — Art direction (approved).** User confirmed Soft Matte Fintech in the supplemental MASTER ТЗ; composition A «Тихий горизонт» is used for the flagship. A/B/C selector remains review-only in the web prototype.
5. **Stage 4 — Design system (in progress).** Web tokens/touch/accessibility corrections are documented; shared semantic palette now exists in SwiftUI.
6. **G2 — Flagship screen (in progress).** Implement the approved Soft Matte Overview in native SwiftUI and keep the web preview as a review-only mirror. The available-balance card now expands with matched-geometry layout and spring motion; native runtime verification is unavailable because full Xcode/iOS SDK and device access are absent.
7. **Stage 6–7 — Motion and scale (in progress).** Motion contract in `design/03-motion-spec.md`; preview disclosure choreography and reduced-motion behavior verified in Chromium. Other native flows await runtime/device evidence.
8. **G3 — Independent QA (in progress for preview only).** Supplementary 180-item risk register and mobile audit are underway. Native runtime, physical iPhone and external reviewer are not available/verified here.

## Acceptance criteria

- Baseline approved explicitly before any UI code changes in this task.
- No unapproved changes to product scope, finance calculations, data model, privacy or bank integration architecture.
- Selected art direction and design tokens are documented before spreading changes to all screens.
- All agreed flows retain success, empty, loading, stale, error and privacy states where applicable.
- Motion has trigger/state/timing/interruptibility/reduced-motion behavior and never implies a financial value changed without a real state change.
- No P0/P1 defects remain at G3; limits and NOT RUN checks are explicit.

## Verification methods

- Static source and design-system audit after G0.
- Core regression scenarios for financial invariants.
- Native Xcode build, iOS Simulator/device screenshots and VoiceOver/Dynamic Type review when Xcode is available.
- Browser screenshots/functional checks only for the explicitly approved preview or shipping web target.
- Independent QA pass with issue severities, evidence and retest results.

## Current progress

- User explicitly approved all baseline requirements on 2026-10-29. G0 is complete.
- Source audit confirmed SwiftUI/SwiftData, iOS 17, root 3-tab owner `RootView`, palette/type owner `AppPalette`/`AppTypography`, and `MoneyCore` calculation owner. `DESIGN.md` and design contracts now exist.
- Public research completed for Sumeria/Fuse/Phantom/Orizon/Nixtio and foundry sources; evidence and type corrections recorded.
- Soft Matte Fintech art direction and composition A approved per supplemental MASTER ТЗ; concept selector is review-only. Motion contract and screen map prepared.
- Actual SwiftUI source now includes a shared-geometry balance reflow on card expansion, spring expansion/collapse, and a Reduce Motion fallback, alongside tab spring, selection haptic and amount-privacy transition. This is source implementation evidence, not runtime verification.
- `xcodebuild` resolves only CommandLineTools; no Xcode/iOS SDK and `simctl` unavailable. Current responsive web preview has been verified with Playwright; native visual QA remains NOT VERIFIED.

- Read submitted AI Design Studio TЗ, `README.md`, relevant `PRODUCT_SPEC.md` sections, Xcode deployment settings and UI inventory.
- Supplemental UX/mobile MASTER ТЗ captured; 180 checklist hypotheses registered: 40 `VERIFIED`, 22 `NOT_APPLICABLE` to this preview, 118 `UNTESTED`.
- Playwright viewport matrix passed for 320/360/375/390/430/768/1024/1440/1920 and 844×390/932×430 landscape. Tested mobile targets all ≥44 px with no overlaps or horizontal overflow.
- Form flow, focus trap/restore, add + demo-only reset, theme, privacy mask, tab, expansion, reduced-motion and toast placement passed in Chromium; no page errors.
- Baseline v1.0 approved: native iOS product, web review preview, preserve functionality and financial rules. Soft Matte and composition A are approved; CoFo remains unlicensed/unbundled.
- Responsive web preview received mobile target, landscape, focus, safe-area, contrast, reduced-motion and toast fixes. Native Overview now has the approved palette and available-balance card; see `design/13-mobile-qa-report.md` and `design/03-risk-register.md`.
- Preview balance expansion now itemizes demo calculation factors and animates the details; mobile/desktop captures refreshed. Chromium verified expanded behavior and no overflow at 320–1440 px plus two landscape sizes; `swiftc -frontend -parse` accepted the edited Swift files.

## Next actionable step

Next, continue applicable risk checks on the remaining native screens and preserve unverified statuses where runtime evidence is unavailable. When full Xcode/iOS hardware is available, build and review the flagship at supported Dynamic Type sizes, safe areas, VoiceOver, portrait/landscape, and physical touch. Keep G3/G4 acceptance open until native and human/device evidence exists.
