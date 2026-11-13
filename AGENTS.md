# PageClock Project Rules (MANDATORY)

These rules are strict release requirements. They apply to every contributor, coding agent, automation, maintainer, and pull request. Do not weaken, bypass, or silently ignore them.

## 1. A feature is NOT shipped until installed users can receive it

- **STRICTLY FORBIDDEN:** Marking an Android feature, bug fix, UI change, or behavior change as "done", "complete", "released", or "delivered" merely because code was committed, a PR was merged, or CI passed.
- Every successful merge to `main` MUST produce a production-signed Android APK and a matching SHA-256 checksum, publish both in a GitHub Release, and make that release discoverable through the exact GitHub Releases endpoint used by the in-app updater.
- The default-branch release workflow is the enforcement mechanism. A successful merge without a successful, verified release is an incident that must be investigated and fixed immediately.
- The latest published APK MUST include the merged `main` commit. Never publish an APK built from an older branch or an unmerged feature branch.
- Do not report success until the release tag, APK asset, checksum asset, release target commit, and updater-visible latest version have all been verified.

## 2. Mandatory Android release pipeline

For every push/merge to `main`:

1. Run dependency resolution, code generation, static analysis, the complete Flutter test suite, and the production web build.
2. Only after those checks pass, build the Android **release** APK using the established production signing keystore.
3. Use a monotonically increasing Android build number. The release version must compare newer than the latest published release according to the app's actual `VersionComparator`.
4. Publish a non-draft, non-prerelease GitHub Release with exactly matching version/tag, APK, and `.apk.sha256` sidecar. Preserve the same signing identity as previously distributed APKs.
5. Verify the published release through `/repos/koushik4475/pageclock/releases/latest`. Verify the exact tag, APK asset, checksum asset, and checksum format before declaring the pipeline successful.
6. If any step fails, the workflow MUST fail visibly. Never fall back to a debug-signed APK, unsigned APK, missing checksum, stale artifact, or success-shaped placeholder.

Production signing secrets are required. Missing or invalid signing configuration MUST fail closed. Never create a new throwaway keystore to get a green build, and never change/rekey the signing identity without an explicit migration plan because Android will reject an update signed by a different key.

## 3. In-app updater is part of release acceptance

- The updater must compare version name and build number correctly, discover the latest stable release, select the APK and checksum belonging to that same release, download over HTTPS, verify SHA-256 before install, and handle errors without claiming that an update was installed.
- Every updater change requires tests for newer/older/equal versions, build-number ordering, missing release/assets/checksum, malformed checksum, checksum mismatch, API rate limits, network failures, redirects, and cancellation where applicable.
- The release must be discoverable by the production updater endpoint, not merely visible in Actions artifacts.
- Validate the installed APK's application ID and signing-certificate continuity before publishing. Do not bypass Android's signature checks or Play Protect.
- Device installation/update verification is required before calling a release fully device-verified. When a physical device is unavailable, state that limitation explicitly; do not fabricate device testing.

## 4. Pull request and completion gates

- PRs that change Android app behavior MUST include tests and must not be described as shipped before the post-merge release workflow succeeds.
- For every merged PR, track the resulting `main` SHA and its release workflow. Ensure the release points at that SHA or a later `main` SHA containing it.
- A cancelled, skipped, stale, failed, or still-running release job is NOT a successful release.
- Never suppress, skip, or make the Android release job optional for ordinary `main` pushes.
- Keep release failures visible in the PR/Actions workflow and fix the root cause. Do not solve failures by disabling tests, removing checksum verification, using debug signing, lowering security, or falsely reporting completion.

## 5. Security and data integrity

- Never expose signing secrets, keystore bytes, passwords, or private credentials in logs, commits, artifacts, or chat.
- Never publish a checksum for a different APK, reuse a stale APK, or allow a release with mismatched version metadata.
- Preserve offline-first behavior and least privilege. A release update must not introduce telemetry, remote config, or permissions unless separately justified and reviewed.
- Do not force-push over another contributor's work or rewrite published release assets without a documented recovery reason.

## 6. Required status reporting

Every delivery report MUST state:
- merged commit SHA;
- CI/test/build result;
- GitHub Release tag and URL;
- APK and SHA-256 asset presence;
- latest-release API verification result;
- whether a real device update/install was tested or remains unverified.

**Final rule: A merged feature that cannot reach the installed app is not complete. Treat this as a release-blocking defect, not a minor follow-up.**
