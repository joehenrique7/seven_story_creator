import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/story_media.dart';

class GalleryService {
  Future<PermissionState> requestPermission() =>
      PhotoManager.requestPermissionExtend();

  Future<List<AssetPathEntity>> fetchAlbums() async {
    final state = await requestPermission();
    if (state == PermissionState.denied ||
        state == PermissionState.restricted) {
      return [];
    }
    return PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: false,
    );
  }

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
