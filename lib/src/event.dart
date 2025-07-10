import 'dart:io';

enum DirectoryMonitorAction { create, delete, modify, move, unknown }

class DirectoryMonitorEvent {
  DirectoryMonitorAction action;
  String parentPath;
  String path;
  String sourcePath;
  final int timestamp;

  final FileSystemEntityType type;
  DirectoryMonitorEvent({
    this.action = DirectoryMonitorAction.unknown,
    this.parentPath = '',
    this.path = '',
    this.sourcePath = '',
    this.timestamp = 0,
    this.type = FileSystemEntityType.notFound,
  });

  @override
  String toString() =>
      'Event(action: $action,parentPath:$parentPath  path: $path, sourcePath: $sourcePath,type: $type,timestamp: $timestamp)';
}
