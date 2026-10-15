import 'dart:io';

const _forbiddenFileNames = <String>{
  'pipfile',
  'pipfile.lock',
  'pyproject.toml',
  'requirements.txt',
  'requirements-dev.txt',
  'setup.cfg',
  'setup.py',
};

const _ignoredDirectoryNames = <String>{
  '.dart_tool',
  '.git',
  '.vercel',
  'build',
  'node_modules',
};

const _scannedExtensions = <String>{
  '.bat',
  '.dart',
  '.json',
  '.md',
  '.ps1',
  '.sh',
  '.yaml',
  '.yml',
};

final _pythonCommand = RegExp(
  r'''^\s*(?:python3?|pip3?)(?:\.exe)?(?:\s|$)|'''
  r'''(?:&&|\|\||;)\s*(?:python3?|pip3?)(?:\.exe)?(?:\s|$)|'''
  r'''Process\.(?:run|start)\s*\(\s*["']python3?["']|'''
  r'''\bpip3?\s+install\b|'''
  r'''\b(?:requirements(?:-dev)?\.txt|Pipfile(?:\.lock)?|pyproject\.toml)\b''',
  caseSensitive: false,
  multiLine: true,
);

Future<void> main(List<String> arguments) async {
  if (arguments.contains('--help') || arguments.contains('-h')) {
    stdout.writeln(
        'Checks Sakay Ta for project-owned Python artifacts and commands.');
    stdout.writeln(
        'Usage: dart run tool/verify_no_python.dart [repository-root]');
    return;
  }

  final root = Directory(
    arguments.isEmpty ? Directory.current.path : arguments.single,
  ).absolute;
  if (!await root.exists()) {
    stderr.writeln('Repository root does not exist: ${root.path}');
    exitCode = 64;
    return;
  }

  final violations = <String>[];
  final allowedGenerated = <String>[];

  await for (final entity in root.list(recursive: true, followLinks: false)) {
    final relative = _relativePath(root.path, entity.path);
    final segments = relative.split('/');

    if (entity is Directory) {
      final name = segments.last.toLowerCase();
      if (name == '__pycache__' || name == '.venv' || name == 'venv') {
        violations.add('$relative/ (Python environment/cache directory)');
      }
      continue;
    }
    final lower = relative.toLowerCase();
    if (lower == 'ios/flutter/ephemeral/flutter_lldb_helper.py') {
      allowedGenerated.add(relative);
      continue;
    }
    if (entity is! File || _isIgnored(segments)) continue;

    final name = segments.last.toLowerCase();
    if (lower.endsWith('.py') ||
        lower.endsWith('.pyc') ||
        _forbiddenFileNames.contains(name)) {
      violations.add('$relative (Python artifact)');
      continue;
    }

    if (relative == 'PYTHON_TO_DART_AUDIT.md' ||
        relative == 'PYTHON_TO_DART_FINAL_REPORT.md' ||
        relative == 'tool/verify_no_python.dart' ||
        !_shouldScan(name)) {
      continue;
    }

    String contents;
    try {
      contents = await entity.readAsString();
    } on FileSystemException {
      continue;
    }
    for (final match in _pythonCommand.allMatches(contents)) {
      final line =
          '\n'.allMatches(contents.substring(0, match.start)).length + 1;
      violations.add('$relative:$line (${match.group(0)!.trim()})');
    }
  }

  stdout.writeln(
      'Generated SDK Python helpers ignored: ${allowedGenerated.length}');
  for (final path in allowedGenerated) {
    stdout.writeln('  $path');
  }

  if (violations.isEmpty) {
    stdout.writeln('No project-owned Python artifacts or commands found.');
    return;
  }

  stderr.writeln('Project-owned Python violations: ${violations.length}');
  for (final violation in violations) {
    stderr.writeln('  $violation');
  }
  exitCode = 1;
}

bool _isIgnored(List<String> segments) {
  if (segments.any(
      (segment) => _ignoredDirectoryNames.contains(segment.toLowerCase()))) {
    return true;
  }
  return segments.length >= 3 &&
      segments[0].toLowerCase() == 'ios' &&
      segments[1].toLowerCase() == 'flutter' &&
      segments[2].toLowerCase() == 'ephemeral';
}

bool _shouldScan(String name) {
  if (name.startsWith('makefile')) return true;
  final dot = name.lastIndexOf('.');
  return dot >= 0 && _scannedExtensions.contains(name.substring(dot));
}

String _relativePath(String root, String path) {
  final normalizedRoot = root.replaceAll('\\', '/');
  final normalizedPath = path.replaceAll('\\', '/');
  return normalizedPath.substring(normalizedRoot.length).replaceFirst('/', '');
}
