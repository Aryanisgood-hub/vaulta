import 'package:flutter/material.dart';

import '../../core/constants/app_info.dart';

/// Intro animation shown when the app opens, then fades away into the app.
///
///  0.0s  the V mark (same picture as the native splash screen, so there is no jump)
///  0.4s  the V slides up
///  0.6s  "Vaulta" fades in, then the tagline
///  2.0s  everything fades out (tap anywhere to skip)
///
/// The real app (sign-in / home) is built underneath from the start, so it is
/// ready the moment the splash is gone.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});
  final Widget child;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> with TickerProviderStateMixin {
  static const navy = Color(0xFF2A3747);

  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
  late final AnimationController _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  late final Animation<double> _opacity = Tween<double>(begin: 1, end: 0).animate(CurvedAnimation(parent: _fade, curve: Curves.easeInOut));
  late final Animation<double> _zoom = Tween<double>(begin: 1, end: 1.07).animate(CurvedAnimation(parent: _fade, curve: Curves.easeIn));

  bool _started = false;
  bool _gone = false;
  bool _fading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Respect "remove animations" in the phone's accessibility settings.
    if (MediaQuery.of(context).disableAnimations) {
      _gone = true;
    } else {
      _intro.forward().whenComplete(_startFade);
    }
  }

  void _startFade() {
    if (_fading || !mounted) return;
    _fading = true;
    _intro.stop();
    _fade.forward().whenComplete(() {
      if (mounted) setState(() => _gone = true);
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The child stays at index 0 in the Stack, so its state survives when the splash is removed.
    return Stack(children: [
      widget.child,
      if (!_gone)
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _startFade,
            child: FadeTransition(
              opacity: _opacity,
              child: ScaleTransition(
                scale: _zoom,
                child: AnimatedBuilder(animation: _intro, builder: (context, _) => _frame(_intro.value)),
              ),
            ),
          ),
        ),
    ]);
  }

  Widget _frame(double t) {
    double seg(double a, double b, [Curve c = Curves.easeOut]) => c.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

    final pop = seg(0.00, 0.12);                       // tiny scale-in of the V
    final rise = seg(0.18, 0.50, Curves.easeInOutCubic); // V slides up
    final word = seg(0.30, 0.60);                      // "Vaulta"
    final tag = seg(0.52, 0.80);                       // tagline

    // Material gives the Text widgets a proper default style (no yellow underline).
    return Material(
      color: navy,
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _PatternPainter(seg(0.0, 0.35)))),
        Center(
          child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
            Transform.translate(
              offset: Offset(0, -56 * rise),
              child: Transform.scale(scale: 0.94 + 0.06 * pop, child: Image.asset('assets/images/vaulta_mark.png', width: 128)),
            ),
            Opacity(
              opacity: word,
              child: Transform.translate(
                offset: Offset(0, 36 + 8 * (1 - word)),
                child: Image.asset('assets/images/vaulta_wordmark.png', width: 190),
              ),
            ),
            Opacity(
              opacity: tag,
              child: Transform.translate(
                offset: Offset(0, 88 + 8 * (1 - tag)),
                child: Text(
                  AppInfo.tagline,
                  style: TextStyle(color: Colors.white.withAlpha(215), fontSize: 16, letterSpacing: 0.4, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Very faint chevron pattern behind the logo.
class _PatternPainter extends CustomPainter {
  const _PatternPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withAlpha((15 * progress).round());
    const w = 110.0, h = 70.0;
    var row = 0;
    for (double y = -h; y < size.height + h; y += h * 1.5) {
      final shift = row.isEven ? 0.0 : w / 2;
      for (double x = -w + shift; x < size.width + w; x += w) {
        canvas.drawPath(
          Path()
            ..moveTo(x, y)
            ..lineTo(x + w / 2, y + h)
            ..lineTo(x + w, y),
          paint,
        );
      }
      row++;
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) => old.progress != progress;
}
