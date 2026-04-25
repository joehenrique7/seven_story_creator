import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import '../capture/models/story_media.dart';
import '../export/story_compressor.dart';
import 'models/story_element.dart';
import 'story_editor_controller.dart';
import 'widgets/drawing_layer.dart';
import 'widgets/filter_layer.dart';
import 'widgets/sticker_layer.dart';
import 'widgets/text_editor.dart';
import 'widgets/text_layer.dart';

enum _Tool { none, draw, filter }

/// Full-screen story editor. Push this page and await a [File] (the exported
/// story), or null if the user cancelled.
///
/// Photo stories: all elements and filters are composited into a single WebP.
/// Video stories: the source video is compressed and returned; overlays are
/// not baked in (use [StoryPreviewWidget] for playback with overlays).
class StoryEditorPage extends StatefulWidget {
  const StoryEditorPage({super.key, required this.media});

  final StoryMedia media;

  @override
  State<StoryEditorPage> createState() => _StoryEditorPageState();
}

class _StoryEditorPageState extends State<StoryEditorPage> {
  final _ctrl = StoryEditorController();
  final _compressor = StoryCompressor();
  final _repaintKey = GlobalKey();

  _Tool _tool = _Tool.none;
  Color _drawColor = Colors.white;
  double _brightness = 0.0;
  double _contrast = 1.0;
  double _saturation = 1.0;
  bool _exporting = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: RepaintBoundary(key: _repaintKey, child: _canvas()),
                ),
              ),
            ),
            if (_tool == _Tool.filter) _filterPanel(),
            if (_tool == _Tool.draw) _drawColorBar(),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _canvas() {
    final drawMode = _tool == _Tool.draw;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background media with color filter
        FilterLayer(
          brightness: _brightness,
          contrast: _contrast,
          saturation: _saturation,
          child: _mediaBackground(),
        ),
        // Drawing strokes — renders under stickers/text; captures gestures when active
        DrawingLayer(
          controller: _ctrl,
          isActive: drawMode,
          currentColor: _drawColor,
        ),
        // Sticker layer — blocked while drawing
        IgnorePointer(
          ignoring: drawMode,
          child: StickerLayer(controller: _ctrl),
        ),
        // Text layer — blocked while drawing
        IgnorePointer(
          ignoring: drawMode,
          child: TextLayer(controller: _ctrl, onEditRequest: _pushTextEditor),
        ),
      ],
    );
  }

  Widget _mediaBackground() {
    if (widget.media.type == StoryType.video) {
      return _VideoBackground(file: widget.media.file);
    }
    return Image.file(
      widget.media.file,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }

  // ---------------------------------------------------------------------------
  // Bars

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(null),
          ),
          const Spacer(),
          ListenableBuilder(
            listenable: _ctrl,
            builder: (_, __) => IconButton(
              icon: Icon(
                Icons.undo,
                color: _ctrl.canUndo ? Colors.white : Colors.white30,
              ),
              onPressed: _ctrl.canUndo ? _ctrl.undo : null,
            ),
          ),
          const SizedBox(width: 8),
          _exporting
              ? const SizedBox(
                  width: 80,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _onDone,
                  child: const Text(
                    'Concluir',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToolBtn(
            icon: Icons.text_fields,
            label: 'Texto',
            active: false,
            onTap: _addText,
          ),
          _ToolBtn(
            icon: Icons.emoji_emotions_outlined,
            label: 'Adesivo',
            active: false,
            onTap: _addSticker,
          ),
          _ToolBtn(
            icon: Icons.brush,
            label: 'Desenhar',
            active: _tool == _Tool.draw,
            onTap: () => setState(
              () => _tool = _tool == _Tool.draw ? _Tool.none : _Tool.draw,
            ),
          ),
          _ToolBtn(
            icon: Icons.tune,
            label: 'Filtro',
            active: _tool == _Tool.filter,
            onTap: () => setState(
              () => _tool = _tool == _Tool.filter ? _Tool.none : _Tool.filter,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterPanel() {
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FilterRow(
            icon: Icons.brightness_6,
            value: _brightness,
            min: -1,
            max: 1,
            onChanged: (v) => setState(() => _brightness = v),
          ),
          _FilterRow(
            icon: Icons.contrast,
            value: _contrast,
            min: 0.5,
            max: 2,
            onChanged: (v) => setState(() => _contrast = v),
          ),
          _FilterRow(
            icon: Icons.color_lens_outlined,
            value: _saturation,
            min: 0,
            max: 2,
            onChanged: (v) => setState(() => _saturation = v),
          ),
        ],
      ),
    );
  }

  Widget _drawColorBar() {
    const colors = [
      Colors.white,
      Colors.black,
      Colors.red,
      Colors.yellow,
      Colors.green,
      Colors.blue,
      Colors.pink,
      Colors.orange,
    ];
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: colors.map((c) {
          final selected = _drawColor == c;
          return GestureDetector(
            onTap: () => setState(() => _drawColor = c),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Colors.white : Colors.transparent,
                  width: 2.5,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions

  void _addText() {
    Navigator.of(context).push<void>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (ctx, _, __) => TextEditor(
          onConfirm: (el) {
            _ctrl.addText(el);
            Navigator.of(ctx).pop();
          },
          onCancel: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  void _pushTextEditor(TextElement existing) {
    Navigator.of(context).push<void>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (ctx, _, __) => TextEditor(
          initial: existing,
          onConfirm: (updated) {
            _ctrl.updateElement(existing.id, updated);
            Navigator.of(ctx).pop();
          },
          onCancel: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  void _addSticker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.black87,
      builder: (_) => _StickerPicker(
        onSelected: (emoji) {
          _ctrl.addSticker(
            StickerElement(
              id: const Uuid().v4(),
              position: const Offset(0.35, 0.35),
              emoji: emoji,
            ),
          );
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _onDone() async {
    setState(() => _exporting = true);
    try {
      final file = await _exportCanvas();
      if (mounted) Navigator.of(context).pop(file);
    } catch (_) {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<File> _exportCanvas() async {
    if (widget.media.type == StoryType.photo) {
      // Bake media + filter + all overlays into a single image.
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('RepaintBoundary not mounted');
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw StateError('toByteData returned null');
      final dir = await getTemporaryDirectory();
      final tmp = File('${dir.path}/${const Uuid().v4()}.png')
        ..writeAsBytesSync(byteData.buffer.asUint8List());
      return _compressor.compressImage(tmp);
    } else {
      // Video: return compressed source video.
      // Overlays are not baked — use StoryPreviewWidget for playback with elements.
      return _compressor.compressVideo(widget.media.file);
    }
  }
}

// ---------------------------------------------------------------------------

class _VideoBackground extends StatefulWidget {
  const _VideoBackground({required this.file});
  final File file;

  @override
  State<_VideoBackground> createState() => _VideoBackgroundState();
}

class _VideoBackgroundState extends State<_VideoBackground> {
  late final VideoPlayerController _vc;

  @override
  void initState() {
    super.initState();
    _vc = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _vc
            ..setLooping(true)
            ..play();
        }
      });
  }

  @override
  void dispose() {
    _vc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_vc.value.isInitialized) return const ColoredBox(color: Colors.black);
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _vc.value.size.width,
        height: _vc.value.size.height,
        child: VideoPlayer(_vc),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ToolBtn extends StatelessWidget {
  const _ToolBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: active
                ? BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  )
                : null,
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final IconData icon;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            activeColor: Colors.white,
            inactiveColor: Colors.white30,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _StickerPicker extends StatelessWidget {
  const _StickerPicker({required this.onSelected});

  final void Function(String) onSelected;

  static const _emojis = [
    '😀', '😂', '🥰', '😎', '🤩', '😜', '🤪', '😍',
    '🔥', '⭐', '💫', '✨', '❤️', '💕', '💯', '👍',
    '🏆', '⚽', '🏐', '🎯', '🎉', '🎊', '🎈', '🏅',
    '🌟', '🌈', '🌊', '🌺', '💪', '🙌', '👏', '🤙',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          childAspectRatio: 1,
        ),
        itemCount: _emojis.length,
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => onSelected(_emojis[i]),
          child: Center(
            child: Text(_emojis[i], style: const TextStyle(fontSize: 26)),
          ),
        ),
      ),
    );
  }
}
