# Flagship screen QA — Overview

**Status:** web review preview checked; native flagship not yet verified.

- Primary purpose and core values are visible: manual total, protected reserve, amount free until next income, near-term obligations, recent operations and budgets/goals.
- Light/dark theme and amount masking both toggle in the preview.
- Composition A remains the current review default; the A/B/C chooser is a design review tool, not a product screen.
- At 320–430 px the screen reflows into a single-column balance-first composition and labeled bottom navigation.
- At 844×390 and 932×430 the compact landscape mode shows mobile navigation and avoids desktop sidebar.
- 44 px minimum touch targets and zero overlap in measured touch sizes.
- Balance disclosure shows a reconciled synthetic example: 416,500 − 180,000 − 136,000 − 40,000 − 18,000 = 42,500 ₽; timeline and breakdown animate into view and expose disclosure state to assistive technology.
- Expanded disclosure remains within viewport width at 320–1440 px and tested landscape sizes; the full tall card can be reached by scrolling on shorter screens.
- Native `AvailableBalanceCard` source includes reserve/goal/spend factors and matched-geometry motion; Swift syntax parses, but the app itself is not built or run here.
- Remaining: 200% zoom/long sums, Safari safe-area and keyboard, VoiceOver, empty/error states, native calculation parity.

Screenshots: `screenshots/mobile/390.png`, `screenshots/mobile/390-dark.png`, `screenshots/mobile/390-modal.png`, `screenshots/mobile/390-toast.png`, and desktop `screenshots/after/1440.png`.
