import 'package:flutter/animation.dart';

abstract final class BookVerseMotion {
  static const Duration micro = Duration(milliseconds: 160);
  static const Duration standard = Duration(milliseconds: 320);
  static const Duration content = Duration(milliseconds: 520);
  static const Duration immersive = Duration(milliseconds: 900);
  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve emphasizedCurve = Curves.easeInOutCubic;
  static const Curve springCurve = Curves.easeOutBack;
}
