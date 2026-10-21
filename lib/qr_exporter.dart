import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:qr/qr.dart';

import 'course_qr.dart';

class QrExporter {
  static const folderName = 'OrientMark QR';
  static QrImage matrix(CourseQr item) => QrImage(
    QrCode.fromData(
      data: item.payload,
      errorCorrectLevel: QrErrorCorrectLevel.H,
    ),
  );
  static void paintMatrix(Canvas canvas, QrImage qr, double size) {
    const quiet = 4;
    final module = size / (qr.moduleCount + quiet * 2);
    canvas.drawRect(
      Offset.zero & Size.square(size),
      Paint()..color = Colors.white,
    );
    final black = Paint()
      ..color = Colors.black
      ..isAntiAlias = false;
    for (var row = 0; row < qr.moduleCount; row++) {
      for (var column = 0; column < qr.moduleCount; column++) {
        if (qr.isDark(row, column)) {
          canvas.drawRect(
            Rect.fromLTWH(
              (column + quiet) * module,
              (row + quiet) * module,
              module,
              module,
            ),
            black,
          );
        }
      }
    }
  }

  Future<Uint8List> render(CourseQr item, {required bool russian}) async {
    final qr = matrix(item);
    final width = (qr.moduleCount + 8) * 20;
    final height = width + 110;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = Colors.white,
    );
    paintMatrix(canvas, qr, width.toDouble());
    final label = TextPainter(
      text: TextSpan(
        text: item.label(russian),
        style: const TextStyle(
          color: Colors.black,
          fontSize: 60,
          fontFamily: 'Segoe UI',
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width.toDouble());
    label.paint(
      canvas,
      Offset((width - label.width) / 2, width + (110 - label.height) / 2),
    );
    final picture = recorder.endRecording();
    ui.Image? image;
    try {
      image = await picture.toImage(width, height);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Не удалось создать PNG');
      return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    } finally {
      image?.dispose();
      picture.dispose();
      label.dispose();
    }
  }

  Future<int> existingCount(String parent, List<CourseQr> items) async {
    var count = 0;
    for (final item in items) {
      if (await File(p.join(parent, folderName, item.fileName)).exists()) {
        count++;
      }
    }
    return count;
  }

  Future<String> save(
    String parent,
    List<CourseQr> items, {
    required bool russian,
    void Function(int)? onSaved,
  }) async {
    if (items.isEmpty) throw ArgumentError('Выберите хотя бы один код');
    final folder = await Directory(p.join(parent, folderName))
        .create(recursive: true);
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final bytes = await render(item, russian: russian);
      await File(p.join(folder.path, item.fileName))
          .writeAsBytes(bytes, flush: true);
      onSaved?.call(i + 1);
    }
    return folder.path;
  }
}

class QrMatrixPainter extends CustomPainter {
  QrMatrixPainter(this.item) : qr = QrExporter.matrix(item);
  final CourseQr item;
  final QrImage qr;
  @override
  void paint(Canvas canvas, Size size) =>
      QrExporter.paintMatrix(canvas, qr, size.shortestSide);
  @override
  bool shouldRepaint(QrMatrixPainter oldDelegate) =>
      oldDelegate.item.id != item.id;
}
