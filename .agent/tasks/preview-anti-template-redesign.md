# Browser preview: remove generic dashboard styling

## Objective and constraints
- Make the browser preview read as a responsive presentation of the existing iOS personal-finance app, not a separate generic web dashboard.
- Preserve the approved Orbit O mark, charcoal/rose brand, demo-only boundary, Russian labels, existing interactive tabs, controls, and no-real-finance behavior.
- Do not claim browser demo values are persisted or connected to banks.

## Existing implementation state
- Preview has functional Overview / Operations / Plan navigation, theme toggle, masked amounts, expandable balance calculation, and demo forms.
- Existing visual composition still uses a desktop sidebar, oversized balance card, decorative concentric rings, duplicate balance summaries, and broad dashboard grids. That is the main source of the template-like appearance.
- The native iOS app uses a TabView and an overview flow led by available balance, followed by summaries, forecast, analytics, purchase check, and recent operations.

## Milestones and dependencies
1. Replace the web dashboard composition with responsive, iOS-inspired navigation and reading order while preserving current tab IDs and actions.
2. Refine tone, hierarchy, surfaces, typography, and labels; remove decorative effects and redundant content.
3. Inspect at desktop and mobile widths; verify tab/theme/expand interactions and check the browser console.

## Acceptance criteria
- Desktop and mobile preview use the same product hierarchy and three primary tabs.
- One restrained balance hero; supporting finance data reads as rows, not repeated tiles.
- No violet panels, glow rings, or ornamental live-status cues for manually entered demo data.
- Russian content, Orbit O asset, dark default, light theme toggle, and existing demo interactions work.
- No horizontal overflow at phone width.

## Verification methods
- Visual inspection in browser at 1280 px and 390 px widths.
- Browser-side checks for active tab, expanded balance details, theme toggle, horizontal overflow, failed requests, and runtime errors.
- `git diff --check` and JavaScript syntax check.

## Current progress
- Replaced desktop sidebar and raised call-to-action with a responsive iOS-style bottom tab bar and contextual add action next to recent operations.
- Removed concentric glow decoration, redundant dashboard tile treatment, and invented “live” signal; the overview now leads with the available amount, dates, confirmed obligations and transaction rows.
- Kept the supplied Orbit O wordmark text, charcoal/rose palette, Russian labels, dark default and the preview's working navigation/theme/amount/form behaviors.
- Desktop and 390px mobile view were visually inspected. The mobile document width equals the viewport; no horizontal overflow.
- Browser interaction checks passed for Overview/Operations/Plan switching, amount expansion, light/dark theme toggle, and add-operation modal. No browser console or page errors.
- JavaScript syntax and `git diff --check` pass.
- Typography uses Avenir Next/system fallback because CoFo font files are not bundled in the project. Native iOS build remains outside this preview verification.

## Next actionable step
- Ask for design feedback on the updated preview; add licensed CoFo font files if the exact selected typography should be rendered.
