# Mandatory Android Release & Update Policy

**Priority: RELEASE BLOCKING. This policy is mandatory for every project contributor and automation.**

## Non-negotiable guarantee

Every successful push/merge to `main` must automatically produce a production-signed Android APK for that exact `main` commit, calculate and publish its SHA-256 sidecar, create a stable GitHub Release, and verify that the release is visible to the app's updater. A merged Android change that is not available to installed users is an incident—not a completed delivery.

## Required sequence

1. **Validate:** dependencies, Drift code generation, `flutter analyze`, all `flutter test` tests, and production web build must pass.
2. **Build:** build the Android release APK only after validation passes. Use the existing production keystore and signing identity. Do not use debug signing as a fallback.
3. **Version:** extract the semantic version from `pubspec.yaml`; use a monotonically increasing CI run number for Android's build number. The new version/build pair must compare newer than the current latest stable GitHub Release.
4. **Package:** publish the APK and its matching `.apk.sha256` file together in a non-draft, non-prerelease release.
5. **Verify:** query `https://api.github.com/repos/koushik4475/pageclock/releases/latest` and assert that it returns the expected tag and both matching assets. Fail the job if anything is missing, stale, or malformed.
6. **Report:** provide the merge SHA, successful checks, release URL, asset verification, and honest device-testing status.

## Fail-closed conditions

- Missing/invalid signing secrets, wrong signing identity, failed build, failed tests, invalid version, duplicate/non-increasing release version, release API mismatch, absent APK, absent checksum, or malformed SHA-256 MUST fail the release workflow.
- Never create or substitute a throwaway keystore; that would break Android update compatibility.
- Never publish unsigned/debug APKs as production updates.
- Never disable tests, skip checksum verification, or claim a release succeeded based only on a CI green badge or an uploaded workflow artifact.
- Never mark a feature "complete" until its code is on `main` and the automatic production release is published and updater-visible.
- Physical-device install/update verification must be recorded separately. If unavailable, disclose it rather than claiming it happened.

## Change control

Any modification to the release workflow, signing configuration, package ID, version comparator, release parser, downloader, installer, or update-check timing requires dedicated review and regression tests. Preserve package ID and signing-certificate continuity. The updater must install only a checksum-verified APK obtained over HTTPS.

## Recovery

If a merge does not produce a release, stop new delivery claims, inspect the failed or missing workflow, repair the root cause, and publish a release from the latest `main` SHA. Verify that the updater's latest-release endpoint returns the new release. A release gap remains open until this verification succeeds.
