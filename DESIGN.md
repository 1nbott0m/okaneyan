---
version: alpha
name: okaneyan.
description: "Local-first Russian iPhone personal finance planner."
colors:
  currentAccent: "#D67E9D"
  currentSoftAccent: "#EFA8BE"
  currentLightCanvas: "#F5F1F2"
  currentDarkCanvas: "#111011"
  currentInk: "#171415"
  currentDarkSurface: "#1C1A1B"
typography:
  display:
    fontFamily: "Oswald, system-ui, sans-serif"
    weights: "500 600"
  ui:
    fontFamily: "Onest, system-ui, sans-serif"
  amounts:
    fontFamily: "Onest, system-ui, sans-serif"
    features: "tabular-nums"
  details:
    fontFamily: "Golos Text, system-ui, sans-serif"
rounded:
  currentCard: "1.5rem"
  currentButton: "1rem"
spacing:
  currentContentInset: "1rem"
components:
  rootNavigation: { owner: "RootView / native TabView" }
  theme: { owner: "AppPalette in iOSApp/AppTypography.swift" }
  typography: { owner: "AppTypography in iOSApp/AppTypography.swift" }
  financeVerdicts: { owner: "FinanceEngine in Sources/MoneyCore" }
---

# okaneyan. Design Context

## Overview

### Creative North Star

A personal money notebook organized around the **money horizon**: what is available now, which obligations stand between today and the next confirmed income, and why the number is trustworthy or unknown. The product should feel like a tactile instrument for clarity, not a bank lobby or crypto terminal.

### Product context and register

- **Audience and primary job:** one Russian-speaking iPhone user; understand how much is available before the next confirmed income and inspect the calculation.
- **Target market(s) and evidence:** Russian language and RUB are confirmed by `PRODUCT_SPEC.md`; this is not evidence of a bank integration or regulated advice status.
- **Locale(s):** Russian UI, RUB, localized dates and Cyrillic fallback.
- **Usage scene:** short, repeated iPhone checks; details are opened when a money decision needs explanation.
- **Register:** product-led, calm and precise.
- **Memorable signature:** the supplied Orbit O mark paired with the money-horizon timeline and spendable amount.
- **Restraint:** one expressive hero, quiet lists and native iOS navigation.
- **Anti-references:** generic AI dashboard gradients, crypto-trading terminal, copied bank branding, made-up sync or certainty.
- **Token ownership/runtime mapping:** frontmatter is a snapshot of current runtime values from `AppPalette`; Soft Matte Fintech and composition A are approved, and native palette rollout is in progress.

The approved dark Editorial/Okaneyan identity is the locked base. `design/concepts/2026-overview-directions.md` records D1/D2/D3 comparisons; D1 is the owner-approved A «Тихий горизонт» path (DEC-008), while D2/D3 remain review-only. `design/tokens.md` records current semantic and typography roles and the remaining web/native parity check.

## Colors

The frontmatter tokens named `current*` mirror the current runtime values. Keep financial meaning separate from pink: use distinct accessible success, warning, insufficient-data, and destructive roles with text labels. Light/dark themes share semantic hierarchy; change surface luminance rather than reverse status meaning.

## Typography

`AppTypography` provides Oswald for display and accents, Onest for controls/navigation and tabular amounts, and Golos Text for small details and transaction history. Exact Google Fonts variable files and SIL OFL notices are retained in `preview/fonts/` and included in the native resource phase. `design/asset-provenance.md` records hashes, required-glyph coverage and weight axes. The web preview confirms font loading and responsive output; native app rendering and Dynamic Type remain unverified until a full Xcode/Simulator is available. Keep display faces out of dense Russian body copy.

## Layout

The native product uses three root tabs in `RootView`: Overview, Operations, Plan. Preserve native safe areas, natural vertical scrolling, large touch targets and state continuity. Web is a responsive demo preview at 390, 768 and 1440 px, never a second production app. The overview hero precedes explanation, due items and recent operations; details expand in context.

## Elevation & Depth

Use material-like tonal steps, quiet borders and only restrained shadows. Dark mode uses graphite surfaces, not a pure black void; avoid blur behind dense money text. Native semantic surfaces are owned by `AppPalette` and track the approved Soft Matte system.

## Shapes

Current overview uses rounded rectangles around 24pt for the hero and cards/buttons around 16pt. Reserve the largest radius for the amount/horizon card; keep rows and controls less inflated. The icon artwork stays square; iOS owns its Home Screen mask.

## Components

### Foundational states

Each action has default, pressed, disabled, feedback/error and accessible focus states. Empty, stale, insufficient-data, hidden-amount and locked states must be explicit. Use native SwiftUI control semantics unless a tested product requirement needs custom behavior.

### Navigation and data display

`RootView` owns root tabs, `NavigationStack` owns list/detail push, sheets own add/import preview, and `FinanceEngine` owns verdicts. Preserve these owners. Charts and the proposed timeline must label known vs estimated data and provide accessible text.

### Iconography

Use the custom okaneyan. mark only for brand placements. Use SF Symbols for controls; icons supplement, never replace, Russian labels for important actions. Icon variant details and asset names are in `design/app-icon-spec.md`.

### Motion

The current code contains a spring on tab selection, haptic selection feedback, a matched-geometry balance expansion and a snappy amount-hide transition. Motion is documented in `design/03-motion-spec.md`; native runtime remains unverified. Custom motion is interruptible and respects Reduce Motion; never animate a balance as if real funds changed without a committed user action.

### Content and data visualization

Use direct, non-judgmental Russian copy, explicit dates and currency, and explain why a plan is constrained. Unknown/stale inputs say “Недостаточно данных”; no green-safe state without reliable history. Distinguish actual, expected and reserved values.

## Do's and Don'ts

- Do keep the available amount and the reason behind it together.
- Do use rose as a material accent, not as the only status channel.
- Do use native navigation and preserve existing financial-domain owners.
- Don't invent bank refresh, forecasts, persistence or transactions in the browser preview.
- Don't distribute CoFo binaries before the app-use license and actual font files are present.
- Don't spread brand marks across every screen; use them for launch, appearance settings, app information and system icons.
