const assert = require('node:assert/strict');
const { chromium, webkit } = require('playwright');

async function test(engine, name) {
  const browser = await engine.launch();
  try {
    const page = await browser.newPage({ hasTouch: true, isMobile: true });
    // Observe the real PCM signal between the production source and its destination.
    await page.addInitScript(() => {
      const connect = AudioBufferSourceNode.prototype.connect;
      AudioBufferSourceNode.prototype.connect = function (destination, ...args) {
        if (destination !== this.context.destination) return connect.call(this, destination, ...args);
        const meter = this.context.createAnalyser();
        window.audioMeter = meter;
        meter.connect(destination);
        return connect.call(this, meter);
      };
    });
    await page.goto(process.env.PAGECLOCK_WEB_URL || 'http://127.0.0.1:4173');
    await page.evaluate(() => {
      const button = document.createElement('button');
      button.textContent = 'Enable test audio';
      button.style.cssText = 'position:fixed;top:0;left:0;z-index:2147483647';
      button.onclick = () => { window.audioReady = pageClockAudio.prepare(); };
      document.body.appendChild(button);
    });
    await page.getByRole('button', { name: 'Enable test audio' }).tap();
    await page.evaluate(() => window.audioReady);
    await page.waitForTimeout(5500); // Timer completion occurs outside transient activation.
    async function expectSignal() {
      await page.waitForFunction(() => {
        const meter = window.audioMeter;
        if (!meter) return false;
        const samples = new Float32Array(meter.fftSize);
        meter.getFloatTimeDomainData(samples);
        return samples.some(sample => Math.abs(sample) > 0.001);
      }, null, { timeout: 5000 });
    }
    for (const theme of ['calm', 'rain', 'forest', 'ocean', 'bell', 'classic']) {
      await page.evaluate(theme => pageClockAudio.play('assets/assets/audio/' + theme + '.wav'), theme);
      await expectSignal();
      await page.evaluate(() => pageClockAudio.stop());
    }
    const result = await page.evaluate(async () => {
      const bytes = await (await fetch('assets/assets/audio/bell.wav')).blob();
      const custom = await new Promise(resolve => {
        const reader = new FileReader();
        reader.onload = () => resolve(reader.result);
        reader.readAsDataURL(bytes);
      });
      await Promise.all(Array.from({ length: 6 }, () => pageClockAudio.play(custom)));
      const last = window.audioMeter;
      const pending = pageClockAudio.play(custom);
      pageClockAudio.stop();
      await pending;
      return { stopped: last === window.audioMeter, custom };
    });
    assert.equal(result.stopped, true);
    await assert.rejects(page.evaluate(() => pageClockAudio.play('data:audio/wav;base64,AA==')));
    await page.evaluate(url => pageClockAudio.play(url), result.custom);
    await expectSignal();
    console.log(name + ': all six presets, delayed playback, rapid replacement, stop, custom audio and decode-error recovery passed');
  } finally {
    await browser.close();
  }
}
(async () => {
  await test(webkit, 'WebKit');
  await test(chromium, 'Chromium');
})().catch(error => { console.error(error); process.exitCode = 1; });
