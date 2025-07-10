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
        '.txt',
        '.mp3',
        '.flac',
        '.m4a',
        '.ogg',
        '.wav',
        '.ape',
        '.mp4',
        '.mov',
        '.opus',
      ],
    );
    watcher.listen((DirectoryMonitorEvent event) {
      print(event);
    });
  } catch (e) {
    print('error: $e');
  }
}
