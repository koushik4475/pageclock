// Keep the context unlocked by the user's timer/preview gesture for the later alarm.
window.pageClockAudio = (() => {
  let context;
  let source;
  let generation = 0;

  async function prepare() {
    context ??= new (window.AudioContext || window.webkitAudioContext)();
    if (navigator.audioSession && navigator.audioSession.type !== 'playback') {
      navigator.audioSession.type = 'playback';
    }
    if (context.state !== 'running') {
      let timeout;
      try {
        await Promise.race([
          context.resume(),
          new Promise((_, reject) => {
            timeout = setTimeout(() => reject(new Error('Tap to enable sound')), 3000);
          }),
        ]);
      } finally {
        clearTimeout(timeout);
      }
    }
  }

  function stop() {
    generation++;
    if (source) {
      source.stop();
      source.disconnect();
      source = null;
    }
  }

  async function play(url) {
    stop();
    const request = generation;
    await prepare();
    const response = await fetch(url);
    if (!response.ok) throw new Error('Audio unavailable: ' + response.status);
    const buffer = await context.decodeAudioData(await response.arrayBuffer());
    if (request !== generation) return;
    const next = context.createBufferSource();
    next.buffer = buffer;
    next.connect(context.destination);
    next.onended = () => {
      next.disconnect();
      if (source === next) source = null;
    };
    source = next;
    next.start();
  }

  return { prepare, play, stop };
})();
