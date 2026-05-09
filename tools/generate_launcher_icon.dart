// Generates SwiftCall launcher icons at all Android mipmap densities.
// Run from project root: dart run tools/generate_launcher_icon.dart
library;

import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

const int _n = 1024;

// Design constants (all in 1024-px source units)
const double _cx = _n / 2.0;
const double _cy = _n / 2.0;
const double _bgCornerR  = _n * 0.22;   // icon rounded-rect corner
const double _badgeX     = _cx + _n * 0.295;
const double _badgeY     = _cy - _n * 0.275;
const double _badgeR     = _n * 0.132;
const double _boltScale  = 13.5;        // px per bolt-unit

void main() {
  print('Generating SwiftCall launcher icon…');
  final source = _buildIcon();

  Directory('assets/icon').createSync(recursive: true);
  File('assets/icon/icon.png').writeAsBytesSync(img.encodePng(source));
  print('  Source  →  assets/icon/icon.png');

  const densities = {
    'mdpi':    48,
    'hdpi':    72,
    'xhdpi':   96,
    'xxhdpi':  144,
    'xxxhdpi': 192,
  };

  for (final e in densities.entries) {
    final out = img.copyResize(
      source,
      width: e.value,
      height: e.value,
      interpolation: img.Interpolation.cubic,
    );
    File('android/app/src/main/res/mipmap-${e.key}/ic_launcher.png')
        .writeAsBytesSync(img.encodePng(out));
    print('  ✓  ${e.key.padRight(9)} ${e.value}×${e.value}');
  }
  print('Done.');
}

// ── Build 1024×1024 source ────────────────────────────────────────────────────
img.Image _buildIcon() {
  final image = img.Image(width: _n, height: _n);
  for (var y = 0; y < _n; y++) {
    for (var x = 0; x < _n; x++) {
      image.setPixel(x, y, _pixel(x, y));
    }
  }
  return image;
}

img.Color _pixel(int x, int y) {
  // ① Rounded-square clip (transparent outside)
  if (!_inRR(x + 0.5, y + 0.5, _cx, _cy, _n.toDouble(), _n.toDouble(), _bgCornerR)) {
    return img.ColorRgba8(0, 0, 0, 0);
  }

  // ② Gold badge + white bolt (on top of everything)
  final inBadge = _inCircle(x, y, _badgeX, _badgeY, _badgeR);
  if (inBadge) {
    return _inBolt(x, y, _badgeX, _badgeY, _boltScale)
        ? img.ColorRgba8(255, 255, 255, 255)
        : img.ColorRgba8(255, 208, 96, 255);
  }

  // ③ White phone receiver
  if (_inPhone(x, y)) return img.ColorRgba8(255, 255, 255, 255);

  // ④ Purple-indigo diagonal gradient background
  final t = ((x + y) / (2.0 * _n)).clamp(0.0, 1.0);
  return img.ColorRgba8(_li(108, 50, t), _li(99, 38, t), _li(255, 178, t), 255);
}

// ── Phone receiver: earpiece + handle + mouthpiece (rotated −40°) ────────────
bool _inPhone(int x, int y) {
  const angle  = -0.698;  // −40°
  const sin40  = 0.6428;
  const cos40  = 0.7660;
  final d = _n * 0.19;

  final ex = _cx + sin40 * d;
  final ey = _cy - cos40 * d;
  final mx = _cx - sin40 * d;
  final my = _cy + cos40 * d;

  final ew = _n * 0.22, eh = _n * 0.14, er = _n * 0.07;
  final hw = _n * 0.11, hh = _n * 0.40, hr = _n * 0.055;

  return _inRotRR(x, y, ex, ey, ew, eh, er, angle) ||
         _inRotRR(x, y, _cx, _cy, hw, hh, hr, angle) ||
         _inRotRR(x, y, mx, my, ew, eh, er, angle);
}

// ── Lightning bolt via point-in-polygon ───────────────────────────────────────
bool _inBolt(int px, int py, double cx, double cy, double scale) {
  final x = (px - cx) / scale;
  final y = (py - cy) / scale;
  const pts = [
    [2.0, -7.0], [6.5, -7.0], [1.0, -0.5], [5.0, -0.5],
    [-2.5, 7.0], [0.0, 1.0], [-4.0, 1.0],
  ];
  var inside = false;
  var j = pts.length - 1;
  for (var i = 0; i < pts.length; i++) {
    final xi = pts[i][0], yi = pts[i][1];
    final xj = pts[j][0], yj = pts[j][1];
    if ((yi > y) != (yj > y) &&
        x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
      inside = !inside;
    }
    j = i;
  }
  return inside;
}

// ── Primitives ────────────────────────────────────────────────────────────────
bool _inCircle(int px, int py, double cx, double cy, double r) {
  final dx = px - cx, dy = py - cy;
  return dx * dx + dy * dy <= r * r;
}

bool _inRotRR(int px, int py, double cx, double cy,
    double w, double h, double r, double angle) {
  final dx = px - cx, dy = py - cy;
  final c = math.cos(-angle), s = math.sin(-angle);
  return _inRR(dx * c - dy * s, dx * s + dy * c, 0, 0, w, h, r);
}

bool _inRR(double px, double py, double cx, double cy,
    double w, double h, double r) {
  final ax = (px - cx).abs(), ay = (py - cy).abs();
  if (ax > w / 2 || ay > h / 2) return false;
  final ix = ax - (w / 2 - r), iy = ay - (h / 2 - r);
  if (ix <= 0 || iy <= 0) return true;
  return ix * ix + iy * iy <= r * r;
}

int _li(int a, int b, double t) => (a + (b - a) * t).round().clamp(0, 255);
