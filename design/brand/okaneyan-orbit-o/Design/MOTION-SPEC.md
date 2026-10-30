# Orbit O — locked release direction

## Mark

- 512 × 512 viewBox, centered O at `(256, 256)`, radius `65`, satin ring width `35`.
- Open orbit centered on the O, radius `176`, stroke width `5`, ending at the upper-left gap.
- Satellite radius `17` at the upper-right dock `(380, 132)`; a single small reflection moves with it.
- Matte graphite background, neutral satin metal and a muted rose satellite. No extra VFX or 3D dependencies.

`Design/orbit-o-master.svg` is the editable static reference. The SwiftUI component draws the same geometry directly; the SVG is not a runtime dependency.

The transparent 1024 × 1024 PNG in `Design/orbit-o-master-1024.png` is a raster export of that SVG for previews and handoff. It is not loaded at runtime.

## Choreography

1. Over 0–2.9 seconds, the O completes one measured turn, the thin orbit draws and the satellite follows the open arc counterclockwise to the upper-right dock. The wordmark appears during the movement.
2. From 2.9–3.25 seconds, the mark holds its finished pose as the authored intro closes.
3. If app readiness is still false after 3.25 seconds, the small orbit gap closes quietly and the satellite continues counterclockwise around a five-second loop.
4. When app readiness becomes true, `onComplete` is called immediately. The component does not wait for a timer, a loop boundary, or a finishing animation.

If readiness arrives during the opening choreography, the component settles immediately and completes. This prevents a fast launch from waiting for the full intro. Reduce Motion shows the static docked mark; the VoiceOver action skips movement while still waiting for the host readiness signal.

## Handoff state

- Public component: `OkaneyanLaunchIntro(isAppReady:onComplete:)`.
- Runtime resources: none; the component uses SwiftUI vector shapes only.
- Dependencies: SwiftUI, iOS 17 or later.
- Host owns readiness, overlay visibility, and any app transition. Do not add `Task.sleep` or another loading timer in the host.
- **Verified:** Xcode build and UI test for the isolated demo on iPhone 17 Simulator (1 passed, 0 failed); the test taps readiness and confirms the intro is removed and the ready screen is accessible. A rendered screenshot records the pending state.
- **Not verified:** VoiceOver interaction, changing the Reduce Motion setting, physical-device integration or measured frame rate. The MoneyWise app itself was not built or changed as part of this isolated handoff.
