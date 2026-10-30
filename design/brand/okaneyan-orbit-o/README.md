# Okaneyan Orbit O SwiftUI component

An isolated Swift Package for the approved Orbit O intro. It includes the reusable source, a manual readiness demo and the editable SVG motion master. It does not change the MoneyWise app target or Xcode project.

## Public API

```swift
OkaneyanLaunchIntro(isAppReady: rootIsReady) {
    isIntroVisible = false
}
```

Set `isAppReady` when the host's first usable screen is mounted. The component runs the authored 3.25-second opening once, then keeps the satellite moving if the app is still loading. The O turn and satellite docking finish by 2.9 seconds; the mark holds its final pose for the last 0.35 seconds. It calls `onComplete` immediately when readiness becomes true. It adds no timer-based loading delay. If readiness arrives before the opening sequence ends, it completes immediately.

The host should keep its real screen behind the intro and remove the intro in `onComplete`. The host owns any brief visual transition and must not wait for another timer before enabling the app.

## Add to an Xcode app

1. Add this folder as a local Swift Package, or copy `Sources/OkaneyanOrbitO/OkaneyanLaunchIntro.swift` into the app target.
2. Import `OkaneyanOrbitO` when using the package product.
3. Present `OkaneyanLaunchIntro` over the already-mounted root. Pass the root's readiness state directly to `isAppReady`.
4. In `onComplete`, remove the splash overlay. Keep the readiness callback tied to actual usable app state, not a fixed delay.

The package has no image, font, shader, network, or third-party runtime dependencies. `Design/orbit-o-master.svg` is an editable reference only; the component renders the same geometry in SwiftUI.

## Brand resources

- `Design/orbit-o-master.svg` — editable 512-unit vector master.
- `Design/orbit-o-master-1024.png` — 1024 × 1024 transparent PNG exported from the SVG for previews and handoff.
- Native rendering uses SwiftUI shapes; the PNG and SVG are not loaded by the component at runtime.

## Demo

Open `Demo/OkaneyanOrbitODemo.xcodeproj` and run the `OkaneyanOrbitODemo` scheme on an iOS 17+ simulator. The project links this package as a local Swift Package and does not modify the MoneyWise app project. Its button manually signals readiness, so you can leave the orbit running for ten seconds or any other duration without simulating a loading timer. Tap again to replay. `Demo/preview-iphone-17.png` shows the running wait state.

Run `xcodebuild test -project Demo/OkaneyanOrbitODemo.xcodeproj -scheme OkaneyanOrbitODemo -destination 'platform=iOS Simulator,name=iPhone 17' ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO` to verify the readiness handoff in the demo.

## Verification

The Swift package and demo app build successfully for the iOS Simulator with Xcode. The UI test passed on iPhone 17 Simulator (1 passed, 0 failed), including a readiness-button tap and confirmation that the app screen becomes accessible. The demo wait state was also visually checked. A physical-device integration run, VoiceOver run, Reduce Motion interaction test and measured frame-rate review remain. See `Design/MOTION-SPEC.md` for the frozen mark and timing.
