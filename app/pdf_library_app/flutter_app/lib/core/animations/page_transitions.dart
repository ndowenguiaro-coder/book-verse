import 'package:flutter/material.dart';
import 'animation_constants.dart';

class BookVersePageRoute<T> extends PageRouteBuilder<T> {
  BookVersePageRoute({required Widget page}) : super(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: BookVerseMotion.content,
    reverseTransitionDuration: BookVerseMotion.standard,
    transitionsBuilder: (_, animation, secondary, child) {
      final curved = CurvedAnimation(parent: animation, curve: BookVerseMotion.emphasizedCurve);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0.035, 0), end: Offset.zero).animate(curved),
          child: ScaleTransition(scale: Tween(begin: 0.985, end: 1.0).animate(curved), child: child),
        ),
      );
    },
  );
}
