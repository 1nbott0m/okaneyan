# Accessibility QA

## Browser evidence

- Light secondary text `#716A6C`: 4.70:1 on `#F4F1F2` and 5.28:1 on white.
- Dark secondary text `#AAA0A2`: 7.28:1 on `#151314`.
- Form borders: light `#8D8185` on white 3.74:1; dark `#817579` on `#292526` 3.43:1. These cover sampled text/control pairs, not every token combination.
- Visible focus style is present. Playwright verified focus entering amount input, required-form validity, forward/reverse tab containment and focus return after Escape.
- No button without visible text or an accessible name was found in the DOM scan.
- Mobile form inputs compute to 16 px, reducing iOS Safari's auto-zoom risk; actual Safari was not tested.
- Reduced motion feature is respected.

## Remaining

- No axe-core/Accessibility Insights scan was executed.
- No VoiceOver/TalkBack session, actual iOS keyboard, 200% text/browser zoom or high-contrast OS mode.
- Images/icons are mostly inline SVG; full non-text contrast and screen-reader review remains open.
