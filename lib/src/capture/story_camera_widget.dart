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

  double _frameAspect = 9 / 16;

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

  void _syncFrameAspect(Size nativePreviewSize) {
    if (nativePreviewSize.isEmpty) return;
    final aspect = nativePreviewSize.width / nativePreviewSize.height;
    if ((aspect - _frameAspect).abs() < 0.001) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _frameAspect = aspect);
    });
  }

  Size _coverSize(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    if (_frameAspect <= 0 || width <= 0 || height <= 0) {
      return Size(width, height);
    }
    return _frameAspect > width / height
        ? Size(height * _frameAspect, height)
        : Size(width, width / _frameAspect);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frame = _coverSize(constraints);
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            minWidth: 0,
            minHeight: 0,
            maxWidth: frame.width,
            maxHeight: frame.height,
            child: SizedBox(
              width: frame.width,
              height: frame.height,
              child: CameraAwesomeBuilder.custom(
                sensorConfig: SensorConfig.single(
                  sensor: Sensor.position(SensorPosition.back),
                  aspectRatio: CameraAspectRatios.ratio_16_9,
                ),
                mirrorFrontCamera: true,
                previewFit: CameraPreviewFit.fitWidth,
                saveConfig: SaveConfig.photoAndVideo(
                  initialCaptureMode: CaptureMode.photo,
                  photoPathBuilder: _photoPathBuilder,
                  videoPathBuilder: _videoPathBuilder,
                ),
                builder: (cameraState, preview) {
                  widget.controller.attachCameraState(cameraState);
                  _syncFrameAspect(preview.nativePreviewSize);
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
