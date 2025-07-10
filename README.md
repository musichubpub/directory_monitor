## Directory Monitor

[![Pub](https://img.shields.io/pub/v/directory_monitor.svg)](https://pub.dev/packages/directory_monitor)

Directory Monitor is a directory monitoring tool that can monitor file and directory changes in a directory and execute corresponding callback functions.

Dart uses ffi to implement dmon extension

## Use it

```dart
import 'package:directory_monitor/directory_monitor.dart';

void main() async {
  try {
    final watcher = await DirectoryMonitor.create(
      watchDir: 'watcher_dir/',
      recursive: true,
      debugMode: true,
      ignoredPaths: [
        // "*.tmp",
        // "*.swp",
        // "*.bak",
        // "*.bk",
        // ".DS_Store",
        // ".Trashes",
        // ".Spotlight-V100",
        // ".fseventsd",
      ],
      allowedExtensions: [
        // '.txt',
        // '.mp3',
        // '.flac',
        // '.m4a',
        // '.ogg',
        // '.wav',
        // '.ape',
        // '.mp4',
        // '.mov',
        // '.opus',
      ],
    );
    watcher.listen((event) {
      print(event);
    });
    //watcher.stop();
  } catch (e) {
    print('error: $e');
  }
}
```
