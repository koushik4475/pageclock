# PageClock ⏱️ (Reading Focus Tracker)

[![PageClock CI / CD & Automated Release](https://github.com/koushik4475/pageclock/actions/workflows/ci.yml/badge.svg)](https://github.com/koushik4475/pageclock/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Privacy: Offline-First](https://img.shields.io/badge/Privacy-100%25%20Offline-green.svg)](PRIVACY_POLICY.md)

PageClock is an offline-first reading focus tracker built with Flutter, Riverpod, Drift (SQLite), and fl_chart. Zero paid services, zero trackers, and zero server costs.

---

## 🔄 Automated In-App Android Updates

PageClock features a built-in, 100% free, automated in-app update mechanism powered by GitHub Releases.

1. **Automatic Discovery**:
   - On application startup (or periodically every 6 hours), PageClock queries `api.github.com/repos/koushik4475/pageclock/releases/latest`.
   - Update checks are completely non-intrusive and never interrupt an active reading session.
2. **Integrity & Security**:
   - Downloads the APK directly from GitHub Releases with live percentage and MB progress.
   - Computes SHA-256 hash using streaming cryptography and validates it against the published `.sha256` asset before opening the installer.
   - Rejects tampered or truncated downloads automatically.
3. **Android Package Installer**:
   - Uses Android `FileProvider` (`androidx.core.content.FileProvider`) and `REQUEST_INSTALL_PACKAGES` to launch the native system installer seamlessly.
4. **Manual Trigger**:
   - Go to **Settings > Check for Updates** anytime to verify or force-check the latest release.

---

## 🔐 Android Release Keystore Configuration (GitHub Actions)

To enable permanent signed releases across all builds, configure the following secrets in GitHub (**Settings > Secrets and variables > Actions**):

| Secret Name | Description | Example / Generation Command |
| :--- | :--- | :--- |
| `ANDROID_KEYSTORE_BASE64` | Base64 representation of release keystore | `base64 -w 0 release.keystore` |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password | `your_keystore_password` |
| `ANDROID_KEY_ALIAS` | Release key alias | `pageclock` |
| `ANDROID_KEY_PASSWORD` | Key password | `your_key_password` |

### How to Generate a Release Keystore (Run Locally Once):
```bash
keytool -genkey -v -keystore release.keystore -alias pageclock -keyalg RSA -keysize 2048 -validity 10000
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

> **Note:** If `ANDROID_KEYSTORE_BASE64` is not configured, the CI workflow falls back to debug signing so testing and development builds continue uninterrupted.

---

## 📱 Exact Download & Installation Paths

### 1. Android Installation
- **Latest GitHub Release:**
  👉 **[https://github.com/koushik4475/pageclock/releases/latest](https://github.com/koushik4475/pageclock/releases/latest)**
  Download `PageClock-v*.apk` and install.
- **Local Path on Your Laptop:**
  `C:\Users\koush\Desktop\pageclock-apk\app-release.apk`

---

### 2. iOS Installation (iPhone & iPad)
- **Free Standalone PWA (Recommended):**
  1. Open `http://<your-ip>:8080` (or GitHub Pages) in Safari on iOS.
  2. Tap **Share** -> **Add to Home Screen**.
  3. Launches full-screen as a standalone application.

---

## 💻 Running Locally

- **Local Web Server**:
  👉 **[http://localhost:8080](http://localhost:8080)**
- **Local Source Code:**
  📁 `C:\Users\koush\Desktop\pageclock`

---

## ⚖️ License & Policy Compliance

- **License**: MIT License (free and open source). See [LICENSE](LICENSE).
- **Privacy Policy**: 100% offline, compliant with Apple App Store Review Guidelines §5.1 and Google Play Data Safety policies. See [PRIVACY_POLICY.md](PRIVACY_POLICY.md).
