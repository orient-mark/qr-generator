import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';

import 'course_qr.dart';
import 'qr_exporter.dart';

import 'models/print_layout.dart';
export 'models/print_layout.dart';

class PrintPainter extends CustomPainter {
  PrintPainter(this.items, {required this.layout, required this.russian});
  final List<CourseQr> items;
  final PrintLayout layout;
  final bool russian;

  static void label(Canvas canvas, String value, Rect box, double size) {
    final text = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'Segoe UI',
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
    )..layout(maxWidth: box.width);
    text.paint(
      canvas,
      Offset(box.center.dx - text.width / 2, box.center.dy - text.height / 2),
    );
    text.dispose();
  }

  static void dashed(Canvas canvas, Offset a, Offset b, Paint stroke) {
    final length = (b - a).distance;
    if (length == 0) return;
    final direction = (b - a) / length;
    for (var distance = 0.0; distance < length; distance += 3.5) {
      canvas.drawLine(
        a + direction * distance,
        a + direction * math.min(distance + 2, length),
        stroke,
      );
    }
  }

  static void cutFold(
    Canvas canvas,
    double x,
    double top,
    double bottom,
    List<double> cuts,
    Paint stroke,
  ) {
    var y = top;
    for (final center in cuts) {
      dashed(canvas, Offset(x, y), Offset(x, center - 5.5), stroke);
      canvas.drawLine(Offset(x, center - 5.5), Offset(x, center + 5.5), stroke);
      y = center + 5.5;
    }
    dashed(canvas, Offset(x, y), Offset(x, bottom), stroke);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(
      size.width / layout.pageWidth,
      size.height / layout.pageHeight,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, layout.pageWidth, layout.pageHeight),
      Paint()..color = Colors.white,
    );
    final stroke = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.25;
    if (layout.kind == ExportKind.sheet) {
      _cards(canvas, stroke);
    } else {
      for (var i = 0; i < math.min(items.length, layout.capacity); i++) {
        _prism(canvas, stroke, items[i], layout.small ? 10 + i * 100.0 : 35);
      }
    }
    canvas.restore();
  }

  void _cards(Canvas canvas, Paint stroke) {
    const width = 95.0;
    final height = 277 / (layout.perSheet ~/ 2);
    final count = math.min(items.length, layout.capacity);
    for (var i = 0; i < count; i++) {
      final x = 10 + (i % 2) * width;
      final y = 10 + (i ~/ 2) * height;
      final corners = [
        Offset(x, y),
        Offset(x + width, y),
        Offset(x + width, y + height),
        Offset(x, y + height),
      ];
      final shared = [
        i >= 2,
        i.isEven && i + 1 < count,
        i + 2 < count,
        i.isOdd,
      ];
      for (var edge = 0; edge < 4; edge++) {
        final a = corners[edge];
        final b = corners[(edge + 1) % 4];
        if (shared[edge]) {
          // Consistent dash phase for both sides of a shared edge.
          final start = Offset(math.min(a.dx, b.dx), math.min(a.dy, b.dy));
          final end = Offset(math.max(a.dx, b.dx), math.max(a.dy, b.dy));
          dashed(canvas, start, end, stroke);
        } else {
          canvas.drawLine(a, b, stroke);
        }
      }
      final qrSize = math.min(width - 14, height - 21);
      canvas.save();
      canvas.translate(x + (width - qrSize) / 2, y + 6);
      QrExporter.paintMatrix(canvas, QrExporter.matrix(items[i]), qrSize);
      canvas.restore();
      label(
        canvas,
        items[i].label(russian),
        Rect.fromLTWH(x + 3, y + qrSize + 8, width - 6, 9),
        5,
      );
    }
  }

  void _prism(Canvas canvas, Paint stroke, CourseQr item, double top) {
    final w = layout.faceWidth;
    final h = layout.faceHeight;
    final outer = layout.netLeft;
    final left = outer + layout.blankWidth;
    final right = left + layout.faces * w;
    for (var i = 0; i < layout.faces; i++) {
      final x = left + i * w;
      canvas.drawPath(
        Path()
          ..moveTo(x, top + h)
          ..lineTo(x + w, top)
          ..lineTo(x + w, top + h)
          ..close(),
        Paint()..color = const Color(0xFFFF7900),
      );
      canvas.drawCircle(
        Offset(x + w / 2, top + (layout.small ? 5 : 9)),
        1.5,
        stroke,
      );
      label(
        canvas,
        item.label(russian),
        Rect.fromLTWH(
          x + 3,
          top + (layout.small ? 12 : 20),
          w - 6,
          layout.small ? 8 : 14,
        ),
        layout.small ? 5.5 : 8,
      );
      final qrSize = layout.small ? 45.0 : 62.0;
      canvas.save();
      canvas.translate(x + (w - qrSize) / 2, top + (layout.small ? 37 : 64));
      QrExporter.paintMatrix(canvas, QrExporter.matrix(item), qrSize);
      canvas.restore();
    }
    final blank = Paint()..color = const Color(0xFFF1F1F1);
    if (layout.blankWidth > 0) {
      canvas.drawRect(Rect.fromLTWH(outer, top, layout.blankWidth, h), blank);
    }
    if (layout.glueWidth > 0) {
      canvas.drawRect(Rect.fromLTWH(right, top, layout.glueWidth, h), blank);
    }
    final centers = [top + h * 0.3, top + h * 0.78];
    final outline = Path()
      ..moveTo(outer, top)
      ..lineTo(right + layout.glueWidth, top);
    if (layout.assembly == Assembly.lock) {
      for (final cy in centers) {
        outline
          ..lineTo(right, cy - 3)
          ..lineTo(right + 4, cy - 3)
          ..lineTo(right + 4, cy - 5)
          ..lineTo(right + 8, cy - 5)
          ..lineTo(right + 11, cy)
          ..lineTo(right + 8, cy + 5)
          ..lineTo(right + 4, cy + 5)
          ..lineTo(right + 4, cy + 3)
          ..lineTo(right, cy + 3);
        dashed(canvas, Offset(right, cy - 3), Offset(right, cy + 3), stroke);
      }
    }
    outline
      ..lineTo(right + layout.glueWidth, top + h)
      ..lineTo(outer, top + h)
      ..close();
    canvas.drawPath(outline, stroke);
    for (var i = 1; i < layout.faces; i++) {
      cutFold(
        canvas,
        left + i * w,
        top,
        top + h,
        layout.small && layout.assembly == Assembly.lock && i == 1
            ? centers
            : const [],
        stroke,
      );
    }
    if (layout.blankWidth > 0) {
      cutFold(canvas, left, top, top + h, centers, stroke);
    }
    if (layout.glueWidth > 0) {
      dashed(canvas, Offset(right, top), Offset(right, top + h), stroke);
    }
  }

  @override
  bool shouldRepaint(PrintPainter oldDelegate) => true;
}

