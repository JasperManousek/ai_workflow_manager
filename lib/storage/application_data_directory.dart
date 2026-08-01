import 'dart:io';

import 'package:path/path.dart' as path;

Directory defaultApplicationDataDirectory() {
  final environment = Platform.environment;
  late final String basePath;

  if (Platform.isLinux) {
    basePath = environment['XDG_DATA_HOME'] ??
        path.join(
          environment['HOME'] ?? Directory.systemTemp.path,
          '.local',
          'share',
        );
  } else if (Platform.isMacOS) {
    basePath = path.join(
      environment['HOME'] ?? Directory.systemTemp.path,
      'Library',
      'Application Support',
    );
  } else if (Platform.isWindows) {
    basePath = environment['LOCALAPPDATA'] ??
        environment['APPDATA'] ??
        Directory.systemTemp.path;
  } else {
    basePath = Directory.systemTemp.path;
  }

  return Directory(path.join(basePath, 'ai_workflow_manager'));
}
