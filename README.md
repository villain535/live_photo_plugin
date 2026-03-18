# live_photo_plugin

A Flutter plugin for saving a local mp4 or mov file as a Live Photo on iOS.

## Features

- Save a local video file as a Live Photo on iOS
- Native iOS implementation using Swift and Objective-C
- Designed for Flutter / FlutterFlow integration through a plugin dependency

## iOS support

This plugin currently supports **iOS only**.

## Requirements

- iOS 13.0+
- A real iPhone device is recommended for testing
- The input file path must be a **local absolute path** to a video file inside the app sandbox

## Installation

Add the plugin as a dependency.

### Git dependency

```yaml
dependencies:
  live_photo_plugin:
    git:
      url: https://github.com/villain535/live_photo_plugin.git
```

## Usage

```dart
import 'package:live_photo_plugin/live_photo_plugin.dart';

final success = await LivePhotoPlugin.saveAsLivePhoto(videoPath);
```

## API

### `saveAsLivePhoto`

```dart
static Future<bool> saveAsLivePhoto(String videoPath)
```

#### Parameters

- `videoPath` — local absolute path to an `.mp4` or `.mov` file

#### Returns

- `true` if the Live Photo was saved successfully
- throws a platform error if saving fails

## Important

- `videoPath` must point to a **local file**
- network URLs are not supported
- Flutter assets are not supported directly
- the plugin saves the Live Photo to the user's Photos library

## iOS permissions

The host app must include these keys in `Info.plist`:

```xml
<key>NSPhotoLibraryAddUsageDescription</key>
<string>App needs access to save Live Photos.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>App needs access to access the photo library.</string>
```

## FlutterFlow notes

This plugin can be connected to FlutterFlow as a Git dependency and called from a Custom Action.

## Notes

- Sharing Live Photo is not included in the current version
- This version focuses only on saving Live Photo to the Photos library

## License

See the `LICENSE` file.
