/// Generates the SwiftCall ringtone — a bright marimba-style ascending phrase.
/// Output: assets/sounds/ringtone.wav  (WAV, 44100 Hz, 16-bit mono)
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

// ── Musical constants ──────────────────────────────────────
const int kSampleRate = 44100;

double noteHz(String name) {
  const base = {
    'C4': 261.63, 'D4': 293.66, 'E4': 329.63, 'F4': 349.23,
    'G4': 392.00, 'A4': 440.00, 'B4': 493.88,
    'C5': 523.25, 'D5': 587.33, 'E5': 659.25, 'F5': 698.46,
    'G5': 783.99, 'A5': 880.00, 'B5': 987.77,
    'C6': 1046.50, 'D6': 1174.66, 'E6': 1318.51,
    'G6': 1567.98, 'A6': 1760.00,
  };
  return base[name] ?? 440.0;
}

// ── ADSR envelope ─────────────────────────────────────────
double adsr(double progress, double a, double d, double s, double r) {
  if (progress < a) return progress / a;
  if (progress < a + d) return 1.0 - (1.0 - s) * (progress - a) / d;
  if (progress > 1.0 - r) return s * ((1.0 - progress) / r);
  return s;
}

// ── Synthesise one note into a buffer ─────────────────────
void addNote(
  Float64List buf,
  String noteName,
  double startSec,
  double durSec, {
  double volume = 0.8,
  double attack = 0.008,
  double decay = 0.06,
  double sustain = 0.55,
  double release = 0.18,
}) {
  final freq = noteHz(noteName);
  final s0 = (startSec * kSampleRate).toInt();
  final len = (durSec * kSampleRate).toInt();
  final end = (s0 + len).clamp(0, buf.length);

  for (var i = s0; i < end; i++) {
    final t = (i - s0) / kSampleRate;
    final progress = (i - s0) / len;
    final env = adsr(progress, attack, decay, sustain, release);

    // Marimba timbre: fundamental + harmonics
    double v = sin(2 * pi * freq * t) * 0.60;
    v += sin(2 * pi * freq * 2 * t) * 0.22;
    v += sin(2 * pi * freq * 3 * t) * 0.10;
    v += sin(2 * pi * freq * 4 * t) * 0.05;
    v += sin(2 * pi * freq * 5 * t) * 0.03;

    buf[i] = (buf[i] + v * env * volume).clamp(-1.0, 1.0);
  }
}

// ── SwiftCall signature phrase ─────────────────────────────
//  Pattern:  C5 E5 G5 | C6 . | A5 G5 E5 | C5 . .
//  Feels like a bright marimba arpeggio with a resolution tail.
Float64List buildRingtone() {
  const totalSec = 2.80;
  final buf = Float64List((totalSec * kSampleRate).toInt());

  // ── Bar 1: quick ascending arpeggio ──
  addNote(buf, 'C5', 0.00, 0.16, volume: 0.75);
  addNote(buf, 'E5', 0.15, 0.16, volume: 0.78);
  addNote(buf, 'G5', 0.30, 0.16, volume: 0.80);

  // ── Bar 2: peak (C6 held) ──
  addNote(buf, 'C6', 0.46, 0.45, volume: 0.90, sustain: 0.65, release: 0.20);

  // ── Brief rest (0.91 – 1.05) ──

  // ── Bar 3: descending melodic tail ──
  addNote(buf, 'A5', 1.05, 0.18, volume: 0.75);
  addNote(buf, 'G5', 1.22, 0.18, volume: 0.72);
  addNote(buf, 'E5', 1.39, 0.16, volume: 0.68);

  // ── Bar 4: root resolution ──
  addNote(buf, 'C5', 1.56, 0.55,
      volume: 0.80, sustain: 0.50, release: 0.28);

  // ── Sparkle accent on the resolution ──
  addNote(buf, 'G5', 1.56, 0.12, volume: 0.30, attack: 0.005, decay: 0.04, sustain: 0.0, release: 0.08);

  // ── Trailing fade (2.11 – 2.80): silence let decay ring out ──

  return buf;
}

// ── WAV file writer ───────────────────────────────────────
void writeWav(Float64List pcm, String path) {
  final numSamples = pcm.length;
  final dataSize = numSamples * 2; // 16-bit mono
  final fileSize = 44 + dataSize;

  final bytes = Uint8List(fileSize);
  final bd = bytes.buffer.asByteData();

  // RIFF header
  bytes.setAll(0,  [0x52, 0x49, 0x46, 0x46]); // "RIFF"
  bd.setUint32(4,  fileSize - 8, Endian.little);
  bytes.setAll(8,  [0x57, 0x41, 0x56, 0x45]); // "WAVE"

  // fmt  chunk
  bytes.setAll(12, [0x66, 0x6D, 0x74, 0x20]); // "fmt "
  bd.setUint32(16, 16, Endian.little);          // chunk size
  bd.setUint16(20, 1,  Endian.little);          // PCM
  bd.setUint16(22, 1,  Endian.little);          // mono
  bd.setUint32(24, kSampleRate, Endian.little);
  bd.setUint32(28, kSampleRate * 2, Endian.little); // byteRate
  bd.setUint16(32, 2,  Endian.little);          // blockAlign
  bd.setUint16(34, 16, Endian.little);          // bitsPerSample

  // data chunk
  bytes.setAll(36, [0x64, 0x61, 0x74, 0x61]); // "data"
  bd.setUint32(40, dataSize, Endian.little);

  for (var i = 0; i < numSamples; i++) {
    final s = (pcm[i] * 32767).round().clamp(-32768, 32767);
    bd.setInt16(44 + i * 2, s, Endian.little);
  }

  File(path).writeAsBytesSync(bytes);
}

// ── Entry point ───────────────────────────────────────────
void main() async {
  const wavPath = 'assets/sounds/ringtone.wav';
  const mp3Path = 'assets/sounds/ringtone.mp3';

  Directory('assets/sounds').createSync(recursive: true);

  print('Synthesising SwiftCall ringtone...');
  final pcm = buildRingtone();

  print('Writing WAV → $wavPath');
  writeWav(pcm, wavPath);
  print('✓ WAV written (${(pcm.length / kSampleRate).toStringAsFixed(2)}s)');

  // Try to convert to MP3 using ffmpeg if available
  print('\nAttempting MP3 conversion via ffmpeg...');
  try {
    final result = await Process.run('ffmpeg', [
      '-y', '-i', wavPath,
      '-codec:a', 'libmp3lame',
      '-b:a', '128k',
      '-ar', '$kSampleRate',
      mp3Path,
    ]);
    if (result.exitCode == 0) {
      print('✓ MP3 written → $mp3Path');
      File(wavPath).deleteSync();
      print('  (WAV removed — using MP3)');
    } else {
      print('  ffmpeg exited ${result.exitCode} — keeping WAV');
      print('  Rename the asset reference to ringtone.wav in code.');
    }
  } on ProcessException {
    print('  ffmpeg not found — keeping WAV.');
    print('  Update incoming_call_screen.dart: ringtone.mp3 → ringtone.wav');
  }
}
