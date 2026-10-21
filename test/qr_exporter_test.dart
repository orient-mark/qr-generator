import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:orientmark_qr/course_qr.dart';
import 'package:orientmark_qr/qr_exporter.dart';
import 'package:path/path.dart' as p;
import 'package:zxing2/qrcode.dart';

import 'fonts.dart';
import 'output_directory.dart';

void main() {
  testWidgets('all 144 labeled PNGs decode independently with ZXing', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await loadPreviewFonts();
      final samples = await createOutputDirectory('png-decode');
      final exporter = QrExporter();
      for (final russian in [false, true]) {
        for (final item in CourseQr.all) {
          final png = await exporter.render(item, russian: russian);
          expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
          final codec = await ui.instantiateImageCodec(png);
          final frame = await codec.getNextFrame();
          try {
            final pixels = (await frame.image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            final source = RGBLuminanceSource(
              frame.image.width,
              frame.image.height,
              pixels.buffer.asInt32List(
                pixels.offsetInBytes,
                pixels.lengthInBytes ~/ 4,
              ),
            );
            final result = QRCodeReader().decode(
              BinaryBitmap(
                HybridBinarizer(
                  source.crop(0, 0, frame.image.width, frame.image.width),
                ),
              ),
              hints: DecodeHints()..put(DecodeHintType.pureBarcode),
            );
            expect(
              result.text,
              item.payload,
              reason: '${item.fileName}, russian=$russian',
            );
          } catch (error) {
            fail('Cannot decode ${item.fileName}, russian=$russian: $error');
          } finally {
            frame.image.dispose();
            codec.dispose();
          }
          await File(
            p.join(samples.path, '${russian ? 'ru' : 'en'}_${item.fileName}'),
          ).writeAsBytes(png);
        }
      }
    });
  });

  testWidgets(
    'exports only chosen files to a Russian path and preserves unrelated files',
    (tester) async {
      await tester.runAsync(() async {
        final parent = await createOutputDirectory('png-save');
        final output = await Directory(
          p.join(parent.path, QrExporter.folderName),
        ).create(recursive: true);
        final keep = File(p.join(output.path, 'keep.txt'));
        await keep.writeAsString('keep');
        final exporter = QrExporter();
        final items = [CourseQr.checkpoint(42), CourseQr.clear];
        final counts = <int>[];
        await exporter.save(
          parent.path,
          items,
          russian: true,
          onSaved: counts.add,
        );
        expect(counts, [1, 2]);
        expect(await exporter.existingCount(parent.path, items), 2);
        expect(await File(p.join(output.path, 'CP_42.png')).exists(), true);
        expect(await File(p.join(output.path, 'CLEAR.png')).exists(), true);
        expect(await File(p.join(output.path, 'START.png')).exists(), false);
        await exporter.save(parent.path, items, russian: false);
        expect(await keep.readAsString(), 'keep');
        expect(
          () => exporter.save(parent.path, [], russian: false),
          throwsArgumentError,
        );
      });
    },
  );
}
