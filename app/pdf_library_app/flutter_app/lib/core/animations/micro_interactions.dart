import 'package:flutter/material.dart';
import 'animation_constants.dart';

class FavoriteBurst extends StatefulWidget {
  const FavoriteBurst({super.key, required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;
  @override State<FavoriteBurst> createState() => _FavoriteBurstState();
}
class _FavoriteBurstState extends State<FavoriteBurst> {
  bool _burst = false;
  void _tap() { setState(() => _burst = true); widget.onTap(); Future.delayed(BookVerseMotion.standard, () { if (mounted) setState(() => _burst = false); }); }
  @override Widget build(BuildContext context) => Stack(alignment: Alignment.center, children: [
    AnimatedScale(scale: _burst ? 1.28 : 1, duration: BookVerseMotion.micro, curve: BookVerseMotion.springCurve, child: IconButton(onPressed: _tap, icon: Icon(widget.active ? Icons.favorite : Icons.favorite_border), color: widget.active ? Colors.redAccent : Colors.white)),
    if (_burst) const IgnorePointer(child: Text('✦', style: TextStyle(color: Colors.white, fontSize: 22))),
  ]);
}
