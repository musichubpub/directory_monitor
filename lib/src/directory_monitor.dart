import 'dart:io'
    show
        Directory,
        File,
        FileSystemEntity,
        FileSystemEntityType,
        Platform,
        Process;
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import 'dart:ffi';
import 'package:directory_monitor/directory_monitor.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;

// FFI signature definitions for native functions
typedef StartMonitorFunc = Int32 Function(
  Pointer<Char> watchDir,
  Int64 port,
  Int32 recursive,
  Bool debugMode,
);
typedef StartMonitor = int Function(
  Pointer<Char> watchDir,
  int port,
  int recursive,
  bool debugMode,
);
typedef StopMonitor = void Function();

/// A class that monitors directory changes using native platform APIs
class DirectoryMonitor {
  final String watchDir; // Directory path to monitor
  final bool recursive; // Whether to monitor subdirectories recursively
  final bool debugMode; // Enable debug logging
  late final DynamicLibrary dylib; // Native library reference
  final List<String> ignoredFiles; // List of files/paths to ignore
  static late final PathMatcher matcher; // Path matching utility
  final List<String> allowedExtensions; // Allowed file extensions
  static late final String packageRoot; // Root path of the package

  /// Factory method for asynchronous constructor
  static Future<DirectoryMonitor> create({
    String watchDir = '',
    bool recursive = false,
    bool debugMode = false,
    List<String> ignoredPaths = const [],
    List<String> allowedExtensions = const [],
  }) async {
    final watcher = DirectoryMonitor._internal(
      watchDir: watchDir,
      recursive: recursive,
      debugMode: debugMode,
      ignoredFiles: ignoredPaths,
      allowedExtensions: allowedExtensions,
    );
    packageRoot = await _getPackageRoot();
    await watcher._initialize();
    matcher = PathMatcher(ignoredPaths, allowedExtensions);
    return watcher;
  }

  // Private constructor
  DirectoryMonitor._internal({
    required this.watchDir,
    required this.recursive,
    required this.debugMode,
    required this.ignoredFiles,
    required this.allowedExtensions,
  });

  // Asynchronous initialization method
  Future<void> _initialize() async {
    if (!Directory(watchDir).existsSync()) {
      throw Exception('Directory does not exist: $watchDir');
    }
    final String library = await _getLibraryPath();
    try {
      dylib = DynamicLibrary.open(library);
    } catch (e) {
      throw Exception('Failed to load dynamic library: $library, error: $e');
    }
  }

