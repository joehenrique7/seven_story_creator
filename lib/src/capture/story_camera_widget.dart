import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'story_capture_controller.dart';

class StoryCameraWidget extends StatefulWidget {
  const StoryCameraWidget({
    super.key,
    required this.controller,
  });

  final StoryCaptureController controller;

  @override
  State<StoryCameraWidget> createState() => _StoryCameraWidgetState();
}

class _StoryCameraWidgetState extends State<StoryCameraWidget> {
  static const _uuid = Uuid();

  Future<CaptureRequest> _photoPathBuilder(List<Sensor> sensors) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/${_uuid.v4()}.jpg';
    return SingleCaptureRequest(path, sensors.first);
  }

  Future<CaptureRequest> _videoPathBuilder(List<Sensor> sensors) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/${_uuid.v4()}.mp4';
    return SingleCaptureRequest(path, sensors.first);
  }

  @override
  Widget build(BuildContext context) {
    return CameraAwesomeBuilder.custom(
      saveConfig: SaveConfig.photoAndVideo(
        initialCaptureMode: CaptureMode.photo,
        photoPathBuilder: _photoPathBuilder,
        videoPathBuilder: _videoPathBuilder,
      ),
      builder: (cameraState, preview) {
        widget.controller.attachCameraState(cameraState);
        return const SizedBox.expand();
      },
    );
  }
}
