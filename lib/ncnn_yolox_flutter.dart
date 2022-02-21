// ignore_for_file: prefer_single_quotes

import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:ncnn_yolox_flutter/models/yolox_results.dart';
import 'package:path_provider/path_provider.dart';

export 'models/models.dart';

typedef DetectYoloxNative = Pointer<Utf8> Function(
  Pointer<Utf8> imagePath,
);

typedef DetectYolox = Pointer<Utf8> Function(
  Pointer<Utf8> imagePath,
);

typedef InitYoloxNative = Void Function(
  Pointer<Utf8> modelPath,
  Pointer<Utf8> paramPath,
);

typedef InitYolox = void Function(
  Pointer<Utf8> modelPath,
  Pointer<Utf8> paramPath,
);

class NcnnYoloxFlutter {
  final dynamicLibrary = Platform.isAndroid
      ? DynamicLibrary.open('libncnn_yolox_flutter.so')
      : DynamicLibrary.process();

  DetectYolox? _detectYoloxFunction;

  /// Initialize YoloX
  /// Run it for the first time
  ///
  /// - [modelPath] - path to model file. like "assets/yolox.bin"
  /// - [paramPath] - path to parameter file. like "assets/yolox.param"
  Future<void> initYolox({
    required String modelPath,
    required String paramPath,
  }) async {
    _detectYoloxFunction =
        dynamicLibrary.lookupFunction<DetectYoloxNative, DetectYolox>('detect');

    final tempModelPath = (await _copy(modelPath)).toNativeUtf8();
    final tempParamPath = (await _copy(paramPath)).toNativeUtf8();
    dynamicLibrary.lookupFunction<InitYoloxNative, InitYolox>('initYolox')(
      tempModelPath,
      tempParamPath,
    );
    calloc
      ..free(tempModelPath)
      ..free(tempParamPath);
  }

  Future<String> _copy(String assetsPath) async {
    final documentDir = await getApplicationDocumentsDirectory();

    final data = await rootBundle.load(assetsPath);

    final file = File("${documentDir.path}/$assetsPath")
      ..createSync(recursive: true)
      ..writeAsBytesSync(
        data.buffer.asUint8List(),
        flush: true,
      );
    return file.path;
  }

  /// Detect YoloX
  /// Run it after initYolox
  /// [imagePath] - path to image file. like "assets/image.jpg"
  List<YoloxResults> detect({
    required String imagePath,
  }) {
    assert(_detectYoloxFunction != null);
    if (_detectYoloxFunction == null) {
      return [];
    }

    final imagePathNative = imagePath.toNativeUtf8();

    final responses = YoloxResults.create(
      _detectYoloxFunction!(
        imagePathNative,
      ).toDartString(),
    );
    calloc.free(imagePathNative);

    return responses;
  }
}
