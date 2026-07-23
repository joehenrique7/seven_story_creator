import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:easy_video_editor/easy_video_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';

import 'models/story_media.dart';

/// Duração máxima de um story em vídeo. Vídeos mais longos passam pelo
/// [StoryTrimmerPage] para o usuário escolher qual janela publicar (o servidor
/// a fatia em clipes de 15s).
const Duration kMaxStoryVideoDuration = Duration(seconds: 60);

/// Duração mínima de um trecho de story em vídeo.
const Duration kMinStoryVideoDuration = Duration(seconds: 15);

/// Tela estilo Instagram para escolher qual trecho de um vídeo longo publicar.
///
/// Mostra o preview do vídeo e uma régua de miniaturas abaixo, com uma janela
/// redimensionável (de [minDuration] a [maxDuration]) que pode ser arrastada.
/// Ao confirmar, recorta fisicamente o vídeo (via `video_compress`) e retorna um
/// [StoryMedia] já cortado. Retorna null se o usuário voltar.
class StoryTrimmerPage extends StatefulWidget {
  const StoryTrimmerPage({
    super.key,
    required this.media,
    this.minDuration = kMinStoryVideoDuration,
    this.maxDuration = kMaxStoryVideoDuration,
  });

  final StoryMedia media;
  final Duration minDuration;
  final Duration maxDuration;

  @override
  State<StoryTrimmerPage> createState() => _StoryTrimmerPageState();
}

class _StoryTrimmerPageState extends State<StoryTrimmerPage> {
  static const int _thumbCount = 10;
  static const double _stripHeight = 56;
  static const double _handleWidth = 16;

  late final VideoPlayerController _preview;
  bool _ready = false;
  bool _exporting = false;

  Duration _total = Duration.zero;
  Duration _start = Duration.zero;
  late Duration _end;

  final List<Uint8List?> _thumbs = List.filled(_thumbCount, null);

  @override
  void initState() {
    super.initState();
    _preview = VideoPlayerController.file(widget.media.file);
    _init();
  }