class PdfExporter {
  Future<bool> exists(String parent, PrintLayout layout) =>
      File(p.join(parent, QrExporter.folderName, layout.fileName)).exists();

  Future<ui.Image> _pageImage(
    List<CourseQr> items, {
    required PrintLayout layout,
    required bool russian,
    int dpi = 300,
  }) async {
    final width = (layout.pageWidth / 25.4 * dpi).round();
    final height = (layout.pageHeight / 25.4 * dpi).round();
    final recorder = ui.PictureRecorder();
    PrintPainter(
      items,
      layout: layout,
      russian: russian,
    ).paint(Canvas(recorder), Size(width.toDouble(), height.toDouble()));
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
  }

  Future<Uint8List> renderPage(
    List<CourseQr> items, {
    required PrintLayout layout,
    required bool russian,
    int dpi = 300,
  }) async {
    final image = await _pageImage(
      items,
      layout: layout,
      russian: russian,
      dpi: dpi,
    );
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Не удалось подготовить страницу PDF');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image.dispose();
    }
  }

  Future<PdfImage> _losslessImage(
    PdfDocument document,
    List<CourseQr> items, {
    required PrintLayout layout,
    required bool russian,
  }) async {
    final image = await _pageImage(items, layout: layout, russian: russian);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) throw StateError('Не удалось подготовить страницу PDF');
      final rgba = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      // The page is fully opaque. Compress each RGB page immediately, rather
      // than retaining 72 uncompressed A4 rasters until PDF serialization.
      final rgb = Uint8List(image.width * image.height * 3);
      for (var source = 0, target = 0; source < rgba.length; source += 4) {
        rgb[target++] = rgba[source];
        rgb[target++] = rgba[source + 1];
        rgb[target++] = rgba[source + 2];
      }
      final compressed = ZLibEncoder().convert(rgb);
      // Use the library's deferred RGB image stream, with the PDF lossless
      // Flate filter replacing its default JPEG filter. No JPEG is generated.
      return PdfImage.jpegStream(
        document,
        width: image.width,
        height: image.height,
        length: compressed.length,
        write: (output) => output.putBytes(compressed),
      )..params['/Filter'] = const PdfName('/FlateDecode');
    } finally {
      image.dispose();
    }
  }

  Future<String> save(
    String parent,
    List<CourseQr> items, {
    required PrintLayout layout,
    required bool russian,
    void Function(int)? onSaved,
  }) async {
    if (items.isEmpty) throw ArgumentError('Выберите хотя бы одну точку');
    if (layout.kind == ExportKind.png) {
      throw ArgumentError('Выберите формат PDF');
    }
    final folder = await Directory(p.join(parent, QrExporter.folderName))
        .create(recursive: true);
    final document = PdfDocument();
    PdfInfo(document, title: 'OrientMark QR', author: 'OrientMark');
    final format = PdfPageFormat(
      layout.pageWidth * PdfPageFormat.mm,
      layout.pageHeight * PdfPageFormat.mm,
    );
    for (var index = 0; index < layout.pageCount(items.length); index++) {
      final page = layout.pageItems(items, index);
      final image = await _losslessImage(
        document,
        page,
        layout: layout,
        russian: russian,
      );
      PdfPage(
        document,
        pageFormat: format,
      ).getGraphics().drawImage(image, 0, 0, format.width, format.height);
      onSaved?.call(math.min((index + 1) * layout.capacity, items.length));
    }
    // Write after serialization so a preparation error preserves the old PDF.
    final bytes = await document.save(enableEventLoopBalancing: true);
    await File(p.join(folder.path, layout.fileName))
        .writeAsBytes(bytes, flush: true);
    return folder.path;
  }
}
