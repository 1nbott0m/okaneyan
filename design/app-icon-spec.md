# okaneyan. app icon specification

## Geometry and exports

- Square master: 1024 × 1024 px, opaque full-bleed background.
- Four approved Orbit O SVG masters copied from the user-supplied `okaneyan-orbit-o 3` set: `design/brand/icons/okaneyan-{original,light,monochrome,glass}.svg`.
- Four exported 1024 × 1024 PNGs live in `design/brand/icons/png/`; 24, 32, 60 and 120 px reference-size PNG exports are provided for small-size inspection.
- The mark keeps the approved centered O, open outer orbit and rose point at the upper-right gap. It has no wordmark text.
- iOS applies its own icon mask. Source artwork remains square and does not include a rounded-square crop.

## iOS asset names

| Purpose | Asset catalog set | UIKit icon name |
|---|---|---|
| Primary / Original | `AppIcon` | `nil` (primary icon) |
| Light | `AppIconLight` | `AppIconLight` |
| Monochrome | `AppIconMonochrome` | `AppIconMonochrome` |
| Glass | `AppIconGlass` | `AppIconGlass` |

The project selects `AppIcon` as its primary set and explicitly includes the three alternate sets. Xcode generates the `CFBundlePrimaryIcon` and `CFBundleAlternateIcons` declarations from these settings.

The settings picker reads `UIApplication.shared.alternateIconName` as the source of truth, checks `supportsAlternateIcons`, calls `setAlternateIconName`, and updates its persisted UI selection only after the callback returns without error and the system reports the requested icon. If the system keeps the prior value, the UI reselects that actual icon and reports the failure. The primary choice calls the API with `nil`.

## Settings behavior

- Path: **Settings → Appearance → App Icon**.
- Four preview cards include title, short purpose, selected state and accessible label/value.
- Cards exceed the 44 pt iPhone target; selection highlight springs unless Reduce Motion is active.
- While iOS applies the change, cards are disabled and a progress state appears.
- Unsupported systems keep the current icon and explain the limitation; API errors do not produce a success state.
- iOS retains its installed alternate icon across ordinary app launches; app storage mirrors the selection and is reconciled from the system each time the picker opens.

## Web resources

- `preview/assets/brand/okaneyan-favicon-32.png`
- `preview/assets/brand/okaneyan-apple-touch-180.png`
- `preview/assets/brand/okaneyan-pwa-192.png` and `okaneyan-pwa-512.png`
- `preview/manifest.webmanifest` is only for the demo review page. A web-browser icon choice does not invoke the native iOS icon API.

## Verification status

- SVGs and PNGs: the four approved source files are now installed; visual inspection completed at 24/32/60/120 px and at 1024 px.
- Native source: Swift frontend parse passed for the app, core sources and checks, but this does not verify SwiftUI/UIKit type-checking or Xcode asset catalog compilation.
- Web preview: `VERIFIED` in Chromium at 390 × 844 and 1440 × 1000; brand image and manifest load, with no console errors or horizontal overflow.
- Project metadata: asset JSON, manifest JSON, storyboard XML and Xcode project plist syntax parse successfully.
- Device runtime: `NOT VERIFIED` because full Xcode, iOS Simulator and an installed iPhone build are unavailable. Asset compilation, native API confirmation and persistence after relaunch still require an iOS runtime check.

## Platform references

- [UIApplication.supportsAlternateIcons](https://developer.apple.com/documentation/uikit/uiapplication/supportsalternateicons)
- [UIApplication.alternateIconName](https://developer.apple.com/documentation/uikit/uiapplication/alternateiconname)
- [UIApplication.setAlternateIconName(_:completionHandler:)](https://developer.apple.com/documentation/uikit/uiapplication/setalternateiconname%28_%3Acompletionhandler%3A%29)
- [Xcode Alternate App Icon Sets build setting](https://developer.apple.com/documentation/xcode/build-settings-reference#Alternate-App-Icon-Sets)
