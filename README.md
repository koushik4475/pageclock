# PageClock ⏱️ (Reading Focus Tracker)

[![PageClock CI / Build](https://github.com/koushik4475/pageclock/actions/workflows/ci.yml/badge.svg)](https://github.com/koushik4475/pageclock/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Privacy: Offline-First](https://img.shields.io/badge/Privacy-100%25%20Offline-green.svg)](PRIVACY_POLICY.md)

PageClock is an offline-first reading focus tracker built with Flutter, Riverpod, Drift (SQLite), and fl_chart. Zero paid services, zero trackers, and zero server costs.

---

## 📱 Exact Download & Installation Paths

### 1. Android Installation
Download the release APK generated directly by GitHub Actions:

- **Direct GitHub Artifact Path:**
  1. Go to the [PageClock GitHub Actions Tab](https://github.com/koushik4475/pageclock/actions)
  2. Click on the latest green workflow run (`PageClock CI / Build`).
  3. Under the **Artifacts** section at the bottom, click **`pageclock-apk`** to download `pageclock-apk.zip`.
  4. Unzip the file to obtain `app-release.apk`.
  5. Tap `app-release.apk` on your Android device to install.

- **Local Path on Your Laptop:**
  `C:\Users\koush\Desktop\pageclock-apk\app-release.apk`

---

### 2. iOS Installation (iPhone & iPad)
Per Apple Developer policies, unsigned IPAs cannot be directly side-loaded without either a free Apple ID or Apple Developer Program membership.

- **Option A (Free PWA — Recommended for iOS without Mac):**
  1. Open the web app on your iPhone in Safari: `http://<your-local-ip>:8080` (or host it for free on GitHub Pages).
  2. Tap the **Share** button in Safari.
  3. Tap **"Add to Home Screen"**.
  4. PageClock will run full-screen as a standalone native-feeling app with local offline storage.

- **Option B (Native Build via Xcode on macOS):**
  1. Clone this repository onto a Mac:
     ```bash
     git clone https://github.com/koushik4475/pageclock.git
     cd pageclock
     flutter run -d ios
     ```
  2. Sign with your free Apple ID under Xcode Signing & Capabilities.

---

## 💻 Running on Laptop (Web / Windows)

- **Local Web Server (Instant)**:
  PageClock is already served on your machine:
  👉 **[http://localhost:8080](http://localhost:8080)**

- **Local Source Code:**
  📁 `C:\Users\koush\Desktop\pageclock`

---

## ✨ Features

- **Timestamp-Based Stopwatch**: Accurate timing that survives backgrounding, force-kills, and device reboot.
- **iPhone StandBy Clock Mode**: Full-screen desk clock mode (landscape and portrait) with a bold oversized digital clock and live reading timer controls.
- **Adaptive UI**: Responsive layouts with adaptive `NavigationRail` on wide screens and `NavigationBar` on mobile.
- **Pure-Dart Analytics Engine**:
  - Automatic midnight-split aggregation.
  - Consistency score (7 / 30 / 90 days).
  - Current & best streak tracking.
  - 4-week linear regression trend (▲ Increasing, ▼ Decreasing, — Steady).
- **Offline & Private**: 100% on-device SQLite storage with full CSV export and instant data wipe.

---

## ⚖️ License & Policy Compliance

- **License**: MIT License (free and open source). See [LICENSE](LICENSE).
- **Privacy Policy**: 100% offline, compliant with Apple App Store Review Guidelines §5.1 and Google Play Data Safety policies. See [PRIVACY_POLICY.md](PRIVACY_POLICY.md).
