# PageClock iOS build and release

## Current iOS build

PageClock uses the shared Flutter application code. The iOS Runner/Xcode host project is generated in CI and attached to the **Build iOS Simulator App** workflow as the `pageclock-ios-simulator` artifact. The generated bundle identifier is `com.pageclock.app`.

The iOS CI job:
- Resolves Flutter dependencies and runs Drift code generation.
- Runs the complete Flutter regression, widget, data-integrity and pressure-test suite on macOS.
- Builds an unsigned **Release** configuration for the iOS Simulator.
- Uploads both the generated Xcode project and simulator app for inspection.

A simulator build is not a signed iPhone install or an App Store release.

## Open and run on an iPhone

1. Download and extract the `pageclock-ios-simulator` artifact from a successful GitHub Actions run.
2. For a physical-device build, generate or retain the iOS host project and open `ios/Runner.xcworkspace` in Xcode.
3. In **Signing & Capabilities**, select the Apple Developer Team and confirm the bundle identifier `com.pageclock.app`.
4. Connect an iPhone, select it as the run destination, and build/run from Xcode.
5. Test notification permission, background/foreground timer recovery, haptics, file export/share, and local database persistence on a physical device.

## TestFlight / App Store

A distribution build requires an Apple Developer Program membership, signing certificate/provisioning profile, and App Store Connect app record. Configure those in the Apple account and Xcode signing settings; do not commit certificates, private keys, provisioning profiles, or App Store Connect API keys to the repository.

Create an Archive in Xcode and upload it to App Store Connect, then distribute through TestFlight before submitting to App Review. Apple-platform updates are delivered through TestFlight/App Store, not PageClock's Android APK updater.

## Privacy and platform behavior

- Core timer, calendar, reports, and local data remain usable without an account or network.
- Reading sessions and notes remain on-device; optional account authentication does not imply cloud sync.
- Request notification permission only when the user enables reminders or timer notifications.
- Validate VoiceOver, Dynamic Type, safe-area layout, dark/light appearance, iPhone portrait/landscape, and iPad multitasking before release.

## Validation boundaries

CI can validate Dart analysis/tests and compile an unsigned simulator app. It cannot certify App Store acceptance, validate Apple signing, or replace physical-device QA.