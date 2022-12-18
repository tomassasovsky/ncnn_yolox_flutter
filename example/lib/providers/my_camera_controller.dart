import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:ncnn_yolox_flutter/ncnn_yolox_flutter.dart';
import 'package:ncnn_yolox_flutter_example/providers/ncnn_yolox_controller.dart';

final myCameraController = Provider(
  MyCameraController.new,
);

class MyCameraController {
  MyCameraController(this.ref);

  final Ref ref;

  CameraController? cameraController;

  KannaRotateDeviceOrientationType get deviceOrientationType =>
      cameraController?.value.deviceOrientation.kannaRotateType ??
      KannaRotateDeviceOrientationType.portraitUp;

  int get sensorOrientation =>
      cameraController?.description.sensorOrientation ?? 90;

  bool _isProcessing = false;

  Future<void> startImageStream() async {
    await ref.read(ncnnYoloxController.notifier).initialize();

    final camera = (await availableCameras())[0];

    cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await cameraController!.initialize();
    await cameraController!.startImageStream(
      (image) async {
        if (_isProcessing) {
          return;
        }

        _isProcessing = true;
        await ref
            .read(ncnnYoloxController.notifier)
            .detectFromCameraImage(image);
        _isProcessing = false;
      },
    );
  }

  Future<void> stopImageStream() async {
    final cameraValue = cameraController?.value;
    if (cameraValue != null) {
      if (cameraValue.isInitialized && cameraValue.isStreamingImages) {
        await cameraController?.stopImageStream();
        await cameraController?.dispose();
        cameraController = null;
      }
    }
  }
}

extension DeviceOrientationExtension on DeviceOrientation {
  KannaRotateDeviceOrientationType get kannaRotateType {
    switch (this) {
      case DeviceOrientation.portraitUp:
        return KannaRotateDeviceOrientationType.portraitUp;
      case DeviceOrientation.portraitDown:
        return KannaRotateDeviceOrientationType.portraitDown;
      case DeviceOrientation.landscapeLeft:
        return KannaRotateDeviceOrientationType.landscapeLeft;
      case DeviceOrientation.landscapeRight:
        return KannaRotateDeviceOrientationType.landscapeRight;
    }
  }
}
