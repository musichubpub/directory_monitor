class PathMatcher {
  final List<String> _patterns;
  final List<String> _allowedExtensions;
  PathMatcher(this._patterns, this._allowedExtensions);

  /// Checks if the path matches any of the patterns
  bool shouldIgnore(String path) {
    if (_patterns.isEmpty) return false;
    for (final pattern in _patterns) {
      if (_matchPattern(path, pattern)) {
        return true;
      }
    }
    return false;
  }

  /// Returns true if the path is allowed by the allowedExtensions
  bool shouldAllowedExtensions(String path) {
    if (_allowedExtensions.isEmpty) return true;
    if (_allowedExtensions.isNotEmpty) {
      final lowerPath = path.toLowerCase();
      if (_allowedExtensions.any((ext) => lowerPath.endsWith(ext))) {
        return true;
      }
    }
    return false;
  }

  /// Core pattern matching logic
  bool _matchPattern(String path, String pattern) {
    // Handle directory patterns (ending with /)
    final isDirectoryPattern = pattern.endsWith('/');
    if (isDirectoryPattern) {
      pattern = pattern.substring(0, pattern.length - 1);
    }

    // 1. Handle wildcard * (matches file extensions)
    if (pattern.startsWith('*.')) {
      final ext = pattern.substring(1); // Get the extension part, e.g. ".tmp"
      return path.endsWith(ext);
    }

    // 2. Handle hidden files (like .DS_Store)
    if (pattern.startsWith('.') &&
        !pattern.contains('/') &&
        !pattern.contains('*')) {
      final fileName = path.split('/').last;
      return fileName == pattern;
    }

    // 3. Handle directory matching (e.g. .vscode/)
    if (isDirectoryPattern) {
      return path.startsWith('$pattern/') || path == pattern;
    }

    // 4. Handle exact path matching with wildcards (e.g. /libs/*)
    if (pattern.contains('*')) {
      final regex = RegExp(
        pattern
            .replaceAll('.', r'\.')
            .replaceAll('*', '[^/]*') // * matches any character except /
            .replaceAll('/', r'\/'),
      );
      return regex.hasMatch(path);
    }

    // 5. Default case: exact path matching
    return path == pattern;
  }
}
