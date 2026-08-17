# BookVerse — Animation System

BookVerse uses a centralized motion vocabulary instead of isolated `fadeIn()` calls.

## Implemented foundation

- Micro interactions: 160 ms
- Standard transitions: 320 ms
- Content transitions: 520 ms
- Immersive transitions: 900 ms
- Cover tilt / depth interaction
- Favorite burst
- Hero cover continuity
- Book opening overlay
- Immersive reader mode
- Page-turn visual feedback
- Web swipe navigation
- Web keyboard navigation
- Reduced-motion accessibility
- Loading animation instead of a static spinner on the app startup gate

## Architecture

`flutter_app/lib/core/animations/`

- `animation_constants.dart`
- `book_animations.dart`
- `page_transitions.dart`
- `micro_interactions.dart`

The remaining PDF-engine-specific physical page curl is deliberately isolated from the UI motion system because the Syncfusion PDF viewer owns the rendered page surface. It can be replaced later by a page-by-page renderer without rewriting the rest of BookVerse.
