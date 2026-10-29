# okaneyan cinematic launch remaster

## Objective and constraints
- Port the approved O → orbit reveal → counterclockwise satellite → dock choreography into the native iOS app.
- Add a focused cinematic lighting pass: turning titanium O, rose-metal satellite, reacting highlights, restrained bloom, one climax streak, and a subtle camera move.
- Preserve the current mark, background palette, event order, launch storyboard, startup failure behavior, and real SwiftData readiness boundary.
- Keep a reduced-motion path and avoid third-party rendering dependencies.

## Existing state
- `iOSApp/MoneyWiseApp.swift` synchronously opens the local SwiftData container before showing `RootView`.
- `iOSApp/LaunchScreen.storyboard` is a static branded system launch screen.
- The approved browser choreography is in the user's `outputs/okaneyan-orbit-animation/index.html`; it already has a one-shot timeline and readiness hold, but is a standalone preview.
- Full iOS SDK / Simulator are unavailable in the current Command Line Tools environment.

## Milestones
1. Inspect the current app root, existing animation source, and platform motion guidance.
2. Implement a self-contained SwiftUI intro and connect its handoff to first ready root content.
3. Apply the same focused lighting pass to the standalone motion preview and update its motion notes.
4. Run available static validation, update the app roadmap and record runtime-only checks that remain unverified.

## Acceptance criteria
- Preserve the existing O spin, open orbit draw, counterclockwise satellite movement, dock, and final entry order.
- Highlights and shading track the same timeline; the climax uses one restrained horizontal signature highlight.
- Entry occurs only after both the authored sequence and the actual app-root readiness callback complete.
- Reduced Motion presents a settled mark and waits only for actual readiness.
- No external 3D dependency, continuously looping background, or particle field.
- Swift source parses; project file, inline JavaScript, and SVG validate; package files match current sources.
- Do not claim recorded playback, measured frame rate, iPhone appearance, or an iOS build unless directly verified.

## Verification
- `swiftc -frontend -parse` for changed Swift sources and `plutil -lint` for the Xcode project/storyboard.
- Node syntax and readiness/timeline harness for the standalone preview.
- Validate SVG and refreshed ZIP integrity.
- Full Xcode build, simulator/device playback, frame-by-frame recording and FPS remain runtime gates if unavailable.

## Progress
- Confirmed the native target is iOS 17 SwiftUI/SwiftData and startup currently opens the local store before rendering the root.
- Reviewed Apple's official launch/motion and reduced-motion guidance and Nothing's official description of meaningful, event-linked light patterns.
- Added `iOSApp/OkaneyanCinematicIntro.swift` and attached it to `MoneyWiseApp` as an overlay on the actual SwiftData-backed root. Root readiness now gates app entry; when the optional app lock is enabled, authentication starts after the cinematic handoff so its system prompt does not overlap the climax. VoiceOver can skip to the settled mark; Reduce Motion shows that mark without the turn.
- Replaced the static storyboard's repeated logo/wordmark with the matching plain launch color, keeping the system launch surface separate from the authored motion.
- Updated the standalone HTML with rotating titanium-like shading, rotation-linked specular sweep, shaded rose satellite, a single docking highlight, and a stable camera settle. Refreshed the static SVG/1024px PNG and its ZIP; the HTML remains a visual prototype with an explicit readiness hook.
- Static JavaScript timeline/readiness harness passed; `swiftc -frontend -parse`, Xcode project plist syntax, storyboard XML, and SVG XML checks passed. The exported PNG is 1024×1024 and was inspected as a still.
- The required recorded playback, frame-by-frame motion review, iPhone/Safari check, measured FPS, and iOS type-check/build are still UNVERIFIED. The available Command Line Tools lack the SwiftUI macro plugin and iOS Simulator SDK; local-file animation recording is unavailable in this session.

## Next actionable step
- Open the native project in full Xcode and record cold launch on an iPhone Simulator and a physical iPhone. Review the dock/flare transition frame by frame at native resolution, check Reduce Motion and locked-app paths, then tune duration/material response from observed playback and measure frame pacing.

## Latest art-direction pass — 2026-10-29

- **Accepted direction:** Japanese industrial precision / contemporary minimalism. Preserve O → orbit → satellite → wordmark → app; subtract cosmetic VFX and retain only deliberate shape, timing, and one small motion-linked highlight.
- **Removed from standalone HTML:** starfield, colored nebula, volumetric beams, lens flare rings, light leak, grain, multiple orbit glows/trails, dock shock rings, and broad bloom. Replaced the glossy gradients with neutral satin metal, a thin orbit, a small rose satellite, and a plain graphite background.
- **Native SwiftUI:** flattened the background; removed orbit bloom, orbital edge layers, exaggerated satellite glow, broad final streak, and noticeable camera tilt. Kept the O turn and placed the only small reflection on the satellite so it travels with the point.
- **Readiness:** HTML and native transitions still wait for the usable app root signal. The HTML is only a prototype and does not fetch the product's real data.
- **Verification:** HTML stub timeline/readiness checks and inline JavaScript syntax pass. Real-browser playback comparison and iPhone/Safari review remain unavailable here; simulator/runtime behavior and iOS build remain UNVERIFIED.
- **Next step:** review the cleaned sequence in full Xcode/iPhone Safari with a before/after recording once that runtime is available; tune only from observed playback.

## Loading beyond the intro — 2026-10-29

- **Problem found:** both implementations stopped their animation timeline at the end of the short intro (2.9 s native, 3.25 s HTML) while separately holding the splash for app readiness. A ten-second launch therefore showed a frozen mark for most of the wait.
- **Change:** keep the original intro once; while readiness is pending, close the orbit's small gap with a low-contrast bridge and move the satellite counterclockwise on a five-second loop. When the real readiness signal arrives, ease the satellite into the wordmark dock, then reveal the app. Reduced Motion and VoiceOver skip retain the static settled mark.
- **Verification:** updated HTML harness checks a ten-second pending load, continuing counterclockwise movement, smooth readiness dock, app entry gate, and reduced-motion behavior. Swift source parse is required; native runtime/build and screenshot evidence remain unavailable without full Xcode/Simulator.
- **Next:** inspect actual browser captures at 390/768/1440 and native iPhone/Safari playback when an eligible runtime is available. G2 remains partial and this is not full DA-01…DA-25 acceptance.