  Future<void> _init() async {
    await _preview.initialize();
    if (!mounted) return;

    // Duração real decodificada é mais confiável que o metadado do asset.
    _total = _preview.value.duration;
    if (_total <= Duration.zero) {
      _total = widget.media.duration ?? widget.maxDuration;
    }
    _start = Duration.zero;
    _end = _total < widget.maxDuration ? _total : widget.maxDuration;

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
    if (pos >= _end || pos < _start) {
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
        final bytes = await VideoCompress.getByteThumbnail(
          path,
          quality: 50,
          position: positionMs,
        );
        if (!mounted) return;
        if (bytes != null) setState(() => _thumbs[i] = bytes);
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

  // --- Manipulação da janela -------------------------------------------------

  Duration _pxToDuration(double px, double stripWidth) {
    if (stripWidth <= 0) return Duration.zero;
    return Duration(milliseconds: (px / stripWidth * _total.inMilliseconds).round());
  }

  void _move(double dx, double stripWidth) {
    final delta = _pxToDuration(dx, stripWidth);
    var newStart = _start + delta;
    final length = _end - _start;
    if (newStart < Duration.zero) newStart = Duration.zero;
    if (newStart + length > _total) newStart = _total - length;
    setState(() {
      _start = newStart;
      _end = newStart + length;
    });
    _preview.seekTo(_start);
  }

  void _resizeStart(double dx, double stripWidth) {
    var newStart = _start + _pxToDuration(dx, stripWidth);
    if (newStart < Duration.zero) newStart = Duration.zero;
    if (_end - newStart < widget.minDuration) newStart = _end - widget.minDuration;
    if (_end - newStart > widget.maxDuration) newStart = _end - widget.maxDuration;
    setState(() => _start = newStart);
    _preview.seekTo(_start);
  }

  void _resizeEnd(double dx, double stripWidth) {
    var newEnd = _end + _pxToDuration(dx, stripWidth);
    if (newEnd > _total) newEnd = _total;
    if (newEnd - _start < widget.minDuration) newEnd = _start + widget.minDuration;
    if (newEnd - _start > widget.maxDuration) newEnd = _start + widget.maxDuration;
    setState(() => _end = newEnd);
    _preview.seekTo(_start);
  }

  // --- Corte -----------------------------------------------------------------

  Future<void> _confirm() async {
    if (_exporting) return;

    setState(() => _exporting = true);
    await _preview.pause();

    try {
      final totalMs = _total.inMilliseconds;
      var startMs = _start.inMilliseconds;
      // Margem de segurança: o corte nativo exige endTimeMs <= duração real do
      // asset, e arredondamentos podem deixar o fim 1ms além. Recuar ~100ms
      // evita o erro sem impacto perceptível.
      var endMs = _end.inMilliseconds;
      final safeMaxEnd = totalMs - 100;
      if (endMs > safeMaxEnd) endMs = safeMaxEnd;
      if (startMs < 0) startMs = 0;
      if (endMs <= startMs) endMs = startMs + widget.minDuration.inMilliseconds;

      debugPrint(
        '[StoryTrimmer] trim src=${widget.media.file.path} '
        'existe=${widget.media.file.existsSync()} '
        'bytes=${widget.media.file.existsSync() ? widget.media.file.lengthSync() : -1} '
        'totalMs=$totalMs startMs=$startMs endMs=$endMs',
      );

      // Chamada direta na platform interface: o `VideoEditorBuilder.export()`
      // tem um `catch (_) => null` que esconde o motivo real da falha.
      // AVAssetExportSession / Media3 preservam o áudio dentro do timeRange.
      final trimmedPath = await EasyVideoEditorPlatform.instance.trimVideo(
        widget.media.file.path,
        startMs,
        endMs,
      );

      if (!mounted) return;

      if (trimmedPath == null) {
        debugPrint('[StoryTrimmer] trimVideo retornou null (erro engolido no nativo iOS)');
        _failExport('Não foi possível cortar o vídeo. Tente novamente.');
        return;
      }

      debugPrint('[StoryTrimmer] trim ok -> $trimmedPath');

      Navigator.of(context).pop(
        widget.media.copyWith(
          file: File(trimmedPath),
          duration: Duration(milliseconds: endMs - startMs),
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('[StoryTrimmer] PlatformException ${e.code}: ${e.message} | ${e.details}');
      if (!mounted) return;
      _failExport('Não foi possível cortar o vídeo. Tente novamente.');
    } catch (e, s) {
      debugPrint('[StoryTrimmer] falha ao cortar: $e');
      debugPrint('$s');
      if (!mounted) return;
      _failExport('Não foi possível cortar o vídeo. Tente novamente.');
    }
  }

  void _failExport(String message) {
    setState(() => _exporting = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    unawaited(_preview.play());
  }

  // --- UI --------------------------------------------------------------------

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
        final totalMs = _total.inMilliseconds == 0 ? 1 : _total.inMilliseconds;
        final leftPx = (_start.inMilliseconds / totalMs * stripWidth).clamp(0.0, stripWidth);
        final rightPx = (_end.inMilliseconds / totalMs * stripWidth).clamp(0.0, stripWidth);
        final windowWidth = (rightPx - leftPx).clamp(_handleWidth * 2, stripWidth);

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
                      child: _thumbs[i] == null
                          ? Container(color: Colors.white12)
                          : Image.memory(_thumbs[i]!, fit: BoxFit.cover, height: _stripHeight),
                    );
                  }),
                ),
                // Sombreamento fora da janela selecionada.
                Positioned(
                  left: 0,
                  width: leftPx,
                  top: 0,
                  bottom: 0,
                  child: Container(color: Colors.black54),
                ),
                Positioned(
                  left: rightPx,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(color: Colors.black54),
                ),
                // Corpo da janela (arrasta para mover).
                Positioned(
                  left: leftPx,
                  width: windowWidth,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (d) => _move(d.delta.dx, stripWidth),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.symmetric(
                          horizontal: BorderSide(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                  ),
                ),
                // Alça esquerda (redimensiona início).
                Positioned(
                  left: leftPx,
                  width: _handleWidth,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: (d) => _resizeStart(d.delta.dx, stripWidth),
                    child: _handle(left: true),
                  ),
                ),
                // Alça direita (redimensiona fim).
                Positioned(
                  left: rightPx - _handleWidth,
                  width: _handleWidth,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: (d) => _resizeEnd(d.delta.dx, stripWidth),
                    child: _handle(left: false),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _handle({required bool left}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: left
            ? const BorderRadius.horizontal(left: Radius.circular(8))
            : const BorderRadius.horizontal(right: Radius.circular(8)),
      ),
      child: const Center(
        child: Icon(Icons.drag_indicator, color: Colors.black54, size: 16),
      ),
    );
  }

  Widget _buildDurationHint() {
    final windowSecs = (_end - _start).inSeconds;
    final startSecs = _start.inSeconds;
    return Text(
      'Trecho de ${windowSecs}s • a partir de ${startSecs}s',
      style: const TextStyle(color: Colors.white70, fontSize: 13),
    );
  }
}