  /// Starts listening to directory changes and invokes callback for each event
  void listen(Function(DirectoryMonitorEvent) event) {
    final receivePort = ReceivePort();
    receivePort.listen((dynamic message) {
      bool shouldIgnore = false;
      final DirectoryMonitorAction action =
          DirectoryMonitorAction.values[message[0]];
      final String path = message[1];
      String sourcePath = '';

      // Determine entity type (file/directory)
      FileSystemEntityType entityType = FileSystemEntity.typeSync(path);
      if (action == DirectoryMonitorAction.delete) {
        // For delete actions, we need to guess the type
        if (isLikelyFile(path)) {
          entityType = FileSystemEntityType.file;
        } else {
          entityType = FileSystemEntityType.directory;
        }
      }

      // Check if file should be ignored based on extension or path patterns
      if (entityType == FileSystemEntityType.file) {
        shouldIgnore = !matcher.shouldAllowedExtensions(path);
        if (!shouldIgnore) {
          shouldIgnore = matcher.shouldIgnore(path);
        }
      }

      if (!shouldIgnore) {
        if (action == DirectoryMonitorAction.move) {
          sourcePath = message[2];
        }

        // Convert paths to relative format
        String parentPathx = p.relative(watchDir);
        String pathx = p.relative(path, from: watchDir);
        String sourcePathx =
            sourcePath != '' ? p.relative(sourcePath, from: watchDir) : '';

        // Normalize paths for Windows
        if (Platform.isWindows) {
          pathx = pathx.replaceAll(r'\', '/');
          sourcePathx = sourcePathx.replaceAll(r'\', '/');
          parentPathx = parentPathx.replaceAll(r'\', '/');
        }

        // Create and dispatch event
        final DirectoryMonitorEvent messageEvent = DirectoryMonitorEvent(
          action: action,
          type: entityType,
          path: pathx,
          sourcePath: sourcePathx,
          parentPath: parentPathx,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        event(messageEvent);

        // Handle directory-specific events
        if (entityType == FileSystemEntityType.directory) {
          if (action == DirectoryMonitorAction.move ||
              action == DirectoryMonitorAction.create) {
            _watchDirectory(
              action: action,
              dirPath: path,
              sourcePath: sourcePath,
              event: event,
            );
          }
        }
      }
    });

    // Lookup and call native start_monitor function
    final StartMonitor startMonitor =
        dylib.lookupFunction<StartMonitorFunc, StartMonitor>('start_monitor');
    final watchDirPtr = watchDir.toNativeUtf8();
    final result = startMonitor(
      watchDirPtr as Pointer<Char>,
      receivePort.sendPort.nativePort,
      recursive ? 1 : 0,
      debugMode,
    );

    malloc.free(watchDirPtr);
    if (result != 0) {
      throw Exception('Failed to start watcher');
    }
  }

  /// Recursively processes directory contents for move/create events
  void _watchDirectory({
    required DirectoryMonitorAction action,
    required String dirPath,
    required String sourcePath,
    required Function(DirectoryMonitorEvent) event,
  }) {
    final directory = Directory(dirPath);
    if (!directory.existsSync()) {
      print('Directory does not exist: $dirPath');
      return;
    }

    // Process all entities in the directory
    for (final FileSystemEntity entity
        in directory.listSync(recursive: recursive)) {
      if (entity.path == '.' || entity.path == '..' || entity.path == '') {
        continue;
      }

      if (entity is File) {
        FileSystemEntityType entityType = entity.statSync().type;
        if (entityType == FileSystemEntityType.notFound) {
          print('File not found: ${entity.path}');
          continue;
        }

        // Check if file should be ignored
        bool shouldIgnore = !matcher.shouldAllowedExtensions(entity.path);
        if (!shouldIgnore) {
          shouldIgnore = matcher.shouldIgnore(entity.path);
        }
        if (shouldIgnore) {
          continue;
        }

        // Prepare paths for event
        String sourcePathx = '';
        String parentPathx = p.relative(watchDir);
        String pathx = p.relative(entity.path, from: watchDir);

        if (action == DirectoryMonitorAction.move) {
          sourcePathx = p.relative(
              entity.path.replaceFirst(dirPath, sourcePath),
              from: watchDir);
        }

        // Normalize paths for Windows
        if (Platform.isWindows) {
          pathx = pathx.replaceAll(r'\', '/');
          sourcePathx = sourcePathx.replaceAll(r'\', '/');
          parentPathx = parentPathx.replaceAll(r'\', '/');
        }

        // Create and dispatch event
        final DirectoryMonitorEvent messageEvent = DirectoryMonitorEvent(
          action: action,
          type: entityType,
          path: pathx,
          sourcePath: sourcePathx,
          parentPath: parentPathx,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        event(messageEvent);
      }

      if (entity is Directory) {
        _watchDirectory(
          action: action,
          dirPath: entity.path,
          sourcePath: sourcePath,
          event: event,
        );
      }
    }
  }

  /// Stops the directory monitoring
  void stop() {
    final StopMonitor stopWatcher =
        dylib.lookupFunction<Void Function(), StopMonitor>('stop_monitor');
    stopWatcher();
  }

  /// Returns true if the path is likely a file (based on extension or path format)
  bool isLikelyFile(String path) {
    String ext = p.extension(path).toLowerCase();
    if (path.endsWith(p.separator) || path.endsWith('/')) {
      return false;
    }
    if (ext.isNotEmpty) {
      return true;
    }
    return ext.isEmpty ? false : true;
  }

  /// Gets the platform-specific path to the native library
  Future<String> _getLibraryPath() async {
    // Define platform-specific library extensions
    const platformExtensions = {
      'macOS': 'dylib',
      'windows': 'dll',
      'linux': 'so',
    };

    // Define supported architectures per platform
    const archMappings = {
      'macOS': {'ARM64': 'arm64', 'X86_64': 'x86_64'},
      'windows': {'ARM64': 'arm64', 'X86_64': 'x86_64'},
      'linux': {'ARM64': 'arm64', 'X86_64': 'x86_64', 'X86': 'i686'},
    };

    // Determine platform
    String platform;
    if (Platform.isMacOS) {
      platform = 'macOS';
    } else if (Platform.isWindows) {
      platform = 'windows';
    } else if (Platform.isLinux) {
      platform = 'linux';
    } else {
      throw Exception('Unsupported platform');
    }

    // Get CPU architecture
    final cpuType = await _getCPUType();
    final archMap = archMappings[platform];
    if (archMap == null || !archMap.containsKey(cpuType)) {
      throw Exception('Unsupported $platform architecture: $cpuType');
    }

    // Construct library path
    final extension = platformExtensions[platform]!;
    final arch = archMap[cpuType]!;
    String relativePath = p.join('libs', 'libDW_$arch.$extension');
    String absolutePath = p.absolute(packageRoot, relativePath);
    return absolutePath;
  }

  /// Gets the root directory of the package
  static Future<String> _getPackageRoot() async {
    PackageConfig? packageConfig = await findPackageConfig(Directory.current);
    if (packageConfig == null) {
      throw Exception('Could not find package configuration');
    }
    // Get the directory_monitor package's root
    Package? package = packageConfig['directory_monitor'];
    if (package == null) {
      throw Exception('Package directory_monitor not found');
    }
    return package.root.toFilePath();
  }

  /// Detects the CPU architecture of the current platform
  Future<String?> _getCPUType() async {
    if (Platform.isMacOS) {
      // macOS uses sysctl
      try {
        final result = await Process.run('sysctl', ['-n', 'hw.cputype']);
        if (result.exitCode == 0) {
          final cpuType = int.parse(result.stdout.trim());
          switch (cpuType) {
            case 16777228: // CPU_TYPE_ARM64
              return 'ARM64';
            case 16777223: // CPU_TYPE_X86_64
              return 'X86_64';
            default:
              return null;
          }
        }
      } catch (e) {
        print('Failed to retrieve macOS CPU architecture: $e');
      }
    } else if (Platform.isWindows) {
      // Windows uses environment variable or wmic command
      final arch =
          Platform.environment['PROCESSOR_ARCHITECTURE']?.toUpperCase();
      if (arch == 'AMD64') return 'X86_64';
      if (arch == 'ARM64') return 'ARM64';
      try {
        final result =
            await Process.run('wmic', ['cpu', 'get', 'architecture']);
        if (result.exitCode == 0) {
          final output = result.stdout.toString().toLowerCase();
          if (output.contains('9')) return 'X86_64'; // 9 indicates x64
          if (output.contains('12')) return 'ARM64'; // 12 indicates ARM64
        }
      } catch (e) {
        print('Failed to retrieve Windows CPU architecture: $e');
      }
    } else if (Platform.isLinux) {
      // Linux uses uname -m
      try {
        final result = await Process.run('uname', ['-m']);
        if (result.exitCode == 0) {
          final arch = result.stdout.trim().toLowerCase();
          if (arch.contains('x86_64')) return 'X86_64';
          if (arch.contains('aarch64') || arch.contains('arm64')) {
            return 'ARM64';
          }
          if (arch.contains('arm')) return 'ARM';
        }
      } catch (e) {
        print('Failed to retrieve Linux CPU architecture: $e');
      }
    }
    // Fallback to environment variable
    final arch = Platform.environment['PROCESSOR_ARCHITECTURE']?.toUpperCase();
    if (arch == 'AMD64') return 'X86_64';
    if (arch == 'ARM64') return 'ARM64';
    if (arch == 'X86') return 'X86';
    return null;
  }
}
