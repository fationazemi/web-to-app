# Sketch — Draw. Create. Share.

A lightweight sketching app for **Android and iOS**, built with Flutter from a
single codebase. Based on the "Sketch Drawing App" concept: a warm, paper-like
UI, a fast canvas, and a freemium model.

## Features

- **Canvas** with pen, soft brush, eraser and flood fill
- **Layers**: add, reorder, hide, rename, set opacity, duplicate, merge down
  (2 layers free, 10 with Pro); the eraser only erases the active layer
- **Zoom and pan**: pinch with two fingers, mouse wheel or trackpad; a quick
  two-finger tap undoes; "fit" button and `Cmd/Ctrl+0` reset the view
- **Mirror drawing**: left/right, top/bottom or four-way symmetry with guides
- Nine preset colors plus an HSV custom color picker; seven paper colors
  including dark paper
- Stroke width slider, undo/redo (100 steps), clear layer
- **Templates**: blank, grid, ruled, dots
- Import a photo from the gallery and draw on top of it
- **Replay** the drawing stroke by stroke, and export a **time-lapse GIF**
- Save drawings locally; reopen and keep editing them (strokes stay vector)
- Export / share as PNG (2x, or 4x for Pro)
- **Backup & restore**: move the whole library between devices as one
  `.sketchbackup` file (AirDrop, Drive, email, cable)
- **Home** with hero card, recent sketches and templates (animated entrance)
- **My Drawings** grid with rename, duplicate and delete
- **Explore** with a prompt of the day, prompt chips and tips
- **Settings**: light/dark/system theme, default brush size, stylus options,
  backup, tips toggle
- **Sketch Pro** through App Store / Google Play billing (`in_app_purchase`):
  unlimited sketches, 10 layers, custom colors, time-lapse export, HD export
- Four starter sketches (Landscape, Flower, Abstract, Portrait) are generated
  on first launch so the library never opens empty
- App icon and native splash screen generated from the same brush-stroke art

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
  `Cmd/Ctrl+0` reset zoom, `P` pen, `B` brush, `E` eraser, `F` fill,
  `L` layers, `M` mirror, `[` / `]` brush size.

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
  billing/billing_service.dart  App Store / Play billing for Pro
  canvas/
    canvas_controller.dart  tool state, layers, symmetry, undo/redo, raster ops
    sketch_painter.dart     stroke rendering and layer compositing
    flood_fill.dart         scanline flood fill on raw RGBA
    template_painter.dart   grid / ruled / dots paper
    timelapse.dart          progressive snapshots + animated GIF encoder
  data/drawing_repository.dart  on-disk storage (layers JSON + PNG per drawing)
  data/backup_service.dart      zip backup / restore of the whole library
  data/sample_sketches.dart     procedurally generated starter sketches
  models/                   Stroke, Layer, ToolType, CanvasTemplate, DrawingMeta
  screens/                  home shell, home, canvas, drawings, explore, settings
  settings/app_settings.dart    persisted user preferences
  theme/layout.dart             responsive breakpoints (phone / tablet / wide)
  widgets/                  canvas (zoom/pan/stylus), layers panel, replay,
                            color picker, dialogs, Pro sheet
test/                       unit + widget tests
tool/render_icon_test.dart  renders assets/icon/*.png (icon + splash art)
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

## Icon and splash

The artwork is rendered by `tool/render_icon_test.dart`; the platform assets
are generated from it:

```bash
flutter test tool/render_icon_test.dart
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## Store setup for Sketch Pro

`BillingService` expects two non-consumable / subscription products:

| Product id            | Type         |
|-----------------------|--------------|
| `sketch_pro_monthly`  | subscription |
| `sketch_pro_lifetime` | one-time     |

Create them in App Store Connect and Google Play Console, then test with a
sandbox account. Purchases are currently verified on-device; add server-side
receipt validation before launch. Debug builds show an "Activate Pro" button
for testing.

## Next steps

- Cloud sync (an account + backend such as Supabase or Firebase); the
  backup file format is the natural sync payload
- Selection / transform tools (move, scale, rotate part of a layer)
- Custom brushes and textures
