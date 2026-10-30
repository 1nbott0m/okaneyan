# Review log

## 2026-10-29 — D2 matte edge response

- **Observe:** the split D2 card had a graphite face but its base border rule used `!important`, so the intended edge state did not change. An exploratory pointer-driven layer also produced unreliable browser captures; text and amount must remain legible in every material state.
- **Reference/direction:** keep D1 as default. D2 remains a provisional comparison; adapt only bounded, optional surface feedback from R-13 (Lumen material states) and R-14 (pointer response). The user's Okaneyan brand board is context for a restrained rose-metal tone; no logo artwork was copied.
- **Change:** D2 keeps a flat matte face at rest and uses CSS-only border-color feedback on hover/press. Removed pointer-driven inline paint updates and the full-card mask. Added a dedicated active-edge token.
- **Before/after:** `outputs/moneywise-instrument-before-dark-390.png` → `outputs/moneywise-instrument-after-dark-390.png`; hover `outputs/moneywise-instrument-hover-dark-390.png`; corresponding light, 768 and 1440 captures are listed in `design/visual-qa-matrix.md`.
- **Verify:** dedicated Playwright check passed hover → leave in both themes, 390/768/1440 widths, unchanged 7 500 ₽, visible amount, reduced-motion setting and disclosure operability. Full current design matrix, 30 required-state captures and 320–430 responsive audit also passed; matrix reports no console errors or overflow.
- **Limit:** Chromium preview only. The CSS `:active` fallback is not verified on a physical touch device; native SwiftUI and Reduce Motion remain unverified. Direction A is owner-approved; independent critique remains open.

## 2026-10-29 — native Reduce Motion source pass

- **Observe:** three visual transitions in SwiftUI were unconditional: the root tab spring, numeric amount masking transition and cinematic intro fade/wait. `accessibilityReduceMotion` already existed in the relevant native surfaces.
- **Change:** conditionally disable those extra transitions and avoid the intro delay when Reduce Motion is enabled. Financial values and action timing stay unchanged.
- **Verify:** `swiftc -frontend -parse` passed for both changed SwiftUI files; `swift build` exited 0 and MoneyCore checks exited 0 with 316 `PASS` lines.
- **Limit:** `swift build` does not compile the iOS app target. Full Xcode/Simulator was not available during this source pass, so native runtime and system Reduce Motion remained `NOT RUN` at that point.

### 2026-10-30 follow-up — Orbit O host transition

- **Observe:** `OkaneyanLaunchIntro` pauses its timeline and settles its mark under `accessibilityReduceMotion`, but `MoneyWiseApp` still wrapped overlay completion in an unconditional 200 ms fade. This host transition was outside the prior component-level source pass.
- **Reference / direction:** locked Orbit O geometry and readiness contract in `design/brand/okaneyan-orbit-o/Design/MOTION-SPEC.md`; keep the approved static docked mark and immediate readiness handoff, without a new visual effect.
- **Change:** use a nil animation transaction for host completion when Reduce Motion is enabled.
- **Verify:** Xcode app-target build completed; Reduce Motion preference was enabled in a newly created iPhone 18 Pro Simulator, the app launched, and its ready Overview was captured at `design/research/evidence/2026-10-30/ios-overview-reduce-motion-after.png`. This does not measure the 200 ms transition frame-by-frame or exercise the waiting orbit under slow startup.

## 2026-10-29 — empty history preview state

- **Observe:** native SwiftUI has an explicit no-transactions view, but the web preview hardcodes four history rows; the existing `.empty-state` rule was unused. The prior preview empty-state experiment centered the copy far from the ledger date heading.
- **Reference/direction:** preserve native `ContentUnavailableView` semantics, rendered with D1's aligned ledger rhythm and no added decorative card.
- **Change:** added explicit QA URL state `?preview-state=empty`, hid filter and sample-only category panels while empty, and aligned the empty copy to the list edge with a single separator. Demo-added transactions now appear in both Overview and Operations, and hide the empty message.
- **Before/after:** `outputs/moneywise-empty-before-dark-390.png` → `outputs/moneywise-empty-operations-dark-390.png`; light desktop pair at `outputs/moneywise-empty-before-light-1440.png` → `outputs/moneywise-empty-operations-light-1440.png`.
- **Verify:** Playwright 390/768/1440 × dark/light; empty state visible, zero history rows, filter hidden, no overflow/errors. Empty → add form → one demo history row passes. Full current 390/768/1440 regression matrix also passes.
- **Limit:** preview only, ephemeral data, no independent reviewer or native runtime. Large type remains open. G3 is not represented as passed.

