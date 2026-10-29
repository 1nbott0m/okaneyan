# Motion spec — web review preview

| Interaction | Trigger / change | Current behavior | Reduced motion / interruption | Evidence |
|---|---|---|---|---|
| Section navigation | Tap tab; active content switches | `document.startViewTransition` when supported; scroll returns to top | CSS reduces animations; immediate state remains | Playwright Plan/Overview flow; actual frame-by-frame feel unreviewed |
| Horizon expansion | Tap disclosure | Height + opacity + transform, spring-like cubic-bezier | Near-instant; button can be tapped again to reverse | Playwright `aria-expanded` true; reverse tap executed |
| Dialog | Add / plan / purchase-check action | Fade overlay + rising dialog | CSS duration ≤0.00001s | Playwright open/close, keyboard and screenshot |
| Button press | Pointer/touch active state | Scale to 0.97/0.98 on primary, secondary and navigation controls | Instant/near-instant | Source styles; hardware touch not verified |
| Toast | Successful demo action | Fade/slide, 3.2-second visibility | Near-instant; stays above mobile nav | Playwright geometry and status text |
| Background ring / progress bars | View render | Slow decorative ring breathing; progress fill | Disabled by reduced-motion media rule | No physical device performance measurement |

Animations are visual preview behavior; this is not proof of native SwiftUI `matchedGeometryEffect` or spring physics. Money amounts do not count upward or mutate through motion.
