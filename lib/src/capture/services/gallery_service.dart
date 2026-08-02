import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/story_media.dart';

class GalleryService {
  /// Ordena os assets com os mais recentes primeiro.
  static final FilterOptionGroup _recentFirst = FilterOptionGroup(
    orders: [
      const OrderOption(type: OrderOptionType.createDate, asc: false),
    ],
  );

  Future<PermissionState> requestPermission() =>
      PhotoManager.requestPermissionExtend();

  Future<PermissionState> permissionState() => PhotoManager.getPermissionState(
        requestOption: const PermissionRequestOption(),
      );

  Future<bool> hasPermission() async {
    final state = await permissionState();
    return state == PermissionState.authorized ||
        state == PermissionState.limited;
  }

  /// iOS / Android 14+: o usuário liberou só algumas fotos.
  Future<bool> isLimited() async =>
      await permissionState() == PermissionState.limited;

  /// Abre o seletor do sistema para o usuário liberar mais fotos (ou todas).
  Future<void> manageLimitedAccess() async {
    await PhotoManager.presentLimited();
    await PhotoManager.clearFileCache();
  }

  /// Todos os álbuns e coleções do aparelho, com "Recentes" (todas as
  /// fotos/vídeos) sempre em primeiro.
  Future<List<AssetPathEntity>> fetchAlbums() async {
    final state = await requestPermission();
    if (state == PermissionState.denied ||
        state == PermissionState.restricted) {
      return [];
    }
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      filterOption: _recentFirst,
    );
    return [
      ...albums.where((album) => album.isAll),
      ...albums.where((album) => !album.isAll),
    ];
  }

  /// Só o álbum "Recentes" — usado na miniatura da câmera, sem varrer as
  /// coleções do usuário.
  Future<AssetPathEntity?> fetchRecentAlbum() async {
    final state = await requestPermission();
    if (state == PermissionState.denied ||
        state == PermissionState.restricted) {
      return null;
    }
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: true,
      filterOption: _recentFirst,
    );
    return albums.isEmpty ? null : albums.first;
  }

  String albumTitle(AssetPathEntity album) =>
      album.isAll ? 'Recentes' : album.name;

  Future<List<AssetEntity>> fetchAssets(
    AssetPathEntity album, {
    int page = 0,
    int pageSize = 60,
  }) =>
      album.getAssetListPaged(page: page, size: pageSize);

  Future<StoryMedia?> toStoryMedia(AssetEntity asset) async {
    final File? file = await asset.file;
    if (file == null) return null;

    File? thumbnail;
    if (asset.type == AssetType.video) {
      thumbnail = await _generateThumbnail(asset);
    }

    return StoryMedia(
      file: file,
      type: asset.type == AssetType.video ? StoryType.video : StoryType.photo,
      duration: asset.type == AssetType.video ? asset.videoDuration : null,
      thumbnail: thumbnail,
    );
  }

  Future<File?> _generateThumbnail(AssetEntity asset) async {
    try {
      final Uint8List? bytes = await asset.thumbnailDataWithSize(
        const ThumbnailSize(200, 200),
      );
      if (bytes == null) return null;
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/thumb_${asset.id}.jpg';
      return File(path)..writeAsBytesSync(bytes);
    } catch (_) {
      return null;
    }
  }
}
