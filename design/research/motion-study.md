# Motion study — observed vs pending

**Research date:** 2026-10-29. A gallery title, listing, tutorial, or motion-system documentation is not an inspected animation. Only an actually played browser/video animation can increment the live-example count.

## Inspected in this research pass

| ID | Example | Trigger → trajectory | Physics / duration | Reduced motion | What was actually inspected | MoneyWise decision |
|---|---|---|---|---|---|---|
| M-01 | Stillwet — live painting canvas · https://stillwet.art/ | Play → painting visibly advances through image frames; Pause is then available | Frame progression was visible; duration, easing and spring physics not measured | Not checked | Original browser runtime opened and Play was activated; frame change was visible in CUA screenshot. No local capture saved. This is creative interaction, not a fintech visual style. | The interaction may respond to direct input and communicate material change; reject fluid simulation, AI-art framing and ambient bloom. Keep financial feedback tied to explicit committed actions. |
| M-02 | Shared layout tabs — Matt Perry · https://motion.dev/examples/react-shared-layout-animation | Click Lettuce → active underline/surface moves to tab 2; tomato image changes to lettuce | Shared-layout mechanic is visible after click; source declares 0.2 s AnimatePresence content transition; exact marker travel timing not measured | Not checked | Original isolated browser demo opened; screenshots before and after click showed the changed active tab and image. The active underline is shared with `layoutId`; no repository capture was saved. | A shared marker can retain identity across feature tabs. For MoneyWise, keep a balance/date anchor stable while context changes, and make reduced motion direct. Avoid emoji tabs and copying the recipe UI. |
| M-03 | Tilt card — Matt Perry · https://motion.dev/examples/react-tilt-card | Pointer moved across the live card → perspective changed as the pointer position changed | Response appeared spring-smoothed; exact duration not measured. Source/tutorial names `useSpring` and default `maxTilt=15°` | Not checked; mobile and touch fallback not checked | Direct example page opened and interacted with at two pointer locations; successive browser screenshots show the card's orientation changing. No local capture saved. | Optional surface treatment only for a nonessential visual object. Reject as a required card action; do not tilt numeric text or rely on pointer/touch alone. Reduce Motion must remove the effect. |
| M-04 | Drag — Motion for JavaScript · https://examples.motion.dev/js/drag | Drag yellow square from center toward lower-right → square followed pointer and stayed at the new position | Direct manipulation observed; spring return, duration and bounds not observed | Not checked | Direct standalone demo opened; before/after screenshots showed square moving from roughly (300, 380) to (465, 515) in the 600×800 browser view. No local capture saved. | Drag may be offered only as an optional, bounded visual affordance; never make a financial action depend on it. This demo gives no evidence for spring return. |
| M-05 | Accordion — Matt Perry · https://motion.dev/examples/react-accordion | Click row → content and container height expand; second click collapses | Expansion/retraction visibly animated; exact duration/easing not measured (source describes auto height) | Not checked | Standalone demo clicked open and closed; AX state changed and screenshot showed expanded content. No local capture saved. | Use height-aware state motion for details, preserving hierarchy and clear expanded/collapsed control. Disclosure must work without animation. |
| M-06 | Modal: Shared layout — Matt Perry · https://motion.dev/examples/react-modal-shared-layout | Click gallery image → tile grows into modal; click backdrop → image returns to grid | Shared geometry visibly links origin and destination; exact duration/easing not measured | Not checked | Standalone demo opened, image selected, then backdrop dismissed; screenshots confirmed both directions. No local capture saved. | Reserve matched geometry for meaningful continuity (for example, Living Card to detail); preserve dismissal/back navigation and avoid trapping routine actions. |
| M-07 | Toast: Notifications list — Matt Perry · https://motion.dev/examples/react-notifications-list | Add notification → new toast appears; existing stack shifts to fit | New row and neighboring reflow visibly occurred; exact spring/duration not measured | Not checked | Standalone demo triggered twice; AX showed Saved, Uploaded, Sent; successive screenshots showed 1→2→3 stacked rows. No local capture saved. | Apply layout reflow to confirmation/Undo messages so they enter without obscuring amounts or controls; cap stack and keep dismissal accessible. |
| M-08 | Line graph — Matt Perry · https://motion.dev/examples/react-line-graph | Drag/pointer over SVG → line extends to selected point and numeric annotation appears | Point/line/annotation visibly updated; exact timing/easing not measured | Not checked | Standalone demo dragged across chart; screenshot showed extended line, focused node and “↑ 350%” label. No local capture saved. | Keep forecast marker, value and event synchronized from one selected date; retain list/range control and distinguish scenario from posted operation. |
| M-15 | Spring: Follow Cursor — Motion · https://examples.motion.dev/js/spring-follow-cursor | Move pointer from center to lower-right → pink circle follows, visibly lags, then settles | Spring response and post-release settling observed; exact constants/duration not measured | Not checked | Original JavaScript demo actively moved; before/after screenshots saved at `evidence/2026-10-29/motion-spring-follow-before.png` and `motion-spring-follow-after.png` | Use lag only for a manipulable timeline/focus marker if it clarifies input; never as an ambient orb or independent balance motion. |
| M-16 | iOS slider — Matt Perry / Motion · https://examples.motion.dev/react/ios-slider | Drag thumb from low to high → fill rises and rounded handle changes shape | Continuous response and final fill observed; tutorial describes elastic pull/squish but duration not measured | Keyboard focus is documented; keyboard path and Reduce Motion not tested | React browser demo actively dragged; before/after frames saved at `evidence/2026-10-29/motion-ios-slider-before.png` and `motion-ios-slider-after.png` | A date/range input may map position directly to value and show a numeric readout; no React snippet is treated as native iOS implementation. |

