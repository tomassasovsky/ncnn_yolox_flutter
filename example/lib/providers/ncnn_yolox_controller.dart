import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:ncnn_yolox_flutter/models/models.dart';
import 'package:ncnn_yolox_flutter/ncnn_yolox.dart';
import 'package:ncnn_yolox_flutter_example/providers/my_camera_controller.dart';
import 'package:ncnn_yolox_flutter_example/providers/ncnn_yolox_options.dart';

final ncnnYoloxController =
    StateNotifierProvider<NcnnYoloxController, List<YoloxResults>>(
  NcnnYoloxController.new,
);

class NcnnYoloxController extends StateNotifier<List<YoloxResults>> {
  NcnnYoloxController(this.ref) : super([]);

  final Ref ref;

  final _ncnnYolox = NcnnYolox();

  static final previewImage = StateProvider<ui.Image?>((_) => null);
  static final computationTime = StateProvider<Duration?>((_) => null);

  Future<void> initialize() async {
    await _ncnnYolox.initYolox(
      // modelPath: 'assets/yolox/yolox.bin',
      // paramPath: 'assets/yolox/yolox.param',
      modelPath: 'assets/yolox/model.bin',
      paramPath: 'assets/yolox/model.param',
      // modelPath: 'assets/yolox/yolov7-sv.bin',
      // paramPath: 'assets/yolox/yolov7-sv.param',
      autoDispose: ref.read(ncnnYoloxOptions).autoDispose,
      nmsThresh: ref.read(ncnnYoloxOptions).nmsThresh,
      confThresh: ref.read(ncnnYoloxOptions).confThresh,
      targetSize: ref.read(ncnnYoloxOptions).targetSize,
    );
  }

  Future<void> detectFromImageFile(XFile file) async {
    state = _ncnnYolox.detectImageFile(file.path);
    log(state.toString());

    final stopwatch = Stopwatch()..start();
    final decodedImage = await decodeImageFromList(
      File(
        file.path,
      ).readAsBytesSync(),
    );
    ref.read(previewImage.notifier).state = decodedImage;

    stopwatch.stop();
    ref.read(computationTime.notifier).state = stopwatch.elapsed;
    log('detect fps: ${1000 / stopwatch.elapsedMilliseconds}');
  }

  Future<void> detectFromCameraImage(CameraImage cameraImage) async {
    final completer = Completer<void>();
    final stopwatch = Stopwatch()..start();

    switch (cameraImage.format.group) {
      case ImageFormatGroup.unknown:
        log('not support format: unknown');
        return;
      case ImageFormatGroup.jpeg:
        log('not support format: jpeg');
        return;
      case ImageFormatGroup.yuv420:
        log('format: yuv420');
        final camController = ref.read(myCameraController);
        state = _ncnnYolox
            .detectYUV420(
              y: cameraImage.planes[0].bytes,
              u: cameraImage.planes[1].bytes,
              v: cameraImage.planes[2].bytes,
              height: cameraImage.height,
              deviceOrientationType: camController.deviceOrientationType,
              sensorOrientation: camController.sensorOrientation,
              onDecodeImage: (image) {
                ref.read(previewImage.notifier).state = image;
                completer.complete();
              },
            )
            .results;
        break;
      case ImageFormatGroup.bgra8888:
        log('format: bgra8888');
        state = _ncnnYolox
            .detectBGRA8888(
              pixels: cameraImage.planes[0].bytes,
              height: cameraImage.height,
              deviceOrientationType:
                  ref.read(myCameraController).deviceOrientationType,
              sensorOrientation: ref.read(myCameraController).sensorOrientation,
              onDecodeImage: (image) {
                ref.read(previewImage.notifier).state = image;
                completer.complete();
              },
            )
            .results;
        break;
    }

    stopwatch.stop();
    ref.read(computationTime.notifier).state = stopwatch.elapsed;
    log('detect fps: ${1000 / stopwatch.elapsedMilliseconds}');

    return completer.future;
  }
}
