# Anti-pattern audit — current web preview

## Confirmed in current HTML

- The concept selector was hidden by a late `.concept-picker{display:none!important}` rule; the user could not compare the promised A/B/C.
- Later CSS overrode the original A/B/C rules: selector hidden; one shared charcoal hero; same metrics/transaction grid for all modes. Names implied concepts the UI did not actually offer.
- Repeated `.balance-card` and `.side-metrics` rules created a long override cascade. This made visual iterations unpredictable.
- Repeated, low-opacity orbital rings and a pulsing animation gave manually entered demo data an unsupported live signal and generic fintech gloss.
- RESOLVED 2026-10-29: the earlier preview named CoFo candidates in CSS without binaries, so it silently fell back. The current preview uses the owner-selected local Oswald, Onest and Golos Text faces, with source/license evidence in `design/asset-provenance.md`.
- Dashboard structure and repeated containers persisted after a prior pass claimed to remove the template dashboard. The browser tab could therefore present an older server or file preview as if current.
- Mock values are fixed in the browser page. They must be labelled as demo and never imply they come from `FinanceEngine` or persistent user data.

## Correction principles

- Three concepts change composition, hierarchy, density and motion, not only palette.
- One controlled palette is used across the concepts so layout and type can be compared honestly.
- One financial amount and one shared breakdown remain unchanged across variants.
- No ornamental ring, fake “live” indicator, or generic gradient; every graphic encodes a real part of the demo timeline.
- Font families are declared only when the actual files are available; system UI remains the fallback. Current local fonts have exact glyph and license evidence and browser load checks.
- Concept selector is visible and keyboard/touch operable. `prefers-reduced-motion` keeps state changes while removing nonessential movement.
