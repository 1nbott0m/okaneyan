# MoneyWise / okaneyan. design tokens

**State:** working implementation tokens, 2026-10-29. Soft Matte Fintech / composition A «Тихий горизонт» is owner-approved in DEC-008; D1 is its review-preview representation. Values here document the web preview and do not claim native parity.

## Color roles

| Role | Web dark | Web light | Purpose |
|---|---|---|---|
| Canvas | `#111011` | `#F5F1F2` | App background |
| Surface | `#1D1A1B` | `#FFFCFD` | Quiet content surface |
| Raised surface | `#262123` | `#EEE7E9` | Inputs and selected states |
| Text | `#F6F0F2` | `#191516` | Primary text |
| Secondary text | `#B5A9AD` | `#766D70` | Supporting labels; body copy stays readable |
| Rule | `#393235` | `#DED6D9` | Dividers and table boundaries |
| Rose accent | `#EFA8BE` | `#D99AAB` | Focus, selected date, brand accent |
| Rose emphasis | `#EFA8BE` | `#805D66` | Contrast-safe active labels |
| Positive / risk | semantic green / amber with text | same roles | Never communicate state by color alone |
| Metal edge | `#766A6E` | `#766A6E` | One restrained Living Card edge; never a full-canvas gradient |
| Metal glint | `#EEE5E7` | `#EEE5E7` | One short perimeter-only highlight during a horizontal drag |

Web values come from `preview/index.html`; native color values currently live in `AppPalette` and are close, not exact per role. The web and native palettes still need a side-by-side iOS capture before a strict color parity claim. Do not add purple, blue or ambient gradients to the financial workbench.

### D2 instrument surface (provisional comparison only)

| Role | Value | Use |
|---|---|---|
| Matte face | `#1B191A` | One balance instrument, unchanged between preview themes |
| Edge at rest | `#665159` | Thin perimeter stroke |
| Edge on hover/press | `#90747C` | Temporary CSS-only feedback; amount and labels stay fixed |

The edge response adapts the bounded surface-state principle from R-13 and R-14; it does not copy their models or code. D1/A «Тихий горизонт» is the owner-approved everyday direction (DEC-008); D2 remains a comparison-only study.

## Type roles

| Role | Current implementation | Rule |
|---|---|---|
| Brand | Existing okaneyan. wordmark/icon | Use only in brand placements and the Living Card |
| Financial display | System sans with tabular digits; CoFo Drifter is an unbundled candidate | Tabular figures, clear minus sign, fit `1 000 000,50 ₽`; do not use mono-looking labels everywhere |
| Short headings | System sans; CoFo Glassier/Kak are unbundled candidates | Preserve Russian word shapes and natural line breaks |
| Body and metadata | Native/system sans with Cyrillic | Prefer natural sentence case; no tiny tracked copy as decoration |

Required proof `ЯяЁё ₽ № −1 000 000,50` and license state are in `design/typography-and-layout.md` and `design/asset-provenance.md`. The owner-approved Oswald, Onest and Golos Text files are bundled with SIL OFL notices in the preview; the same files are included as native app resources. Native font loading/rendering is not yet verified without full Xcode/Simulator.

## Geometry and spacing

| Token | Value | Use |
|---|---:|---|
| Card radius / D1 balance card | 16 px web; 26 pt native hero (current) | One prominent Living Card; align radius after native capture |
| Row radius | 0–8 px | Data lists and transaction rows stay flat |
| Control radius | 8–12 px | Inputs and compact action controls |
| Large section gap | 24–32 px | Separate content groups |
| Dense row padding | 9–14 px | Transaction / breakdown lists |
| Mobile horizontal inset | 17–19 px preview | Keep sums visible at 360–430 px |
| Touch target | at least 44 px/pt | Primary actions, disclosure and navigation |

## Motion roles

Use the bands in `design/motion-bible.md`: feedback 80–180 ms, navigation 200–450 ms, state changes 250–600 ms, and signature transitions up to 900 ms only when interruptible. No idle orbit, ambient breathing or repeated number-counting. Reduced motion must leave state, back navigation and controls fully usable.

## Component rules

- `Living Card`: free-to-spend amount first, account total visibly separate, calculation disclosure in place, confirmed vs expected events differentiated in copy and shape.
- `Account artifact`: use the okaneyan mark only for a real manual/demo account context; no payment network, fabricated card number or claim of issuance.
- `Financial Horizon`: one selected date state drives marker, amount, chart and event list.
- `Financial Gravity`: component register plus accessible list; categories may overlap and must never imply additive totals.
- `Transactions`: ledger rows, not equal promotional tiles.
- `Feature entry points`: compact labeled rows on web preview and native navigation links; no three-card bento grid as default product chrome.

## Ownership and regression

- Web preview uses CSS custom properties at the `:root` / `data-theme` owner in `preview/index.html`.
- Native color and type use `AppPalette` and `AppTypography` in `iOSApp/AppTypography.swift`.
- Finance values and calculation labels continue to come from native MoneyCore/FinanceEngine; web preview sample values remain synthetic.
- Before changing these tokens, capture the affected screen, name the source/reference and direction, run the preview state matrix, and update the before/after evidence. Do not baseline a transient transition frame.
