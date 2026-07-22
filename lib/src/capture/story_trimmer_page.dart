import 'dart:async';
import 'dart:io';

import 'package:easy_video_editor/easy_video_editor.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import 'models/story_media.dart';

/// Duração máxima de um story em vídeo. Vídeos mais longos passam pelo
/// [StoryTrimmerPage] para o usuário escolher qual janela de [maxDuration]
/// segundos publicar (o servidor a fatia em clipes de 15s).
const Duration kMaxStoryVideoDuration = Duration(seconds: 60);

/// Tela estilo Instagram para escolher qual trecho de um vídeo longo publicar.
///
/// Mostra o preview do vídeo e uma régua de miniaturas abaixo, com uma janela
/// arrastável de [maxDuration] de largura. Ao confirmar, recorta fisicamente o
/// vídeo (via `easy_video_editor`, sem ffmpeg) e retorna um [StoryMedia] já
/// cortado. Retorna null se o usuário voltar.
class StoryTrimmerPage extends StatefulWidget {
  const StoryTrimmerPage({
    super.key,
    required this.media,
    this.maxDuration = kMaxStoryVideoDuration,
  });

  final StoryMedia media;
  final Duration maxDuration;

  @override
  State<StoryTrimmerPage> createState() => _StoryTrimmerPageState();
}

class _StoryTrimmerPageState extends State<StoryTrimmerPage> {
  static const int _thumbCount = 10;
  static const double _stripHeight = 56;
  static const double _handleWidth = 12;

  late final VideoPlayerController _preview;
  bool _ready = false;
  bool _exporting = false;

  Duration _total = Duration.zero;
  late Duration _window;
  Duration _start = Duration.zero;

  final List<File?> _thumbs = List.filled(_thumbCount, null);

  @override
  void initState() {
    super.initState();
    _preview = VideoPlayerController.file(widget.media.file);
    _init();
  }

  Future<void> _init() async {
    await _preview.initialize();
    if (!mounted) return;

    _total = widget.media.duration ?? _preview.value.duration;
    _window = _total < widget.maxDuration ? _total : widget.maxDuration;

    await _preview.setLooping(false);
    await _preview.setVolume(1);
    _preview.addListener(_loopWithinWindow);

    setState(() => _ready = true);
    unawaited(_preview.play());
    unawaited(_generateThumbs());
  }

  /// Mantém o preview reproduzindo apenas dentro da janela selecionada.
  void _loopWithinWindow() {
    if (!_ready || _exporting) return;
    final pos = _preview.value.position;
    final end = _start + _window;
    if (pos >= end || pos < _start) {
      _preview.seekTo(_start);
    }
  }

  Future<void> _generateThumbs() async {
    final path = widget.media.file.path;
    final totalMs = _total.inMilliseconds;
    if (totalMs <= 0) return;

    for (var i = 0; i < _thumbCount; i++) {
      final positionMs = (totalMs * i / _thumbCount).round();
      try {
        final out = await VideoEditorBuilder(videoPath: path).generateThumbnail(
          positionMs: positionMs,
          quality: 60,
          width: 120,
          height: 200,
        );
        if (!mounted) return;
        if (out != null) setState(() => _thumbs[i] = File(out));
      } catch (_) {
        // Miniatura é decorativa; ignora falhas pontuais.
      }
    }
  }

  @override
  void dispose() {
    _preview.removeListener(_loopWithinWindow);
    _preview.dispose();
    super.dispose();
  }

  void _onWindowDrag(double dx, double stripWidth) {
    if (_total <= _window) return;
    final selectable = _total - _window;
    final deltaMs = (dx / stripWidth) * _total.inMilliseconds;
    final nextMs = (_start.inMilliseconds + deltaMs)
        .clamp(0, selectable.inMilliseconds)
        .round();
    setState(() => _start = Duration(milliseconds: nextMs));
    _preview.seekTo(_start);
  }

