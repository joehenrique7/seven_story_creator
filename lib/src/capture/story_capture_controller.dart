import 'dart:async';
import 'dart:io';

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/foundation.dart';

import 'models/story_media.dart';

enum CaptureState { idle, recording, processing }

enum StoryFlashMode { off, auto, on, always }

class StoryCaptureController extends ChangeNotifier {
  StoryCaptureController({
    this.maxRecordingDuration = const Duration(seconds: 15),
    this.onMaxDurationReached,
  });

  final Duration maxRecordingDuration;
  final VoidCallback? onMaxDurationReached;

  CaptureState _state = CaptureState.idle;
  StoryFlashMode _flashMode = StoryFlashMode.off;
  bool _isFrontCamera = false;
  Duration _recordingDuration = Duration.zero;

  CameraState? _cameraState;
  Timer? _recordingTimer;

  CaptureState get state => _state;
  StoryFlashMode get flashMode => _flashMode;
  bool get isFrontCamera => _isFrontCamera;
  Duration get recordingDuration => _recordingDuration;
  bool get isRecording => _state == CaptureState.recording;

  void attachCameraState(CameraState cameraState) {
    _cameraState = cameraState;
  }

  Future<StoryMedia?> takePhoto() async {
    final camState = _cameraState;
    if (camState == null) return null;

    _setState(CaptureState.processing);
    try {
      final completer = Completer<StoryMedia?>();
      camState.when(
        onPhotoMode: (s) {
          s.takePhoto(
            onPhoto: (request) {
              final path = request.when(
                single: (r) => r.file?.path,
                multiple: (r) => r.fileBySensor.values.first?.path,
              );
              if (path != null) {
                completer.complete(
                  StoryMedia(file: File(path), type: StoryType.photo),
                );
              } else {
                completer.complete(null);
              }
            },
            onPhotoFailed: (_) => completer.complete(null),
          );
        },
      );

      final result = await completer.future;
      _setState(CaptureState.idle);
      return result;
    } catch (_) {
      _setState(CaptureState.idle);
      return null;
    }
  }

  Future<void> startRecording() async {
    final camState = _cameraState;
    if (camState == null || _state != CaptureState.idle) return;

    camState.when(
      onVideoMode: (s) => s.startRecording(),
    );

    _recordingDuration = Duration.zero;
    _setState(CaptureState.recording);

    _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _recordingDuration += const Duration(milliseconds: 100);
      notifyListeners();
      if (_recordingDuration >= maxRecordingDuration) {
        onMaxDurationReached?.call();
        stopRecording();
      }
    });
  }

  Future<StoryMedia?> stopRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;

    final camState = _cameraState;
    if (camState == null) {
      _setState(CaptureState.idle);
      return null;
    }

    _setState(CaptureState.processing);
    try {
      final completer = Completer<StoryMedia?>();
      camState.when(
        onVideoRecordingMode: (s) {
          s.stopRecording(
            onVideo: (request) {
              final path = request.when(
                single: (r) => r.file?.path,
                multiple: (r) => r.fileBySensor.values.first?.path,
              );
              if (path != null) {
                completer.complete(
                  StoryMedia(
                    file: File(path),
                    type: StoryType.video,
                    duration: _recordingDuration,
                  ),
                );
              } else {
                completer.complete(null);
              }
            },
          );
        },
      );

      final result = await completer.future;
      _setState(CaptureState.idle);
      return result;
    } catch (_) {
      _setState(CaptureState.idle);
      return null;
    }
  }

  void toggleCamera() {
    final camState = _cameraState;
    if (camState == null) return;
    _isFrontCamera = !_isFrontCamera;
    camState.switchCameraSensor(
      aspectRatio: CameraAspectRatios.ratio_16_9,
    );
    notifyListeners();
  }

  void cycleFlash() {
    _flashMode = StoryFlashMode.values[
        (_flashMode.index + 1) % StoryFlashMode.values.length];
    _applyFlash();
    notifyListeners();
  }

  void _applyFlash() {
    final FlashMode mode = switch (_flashMode) {
      StoryFlashMode.off => FlashMode.none,
      StoryFlashMode.auto => FlashMode.auto,
      StoryFlashMode.on => FlashMode.on,
      StoryFlashMode.always => FlashMode.always,
    };
    _cameraState?.sensorConfig.setFlashMode(mode);
  }

  void _setState(CaptureState s) {
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    super.dispose();
  }
}
