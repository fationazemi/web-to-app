# Sketch — Draw. Create. Share.

A lightweight sketching app for **Android and iOS**, built with Flutter from a
single codebase. Based on the "Sketch Drawing App" concept: a warm, paper-like
UI, a fast canvas, and a freemium model.

## Features

- **Canvas** with pen, soft brush, eraser and flood fill
- Nine preset colors plus an HSV custom color picker
- Stroke width slider, undo/redo (100 steps), clear canvas
- **Templates**: blank, grid, ruled, dots
- Import a photo from the gallery and draw on top of it
- Save drawings locally; reopen and keep editing them (strokes stay vector)
- Export / share as PNG (2x, or 4x for Pro)
- **Home** with hero card, recent sketches and templates
- **My Drawings** grid with rename and delete
- **Explore** with a prompt of the day, prompt chips and tips
- **Settings**: light/dark/system theme, default brush size, tips toggle
- **Freemium**: free plan keeps up to 10 sketches; Pro unlocks unlimited
  sketches, custom colors and HD export
- Four starter sketches (Landscape, Flower, Abstract, Portrait) are generated
  on first launch so the library never opens empty
- Duplicate a sketch from its menu

## Tablets and stylus

The app is built for phones **and** tablets (iPad, Android tablets):

- Phones stay in portrait; tablets rotate freely (iPad supports all four
  orientations and Split View).
- Screens 900dp and wider switch from the bottom bar to a navigation rail.
- In landscape on a tablet the canvas fills the height and the tools move to
  a side panel. Grids and lists add columns and keep content centered at a
  readable width.
- **Pressure sensitivity** with Apple Pencil, S Pen and other styluses: press
  harder for thicker lines (can be turned off in Settings).
- **Palm rejection**: a stylus on the screen takes priority over fingers, and
  "Draw with stylus only" ignores touches entirely.
- **Keyboard shortcuts** (iPad keyboards, Chromebooks, desktops):
  `Cmd/Ctrl+Z` undo, `Shift+Cmd/Ctrl+Z` or `Ctrl+Y` redo, `Cmd/Ctrl+S` save,
  `P` pen, `B` brush, `E` eraser, `F` fill, `[` / `]` brush size.

## Design

- Typography: **Inter** for UI, **Caveat** for handwritten accents (canvas
  title, hints, notes). Both are bundled under `assets/fonts/` with their
  licenses.
- Warm paper background, white cards with soft shadows, near-black ink and a
  dusty blue accent.
- Home hero card with a painterly brush stroke drawn procedurally
  (`lib/widgets/brush_stroke.dart`), docked "+" button with a notched bottom
  bar, and light/dark themes.

## Project layout

```
lib/
  main.dart                 entry point, loads settings + repository
  app.dart                  MaterialApp, AppScope (DI via InheritedWidget)
  canvas/
    canvas_controller.dart  tool state, undo/redo history, raster ops
    sketch_painter.dart     stroke rendering and full-drawing compositing
    flood_fill.dart         scanline flood fill on raw RGBA
    template_painter.dart   grid / ruled / dots paper
  data/drawing_repository.dart  on-disk storage (JSON + PNG per drawing)
  data/sample_sketches.dart     procedurally generated starter sketches
  models/                   Stroke, ToolType, CanvasTemplate, DrawingMeta
  screens/                  home shell, home, canvas, drawings, explore, settings
  settings/app_settings.dart    persisted user preferences
  theme/layout.dart             responsive breakpoints (phone / tablet / wide)
  widgets/                  canvas widget, color picker, dialogs, Pro sheet
test/                       unit + widget tests
```

Stroke geometry is stored in normalized `0..1` coordinates, so drawings render
identically on every screen size. Eraser strokes use `BlendMode.clear` inside a
layer so they remove ink but never the paper or template.

## Run

```bash
cd sketch_app
flutter pub get
flutter run            # pick an Android emulator / iOS simulator / device
```

## Test and lint

```bash
flutter analyze
flutter test
```

## Build

```bash
flutter build apk --release        # Android
flutter build appbundle --release  # Play Store
flutter build ipa --release        # iOS (requires macOS + Xcode + signing)
```

## Next steps

- Wire real billing (`in_app_purchase` or RevenueCat) into `AppSettings.setPro`
- Cloud backup / sync
- Layers and selection tools
- Pressure sensitivity for stylus input
