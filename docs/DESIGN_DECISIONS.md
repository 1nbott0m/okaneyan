# MoneyWise design decisions

- Platform: native iPhone SwiftUI. `preview/index.html` is a synthetic-data review surface only.
- Brand: `okaneyan.`; retain the dark Okaneyan/Editorial base, graphite surfaces, soft white text, and restrained muted-pink accent.
- Current Overview direction: D1/A “Тихий горизонт” with Living Card context. D1/D2/D3 labels and the static “Линия до события” concept remain provisional unless the owner explicitly selects them.
- Main screen answers what is currently available, until which event, and why; keep important context without turning Overview into a feature catalog.
- Preserve the distinction between current balances, forecasts, reserves, and hypothetical purchase scenarios. Never animate an uncommitted forecast as a completed financial event.
- Current type roles are Oswald, Onest, and Golos Text with Russian glyphs and financial numerals. Do not add or substitute font files without license/glyph evidence in `design/asset-provenance.md`.
- Orbit O's approved release component is integrated as a SwiftUI source in the native app target. The host passes the actual root readiness signal, owns overlay dismissal, and honors Reduce Motion; no loading delay is added. The vector master and motion spec remain in `design/brand/okaneyan-orbit-o/Design/`.
- The approved D1/A «Тихий горизонт» remains the Overview direction. The unapproved 2026-10-29 composition concept remains review-only and is not integrated.
- Before future visual patches, follow repository `AGENTS.md`: inspect current affected screen at mobile/web sizes, add the concrete gap and supporting references/art-direction to `design/research/visual-gap-audit.md`, capture resulting evidence, and use G0–G4 and DA-01…DA-25. Do not call design done with missing gates.

See [brand guidelines](../design/brand-guidelines.md), [design system](../design/05-design-system.md), [decision log](../design/decision-log.md), and [requirements conformance](../design/requirements-conformance-audit.md).
