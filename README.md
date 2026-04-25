# seven_story_creator

Flutter package for creating Instagram-style stories: capture or pick media from gallery, edit with text, stickers and freehand drawing, apply color filters, preview, and export to a compressed file.

## Features

- **Capture** — fullscreen camera with photo and video (hold to record, progress bar, flash control, front/back toggle)
- **Gallery picker** — browse and select from device gallery
- **Editor** — layered canvas with:
  - Text elements (color, font size, font family, shadow, alignment)
  - Emoji stickers
  - Freehand drawing strokes (color, width, solid/dashed style)
  - Drag / pinch-to-scale / rotate on every element
  - 30-step undo history
- **Filters** — brightness, contrast and saturation via `ColorFiltered`
- **Preview** — read-only `StoryPreviewWidget` (9:16 aspect ratio, auto-plays video)
- **Export** — compresses to `.webp` (photo) or `.mp4` (video) and writes a JSON sidecar with all elements and filter values

## Getting started

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  seven_story_creator:
    path: ../seven_story_creator   # adjust to your path or pub server
```

### Permissions

#### Android — `android/app/src/main/AndroidManifest.xml`
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

#### iOS — `ios/Runner/Info.plist`
```xml
<key>NSCameraUsageDescription</key>
<string>Camera is used to capture stories.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Microphone is used to record video stories.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access is used to pick media for stories.</string>
```

## Usage

### 1 — Capture media

Push `StoryCapturePage` and await the result. Returns `null` if the user cancels.

```dart
import 'package:seven_story_creator/seven_story_creator.dart';

final StoryMedia? media = await Navigator.of(context).push<StoryMedia>(
  MaterialPageRoute(builder: (_) => const StoryCapturePage()),
);

if (media == null) return; // user cancelled
```

### 2 — Edit elements with `StoryEditorController`

```dart
final editorController = StoryEditorController();

// Add a text element
editorController.addText(
  TextElement(
    id: const Uuid().v4(),
    position: const Offset(0.3, 0.4), // fractional 0.0–1.0
    text: 'Hello world!',
    color: Colors.white,
    fontSize: 28,
    hasShadow: true,
    align: TextAlign.center,
  ),
);

// Add an emoji sticker
editorController.addSticker(
  StickerElement(
    id: const Uuid().v4(),
    position: const Offset(0.5, 0.6),
    emoji: '🔥',
    size: 48,
  ),
);

// Add a freehand drawing stroke
editorController.addDrawingStroke(
  DrawingElement(
    id: const Uuid().v4(),
    points: [
      const Offset(0.1, 0.2),
      const Offset(0.2, 0.3),
      const Offset(0.3, 0.2),
    ],
    color: Colors.red,
    strokeWidth: 6,
    style: StrokeStyle.solid,
  ),
);

// Undo last action
editorController.undo();
```

### 3 — Preview the story

```dart
StoryPreviewWidget(
  media: media,
  elements: editorController.elements,
  brightness: 0.1,   // -1.0 to 1.0
  contrast: 1.2,     // 0.0+
  saturation: 1.1,   // 0.0+
)
```

### 4 — Export

```dart
final exportService = StoryExportService();

final File outputFile = await exportService.export(
  media: media,
  elements: editorController.elements,
  brightness: 0.1,
  contrast: 1.2,
  saturation: 1.1,
);

print('Saved to: ${outputFile.path}');
// A JSON sidecar is also written alongside the file.
```

### 5 — Reload a saved story

```dart
import 'dart:io';

final sidecarFile = File('/path/to/story_id.json');

final (:StoryMedia media, :List<StoryElement> elements) =
    await exportService.loadFromSidecar(sidecarFile);
```

### Full example — end to end

```dart
class CreateStoryFlow extends StatelessWidget {
  const CreateStoryFlow({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _run(context),
      child: const Text('Create story'),
    );
  }

  Future<void> _run(BuildContext context) async {
    // Step 1 — capture
    final media = await Navigator.of(context).push<StoryMedia>(
      MaterialPageRoute(builder: (_) => const StoryCapturePage()),
    );
    if (media == null || !context.mounted) return;

    // Step 2 — build elements
    final controller = StoryEditorController()
      ..addText(
        TextElement(
          id: const Uuid().v4(),
          position: const Offset(0.25, 0.1),
          text: 'My first story',
          fontSize: 32,
          hasShadow: true,
        ),
      );

    // Step 3 — export
    final file = await StoryExportService().export(
      media: media,
      elements: controller.elements,
    );

    debugPrint('Story exported to ${file.path}');
  }
}
```

## API overview

| Class | Description |
|---|---|
| `StoryCapturePage` | Fullscreen capture page; returns `StoryMedia?` |
| `StoryMedia` | Holds the captured `File`, `StoryType`, optional duration and thumbnail |
| `StoryEditorController` | `ChangeNotifier` that manages elements and undo history |
| `TextElement` | Text layer with color, font, shadow and alignment |
| `StickerElement` | Emoji sticker layer |
| `DrawingElement` | Freehand stroke layer |
| `StoryPreviewWidget` | Read-only 9:16 preview with filter support |
| `StoryExportService` | Compresses and saves story + JSON sidecar |

## Dependencies

| Package | Purpose |
|---|---|
| `camerawesome` | Camera capture |
| `photo_manager` | Gallery access |
| `video_player` | Video preview |
| `ffmpeg_kit_flutter_new` | Video compression |
| `flutter_image_compress` | Image compression to WebP |
| `path_provider` | Output directory |
| `uuid` | Element ID generation |
