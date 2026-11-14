const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { webkit } = require('playwright');

const baseUrl = process.env.PAGECLOCK_WEB_URL || 'http://127.0.0.1:4173';
const outputDir = path.join(os.tmpdir(), 'pageclock-ios-webkit');
fs.mkdirSync(outputDir, { recursive: true });

const devices = [
  { name: 'iphone-compact-portrait', width: 320, height: 568 },
  { name: 'iphone-standard-portrait', width: 390, height: 844 },
  { name: 'iphone-large-portrait', width: 430, height: 932 },
  { name: 'iphone-landscape', width: 844, height: 390 },
  { name: 'ipad-portrait', width: 820, height: 1180 },
  { name: 'ipad-landscape', width: 1180, height: 820 },
];

(async () => {
  const browser = await webkit.launch({ headless: true });
  try {
    const failures = [];
    for (const device of devices) {
      const page = await browser.newPage({
        viewport: { width: device.width, height: device.height },
        deviceScaleFactor: 2,
        isMobile: true,
        hasTouch: true,
      });
      const pageErrors = [];
      page.on('pageerror', error => pageErrors.push(error.message));

      const response = await page.goto(baseUrl, { waitUntil: 'load', timeout: 120000 });
      if (!response || response.status() >= 400) {
        throw new Error(device.name + ': web app returned HTTP ' + (response ? response.status() : 'no response'));
      }

      await page.waitForFunction(
        () => Boolean(document.querySelector('flt-glass-pane, flutter-view')),
        null,
        { timeout: 120000 },
      );
      await page.waitForTimeout(1200);

      const result = await page.evaluate(async () => {
        const appleCapable = document.querySelector('meta[name="apple-mobile-web-app-capable"]')?.content;
        const appleTitle = document.querySelector('meta[name="apple-mobile-web-app-title"]')?.content;
        const appleIcon = document.querySelector('link[rel="apple-touch-icon"]')?.href;
        const manifestLink = document.querySelector('link[rel="manifest"]')?.href;
        let manifest = null;
        if (manifestLink) {
          const response = await fetch(manifestLink);
          if (response.ok) manifest = await response.json();
        }
        const manifestIconStatuses = await Promise.all((manifest?.icons || []).map(async icon => {
          try {
            const iconResponse = await fetch(new URL(icon.src, manifestLink).href);
            return { src: icon.src, status: iconResponse.status };
          } catch (_) {
            return { src: icon.src, status: 0 };
          }
        }));
        let serviceWorkerActive = false;
        try {
          if ('serviceWorker' in navigator) {
            const registration = await navigator.serviceWorker.register(new URL('sw.js', location.href).href);
            const ready = await Promise.race([
              navigator.serviceWorker.ready,
              new Promise(resolve => setTimeout(() => resolve(null), 15000)),
            ]);
            serviceWorkerActive = Boolean(ready?.active || registration.active);
          }
        } catch (_) {
          serviceWorkerActive = false;
        }
        let appleIconStatus = 0;
        if (appleIcon) {
          const iconResponse = await fetch(appleIcon);
          appleIconStatus = iconResponse.status;
        }
        return {
          title: document.title,
          viewportWidth: window.innerWidth,
          documentWidth: document.documentElement.clientWidth,
          scrollWidth: document.documentElement.scrollWidth,
          flutterRoot: Boolean(document.querySelector('flt-glass-pane, flutter-view')),
          appleCapable,
          appleTitle,
          appleIcon,
          appleIconStatus,
          serviceWorkerActive,
          manifestIconStatuses,
          manifestDisplay: manifest?.display,
          manifestOrientation: manifest?.orientation,
          canvasCount: document.querySelectorAll('canvas').length,
          touchPoints: navigator.maxTouchPoints,
        };
      });

      if (!result.flutterRoot) failures.push(device.name + ': Flutter root did not mount');
      if (result.scrollWidth > result.documentWidth + 1) {
        failures.push(device.name + ': horizontal page overflow (' + result.scrollWidth + ' > ' + result.documentWidth + ')');
      }
      if (result.appleCapable !== 'yes') failures.push(device.name + ': iOS standalone metadata is missing');
      if (result.appleTitle !== 'PageClock') failures.push(device.name + ': iOS home-screen title is missing');
      if (!result.appleIcon || result.appleIconStatus !== 200) failures.push(device.name + ': iOS home-screen icon is unavailable');
      if (result.manifestDisplay !== 'standalone') failures.push(device.name + ': PWA manifest is not standalone');
      if (!result.manifestIconStatuses.length || result.manifestIconStatuses.some(icon => icon.status !== 200)) failures.push(device.name + ': one or more PWA manifest icons are missing');
      if (!result.serviceWorkerActive) failures.push(device.name + ': offline service worker did not activate');
      if (pageErrors.length) failures.push(device.name + ': JavaScript errors: ' + pageErrors.join(' | '));

      await page.screenshot({
        path: path.join(outputDir, device.name + '.png'),
        fullPage: true,
      });
      console.log(device.name + ': ' + JSON.stringify(result));
      await page.close();
    }

    if (failures.length) {
      throw new Error('iOS WebKit smoke checks failed:\n- ' + failures.join('\n- '));
    }
    console.log('Passed iOS WebKit PWA smoke checks on all six iPhone/iPad viewports.');
  } finally {
    await browser.close();
  }
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
