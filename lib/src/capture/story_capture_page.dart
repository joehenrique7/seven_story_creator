import 'dart:async';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import 'models/story_media.dart';
import 'services/gallery_service.dart';
import 'story_camera_widget.dart';
import 'story_capture_controller.dart';

class StoryCapturePage extends StatefulWidget {
  const StoryCapturePage({super.key});

  /// Push this page and await a [StoryMedia], or null if user cancelled.
  @override
  State<StoryCapturePage> createState() => _StoryCapturePageState();
}

class _StoryCapturePageState extends State<StoryCapturePage> {
  late final StoryCaptureController _controller;
  final GalleryService _gallery = GalleryService();

  @override
  void initState() {
    super.initState();
    _controller = StoryCaptureController(
      onMaxDurationReached: () {
        // stopRecording is already called by the controller; pop result.
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          StoryCameraWidget(controller: _controller),
          SafeArea(child: _buildOverlay()),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    return Column(
      children: [
        _buildTopBar(),
        const Spacer(),
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => _buildProgressBar(),
        ),
        const SizedBox(height: 8),
        _buildBottomBar(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            onPressed: () => Navigator.of(context).pop(null),
          ),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => IconButton(
              icon: Icon(_flashIcon(), color: Colors.white, size: 28),
              onPressed: _controller.cycleFlash,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    if (!_controller.isRecording) return const SizedBox(height: 4);
    final progress = _controller.recordingDuration.inMilliseconds /
        _controller.maxRecordingDuration.inMilliseconds;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          backgroundColor: Colors.white24,
          color: Colors.red,
          minHeight: 4,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _GalleryThumb(gallery: _gallery, onSelected: _onMediaFromGallery),
        _CaptureButton(controller: _controller, onResult: _onCaptured),
        IconButton(
          icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 32),
          onPressed: _controller.toggleCamera,
        ),
      ],
    );
  }

  IconData _flashIcon() => switch (_controller.flashMode) {
        StoryFlashMode.off => Icons.flash_off,
        StoryFlashMode.auto => Icons.flash_auto,
        StoryFlashMode.on => Icons.flash_on,
        StoryFlashMode.always => Icons.flashlight_on,
      };

  void _onCaptured(StoryMedia? media) {
    if (media != null) Navigator.of(context).pop(media);
  }

  Future<void> _onMediaFromGallery() async {
    final albums = await _gallery.fetchAlbums();
    if (!mounted || albums.isEmpty) return;
    final assets = await _gallery.fetchAssets(albums.first);
    if (!mounted || assets.isEmpty) return;

    final selected = await showModalBottomSheet<AssetEntity>(
      context: context,
      backgroundColor: Colors.black,
      builder: (_) => _GallerySheet(assets: assets, gallery: _gallery),
    );
    if (!mounted || selected == null) return;

    final media = await _gallery.toStoryMedia(selected);
    if (!mounted || media == null) return;
    Navigator.of(context).pop(media);
  }
}

// ---------------------------------------------------------------------------

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({
    required this.controller,
    required this.onResult,
  });

  final StoryCaptureController controller;
  final void Function(StoryMedia?) onResult;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final recording = controller.isRecording;
        return GestureDetector(
          onTap: () async {
            final media = await controller.takePhoto();
            onResult(media);
          },
          onLongPress: () => controller.startRecording(),
          onLongPressEnd: (_) async {
            final media = await controller.stopRecording();
            onResult(media);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: recording ? Colors.red : Colors.white,
                width: recording ? 4 : 3,
              ),
            ),
            child: recording
                ? const Icon(Icons.stop, color: Colors.red, size: 32)
                : null,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

class _GalleryThumb extends StatefulWidget {
  const _GalleryThumb({required this.gallery, required this.onSelected});

  final GalleryService gallery;
  final VoidCallback onSelected;

  @override
  State<_GalleryThumb> createState() => _GalleryThumbState();
}

class _GalleryThumbState extends State<_GalleryThumb> {
  AssetEntity? _latest;

  @override
  void initState() {
    super.initState();
    _loadLatest();
  }

  Future<void> _loadLatest() async {
    final albums = await widget.gallery.fetchAlbums();
    if (albums.isEmpty || !mounted) return;
    final assets = await widget.gallery.fetchAssets(albums.first, pageSize: 1);
    if (assets.isNotEmpty && mounted) setState(() => _latest = assets.first);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onSelected,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white30),
        ),
        child: _latest == null
            ? const Icon(Icons.photo_library, color: Colors.white54, size: 24)
            : ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _AssetThumb(asset: _latest!, size: const ThumbnailSize(100, 100)),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _GallerySheet extends StatelessWidget {
  const _GallerySheet({required this.assets, required this.gallery});

  final List<AssetEntity> assets;
  final GalleryService gallery;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: assets.length,
      itemBuilder: (context, i) {
        final asset = assets[i];
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(asset),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _AssetThumb(asset: asset, size: const ThumbnailSize(200, 200)),
              if (asset.type == AssetType.video)
                const Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.videocam, color: Colors.white, size: 18),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

class _AssetThumb extends StatelessWidget {
  const _AssetThumb({required this.asset, required this.size});

  final AssetEntity asset;
  final ThumbnailSize size;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: asset.thumbnailDataWithSize(size),
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes == null) return const ColoredBox(color: Colors.black26);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      },
    );
  }
}