## Candidate live examples (not counted)

| ID | Example / source | Intended observation | Status |
|---|---|---|---|
| M-09 | Motion layout animation · https://motion.dev/examples/react-layout-animation | spring response, amount/layout stability | Page/source opened; declared 0.2s spring and layout prop; direct click produced no reliable visible state change, so not counted |
| M-10 | Motion drag with spring follow · https://motion.dev/examples | pointer mapping, spring return, bounds | Catalog only |
| M-11 | Codrops async page transitions · https://tympanus.net/codrops/hub/ | asynchronous nav and interaction blocking | Catalog only |
| M-12 | Codrops On-scroll SVG Mask Transitions · https://tympanus.net/codrops/hub/ | reveal mask tied to scroll | Catalog only |
| M-13 | Codrops Grid To Full Preview · https://tympanus.net/codrops/hub/ | origin continuity between card and detail | Catalog only |
| M-14 | Sileent · https://www.sileent.com/ | navigation/cursor brand behavior described by ET Studio | Live original not opened |

## Product-specific motion hypotheses (not sourced as external observations)

- Reserve change: short press response + explicit committed amount update + Undo; no animated “bank locking”.
- Horizon: one date state drives amount, graph and events from the same forecast; no independent number timer.
- Gravity: focus/selection and scale encode real object type/amount; plain list remains equivalent.
- Card tilt remains a hypothesis until device and Reduce Motion tests show it is useful, bounded and not gesture-required.
- Shared transitions retain the same amount/date identity, are reversible and do not block taps. iOS and web implementations remain separate.

## MoneyWise preview recordings — 2026-10-29

| Direction | Trigger → trajectory | Duration/evidence | Reduced motion / platform limit | Recording |
|---|---|---|---|---|
| D1 Quiet Horizon | Tap “Состав суммы” → balance card opens seven arithmetic rows in place; second tap collapses them | Captured 66 browser frames at 390×844 and encoded at 15 fps; H.264 MOV, 4.4 s | Browser preview only; reduced motion is separately checked in the Playwright matrix, not in this clip. No iOS or device result. | `outputs/moneywise-card-disclosure.mov` |
| D2 Obsidian Instrument | Same trigger/state within the split balance/next-income panel | Captured 66 browser frames at 390×844 and encoded at 15 fps | Same scope/limitations as D1 | `outputs/moneywise-d2-disclosure.mov` |
| D3 Editorial Utility | Same trigger/state in the journal composition | Captured 66 browser frames at 390×844 and encoded at 15 fps | Same scope/limitations as D1 | `outputs/moneywise-d3-disclosure.mov` |

## Motion family recordings — 2026-10-29

All clips below are real browser-preview interactions captured at 390×844, 15 fps. Standard mode uses normal browser motion preferences; reduced mode uses Playwright's `prefers-reduced-motion: reduce`. Console errors were absent and each final UI state was checked. These recordings do not establish native SwiftUI behavior, device FPS, exact durations, VoiceOver behavior, or interruption safety.

| Role | Trigger → checked final state | Standard | Reduced motion |
|---|---|---|---|
| Feedback | Toggle amount privacy → values masked and control label changes to “Показать суммы” | `outputs/moneywise-motion-feedback-standard.mov` | `outputs/moneywise-motion-feedback-reduced.mov` |
| Navigation | Select “План” → Plan becomes active | `outputs/moneywise-motion-navigation-standard.mov` | `outputs/moneywise-motion-navigation-reduced.mov` |
| State change | Expand balance breakdown → `aria-expanded=true` and details open | Existing D1/D2/D3 disclosure clips | `outputs/moneywise-motion-state-reduced.mov` |
| Signature transition | Open Financial Horizon → Horizon view active; default demo forecast is −16 500 ₽ over 7 days, with expected salary still excluded | `outputs/moneywise-motion-signature-standard.mov` | `outputs/moneywise-motion-signature-reduced.mov` |

## Surface response — 2026-10-29

D2 uses a quiet 300 ms CSS edge-color transition on hover and press, informed by the bounded, optional material responses in R-13/R-14. The amount and supporting copy do not tilt or move. Chromium confirmed hover and pointer-leave at 390/768/1440, and the reduced-motion preference removes the transition; a real touch device and iOS are still untested. Static/rest and hover captures: `outputs/moneywise-instrument-after-dark-390.png`, `outputs/moneywise-instrument-hover-dark-390.png`.

The source frames came from actual browser transitions; macOS AVFoundation encoded the captured frames because FFmpeg was unavailable. Clips provide prototype evidence for all four interaction roles and a reduced-motion path, but do not establish smooth device playback, measured spring constants, native SwiftUI fidelity, or exact timing against the brief's target bands.

**Status:** 10 live examples inspected: M-01–M-08, M-15 and M-16. Direct drag and a separate spring-follow response were observed, but spring return for the direct-drag demo was not. Reduced Motion, exact timing, keyboard parity and native-device behavior remain unchecked; meeting the example count does not complete broader motion QA or native acceptance.
