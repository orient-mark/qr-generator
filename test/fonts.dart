import 'dart:io';

import 'package:flutter/services.dart';

Future<void> loadPreviewFonts() async {
  if (!Platform.isWindows) return;
  final loader = FontLoader('Segoe UI');
  for (final path in [
    'C:/Windows/Fonts/segoeui.ttf',
    'C:/Windows/Fonts/segoeuib.ttf',
  ]) {
    final file = File(path);
    if (await file.exists()) {
      loader.addFont(
        Future.value(ByteData.sublistView(await file.readAsBytes())),
      );
    }
  }
  await loader.load();
  final sdk = Platform.environment['FLUTTER_ROOT'];
  if (sdk != null) {
    final icons = File(
      '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (await icons.exists()) {
      await (FontLoader('MaterialIcons')..addFont(
            Future.value(ByteData.sublistView(await icons.readAsBytes())),
          ))
          .load();
    }
  }
}
