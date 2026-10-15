import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
// Tests use the interface of the already installed path_provider plugin.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sakay_ta/services/database_service.dart';

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

Future<void> useIsolatedDatabase() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final oldPaths = PathProviderPlatform.instance;
  final oldTarget = debugDefaultTargetPlatformOverride;
  final oldFixtures = DatabaseService.allowTestAccountsOverride;
  final tempRoot = Directory.systemTemp.absolute.path;
  final directory =
      await Directory.systemTemp.createTemp('sakay_real_data_test_');
  PathProviderPlatform.instance = _TestPaths(directory.path);
  debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  DatabaseService.allowTestAccountsOverride = false;
  await DatabaseService.instance.database;
  addTearDown(() async {
    await DatabaseService.instance.close();
    PathProviderPlatform.instance = oldPaths;
    debugDefaultTargetPlatformOverride = oldTarget;
    DatabaseService.allowTestAccountsOverride = oldFixtures;
    if (directory.absolute.path
        .startsWith('$tempRoot${Platform.pathSeparator}')) {
      await directory.delete(recursive: true);
    }
  });
}
