# Mandatory Android Release & Update Policy

**Priority: RELEASE BLOCKING. This policy is mandatory for every project contributor and automation.**

## Non-negotiable guarantee

Every push/merge to `main` must pass dependency resolution, Drift code generation, Dart analysis, the full Flutter test suite, and the production web build. A merged Android change is not shipped until a separate version-tag release has produced a production-signed APK and matching SHA-256 sidecar, published both in a stable GitHub Release, and verified updater visibility. Production signing secrets are available only to a `push` event for a `v*` tag that points to the exact current `main` HEAD; ordinary branch pushes, pull requests, legacy release branches, and manual workflow dispatch must never access those secrets.

## Required sequence

1. **Validate main and PRs:** dependencies, Drift code generation, `flutter analyze`, all `flutter test` tests, and production web build must pass. These jobs do not receive production signing secrets.
2. **Prepare a release tag:** after validation passes, create `vMAJOR.MINOR.PATCH+BUILD_NUMBER` on the exact current `main` HEAD. Never tag an old commit, legacy release branch, or unmerged feature branch.
3. **Verify the tag:** the tag-triggered workflow must confirm that the tag matches `pubspec.yaml`, its commit equals `GITHUB_SHA`, and that SHA equals current `main` HEAD. Recheck before publishing.
4. **Build:** only the `push` event for a `v*` tag may run the production APK job or access the existing production keystore. Use the same signing identity as the currently published APK.
5. **Version:** use the build number encoded in the tag as Android's `versionCode`; it must increase monotonically and the version pair must compare newer than the latest stable GitHub Release.
6. **Package:** publish the APK and its matching `.apk.sha256` file together in a non-draft, non-prerelease release.
7. **Verify:** query `https://api.github.com/repos/koushik4475/pageclock/releases/latest` and assert that it returns the expected tag, exact source commit, APK, and checksum. Independently verify the downloaded APK bytes against the sidecar.
8. **Report:** provide the main/tag commit SHA, successful checks, release URL, asset verification, and honest device-testing status.

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
