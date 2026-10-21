import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orientmark_qr/main.dart';
import 'package:orientmark_qr/print_exporter.dart';

import 'fonts.dart';
import 'output_directory.dart';

void main() {
  testWidgets(
    'selection, every format, assembly, pagination and Russian labels work',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(loadPreviewFonts);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(key: boundary, child: const OrientMarkQrApp()),
      );
      await tester.pumpAndSettle();
      Future<void> chooseKind(ExportKind kind) async {
        await tester.ensureVisible(find.byKey(const Key('export-kind')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('export-kind')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(kind.label).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      Future<void> chooseAssembly(Assembly value) async {
        await tester.ensureVisible(find.byKey(const Key('assembly')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('assembly')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(value.label).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      PrintPainter painter() =>
          tester
                  .widget<CustomPaint>(
                    find.byKey(const Key('print-preview')).first,
                  )
                  .painter!
              as PrintPainter;
      Future<void> screenshot(String name) async {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          try {
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            final output = await createOutputDirectory('widget-preview');
            await File('${output.path}/$name.png').writeAsBytes(
              bytes.buffer.asUint8List(
                bytes.offsetInBytes,
                bytes.lengthInBytes,
              ),
            );
          } finally {
            image.dispose();
          }
        });
      }

      expect(find.text('72 / 72'), findsOneWidget);
      await chooseKind(ExportKind.largePrism);
      for (final value in Assembly.values) {
        await chooseAssembly(value);
        expect(painter().layout.assembly, value);
        expect(find.text('Страница 1 / 72'), findsOneWidget);
      }
      await chooseAssembly(Assembly.lock);
      await screenshot('ui-large-lock');
      await tester.tap(find.text('Увеличить страницу'));
      await tester.pumpAndSettle();
      expect(find.text('Предпросмотр А4 · Страница 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await chooseKind(ExportKind.smallPrism);
      for (final value in Assembly.values) {
        await chooseAssembly(value);
        expect(painter().layout.faces, value == Assembly.glue ? 3 : 4);
        expect(painter().items.length, 2);
      }
      await tester.tap(find.byKey(const Key('next-page')));
      await tester.pumpAndSettle();
      expect(find.text('Страница 2 / 36'), findsOneWidget);
      expect(painter().items.first.number, 33);
      await chooseKind(ExportKind.sheet);
      for (final count in [4, 6, 8]) {
        await tester.tap(find.text('$count шт.'));
        await tester.pumpAndSettle();
        expect(painter().layout.perSheet, count);
        expect(painter().items.length, count);
      }
      await screenshot('ui-sheet-eight');
      await chooseKind(ExportKind.png);
      await tester.tap(find.text('Снять выбор'));
      await tester.pumpAndSettle();
      expect(find.text('0 / 72'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('generate')))
            .onPressed,
        isNull,
      );
      await chooseKind(ExportKind.sheet);
      expect(painter().items, isEmpty);
      expect(find.text('Нет выбранных точек'), findsOneWidget);
      await chooseKind(ExportKind.png);
      await tester.tap(find.byKey(const Key('point-CP_31')));
      await tester.pumpAndSettle();
      expect(find.text('1 / 72'), findsOneWidget);
      await tester.tap(find.byKey(const Key('russian-labels')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('preview-label'))).data,
        'КП 31',
      );
      await tester.tap(find.byKey(const Key('point-START')));
      await tester.tap(find.byKey(const Key('point-CLEAR')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('preview-label'))).data,
        'ОЧИСТКА',
      );
      await chooseKind(ExportKind.smallPrism);
      await chooseAssembly(Assembly.lock);
      await tester.tap(find.byKey(const Key('next-page')));
      await tester.pumpAndSettle();
      expect(find.text('Страница 2 / 2'), findsOneWidget);
      expect(painter().items.length, 1);
      expect(painter().items.single.id, 'CLEAR');
      expect(painter().russian, true);
      await screenshot('ui-small-remainder');
      tester.view.physicalSize = const Size(440, 800);
      await tester.pumpAndSettle();
      for (final kind in ExportKind.values) {
        await chooseKind(kind);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
