> Historical research snapshot from before the final type assignment. The active decision and verified files are in [`design/typography-and-layout.md`](../typography-and-layout.md): the user selected Oswald for display, Onest for controls/amounts and Golos Text for small transaction detail; the exact licensed files are now included. The open native-runtime limits still apply.

# Typography and layout research — pending verified font choice

**State:** source audit and role proposal; no font files added and no final type lock. Official live specimens for CoFo Drifter, Glassier and Kak were opened and captured on 2026-10-29. The foundry offers an app-license category, but this project has no font binaries or app license. Specimen-page glyph subsets are evidence about those pages, not proof for a licensed file.

## Current implementation evidence

- `iOSApp/AppTypography.swift` attempts CoFo names and system fallbacks; no CoFo binaries are bundled.
- Browser preview uses a system/Avenir Next stack with system fallback. `font-variant-numeric: tabular-nums` is used for financial values in many places.
- Russian body text remains readable in current desktop/mobile screenshots, but the mobile card labels are very large in vertical area and all text currently shares a broadly similar sans personality.

## Type roles to lock after sample/license testing

| Role | Candidate direction | Proof required | Interim fallback |
|---|---|---|---|
| Display / short editorial headings | CoFo Glassier (user preference; provisional) | Foundry specimen is narrow/high contrast and its reduced set shows `Ё`, `№`, `₽`; still need exact app file, license, wrap/readability, Dynamic Type | system sans with existing brand wordmark; no faux serif substitute |
| Numerical amount / dates | CoFo Drifter (user preference; provisional, limited to testing) or system tabular numerals | Foundry reduced subset shows Cyrillic `Ёё` and `№` but omits `₽`; full licensed file, tabular alignment and `1 000 000,50 ₽` must be checked | system sans with `.monospacedDigit()` on values only |
| Short accent / brand word | CoFo Kak (user preference; provisional) | Foundry reduced set shows `Ёё`, `№`, `₽`; Regular is condensed and Black very heavy. Test one short phrase, exact app file and size/contrast first | existing wordmark asset and standard text style |
| Body / labels | native system sans with Cyrillic coverage | iOS Dynamic Type, Russian punctuation, 44 pt labels where actions | system font |

Do not download or bundle foundry binaries before an app-use license is held. Verify `ЯяЁё₽№` and `−1 000 000,50` in the exact licensed files, not just on the foundry specimen pages. The official catalogue lists Drifter as 2023, Glassier as 2023 and Kak as 2020; they are the owner's preferred candidates, not new 2026 releases.

## Layout constraints

| Surface | Widths to capture | Layout rule |
|---|---|---|
| iPhone native | 360/375/390/430 pt when simulator/device is available | vertical reading order, safe areas, touch targets ≥44pt; numbers remain visible without horizontal scroll |
| Web preview mobile | 390 px first, then 360/430 | adapt information order; don't simply scale desktop columns |
| Web preview tablet | 768 px | maintain legible row widths and navigation; no two-column squeeze that creates long labels + tiny sums |
| Web preview desktop | 1440 px | use a constrained content width; Overview may use asymmetry but must retain clear primary answer |

## Baseline observations

Existing 390 px screenshot (`outputs/okaneyan-preview-mobile.png`) has a tall hero with wide tracking and generous whitespace; on current capture, account/reserve details and nearest payments fall below the first viewport. Existing 1440 view has a two-column composition and stable rows; visual emphasis could be more product-owned than the generic outlined/rounded panel vocabulary.

## Inspected typography sources

- Typewolf: https://www.typewolf.com/ (discovery catalog only until a concrete family/specimen is inspected)
- CoFo Drifter specimen (2023): https://contrastfoundry.com/typeface/cofo-drifter · seven styles and variable mode; reduced glyph set shows `Ёё` and `№`, not `₽` · capture `design/research/evidence/2026-10-29/cofo-drifter-specimen-desktop.png`
- CoFo Glassier specimen (2023): https://contrastfoundry.com/typeface/cofo-glassier · reduced glyph set shows `Ё`, `№`, `₽` · capture `design/research/evidence/2026-10-29/cofo-glassier-specimen-desktop.png`
- CoFo Kak specimen (2020): https://contrastfoundry.com/typeface/cofo-kak · three styles; reduced set shows `Ёё`, `№`, `₽` · capture `design/research/evidence/2026-10-29/cofo-kak-specimen-desktop.png`
- Feature type.today specimen (2025): https://type.today/en/feature · Russian specimen text, tabular lining figures and 30 styles; `₽` and app-use rights remain unverified · capture `design/research/evidence/2026-10-29/feature-specimen-viewer-desktop.png`
- Futura®100 Cyrillic (2025): https://www.infonta.com/fonts/futura · Cyrillic-extension case page, 23 scripts; exact financial glyphs, tabular figures and app license not established · capture `design/research/evidence/2026-10-29/futura100-cyrillic-desktop.png`
- CoFo licensing and glyph coverage: https://contrastfoundry.com/faq
- Apple typography / Dynamic Type docs: https://developer.apple.com/design/human-interface-guidelines/typography

**Not yet tested:** licensed CoFo binaries, app-license terms for the intended distribution, font rendering, ligatures and variable axes in the app, fallback behavior, Dynamic Type, iOS accessibility sizes, very large amount truncation, and exact glyph coverage in any licensed file. The five inspected families are comparative research only; no new font is selected or bundled.
