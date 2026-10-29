# Typography and layout — owner-approved roles

**Decision date:** 2026-10-29 · **Direction:** Soft Matte Fintech / A «Тихий горизонт» · **Owner selection:** explicit role assignment from the user.

## Approved type roles

| Role | Family and weights | Application |
|---|---|---|
| Display / accent / brand | Oswald Variable, `wght` 500 and 600 | Page and detail-screen titles, concise accent labels, wordmark text. Compact panel headings and feature links remain Onest; keep Oswald out of dense body copy and financial values. |
| UI / navigation / actions | Onest Variable, `wght` 400–700 | Buttons, navigation, forms and primary UI labels. |
| Amounts | Onest Variable, `wght` 450–600 with tabular figures | Balance, currency values, ratios and transaction amounts. The exact font file has OpenType `tnum`; web CSS and SwiftUI amount role request monospaced digits. |
| Small details / transaction history | Golos Text Variable, `wght` 400–600 | Small metadata and transaction name/category/date. The owner had made this conditional on comparison; Onest remains available for the A/B review. |

The web preview defaults to Golos Text for detail labels. Compare Onest at `http://localhost:5175/?font-study=onest`. This is a visual-review route, not a user-facing font preference. The rest of the interface stays on the approved role mapping in both states.

## Source and asset proof

- The three exact TTFs are pinned to Google Fonts repository commit `9862abc066c9b83bf84c3e8ed1fc2d8d48f9bbf0` and retained unchanged in `preview/fonts/` with their corresponding SIL Open Font License 1.1 notices.
- SHA-256, exact glyph, weight-axis and license evidence is recorded in `design/asset-provenance.md`.
- CoreText mapped `ЯяЁё ₽ № −1 000 000,50` for each exact font file. Onest and Golos Text include OpenType `tnum`; Oswald is reserved for non-numeric display roles.
- Browser verification loads all three faces successfully at 390 and 1440 CSS px in both themes. No font requests fail and the document has no horizontal overflow.
- The Xcode project copies the same font files and license notices into the app resource bundle. `AppTypography` registers the fonts and exposes display, UI, amount and detail roles. Native SwiftUI rendering is not verified because full Xcode/Simulator is unavailable.
- SwiftUI source keeps Oswald on 29–30 pt screen titles; compact panel, feature, event and row titles request Onest. Source syntax parses, but font appearance and Dynamic Type require full Xcode/Simulator and are not yet verified.

## Comparison evidence

- Before: `outputs/moneywise-system-type-before-dark-390.png` and `outputs/moneywise-system-type-before-dark-1440.png` show the pre-role fallback hierarchy.
- After: `outputs/moneywise-typography-{golos,onest}-{dark,light}-{390,1440}.png` and `outputs/moneywise-typography-report.json` contain the 8 Chromium comparisons.
- The comparison keeps the same layout, colors, content and amounts. Golos Text makes Russian transaction metadata more distinct from the Onest amount while keeping the longer category in one line at 390 px; it is selected as the detail face. Onest remains the stronger fit for numerical emphasis and controls.
- The report confirms computed roles: Oswald 600 for page heading, Onest with tabular numerals for money, Golos Text for transaction labels. All three `document.fonts.check` results are true in each captured state.

## Layout constraints

| Surface | Review widths | Rule |
|---|---|---|
| Native iPhone | 360/375/390/430 pt when a Simulator/device is available | Dynamic Type, safe areas, large text, touch targets ≥44 pt, and long amount fitting. Native evidence remains blocked here. |
| Web preview mobile | 390 px first, then 360/430 | Preserve natural line breaks, readable transaction details and sums without horizontal scrolling. |
| Web preview tablet | 768 px | Avoid squeezed transaction labels or miniature values. |
| Web preview desktop | 1440 px | Preserve hierarchy and restrained display usage. |

Apple's typography guidance remains relevant to native text scaling and legibility: https://developer.apple.com/design/human-interface-guidelines/typography. It does not replace the owner-selected font families.

## Still unverified

- iOS app target compilation, font registration in a built app, physical device/Simulator appearance, VoiceOver, Dynamic Type, and maximum accessibility sizes.
- Actual native OpenType tabular-digit shaping and small-label contrast at system text scales.
- Independent design critique (G3) and full DA-01…DA-25 acceptance remain open.

CoFo Drifter, Glassier and Kak were earlier owner-preferred research candidates. This later role assignment supersedes that typography proposal; no CoFo font file or license is included in the app.
