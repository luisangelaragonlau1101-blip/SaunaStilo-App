/* Local capture only. Samples never leave the browser until the owner submits them. */
(() => {
  let session = null;
  let starting = false;
  let generation = 0;
  function wav24(samples) {
    const buffer = new ArrayBuffer(44 + samples.length * 2);
    const view = new DataView(buffer);
    const text = (offset, value) => [...value].forEach((c, i) => view.setUint8(offset + i, c.charCodeAt(0)));
    text(0, 'RIFF'); view.setUint32(4, buffer.byteLength - 8, true); text(8, 'WAVE'); text(12, 'fmt ');
    view.setUint32(16, 16, true); view.setUint16(20, 1, true); view.setUint16(22, 1, true);
    view.setUint32(24, 24000, true); view.setUint32(28, 48000, true); view.setUint16(32, 2, true); view.setUint16(34, 16, true);
    text(36, 'data'); view.setUint32(40, samples.length * 2, true);
    samples.forEach((v, i) => view.setInt16(44 + i * 2, Math.round(Math.max(-1, Math.min(1, v)) * (v < 0 ? 32768 : 32767)), true));
    return new Uint8Array(buffer);
  }
  async function clean(s) {
    if (!s) return;
    s.closed = true;
    clearTimeout(s.timer);
    s.stream.getTracks().forEach(t => t.stop());
    try { s.node?.disconnect(); s.source?.disconnect(); s.silent?.disconnect(); } catch (_) {}
    if (s.context.state !== 'closed') await s.context.close();
  }
  window.saunaVoiceCapture = {
    async start(maxSeconds = 10) {
      if (session || starting) throw new Error('Ya hay una grabación en curso.');
      starting = true; const ticket = ++generation;
      let stream; let context;
      try {
        if (!navigator.mediaDevices?.getUserMedia) throw new Error('El micrófono requiere un navegador seguro.');
        const Context = window.AudioContext || window.webkitAudioContext;
        context = new Context();
        await context.resume();
        stream = await navigator.mediaDevices.getUserMedia({audio: {channelCount: 1, echoCancellation: true, noiseSuppression: true}, video: false});
        if (ticket !== generation) throw new Error('Grabación cancelada.');
        const s = {stream, context, rate: context.sampleRate, chunks: [], length: 0, max: Math.floor(context.sampleRate * Math.max(1, Math.min(10, maxSeconds))), closed: false};
        session = s;
        s.source = context.createMediaStreamSource(stream);
        s.silent = context.createGain(); s.silent.gain.value = 0;
        const collect = samples => {
          if (s.closed || s.length >= s.max) return;
          const chunk = samples.slice(0, s.max - s.length);
          s.chunks.push(chunk); s.length += chunk.length;
        };
        // Use the actual AudioContext rate, not the requested microphone constraint.
        if (context.audioWorklet && window.AudioWorkletNode) {
          const source = `class StiloCapture extends AudioWorkletProcessor {process(inputs, outputs) {const channels = inputs[0]; if (channels && channels[0]) {const mono = new Float32Array(channels[0].length); for(const ch of channels) for(let i=0;i<mono.length;i++) mono[i]+=ch[i]/channels.length; this.port.postMessage(mono, [mono.buffer]);} return true;}} registerProcessor('stilo-capture', StiloCapture);`;
          const url = URL.createObjectURL(new Blob([source], {type: 'text/javascript'}));
          try {await context.audioWorklet.addModule(url);} finally {URL.revokeObjectURL(url);}
          if (ticket !== generation) throw new Error('Grabación cancelada.');
          s.node = new AudioWorkletNode(context, 'stilo-capture');
          s.node.port.onmessage = e => collect(e.data);
        } else {
          s.node = context.createScriptProcessor(2048, 1, 1);
          s.node.onaudioprocess = e => collect(e.inputBuffer.getChannelData(0));
        }
        s.source.connect(s.node); s.node.connect(s.silent); s.silent.connect(context.destination);
        s.timer = setTimeout(() => {s.closed = true; stream.getTracks().forEach(t => t.stop());}, maxSeconds * 1000 + 250);
      } catch (error) {
        await clean(session); session = null;
        stream?.getTracks().forEach(t => t.stop());
        if (context && context.state !== 'closed') await context.close();
        throw error;
      } finally {starting = false;}
    },
    async stop() {
      const s = session; session = null;
      if (!s) return new Uint8Array();
      await clean(s);
      if (s.length < s.rate * 3) throw new Error('Graba entre 3 y 10 segundos.');
      const mono = new Float32Array(s.length); let offset = 0;
      for (const chunk of s.chunks) {mono.set(chunk, offset); offset += chunk.length;}
      // Real resampling preserves duration and pitch for 44.1/48 kHz microphones.
      const Offline = window.OfflineAudioContext || window.webkitOfflineAudioContext;
      const length = Math.min(240000, Math.round(s.length * 24000 / s.rate));
      const offline = new Offline(1, length, 24000);
      const audio = offline.createBuffer(1, mono.length, s.rate); audio.copyToChannel(mono, 0);
      const source = offline.createBufferSource(); source.buffer = audio; source.connect(offline.destination); source.start();
      const rendered = await offline.startRendering();
      return wav24(rendered.getChannelData(0));
    },
    async dispose() {++generation; const s = session; session = null; await clean(s);},
  };
})();
