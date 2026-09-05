// Audio is sent directly through the authenticated callable, never shared Storage.
const MAX_WAV_BYTES = 480044;
function decodeVoiceWav(value, HttpsError) {
  const invalid = () => new HttpsError('invalid-argument', 'Graba audio mono WAV de 24 kHz, 16 bits, entre 3 y 10 segundos.');
  if (typeof value !== 'string' || value.length > Math.ceil(MAX_WAV_BYTES / 3) * 4 || !/^[A-Za-z0-9+/]+={0,2}$/.test(value)) throw invalid();
  const bytes = Buffer.from(value, 'base64');
  if (bytes.length < 144044 || bytes.length > MAX_WAV_BYTES) throw invalid();
  if (bytes.toString('ascii', 0, 4) !== 'RIFF' || bytes.toString('ascii', 8, 12) !== 'WAVE' || bytes.toString('ascii', 12, 16) !== 'fmt ' || bytes.toString('ascii', 36, 40) !== 'data') throw invalid();
  if (bytes.readUInt32LE(4) !== bytes.length - 8 || bytes.readUInt32LE(16) !== 16 || bytes.readUInt16LE(20) !== 1 || bytes.readUInt16LE(22) !== 1 || bytes.readUInt32LE(24) !== 24000 || bytes.readUInt32LE(28) !== 48000 || bytes.readUInt16LE(32) !== 2 || bytes.readUInt16LE(34) !== 16 || bytes.readUInt32LE(40) !== bytes.length - 44 || (bytes.length - 44) % 2) throw invalid();
  return bytes;
}
module.exports = { decodeVoiceWav, MAX_WAV_BYTES };
