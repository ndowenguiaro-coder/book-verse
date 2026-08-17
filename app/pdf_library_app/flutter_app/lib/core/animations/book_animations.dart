import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'animation_constants.dart';

class BookTilt extends StatefulWidget {
  const BookTilt({super.key, required this.child, this.onTap, this.maxTilt = 0.045});
  final Widget child;
  final VoidCallback? onTap;
  final double maxTilt;
  @override State<BookTilt> createState() => _BookTiltState();
}
class _BookTiltState extends State<BookTilt> {
  Offset _pointer = Offset.zero;
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (e) => setState(() => _pointer = e.localPosition),
      onExit: (_) => setState(() => _pointer = Offset.zero),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: LayoutBuilder(builder: (context, c) {
          final cx = c.maxWidth / 2;
          final cy = c.maxHeight / 2;
          final dx = cx == 0 ? 0 : ((_pointer.dx - cx) / cx).clamp(-1.0, 1.0);
          final dy = cy == 0 ? 0 : ((_pointer.dy - cy) / cy).clamp(-1.0, 1.0);
          return AnimatedContainer(
            duration: BookVerseMotion.micro,
            curve: BookVerseMotion.standardCurve,
            transformAlignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateX(-dy * widget.maxTilt)
              ..rotateY(dx * widget.maxTilt)
              ..scale(_pressed ? 0.97 : 1.0),
            child: widget.child,
          );
        }),
      ),
    );
  }
}

class BookOpeningOverlay extends StatefulWidget {
  const BookOpeningOverlay({super.key, required this.cover, required this.child, this.duration = BookVerseMotion.immersive});
  final Widget cover;
  final Widget child;
  final Duration duration;
  @override State<BookOpeningOverlay> createState() => _BookOpeningOverlayState();
}
class _BookOpeningOverlayState extends State<BookOpeningOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration)..forward();
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return Stack(children: [
      widget.child,
      IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            final t = Curves.easeInOutCubic.transform(_controller.value);
            final angle = math.pi * 0.5 * t;
            final scale = 1.0 + 0.10 * t;
            final opacity = 1.0 - t;
            return Opacity(
              opacity: opacity,
              child: ColoredBox(
                color: const Color(0xFF0B1020),
                child: Center(
                  child: Transform(
                    alignment: Alignment.centerLeft,
                    transform: Matrix4.identity()..setEntry(3, 2, 0.0018)..rotateY(angle)..scale(scale),
                    child: widget.cover,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class PageCurlTransition extends StatelessWidget {
  const PageCurlTransition({super.key, required this.progress, required this.current, required this.next, this.forward = true});
  final double progress;
  final Widget current;
  final Widget next;
  final bool forward;
  @override Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    return ClipRect(
      child: Stack(children: [
        Positioned.fill(child: next),
        Align(
          alignment: forward ? Alignment.centerLeft : Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: (1 - p).clamp(0.0, 1.0),
            alignment: forward ? Alignment.centerLeft : Alignment.centerRight,
            child: Transform(
              alignment: forward ? Alignment.centerRight : Alignment.centerLeft,
              transform: Matrix4.identity()..setEntry(3, 2, 0.002)..rotateY((forward ? -1 : 1) * math.pi * p),
              child: DecoratedBox(
                decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 22 * p, offset: Offset((forward ? 1 : -1) * 10 * p, 0))]),
                child: current,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
