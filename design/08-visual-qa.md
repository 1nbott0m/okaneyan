# Visual QA

**Compared:** earlier preview captures in `screenshots/before/` against final Chromium captures in `screenshots/after/` and `screenshots/mobile/`.

| Viewport | Observation | Result |
|---|---|---|
| 320×780 | Single-column; expanded balance disclosure fits document width; no horizontal overflow | `VERIFIED` |
| 360×844, 375×844, 390×844, 430×932 | Balance-first portrait stack; bottom tabs stay labeled | `VERIFIED` |
| 768×1024, 1024×768 | Tablet sizing; controls ≥44 px; document width fits | `VERIFIED` |
| 844×390, 932×430 | Compact landscape composition, no sidebar, labeled bottom tabs | `VERIFIED` |
| 1440×900, 1920×1080 | Desktop sidebar, panels and columns fit viewport | `VERIFIED` |

Expanded balance disclosure was captured at 390×844 and 1440×900 in `screenshots/mobile/390-breakdown.png` and `screenshots/after/1440-breakdown.png`. The card reveals its amount factors with a stagger; the illustrative figures reconcile arithmetically. This is browser demo content only.

The viewport check measures browser layout and visual captures. It does not prove Safari/Firefox rendering, real touch ergonomics, 200% browser zoom or native iOS layout. Desktop controls under 44 px are outside the mobile hit-area criterion; touch-enabled desktop has not been tested.
