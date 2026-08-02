import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

import 'models/story_media.dart';
import 'services/gallery_service.dart';
import 'story_camera_widget.dart';
import 'story_capture_controller.dart';
import 'story_trimmer_page.dart';

enum _CameraAccess { checking, granted, denied }

class StoryCapturePage extends StatefulWidget {
  const StoryCapturePage({super.key});

  /// Push this page and await a [StoryMedia], or null if user cancelled.
  @override
  State<StoryCapturePage> createState() => _StoryCapturePageState();
}

class _StoryCapturePageState extends State<StoryCapturePage> {
  late final StoryCaptureController _controller;
  final GalleryService _gallery = GalleryService();
  _CameraAccess _access = _CameraAccess.checking;

  @override
  void initState() {
    super.initState();
    _controller = StoryCaptureController(
      onMaxDurationReached: () {
        // stopRecording is already called by the controller; pop result.
      },
    );
    _ensurePermissions();
  }

  Future<void> _ensurePermissions() async {
    final statuses = await [Permission.camera, Permission.microphone].request();
    if (!mounted) return;
    final granted = (statuses[Permission.camera]?.isGranted ?? false) &&
        (statuses[Permission.microphone]?.isGranted ?? false);
    setState(() => _access = granted ? _CameraAccess.granted : _CameraAccess.denied);
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
      body: switch (_access) {
        _CameraAccess.checking => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        _CameraAccess.denied => SafeArea(child: _buildPermissionDenied()),
        _CameraAccess.granted => Stack(
            fit: StackFit.expand,
            children: [
              StoryCameraWidget(controller: _controller),
              SafeArea(child: _buildOverlay()),
            ],
          ),
      },
    );
  }

  Widget _buildPermissionDenied() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(null),
            ),
          ),
        ),
        const Spacer(),
        const Icon(Icons.no_photography, color: Colors.white54, size: 56),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Precisamos de acesso à câmera e ao microfone para criar seu story.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
          ),
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: openAppSettings,
          child: const Text(
            'Abrir configurações',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        const Spacer(),
      ],
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

    final selected = await showModalBottomSheet<AssetEntity>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _GallerySheet(albums: albums, gallery: _gallery),
    );
    if (!mounted || selected == null) return;

    final media = await _gallery.toStoryMedia(selected);
    if (!mounted || media == null) return;

    // Vídeo maior que a duração máxima de um story → o usuário escolhe qual
    // janela publicar na régua de corte (estilo Instagram).
    if (media.type == StoryType.video &&
        media.duration != null &&
        media.duration! > kMaxStoryVideoDuration) {
      final trimmed = await Navigator.of(context).push<StoryMedia?>(
        MaterialPageRoute(builder: (_) => StoryTrimmerPage(media: media)),
      );
      if (!mounted || trimmed == null) return;
      Navigator.of(context).pop(trimmed);
      return;
    }

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
    if (!await widget.gallery.hasPermission() || !mounted) return;
    final album = await widget.gallery.fetchRecentAlbum();
    if (album == null || !mounted) return;
    final assets = await widget.gallery.fetchAssets(album, pageSize: 1);
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

class _GallerySheet extends StatefulWidget {
  const _GallerySheet({required this.albums, required this.gallery});

  final List<AssetPathEntity> albums;
  final GalleryService gallery;

  @override
  State<_GallerySheet> createState() => _GallerySheetState();
}

class _GallerySheetState extends State<_GallerySheet> {
  static const int _pageSize = 60;

  late List<AssetPathEntity> _albums = widget.albums;
  late AssetPathEntity _album = widget.albums.first;
  final List<AssetEntity> _assets = [];
  int _page = 0;
  bool _loading = false;
  bool _hasMore = true;
  bool _choosingAlbum = false;
  bool _limited = false;

  @override
  void initState() {
    super.initState();
    _loadMore();
    _checkLimited();
  }

  Future<void> _checkLimited() async {
    final limited = await widget.gallery.isLimited();
    if (mounted) setState(() => _limited = limited);
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    _loading = true;
    final batch = await widget.gallery.fetchAssets(
      _album,
      page: _page,
      pageSize: _pageSize,
    );
    if (!mounted) return;
    setState(() {
      _assets.addAll(batch);
      _page++;
      _hasMore = batch.length == _pageSize;
      _loading = false;
    });
  }

  void _selectAlbum(AssetPathEntity album) {
    setState(() {
      _album = album;
      _choosingAlbum = false;
      _assets.clear();
      _page = 0;
      _hasMore = true;
      _loading = false;
    });
    _loadMore();
  }

  Future<void> _manageLimited() async {
    await widget.gallery.manageLimitedAccess();
    final albums = await widget.gallery.fetchAlbums();
    if (!mounted || albums.isEmpty) return;
    setState(() => _albums = albums);
    _selectAlbum(albums.first);
    _checkLimited();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: ColoredBox(
            color: Colors.black,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                _buildHeader(),
                if (_limited) _buildLimitedBanner(),
                Expanded(
                  child: _choosingAlbum
                      ? _buildAlbumList(scrollController)
                      : _buildAssetGrid(scrollController),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _choosingAlbum = !_choosingAlbum),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        widget.gallery.albumTitle(_album),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      _choosingAlbum
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.white,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 24),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitedBanner() {
    return Container(
      width: double.infinity,
      color: Colors.white10,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Você liberou apenas algumas fotos para o app.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _manageLimited,
            child: const Text(
              'Gerenciar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumList(ScrollController scrollController) {
    return ListView.builder(
      controller: scrollController,
      itemCount: _albums.length,
      itemBuilder: (context, i) {
        final album = _albums[i];
        return _AlbumTile(
          album: album,
          title: widget.gallery.albumTitle(album),
          selected: album.id == _album.id,
          onTap: () => _selectAlbum(album),
        );
      },
    );
  }

  Widget _buildAssetGrid(ScrollController scrollController) {
    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _assets.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= _assets.length) {
          _loadMore();
          return const ColoredBox(
            color: Colors.black26,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              ),
            ),
          );
        }
        final asset = _assets[i];
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

class _AlbumTile extends StatelessWidget {
  const _AlbumTile({
    required this.album,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final AssetPathEntity album;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 48,
          height: 48,
          child: FutureBuilder<List<AssetEntity>>(
            future: album.getAssetListPaged(page: 0, size: 1),
            builder: (context, snap) {
              final assets = snap.data;
              if (assets == null || assets.isEmpty) {
                return const ColoredBox(color: Colors.white12);
              }
              final asset = assets.first;
              return _AssetThumb(
                asset: asset,
                size: const ThumbnailSize(100, 100),
              );
            },
          ),
        ),
      ),
      title: Text(
        title,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      subtitle: FutureBuilder<int>(
        future: album.assetCountAsync,
        builder: (context, snap) => Text(
          '${snap.data ?? 0}',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check, color: Colors.white, size: 20)
          : null,
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
