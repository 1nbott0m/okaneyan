# Motion language — money horizon

| Interaction | Trigger and state change | Timing/curve | Interruption / reduced motion |
|---|---|---|---|
| Concept change | A/B/C changes the overview composition; the available amount retains its visual anchor | 520ms spring-like `cubic-bezier(.2,.82,.22,1.08)`; grid and details stagger ≤90ms | Immediate state change on new choice; reduced motion: instant opacity/state swap |
| Horizon reveal | User opens “Состав суммы”; same amount remains, breakdown and dates open below | 520ms height + 320ms opacity, rows stagger 45ms | Button toggles anytime; reduced motion instant |
| Navigation | Tab change transitions between existing preview views | Native View Transition where supported; short cross-fade fallback | Repeated tab tap resolves latest selection; reduced motion instant |
| Purchase check | Form submits; message explains demo result | Short toast rise/fade, 180ms | Toast timer restarts; reduced motion no travel |

No automatic number animation, breathing/pulsing live dots, fake progress or implied transaction occurs. The project uses local demo state only. Browser motion is a preview contract; native `FinanceEngine`/SwiftUI motion is not verified by this page.
