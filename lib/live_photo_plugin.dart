import 'dart:io';
import 'package:flutter/services.dart';

class LivePhotoPlugin {
  static const MethodChannel _channel = MethodChannel('live_photo_plugin');

  static Future<bool> saveAsLivePhoto(String videoPath) async {
    if (!Platform.isIOS) {
      throw UnsupportedError('saveAsLivePhoto is supported only on iOS');
    }

    final result = await _channel.invokeMethod<bool>(
      'saveAsLivePhoto',
      <String, dynamic>{
        'videoPath': videoPath,
      },
    );

    return result ?? false;
  }
}
