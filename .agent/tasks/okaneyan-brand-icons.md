# okaneyan. brand identity and app icons

## Objective and constraints

Implement the user's approved okaneyan. brand reference in the native iOS app and review-only web preview. Recreate the balance/flow mark and sphere from `/Users/yan/Downloads/вв.png` as original vector artwork; do not use the cropped slide as a production image. Keep the exact wordmark `okaneyan.`. Add four icon variants and a real iOS Alternate App Icons picker. No false success state, no extra native wrapper, no new finance behavior.

## Existing state

- Product is a native SwiftUI/SwiftData iOS app with iOS 17 deployment target; web is a static review preview.
- No asset catalog or app-icon assets currently exist. Project generates its Info.plist.
- `SettingsView` is a SwiftUI `Form`; product is native SwiftUI/SwiftData iOS 17, with a static web review preview.
- Reference image is present at `/Users/yan/Downloads/вв.png`.
- Full Xcode/iOS Simulator is unavailable in this environment, so compiled asset catalog and installed-device icon change cannot be verified here.

## Milestones

1. **Brand source and guidelines:** trace the reference into four standalone SVG icon sources, specify geometry/color/safe area, and export app-ready PNGs.
2. **Asset catalog and platform plumbing:** configure primary and alternate iOS app icons through Xcode build settings, add preview images, and brand the launch screen/display name.
3. **Settings UI:** add Settings → Appearance → App Icon grid; read the actual icon name from UIApplication, invoke the UIKit API, persist only after success, and surface unsupported/error states.
4. **Web preview:** use the exact wordmark and branded favicon/touch icons; do not suggest browser selection changes the installed iOS icon.
5. **Verification:** render and inspect icons at 24/32/60/120 and 1024 px, check SVG/PNG dimensions and parity, run available browser interaction and static Swift syntax checks, document iOS build/device limitation.

## Acceptance criteria

- Four centered, distinct icon assets share the reference symbol and safe-area proportions.
- `okaneyan.` appears in text branding, never inside the app icon.
- iOS picker offers all four variants and primary reset, with ≥44 pt hit areas, accessible labels, selected state, Reduce Motion-aware selection, persistence reconciled against the system and actionable failure UI.
- System icon updates only after UIKit reports success; support is checked before changing.
- Web preview and favicon reflect the brand without representing a real native icon change.
- Brand guidelines and app icon spec exist; verification status and platform limits are recorded honestly.

## Progress

- Reference image located, visually inspected and traced into four independent SVG variants; 1024px assets and small-size exports prepared.
- Four app icon sets and preview image sets added to `iOSApp/Assets.xcassets`; Xcode build settings include primary and alternate app icons.
- App display name, launch screen, appearance route, icon selection UI, branded docs and web preview have been updated.
- Swift frontend parse passed for app, core and checks sources. Asset JSON, manifest JSON, storyboard XML and project OpenStep plist syntax validate. Desktop 1440px and mobile 390px preview checked in Chromium; no console errors or horizontal overflow, and brand image loads.
- Full Xcode, simulator and device are unavailable. Asset catalog compilation, SwiftUI type-check and actual UIKit icon replacement are `NOT VERIFIED`.

## Next actionable step

Open the project with full Xcode, build and install on an iPhone/simulator, select all four choices, confirm iOS reports the same alternate icon, relaunch to confirm persistence, and exercise unsupported/error behavior if a test harness allows it.
