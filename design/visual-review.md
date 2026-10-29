# Visual review — concept review pass

## Render evidence

Captured with installed Google Chrome via Playwright at browser viewports 1440×1024 and 390×844. The same local page is also open in the in-app browser at `http://localhost:5175/?concept=a&rev=2`. Inspected all six PNGs with image viewer; desktop B/C and mobile A/B/C were individually compared. Native iOS Simulator was not available for this pass.

| Check | Finding | Correction / status |
|---|---|---|
| Copy and data | All three modes keep the same amount, reserve, payment, goal and operation data; all are explicitly demo preview values. | No financial calculations changed. Web demo figures remain illustrative. |
| Composition | Picker had been hidden and late CSS overrode A/B/C with one composition. | Selector is visible; A poster-like amount, B ruled ledger and C instrument panel now use different layout hierarchy. |
| Typography | At this review point CoFo names in CSS did not have files to render. | Superseded 2026-10-29: owner-selected local Oswald/Onest/Golos roles now load in web preview; exact source/license evidence and comparison are in `design/typography-and-layout.md`. Native runtime remains unverified. |
| Palette | Several overlapping dark tokens had shifted away from approved brand values. | Consolidated final overrides to approved charcoal/rose in dark, soft neutral/rose in light. |
| Surfaces and ornament | Decorative rings and card repetitions felt generic. | Ring and glow removed. A/B use open ruled composition; C has a single outlined instrument surface with functional timeline. |
| Phone layout | B amount originally wrapped into two rows; A/C metric labels became narrow columns. | B uses a stacked mobile ledger with a nowrap amount. A/C metrics are vertical label/value units. |
| Navigation/motion | Native-style tab movement existed but concept selection was not reachable. | Selector is touch/keyboard operable; concept changes use shared page transition with reduced-motion instant fallback. |
| Review control fidelity | Unselected concept buttons initially inherited the browser's gray default. Direct `?concept=b/c` loads also kept A's pressed state. | Buttons are transparent by default; first render, URL state and `aria-pressed` now agree. Screenshots were recaptured from independent concept URLs after all transitions finished. |
| Tap targets | Concept controls are at least 44px high on phone. | Verified in stylesheet and browser rendering. |

## Iteration log

1. **Audit pass:** found hidden selector, overruled concept CSS, absent CoFo files, orbital decoration and unsupported live-status appearance. Made the selector accessible and restored the dark matte charcoal/rose tokens.
2. **Composition pass:** replaced palette-only changes with A's large editorial type, B's ruled money ledger and C's instrument card/rail; reused the exact same data and screen actions.
3. **Mobile critique:** caught B's amount wrapping and A/C metrics clipping/wrapping; changed B mobile layout to stacked rows, A/C summaries to label-above-value blocks. Fixed C's doubled panel rules.
4. **Render pass:** captured desktop/mobile first viewports; confirmed amount alignment and panel hierarchy. Remaining work after user direction: any requested chosen direction gets ≥3 further focused critique cycles before SwiftUI adoption.

## Responsive and interaction status

- Browser widths 320, 390, 430, 768, 1440: no document horizontal overflow found for A/B/C.
- Tested expanded calculation (`aria-expanded=true`, region visible), Overview→Operations→Overview tab path, hide/show amount (`42 500` → masked → restored), light/dark toggle, and add-operation demo form.
- Demo-added row appears in the current preview and disappears after reload. This is intentionally not persistent and not a real financial operation.
- `prefers-reduced-motion: reduce`: balance-card transition duration resolves to `0s`; state changes remain usable.
- Browser console/page errors: none in the completed render pass.

## Copy and fidelity ledger

Above-the-fold product copy and numbers remain the pre-existing preview content. Intentional visible additions are the three-option review selector and one sentence describing the selected composition. No other above-the-fold copy was changed. The styles were compared against the locked content roles (brand charcoal, warm rose, system Cyrillic, timeline as actual dates/obligations, no unsupported prediction). No horizontal overflow or amount wrapping remains in checked widths.

## Deliverables

- Desktop: `outputs/okaneyan-concept-{a,b,c}-desktop.png` (1440×1024)
- Phone: `outputs/okaneyan-concept-{a,b,c}-mobile.png` (390×844)
- Browser page: `preview/index.html`, served at `http://localhost:5175/?concept=a&final=3` (the visible in-app browser has this version open)

## Selected A — three post-selection visual cycles

Selection: `A · Editorial`, confirmed by the user's response «а».

1. **Cycle 1 / composition:** Chrome screenshots exposed excessive desktop left-column width, long empty gaps, and a tall mobile hero. Narrowed the main column, aligned the two balance metrics, tightened the title and mobile financial block. `outputs/okaneyan-editorial-cycle-1-1440.png` and `...-390.png` were inspected. The mobile first viewport shows the balance, next income, horizon and both metrics.
2. **Cycle 2 / editorial hierarchy:** the overview title did not establish its own rhythm. Increased its scale, tightened its relationship to the financial content, and added the factual desktop marginal note “ЗАРПЛАТА НЕ ЗАЧТЕНА”. The note is hidden on phone where the same fact is already clear from the expected-income line. Captures `outputs/okaneyan-editorial-cycle-2-{1440,390}.png` inspected.
3. **Cycle 3 / motion:** automatic block entrance delayed legibility and looked generic; tab transitions ignored Reduce Motion. Removed load-time entrance motion for A, retained interactive calculation-row motion, linked amount/balance/next-income as shared transition elements, and disabled view transitions when reduced motion is requested. Captures `outputs/okaneyan-editorial-cycle-3-{1440,390}.png` inspected; reduced-motion and interactive states checked.

## Remaining limits

- This is a web-only review demo, not production or an iOS Simulator run. Browser sample numbers are not read from `FinanceEngine`; the native SwiftUI app and its existing calculator remain unchanged.
- CoFo binaries remain excluded. The system fallback is retained; the owner-selected Google Fonts roles are now the loaded web faces. iOS registration/render QA remains unverified.
- Refero did not provide research due `NO_SUBSCRIPTION`; conclusions use sources documented in `creative-research.md` and the reference audit.
- Selected A has completed the three required web critique cycles. Native SwiftUI integration and iOS Simulator QA are the next step and remain `NOT DONE`.

## Overview completeness check against iOS `RootView.home`

The user correctly identified that the earlier web overview surfaced fewer native-home areas. Compared against `iOSApp/MoneyWiseApp.swift`, the web preview now includes the following overview roles: available balance and breakdown; account/reserve summary; next confirmed payments; plan health / daily-limit explanation; spending analytics with an explicit sample-period switch; purchase-check entry; recent operation list (four existing sample rows, with income excluded from the shown expense total); budgets and goal; and the manual-balance / account state. This aligns with native overview *sections*, without attempting to put the complete operation database on one screen.

Numbers in the browser remain static illustrative values and are not connected to SwiftData or `FinanceEngine`. The forecast and safe daily limit are therefore identified as app-calculated, not presented as computed demo facts. Expense sample sum `35,030 ₽` is the sum of the three displayed outflows (`32,000 + 2,340 + 690`); the income row is excluded. Accounts show one manual aggregate because the preview contains no account-level split.

Verified in Chrome at 1440×1024 and 390×844: all three new section headings render, four sample transactions are present, the period control updates its label, amount hiding also hides chart values/accessibility content, purchase-check opens the demo modal, calculation expands, and there is no horizontal overflow or browser error. Captures: `outputs/okaneyan-editorial-expanded-{1440,390}.png` and `outputs/okaneyan-editorial-expanded-detail-{1440,390}.png`.