  Future<void> _confirm() async {
    if (_exporting) return;

    // Não precisa cortar se o vídeo inteiro já cabe na janela.
    if (_total <= widget.maxDuration) {
      if (mounted) Navigator.of(context).pop(widget.media);
      return;
    }

    setState(() => _exporting = true);
    await _preview.pause();

    try {
      final dir = await getTemporaryDirectory();
      final outPath = '${dir.path}/${const Uuid().v4()}.mp4';
      final start = _start.inMilliseconds;
      final end = (_start + _window).inMilliseconds;

      final trimmed = await VideoEditorBuilder(videoPath: widget.media.file.path)
          .trim(startTimeMs: start, endTimeMs: end)
          .export(outputPath: outPath);

      if (!mounted) return;

      if (trimmed == null) {
        setState(() => _exporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível cortar o vídeo. Tente novamente.')),
        );
        unawaited(_preview.play());
        return;
      }

      Navigator.of(context).pop(
        widget.media.copyWith(file: File(trimmed), duration: _window),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _exporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível cortar o vídeo. Tente novamente.')),
      );
      unawaited(_preview.play());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: !_ready
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Column(
                children: [
                  _buildTopBar(),
                  Expanded(child: _buildPreview()),
                  _buildStrip(),
                  const SizedBox(height: 12),
                  _buildDurationHint(),
                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: _exporting ? null : () => Navigator.of(context).pop(null),
            child: const Text('Voltar', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
          TextButton(
            onPressed: _exporting ? null : _confirm,
            child: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Avançar',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return GestureDetector(
      onTap: () {
        _preview.value.isPlaying ? _preview.pause() : _preview.play();
        setState(() {});
      },
      child: Center(
        child: AspectRatio(
          aspectRatio: _preview.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_preview),
              if (!_preview.value.isPlaying)
                const Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 64),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStrip() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stripWidth = constraints.maxWidth - 32;
        final windowFraction =
            _total.inMilliseconds == 0 ? 1.0 : _window.inMilliseconds / _total.inMilliseconds;
        final windowWidth =
            (stripWidth * windowFraction).clamp(_handleWidth * 2, stripWidth).toDouble();
        final startFraction =
            _total.inMilliseconds == 0 ? 0.0 : _start.inMilliseconds / _total.inMilliseconds;
        final windowLeft = stripWidth * startFraction;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: _stripHeight,
            width: stripWidth,
            child: Stack(
              children: [
                Row(
                  children: List.generate(_thumbCount, (i) {
                    return Expanded(
                      child: ClipRRect(
                        borderRadius: i == 0
                            ? const BorderRadius.horizontal(left: Radius.circular(8))
                            : i == _thumbCount - 1
                                ? const BorderRadius.horizontal(right: Radius.circular(8))
                                : BorderRadius.zero,
                        child: _thumbs[i] == null
                            ? Container(color: Colors.white12)
                            : Image.file(_thumbs[i]!, fit: BoxFit.cover, height: _stripHeight),
                      ),
                    );
                  }),
                ),
                // Sombreamento fora da janela selecionada.
                Positioned(
                  left: 0,
                  width: windowLeft,
                  top: 0,
                  bottom: 0,
                  child: Container(color: Colors.black54),
                ),
                Positioned(
                  left: windowLeft + windowWidth,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(color: Colors.black54),
                ),
                // Janela arrastável.
                Positioned(
                  left: windowLeft,
                  width: windowWidth,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (d) => _onWindowDrag(d.delta.dx, stripWidth),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _handle(),
                          _handle(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _handle() {
    return Container(
      width: _handleWidth,
      decoration: const BoxDecoration(color: Colors.white),
      child: const Center(
        child: Icon(Icons.drag_indicator, color: Colors.black54, size: 14),
      ),
    );
  }

  Widget _buildDurationHint() {
    final windowSecs = _window.inSeconds;
    final startSecs = _start.inSeconds;
    return Text(
      'Trecho de ${windowSecs}s • a partir de ${startSecs}s',
      style: const TextStyle(color: Colors.white70, fontSize: 13),
    );
  }
}
