import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'live_photo_plugin_method_channel.dart';

abstract class LivePhotoPluginPlatform extends PlatformInterface {
  /// Constructs a LivePhotoPluginPlatform.
  LivePhotoPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static LivePhotoPluginPlatform _instance = MethodChannelLivePhotoPlugin();

  /// The default instance of [LivePhotoPluginPlatform] to use.
  ///
  /// Defaults to [MethodChannelLivePhotoPlugin].
  static LivePhotoPluginPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [LivePhotoPluginPlatform] when
  /// they register themselves.
  static set instance(LivePhotoPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
