import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

Future<Directory> createOutputDirectory(String name) async {
  final root = await Directory.systemTemp.createTemp('orientmark-qr-$name-');
  addTearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });
  return Directory(p.join(root.path, 'Русская папка')).create();
}
