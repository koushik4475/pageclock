# PageClock ⏱️ (Reading Focus Tracker)

[![PageClock CI / CD & Automated Release](https://github.com/koushik4475/pageclock/actions/workflows/ci.yml/badge.svg)](https://github.com/koushik4475/pageclock/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Privacy: Offline-First](https://img.shields.io/badge/Privacy-100%25%20Offline-green.svg)](PRIVACY_POLICY.md)

PageClock is an offline-first reading focus tracker built with Flutter, Riverpod, Drift (SQLite), and fl_chart. Zero paid services, zero trackers, and zero server costs.

---

## ✨ Features

- **Dual-Mode Focus Experience**: Switch seamlessly between a high-density Toggl Track timeline / entry list and a full-featured Pomodoro ring countdown.
- **Apple Mac Retro Flip Clock**: Ambient Fliqlo-style flip clock with authentic matte plates, central creasing slit, and StandBy clock mode.
- **Eleven Refined Themes**:
  - `Obsidian`: Quiet dark surfaces with an indigo glow.
  - `Porcelain`: Crisp light surfaces with refined slate.
  - `Pastel Waves`: Cream, rose, butter yellow, and sky blue.
  - `Midnight Aurora`, `Ocean Mist`, `Lavender Haze`, `Forest Grove`, `Sunset Ember`, `Rose Quartz`, `Nordic Frost`, and `Solar Citrus`.
  - Theme selection is persisted locally.
- **100% Offline-First Persistence**: Powered by SQLite via Drift on mobile and desktop, and SharedPreferences-backed storage on Web.
- **Complete Data Portability**:
  - Export formatted PDF reading reports with streaks and charts.
  - Full JSON v2 database backups with schema versioning.
  - CSV export for spreadsheets.
  - Safe import with duplicate record skipping.
- **Danger Zone Purge**: Reset all sessions or factory restore the entire app with case-insensitive typed `"confirm"` confirmation dialogues.

---

## 🔄 Automated In-App Android Updates

PageClock features a built-in automated in-app update mechanism powered by GitHub Releases.

1. **Automatic Discovery**:
   - On application startup (or periodically every 6 hours), PageClock queries `api.github.com/repos/koushik4475/pageclock/releases/latest`.
   - Update checks are non-intrusive and never interrupt an active reading session.
2. **Integrity & Security**:
   - Downloads the APK directly from GitHub Releases with live percentage and progress.
   - Computes SHA-256 hash using streaming cryptography and validates it against the published `.sha256` asset before opening the installer.
   - Rejects tampered or truncated downloads automatically.
3. **Android Package Installer**:
   - Uses Android `FileProvider` (`androidx.core.content.FileProvider`) and `REQUEST_INSTALL_PACKAGES` to launch the native system installer.

---

## 🚨 MANDATORY: Android release delivery is part of every merge

**STRICT PROJECT RULE — NO EXCEPTIONS:** A feature is not complete when its code is merely committed, merged, or CI-tested. Every successful push/merge to `main` must automatically produce a production-signed Android APK, publish the matching SHA-256 checksum and stable GitHub Release, and verify that the release is visible through the in-app updater's `/releases/latest` endpoint.

The release workflow is fail-closed: full validation must pass first; the existing production signing identity is mandatory; APK and checksum must match; and the latest-release API must return the exact new tag and both assets. Missing secrets, failed checks, stale/duplicate versions, missing assets, or API verification failures must fail the workflow. **Debug/unsigned APKs and throwaway signing keys are strictly forbidden as production-update fallbacks.**

Do not mark Android work as shipped until the release is published and updater-visible. Report whether a real-device installation/update was tested; never claim device verification without evidence. The binding rules are in [AGENTS.md](AGENTS.md) and [the mandatory Android release policy](docs/ANDROID_RELEASE_POLICY.md).

## 🔐 Android Release Keystore Configuration (GitHub Actions)

To enable permanent signed releases across all builds, configure the following secrets in GitHub (**Settings > Secrets and variables > Actions**):

| Secret Name | Description | Example / Generation Command |
| :--- | :--- | :--- |
| `ANDROID_KEYSTORE_BASE64` | Base64 representation of release keystore | `base64 -w 0 release.keystore` |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password | `your_keystore_password` |
| `ANDROID_KEY_ALIAS` | Release key alias | `pageclock_key` |
| `ANDROID_KEY_PASSWORD` | Key password | `your_key_password` |

### How to Generate a Release Keystore (Run Locally Once):
```bash
keytool -genkey -v -keystore release.keystore -alias pageclock_key -keyalg RSA -keysize 2048 -validity 10000
```
Then encode it to Base64:
- **macOS / Linux:**
  ```bash
  base64 -w 0 release.keystore > keystore_base64.txt
  ```
- **Windows PowerShell:**
  ```powershell
  [Convert]::ToBase64String([IO.File]::ReadAllBytes("release.keystore")) | Out-File -Encoding ascii keystore_base64.txt
  ```
Paste the output into GitHub secret `ANDROID_KEYSTORE_BASE64`.

> **Security Guard:** If `ANDROID_KEYSTORE_BASE64` is missing, PR and development branch builds will build a debug APK without publishing. Release builds on tag `v*` will fail with an error rather than generating an untrusted throwaway keystore.

---

## 📱 Installation & Distribution

### 1. Android Installation
- **Latest GitHub Release:**
  👉 **[https://github.com/koushik4475/pageclock/releases/latest](https://github.com/koushik4475/pageclock/releases/latest)**
  Download `PageClock-v*.apk` and install.

---

### 2. iOS Installation (iPhone & iPad)
- **Free Standalone PWA:**
  1. Open the hosted web application in Safari on iOS.
  2. Tap **Share** -> **Add to Home Screen**.
  3. Launches full-screen as a standalone application.

---

## 💻 Running Locally

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d chrome
```

---

## ⚖️ License & Policy Compliance

- **License**: MIT License (free and open source). See [LICENSE](LICENSE).
- **Privacy Policy**: 100% offline-first. No third-party trackers, no cloud sync, zero telemetry. See [PRIVACY_POLICY.md](PRIVACY_POLICY.md).
