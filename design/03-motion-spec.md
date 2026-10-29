# Motion contract — «Мои деньги»

Движение обслуживает навигацию и понимание раскрываемого расчёта. Оно никогда не сообщает, что деньги поступили/исчезли без явного сохранённого действия. Суммы не «досчитываются» автоматически на таймере. Поддержать системный Reduce Motion: убрать непрерывность/пружины, оставить мгновенную смену состояния либо короткий dissolve.

| ID / interaction | Trigger; from → to | Normal motion | Interruptibility / fallback | Product safeguard |
|---|---|---|---|---|
| M-01 Tab selection | Tap tab; current root → selected root | Native tab transition; SwiftUI spring `response 0.42, damping 0.88`; selection haptic | Taps always accepted; native Reduce Motion behavior not separately verified | Do not animate financial numbers. Preserve scroll position per tab where native state allows. |
| M-02 Горизонт → подробности | Tap “Показать состав суммы”; compact → expanded breakdown | Same amount view uses `matchedGeometryEffect`; spring `0.48/0.86`; details enter with top/opacity transition (no stagger) | Reversible on repeat tap; `accessibilityReduceMotion` disables spring and applies an unanimated opacity transition | Keep exact source value and show reserve/obligations separately; don't imply chart forecast certainty. |
| M-03 Purchase check | Open; overview CTA → dedicated check flow; then explicit “Проверить” | Sheet: native interactive spring; result panel reveals height/opacity after domain verdict; 0.32s | Drag to dismiss before submitting; keyboard/focus follows native sheet; Reduce Motion dissolve | No positive color/status before the calculation returns; all four verdicts retain explicit text. |
| M-04 Transaction detail | Tap row; list row → detail/edit | Native NavigationStack push with source row identity; 0.32–0.42s platform transition | Standard interactive back swipe; Reduce Motion platform behavior | No balance mutation before Save. |
| M-05 Add/import sheet | Plus/import; origin → form / CSV preview | Native detents and spring; successful row uses subtle insertion fade/translate ≤0.18s | Can cancel; form retains entered data when validation fails; Reduce Motion removes translation | Preview precedes CSV persistence; cancellation keeps data unchanged. |
| M-06 Privacy hide | Tap eye; readable → masked | Short content transition ≤0.18s; don't spatially fly figures | Repeated taps reverse; Reduce Motion instant mask | The hidden state must not leave amount in accessibility labels/screenshots unintentionally; keep explicit button label. |
| M-07 Toast/reminder feedback | User action completes / local reminder; idle → visible status | 0.18s fade/slide; auto-dismiss per message role; no spring overshoot | VoiceOver announcement; persistent error until resolved or dismissed; Reduce Motion fade | Copy mirrors action; never say bank sync succeeded unless confirmed from a real adapter. |

## Current code evidence / gap

M-01 tab spring/haptic, M-02 expandable `AvailableBalanceCard` with matched amount placement and Reduce Motion fallback, and privacy amount transition exist in source. Browser preview motion has been exercised separately; native source has **not** been built or run because full Xcode/iOS runtime is unavailable. M-03–M-07 remain interaction contracts, not verified implementation claims.
