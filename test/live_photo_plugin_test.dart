import 'package:flutter_test/flutter_test.dart';
import 'package:live_photo_plugin/live_photo_plugin.dart';
import 'package:live_photo_plugin/live_photo_plugin_platform_interface.dart';
import 'package:live_photo_plugin/live_photo_plugin_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockLivePhotoPluginPlatform
    with MockPlatformInterfaceMixin
    implements LivePhotoPluginPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final LivePhotoPluginPlatform initialPlatform = LivePhotoPluginPlatform.instance;

  test('$MethodChannelLivePhotoPlugin is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelLivePhotoPlugin>());
  });

  test('getPlatformVersion', () async {
    LivePhotoPlugin livePhotoPlugin = LivePhotoPlugin();
    MockLivePhotoPluginPlatform fakePlatform = MockLivePhotoPluginPlatform();
    LivePhotoPluginPlatform.instance = fakePlatform;

    expect(await livePhotoPlugin.getPlatformVersion(), '42');
  });
}
