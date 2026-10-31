# Design system — Soft Matte Fintech

**Direction:** Soft Matte Fintech / A «Тихий горизонт» is approved in DEC-008. This semantic table is implemented in the SwiftUI palette provider and the web preview. Source-level parity is checked; native pixel parity and iOS contrast rendering still require Xcode/Simulator evidence.

| Semantic token | Light | Dark | Use |
|---|---|---|---|
| Page | `#F5F1F2` | `#111011` | Warm matte canvas |
| Surface | `#FFFCFD` | `#1D1A1B` | Panels and dialog |
| Surface soft | `#EEE7E9` | `#262123` | Form field background |
| Ink | `#191516` | `#F6F0F2` | Primary text |
| Muted | `#766D70` | `#B5A9AD` | Secondary text |
| Divider | `#DED6D9` | `#393235` | Separation |
| Control border | `#8D8185` | `#766A6E` | Inputs and close control |
| Rose | `#D99AAB` | `#EFA8BE` | Quiet accent |
| Rose pale | `#F2E1E6` | `#34252A` | Selected and supporting surface |
| Rose deep / focus | `#805D66` | `#EFA8BE` | Focus and small accent |
| Hero surface | `#171516` | `#1D1A1B` | Living Card / emphasized money context |
| Hero ink | `#F6F0F2` | `#F6F0F2` | Text and amounts on the dark Living Card |
| Hero muted | `#D0C8CB` | `#D0C8CB` | Supporting copy on the dark Living Card |
| Hero divider | `#393235` | `#393235` | Internal rules and timeline rail on the card |
| Hero accent | `#EFA8BE` | `#EFA8BE` | Timeline and primary card marker |
| Metal edge | `#766A6E` | `#766A6E` | Restrained static edge on the Living Card only |
| Metal highlight | `#EEE5E7` | `#EEE5E7` | One short perimeter glint, revealed only by a direct horizontal drag |
| Black | `#171516` | `#080809` | Primary button |

## Type and scale

- Oswald Variable 500/600 is reserved for page/detail-screen display titles, short accents and the text wordmark. Compact panel headings and feature-link titles use Onest so display type does not become a repeated UI-kit texture.
- Onest Variable is the UI and control face, including compact panel headings; Onest amounts use tabular figures (`tnum`) and keep the minus sign and ₽ aligned.
- Golos Text Variable is selected for small details and transaction history after a same-layout Onest/Golos comparison at 390/1440 in dark/light preview states.
- Exact binaries, SIL OFL notices, hashes and `ЯяЁё ₽ № −1 000 000,50` proof are listed in `design/asset-provenance.md`. The web preview loads all three faces; native resources and `AppTypography` are wired, while iOS rendering remains unverified without full Xcode/Simulator.
- Keep display typography out of dense financial copy. Mobile form fields remain 16 px and primary labels retain readable contrast.

## Touch / focus / motion

- Mobile/tablet controls: min 44×44 CSS px; key gaps 8 px. Keep icon artwork compact inside expanded target boxes.
- Keyboard focus: 3 px `:focus-visible` outline using deep rose.
- Form controls: ≥3:1 sampled border contrast; normal text token pairs ≥4.5:1. Full component-pair scan remains open.
- `prefers-reduced-motion: reduce` disables nonessential movement and smooth scrolling.
- Safe-area env values are wired into mobile and modal layout but require physical iOS validation.
- Native Overview now uses the shared palette tokens and an expandable available-balance card with matched-geometry amount placement, spring expansion, and an opacity fallback for Reduce Motion. Runtime behavior remains `NOT VERIFIED` until built and opened on iOS.
- The browser review preview now demonstrates an expandable, staggered balance breakdown using clearly labeled synthetic figures. It itemizes manual balance, protected reserve, goal reserve, confirmed near-term obligations and an ordinary-spend estimate, and the displayed example reconciles to 42,500 ₽. These values are not linked to the native store.

## Native flagship material — 2026-10-31

The owner creative contract permits a developed metal Living Card within D1/A. `BrushedMetalCardSurface` uses procedural machining, directional reflection and a layered bevel instead of the flat hero fill. Numeric text does not move with touch. Reduce Motion removes touch lighting and keeps the neutral composed still. No timeline/timer or proprietary texture is used. Hero supporting text is raised to `#D0C8CB`; the conservative surface-peak estimate of sRGB 0.32 gives 4.79:1 against this text (analytical bound, not an exhaustive rendered contrast audit). Web review surfaces retain their existing material until explicitly updated; parity is not claimed.