## 2026-10-29 — mobile and total-risk audit, iteration 1

- **Observe:** mobile controls measured 30–37 px, phone landscape used desktop sidebar, form focus could return to document root, light control borders were weak, success toast intersected the bottom-nav region.
- **Diagnose:** desktop-first breakpoints and CSS sizing; modal trigger relied on activeElement after accessibility activation; toast anchored too close to viewport bottom.
- **Fix:** expanded mobile/tablet targets, added landscape-phone composition and safe-area insets, explicit trigger focus and Tab trap, 16 px input, higher contrast tokens, bottom-nav gap and toast offset/duration; corrected weekday.
- **Verify:** Playwright viewport and action flows; target rectangles and overlap detection; reduced-motion media; focus sequence; demo add/reload; theme/privacy/tabs/disclosure; zero page errors.
- **Result:** all measured touch viewport sizes pass; desktop 1440/1920 also fit, with mouse-oriented controls under 44 px.
- **Remaining:** actual iPhone/Android/Safari, 200% text, VoiceOver, axe, user study, performance and many of the 180 checklist items remain open.

## 2026-10-29 — D1 Living Card metallic edge response

- **Observe/reference:** D1's locked specification calls for metal only at the Living Card edge and a traveling specular line during direct drag. R-13/R-14 support bounded, optional response. The user-supplied `okaneyan-orbit-animation 2` is a separate launch scene; its README explicitly labels its dashboard sample markup, and the scene loops the Orbit O until app readiness. It supports the existing intro/handoff, not ambient animation on the financial work surface.
- **Change:** added semantic metal edge/highlight roles to CSS and `AppPalette`; D1 web Living Card gets a faint edge and short glint only during horizontal drag. Added equivalent optional SwiftUI source treatment, guarded by Reduce Motion. No idle movement, text sheen or FinanceEngine/MoneyCore changes.
- **Before/after:** `outputs/moneywise-living-card-rim-before-{dark,light}-{390,1440}.png` → `outputs/moneywise-living-card-rim-after-{dark,light}-{390,1440}.png`; active state `outputs/moneywise-living-card-rim-after-drag-390.png`.
- **Verify:** dedicated browser check passed drag, release, no text selection, disclosure, reduced motion, horizontal touch and preserved vertical scroll; 0 console errors. Full 9-case current matrix, 32-value CSS/SwiftUI palette contract, JS syntax and Swift frontend parse pass.
- **Limit:** G3 independent critique not tested. iOS app target, physical/simulator touch, VoiceOver, native Reduce Motion and FPS remain unverified without full Xcode/Simulator.

## 2026-10-29 — remove duplicated vertical income microcopy

- **Observe:** fresh D1 desktop capture repeated the income state vertically on the card edge («Зарплата не зачтена») while the next-income row and horizon already show date and expected status. On phone the pseudo-label was hidden, so layouts diverged.
- **Reference/direction:** D1 Quiet Horizon encodes useful chronology directly; R-01 Morrow supports amount-first progressive disclosure; R-15 Sumeria supports readable account chronology. Remove copy without removing the expected-income state.
- **Change:** deleted the pseudo-element and its amount padding from web D1 only. Amount, date, expected marker, timeline, business data and native code remain unchanged.
- **Before/after:** `outputs/moneywise-d1-label-before-{dark,light}-{390,1440}.png` → `outputs/moneywise-d1-label-after-{dark,light}-{390,1440}.png`.
- **Verify:** `work/pw-audit/capture-d1-decorative-label.mjs` confirms no pseudo-label at all four view/theme states, keeps “Следующее поступление” + “ожидается” and 7 500 ₽, no browser errors. Full design matrix and syntax checks pass.
- **Limit:** internal critique only; no independent G3. No native code change; iOS runtime still unverified.
