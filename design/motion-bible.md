# MoneyWise motion bible — draft for research and prototype

**Status:** decision draft, not performance- or device-validated. External live motion study covers 10 observed browser examples against an 8-example minimum. Every monetary result stays owned by FinanceEngine; motion interpolates presentation, never recalculates money.

## Four roles and timing targets

| Role | Target | Use |
|---|---:|---|
| Feedback | 80–180 ms | selection, press, confirmation, Undo appearance |
| Navigation | 200–450 ms | matched amount/card anchor across existing feature navigation |
| State change | 250–600 ms | expansion, reserve edit, forecast date and chart state |
| Signature transition | ≤900 ms, interruptible | only an explicitly selected card ↔ horizon ↔ gravity transition |

These are initial bands from the user's brief, not measured implementation results.

## Signature model: the same number follows context

1. The amount keeps its identity; label/context and adjacent date state change.
2. Timeline selection, projected balance, chart and event list update from the same selected horizon state.
3. Gravity scale/focus is derived from the same data; it cannot animate a simulated purchase as though an actual transaction posted.
4. Reserve action gets a brief mechanical closure cue only after local persistence succeeds, then an Undo affordance remains visible.
5. Every transition can be interrupted; canceling animation does not cancel or duplicate the data action.

## Materials and motion

- One muted specular edge on Living Card, driven only by direct pointer/drag input. Clamp tilt/angle, stop at release, no perpetual idle movement.
- No material highlight behind text. The face remains matte and the number uses a stable inset.
- Reduce Motion replaces tilt, parallax, path drawing and shared zoom with direct state change or a short opacity dissolve.
- `prefers-reduced-motion` in web and `accessibilityReduceMotion` in SwiftUI are mandatory; no interaction is animation-only.
- Don't use haptic as the only confirmation; always show state text and amount.

## Per-feature behavior

| Feature | Input → response | Data truth | Accessibility fallback |
|---|---|---|---|
| Living Card / reserve | tap expands; long press opens actions; optional bounded drag tilts; committed reserve edit shows shutter cue and Undo | same balance/reserve fields; local plan only, no bank lock | explicit tap controls, no tilt requirement, summary text |
| Horizon / Time Machine | date/range changes projection marker, amount, graph and events together; purchase scenario adds a second line | FinanceEngine projection only; future expected income stays unconfirmed | range buttons and dated list equivalent to plot |
| Gravity | restrained row emphasis on selection; no decorative orbit, rotation or simulated money movement | category emphasis is derived from snapshot data | complete list/register with the same values and details |
| Navigation | amount/card identity follows one transition | navigation state stays in SwiftUI root | standard NavigationStack/tab controls |

## Evidence and open items

- Ten external live demos have been triggered and observed; observations are recorded in `design/research/motion-study.md`. Spring-follow and iOS-like slider were also inspected as browser examples. D1/D2/D3 card-disclosure clips now exist for the web preview.
- The web-preview motion set now includes feedback, navigation and signature transitions in standard and `prefers-reduced-motion` modes, plus a reduced-motion disclosure. Recordings are listed in `design/research/motion-study.md` and were captured at 390×844 from real browser interactions. They establish functional preview states and visible trajectories only.
- No 60fps, exact spring timing, interruption behavior, native-device rendering, or native `accessibilityReduceMotion` claim has been verified.
- Current source has some spring and matched-geometry code, but native rendered motion and 60 fps are not verified without Xcode/device.
- Web preview uses CSS/view transitions; don't describe as native proof.
- D1/D2/D3 web-preview disclosure recordings: `outputs/moneywise-card-disclosure.mov`, `outputs/moneywise-d2-disclosure.mov`, `outputs/moneywise-d3-disclosure.mov`. See `design/research/motion-study.md`; these are not native iOS evidence.
- Web-preview family recordings: `outputs/moneywise-motion-feedback-standard.mov`, `outputs/moneywise-motion-feedback-reduced.mov`, `outputs/moneywise-motion-navigation-standard.mov`, `outputs/moneywise-motion-navigation-reduced.mov`, `outputs/moneywise-motion-state-reduced.mov`, `outputs/moneywise-motion-signature-standard.mov`, `outputs/moneywise-motion-signature-reduced.mov`. They are evidence for the preview, not native iOS evidence.
