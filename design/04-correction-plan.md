# Design correction plan

**Scope:** current interactive web review preview. Preserve the approved Soft Matte Fintech direction and existing MoneyWise finance boundaries.

## Completed and retested in Chromium

1. Mobile and tablet hit-area sizing: 44 CSS px minimum, with 8 px gaps in concept and bottom navigation.
2. Landscape phone composition: hide the desktop sidebar and show labeled bottom navigation at 844×390 and 932×430.
3. iPhone-oriented CSS: safe-area padding for top/bottom/left/right; dynamic viewport modal scrolling. CSS values are present, but device insets remain `NOT VERIFIED` on hardware.
4. Dialog keyboard model: focus entry, tab containment, Escape/backdrop/close action, focus restoration.
5. Numeric field: visible required labels, decimal input mode, 16 px text for mobile/tablet.
6. Contrast: muted text and form borders raised to computed WCAG AA / non-text-control contrast on sampled pairs.
7. Toast: moved above mobile navigation, duration increased to 3.2 seconds.
8. Reduced motion: transitions/animations reduce to ≤0.00001 s in Chromium emulation.
9. Reflow: no horizontal document overflow at the 11 measured sizes.

## Next by risk

1. Complete the 180-item applicability pass for the web preview and native SwiftUI source; update `03-risk-register.md` with evidence rather than assumptions.
2. Test 200% browser zoom / text enlargement, keyboard visibility while the mobile software keyboard is open, and long localized values.
3. Test Safari iOS and actual iPhone safe areas/touch; test Android Chrome and at least one tablet.
4. Run axe-core (or equivalent), VoiceOver, and keyboard-only screen review.
5. Measure Lighthouse/Web Vitals only for a production-like build; current static preview has no field performance telemetry.
6. Conduct unprompted user tasks; AI walkthroughs do not count as user testing.
7. Continue native SwiftUI flagship after source-level parity review; do not claim web screenshots verify native behavior.
