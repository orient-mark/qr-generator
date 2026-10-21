import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orientmark_qr/course_qr.dart';
import 'package:orientmark_qr/print_exporter.dart';
import 'package:orientmark_qr/qr_exporter.dart';
import 'package:path/path.dart' as p;

import 'fonts.dart';
import 'output_directory.dart';

final layouts = [
  for (final count in [4, 6, 8])
    PrintLayout(kind: ExportKind.sheet, perSheet: count),
  for (final kind in [ExportKind.largePrism, ExportKind.smallPrism])
    for (final assembly in Assembly.values)
      PrintLayout(kind: kind, assembly: assembly),
];

void main() {
  test('all nets fit A4 and slit locations match the approved folds', () {
    for (final layout in layouts.where((value) => value.kind.isPrism)) {
      expect(layout.netLeft, greaterThanOrEqualTo(7.5));
      expect(layout.faceWidth, lessThan(148));
      expect(layout.faceHeight, lessThan(210));
      if (layout.assembly == Assembly.lock) {
        expect(
          layout.slitX,
          layout.netLeft + (layout.small ? layout.faceWidth : 12),
        );
        expect(layout.faces, layout.small ? 4 : 3);
      }
      if (layout.assembly == Assembly.glue) expect(layout.faces, 3);
    }
  });

  test(
    'pagination preserves selection order without duplicate or empty items',
    () {
      for (final layout in layouts) {
        for (var count = 0; count <= 72; count++) {
          final items = CourseQr.all.take(count).toList();
          final pages = [
            for (var i = 0; i < layout.pageCount(count); i++)
              layout.pageItems(items, i),
          ];
          expect(pages.expand((page) => page).toList(), items);
          if (count > 0) {
            expect(pages.last.length, inInclusiveRange(1, layout.capacity));
            expect(
              pages
                  .take(pages.length - 1)
                  .every((page) => page.length == layout.capacity),
              true,
            );
          }
        }
      }
    },
  );

  testWidgets(
    'exports every PDF variant, including all 72 points and odd remainders',
    (tester) async {
      await tester.runAsync(() async {
        await loadPreviewFonts();
        final parent = await createOutputDirectory('pdf-save');
        final folder = await Directory(
          p.join(parent.path, QrExporter.folderName),
        ).create(recursive: true);
        final existing = File(p.join(folder.path, 'CP_99.png'));
        await existing.writeAsString('preserve existing PNG');
        final exporter = PdfExporter();
        final manifest = <String, Object>{};
        for (final layout in layouts) {
          final items = layout.kind == ExportKind.sheet
              ? [
                  ...CourseQr.all.take(6),
                  CourseQr.start,
                  CourseQr.finish,
                  CourseQr.clear,
                ]
              : layout.kind == ExportKind.largePrism &&
                    layout.assembly == Assembly.lock
              ? CourseQr.all
              : layout.small
              ? [CourseQr.checkpoint(31), CourseQr.start, CourseQr.clear]
              : [
                  CourseQr.checkpoint(31),
                  CourseQr.start,
                  CourseQr.finish,
                  CourseQr.clear,
                ];
          final progress = <int>[];
          await exporter.save(
            parent.path,
            items,
            layout: layout,
            russian: true,
            onSaved: progress.add,
          );
          final capacity = layout.kind == ExportKind.sheet
              ? layout.perSheet
              : (layout.kind == ExportKind.smallPrism ? 2 : 1);
          final faces = layout.kind == ExportKind.sheet
              ? 1
              : (layout.kind == ExportKind.smallPrism &&
                        layout.assembly != Assembly.glue
                    ? 4
                    : 3);
          final pageCount = (items.length / capacity).ceil();
          expect(progress.last, items.length);
          expect(progress.length, pageCount);
          expect(await exporter.exists(parent.path, layout), true);
          final file = File(p.join(folder.path, layout.fileName));
          final bytes = await file.readAsBytes();
          expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
          expect(bytes.length, lessThan(40 * 1024 * 1024));
          manifest[layout.fileName] = {
            'width': layout.kind == ExportKind.sheet ? 210 : 297,
            'height': layout.kind == ExportKind.sheet ? 297 : 210,
            'pages': [
              for (var i = 0; i < pageCount; i++)
                [
                  for (final item in items.skip(i * capacity).take(capacity))
                    for (var face = 0; face < faces; face++)
                      jsonEncode({
                        'point': switch (item.kind) {
                          PointKind.checkpoint => {'checkpoint': item.number},
                          PointKind.start => 'start',
                          PointKind.finish => 'finish',
                          PointKind.clear => 'cleaning',
                        },
                      }),
                ],
            ],
          };
        }
        final manifestFile = File(p.join(parent.path, 'manifest.json'));
        await manifestFile.writeAsString(jsonEncode(manifest));
        final verification = await Process.run(
          Platform.environment['ORIENTMARK_TEST_PYTHON'] ?? 'python',
          ['tool/verify_pdf.py', manifestFile.path],
        );
        expect(
          verification.exitCode,
          0,
          reason:
              'PDF verification failed:\n'
              '${verification.stdout}\n${verification.stderr}',
        );
        expect(verification.stdout, contains('Verified 9 PDFs'));
        expect(await existing.readAsString(), 'preserve existing PNG');
        expect(
          () => exporter.save(
            parent.path,
            [],
            layout: layouts.first,
            russian: true,
          ),
          throwsArgumentError,
        );
        expect(
          () => exporter.save(
            parent.path,
            [CourseQr.start],
            layout: const PrintLayout(kind: ExportKind.png),
            russian: true,
          ),
          throwsArgumentError,
        );
      });
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
