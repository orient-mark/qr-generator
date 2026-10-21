import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_info.dart';
import '../localization/app_strings.dart';
import '../course_qr.dart';
import '../qr_exporter.dart';
import '../print_exporter.dart';
import 'app_theme.dart';
import 'github_icon.dart';

class GeneratorPage extends StatefulWidget {
  const GeneratorPage({super.key});
  @override
  State<GeneratorPage> createState() => _GeneratorPageState();
}

class _GeneratorPageState extends State<GeneratorPage> {
  AppStrings get s => AppStrings.of(context);
  String? _language;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_language != s.language.code) {
      _language = s.language.code;
      message = null;
    }
  }

  final selected = CourseQr.all.map((item) => item.id).toSet();
  final exporter = QrExporter();
  final pdfExporter = PdfExporter();
  CourseQr preview = CourseQr.all.first;
  bool russian = false;
  ExportKind kind = ExportKind.png;
  Assembly assembly = Assembly.glue;
  int perSheet = 4;
  int previewPage = 0;
  bool saving = false;
  int completed = 0;
  String? folder;
  String? savedFolder;
  String? message;
  bool error = false;

  PrintLayout get layout =>
      PrintLayout(kind: kind, perSheet: perSheet, assembly: assembly);
  List<CourseQr> get chosen =>
      CourseQr.all.where((item) => selected.contains(item.id)).toList();
  int get pageIndex => previewPage.clamp(
    0,
    (layout.pageCount(selected.length) - 1).clamp(0, 72),
  );

  void toggle(CourseQr item) => setState(() {
    if (!selected.add(item.id)) selected.remove(item.id);
    preview = item;
    message = null;
  });

  Future<void> chooseFolder() async {
    try {
      final path = await getDirectoryPath(
        confirmButtonText: s.text('chooseFolder'),
      );
      if (path != null && mounted) {
        setState(() {
          folder = path;
          message = null;
        });
      }
    } catch (exception) {
      debugPrint('Generator operation failed: $exception');
      if (mounted) {
        setState(() {
          error = true;
          message = s.text('folderError');
        });
      }
    }
  }

  Future<void> generate() async {
    if (saving || selected.isEmpty) return;
    if (folder == null) await chooseFolder();
    if (folder == null || !mounted) return;
    final items = CourseQr.all
        .where((item) => selected.contains(item.id))
        .toList();
    final destination = folder!;
    final useRussian = russian;
    final exportLayout = layout;
    final usePdf = kind != ExportKind.png;
    setState(() {
      saving = true;
      completed = 0;
      message = null;
    });
    try {
      final existing = usePdf
          ? (await pdfExporter.exists(destination, exportLayout) ? 1 : 0)
          : await exporter.existingCount(destination, items);
      if (!mounted) return;
      if (existing > 0) {
        final replace = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(s.text('replaceTitle')),
            content: Text(
              usePdf
                  ? s.text('replacePdf', {'file': exportLayout.fileName})
                  : s.text('replacePng', {'count': existing}),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(s.text('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(s.text('replace')),
              ),
            ],
          ),
        );
        if (replace != true) return;
      }
      void updateProgress(int count) {
        if (mounted) setState(() => completed = count);
      }

      final result = usePdf
          ? await pdfExporter.save(
              destination,
              items,
              layout: exportLayout,
              russian: useRussian,
              onSaved: updateProgress,
            )
          : await exporter.save(
              destination,
              items,
              russian: useRussian,
              onSaved: updateProgress,
            );
      if (mounted) {
        setState(() {
          savedFolder = result;
          error = false;
          message = usePdf
              ? s.text('pdfSaved', {
                  'pages': exportLayout.pageCount(items.length),
                  'count': items.length,
                })
              : s.text('pngSaved', {'count': items.length});
        });
      }
    } catch (exception) {
      debugPrint('Generator operation failed: $exception');
      if (mounted) {
        setState(() {
          error = true;
          message = s.text('saveError', {
            'done': completed,
            'total': items.length,
          });
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> openReleases() async {
    await openExternalLink(releasesUri, 'versionError');
  }

  Future<void> openRepository() async {
    await openExternalLink(repositoryUri, 'repositoryError');
  }

  Future<void> openExternalLink(Uri uri, String errorKey) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Cannot open external URL');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.text(errorKey))));
      }
    }
  }

  Future<void> openFolder() async {
    try {
      await Process.start('explorer.exe', [savedFolder!]);
    } catch (exception) {
      debugPrint('Generator operation failed: $exception');
      if (mounted) {
        setState(() {
          error = true;
          message = s.text('openFolderError');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 1320),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(
                    MediaQuery.sizeOf(context).width < 700 ? 20 : 36,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(),
                      SizedBox(height: 24),
                      Text(
                        s.text('heading'),
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.7,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        s.text('intro'),
                        style: TextStyle(color: muted, fontSize: 15),
                      ),
                      SizedBox(height: 26),
                      AbsorbPointer(
                        absorbing: saving,
                        child: ExcludeFocus(
                          excluding: saving,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth < 880) {
                                return Column(
                                  children: [
                                    _selectionCard(),
                                    SizedBox(height: 20),
                                    _previewCard(),
                                  ],
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 7, child: _selectionCard()),
                                  SizedBox(width: 24),
                                  Expanded(flex: 4, child: _previewCard()),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: muted,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.text('compatibility'),
                              style: TextStyle(fontSize: 12, color: muted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(36, 12, 36, 20),
                child: Column(children: [_exportCard(), _footer()]),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _header() => Row(
    children: [
      Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: green,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 30),
      ),
      SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'OrientMark QR',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: -0.4,
              ),
            ),
            Text(
              s.text('tagline'),
              style: TextStyle(color: muted, fontSize: 10, letterSpacing: 1.4),
            ),
          ],
        ),
      ),
      SizedBox(
        width: 148,
        child: DropdownButtonFormField<String>(
          key: Key('app-language'),
          initialValue: s.language.code,
          isExpanded: true,
          decoration: InputDecoration(labelText: s.text('language')),
          items: [
            for (final language in s.catalog.languages)
              DropdownMenuItem(
                value: language.code,
                child: Text(language.name),
              ),
          ],
          onChanged: saving
              ? null
              : (code) {
                  if (code != null) s.changeLanguage(code);
                },
        ),
      ),
      SizedBox(width: 12),
      if (MediaQuery.sizeOf(context).width > 600)
        _Badge('WINDOWS', icon: Icons.desktop_windows_outlined),
    ],
  );

  Widget _selectionCard() => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                s.text('coursePoints'),
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
            ),
            _Badge('${selected.length} / 72', key: Key('selection-count')),
          ],
        ),
        SizedBox(height: 6),
        Text(
          s.text('selectionHint'),
          style: TextStyle(color: muted, fontSize: 13),
        ),
        SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => setState(() {
                selected.addAll(CourseQr.all.map((item) => item.id));
                message = null;
              }),
              icon: Icon(Icons.done_all, size: 18),
              label: Text(s.text('selectAll')),
            ),
            TextButton(
              onPressed: () => setState(() {
                selected.clear();
                message = null;
              }),
              child: Text(s.text('clearSelection')),
            ),
          ],
        ),
        SizedBox(height: 24),
        _SectionLabel(s.text('servicePoints')),
        SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final tiles = [
              _special(
                CourseQr.start,
                Icons.play_arrow_rounded,
                s.text('start'),
                Color(0xFF176B52),
              ),
              _special(
                CourseQr.finish,
                Icons.flag_outlined,
                s.text('finish'),
                Color(0xFFB9782B),
              ),
              _special(
                CourseQr.clear,
                Icons.restart_alt_rounded,
                s.text('clear'),
                Color(0xFF64768C),
              ),
            ];
            if (constraints.maxWidth < 440) {
              return Column(
                children: [
                  for (final tile in tiles)
                    Padding(padding: EdgeInsets.only(bottom: 8), child: tile),
                ],
              );
            }
            return Row(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) SizedBox(width: 10),
                  Expanded(child: tiles[i]),
                ],
              ],
            );
          },
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Divider(height: 1, color: line),
        ),
        Row(
          children: [
            Expanded(child: _SectionLabel(s.text('checkpoints'))),
            Text('31–99', style: TextStyle(color: muted, fontSize: 12)),
          ],
        ),
        SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = (constraints.maxWidth / 54).floor().clamp(1, 11);
            final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in CourseQr.all.where(
                  (item) => item.kind == PointKind.checkpoint,
                ))
                  SizedBox(width: width, height: 36, child: _checkpoint(item)),
              ],
            );
          },
        ),
        SizedBox(height: 18),
        Row(
          children: [
            Icon(Icons.touch_app_outlined, size: 16, color: muted),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                s.text('previewHint'),
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _special(CourseQr item, IconData icon, String name, Color color) {
    final checked = selected.contains(item.id);
    return Semantics(
      checked: checked,
      label: name,
      child: Material(
        color: checked ? color.withValues(alpha: 0.06) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: checked ? color.withValues(alpha: 0.4) : line,
          ),
        ),
        child: InkWell(
          key: Key('point-${item.id}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => toggle(item),
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 23, color: color),
                    Spacer(),
                    Icon(
                      checked
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 19,
                      color: checked ? color : muted,
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  name,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _checkpoint(CourseQr item) {
    final checked = selected.contains(item.id);
    final active = preview.id == item.id;
    return Semantics(
      checked: checked,
      label: s.text('checkpointLabel', {'number': item.number!}),
      child: Material(
        color: active
            ? green
            : checked
            ? Color(0xFFEEF5EF)
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
          side: BorderSide(
            color: active
                ? green
                : checked
                ? Color(0xFFCFE0D4)
                : line,
          ),
        ),
        child: InkWell(
          key: Key('point-${item.id}'),
          onTap: () => toggle(item),
          borderRadius: BorderRadius.circular(9),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${item.number}',
                  style: TextStyle(
                    color: active
                        ? Colors.white
                        : checked
                        ? green
                        : muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (checked) ...[
                  SizedBox(width: 3),
                  Icon(
                    Icons.check,
                    size: 11,
                    color: active ? Colors.white : green,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _printPage() => AspectRatio(
    aspectRatio: layout.pageWidth / layout.pageHeight,
    child: CustomPaint(
      key: Key('print-preview'),
      painter: PrintPainter(
        layout.pageItems(chosen, pageIndex),
        layout: layout,
        russian: russian,
      ),
    ),
  );

  Future<void> _enlargePage() => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 1000),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(s.text('pageTitle', {'page': pageIndex + 1})),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close),
                  ),
                ],
              ),
              Flexible(child: _printPage()),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _previewCard() => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                s.text('formatPreview'),
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
            ),
            Icon(Icons.visibility_outlined, size: 20, color: muted),
          ],
        ),
        SizedBox(height: 18),
        DropdownButtonFormField<ExportKind>(
          key: Key('export-kind'),
          initialValue: kind,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: s.text('exportFormat'),
            border: OutlineInputBorder(),
          ),
          items: [
            for (final value in ExportKind.values)
              DropdownMenuItem(
                value: value,
                child: Text(
                  s.text('format_${value.name}'),
                  style: TextStyle(fontSize: 13),
                ),
              ),
          ],
          onChanged: saving
              ? null
              : (value) => setState(() {
                  kind = value!;
                  previewPage = 0;
                  message = null;
                }),
        ),
        if (kind == ExportKind.sheet) ...[
          SizedBox(height: 16),
          Text(s.text('onSheet'), style: TextStyle(color: muted, fontSize: 12)),
          SizedBox(height: 8),
          SegmentedButton<int>(
            key: Key('sheet-capacity'),
            segments: [
              for (final count in [4, 6, 8])
                ButtonSegment(
                  value: count,
                  label: Text(s.text('quantity', {'count': count})),
                ),
            ],
            selected: {perSheet},
            showSelectedIcon: false,
            onSelectionChanged: saving
                ? null
                : (value) => setState(() {
                    perSheet = value.first;
                    previewPage = 0;
                    message = null;
                  }),
          ),
        ],
        if (kind.isPrism) ...[
          SizedBox(height: 16),
          DropdownButtonFormField<Assembly>(
            key: Key('assembly'),
            initialValue: assembly,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: s.text('assembly'),
              border: OutlineInputBorder(),
            ),
            items: [
              for (final value in Assembly.values)
                DropdownMenuItem(
                  value: value,
                  child: Text(s.text('assembly_${value.name}')),
                ),
            ],
            onChanged: saving
                ? null
                : (value) => setState(() {
                    assembly = value!;
                    message = null;
                  }),
          ),
        ],
        SizedBox(height: 18),
        if (kind != ExportKind.png) ...[
          _printPage(),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                key: Key('previous-page'),
                onPressed: saving || pageIndex == 0
                    ? null
                    : () => setState(() => previewPage = pageIndex - 1),
                tooltip: s.text('previousPage'),
                icon: Icon(Icons.chevron_left),
              ),
              Text(
                selected.isEmpty
                    ? s.text('noSelection')
                    : s.text('pageCount', {
                        'page': pageIndex + 1,
                        'pages': layout.pageCount(selected.length),
                      }),
                key: Key('page-count'),
                style: TextStyle(fontSize: 12),
              ),
              IconButton(
                key: Key('next-page'),
                onPressed:
                    saving || pageIndex + 1 >= layout.pageCount(selected.length)
                    ? null
                    : () => setState(() => previewPage = pageIndex + 1),
                tooltip: s.text('nextPage'),
                icon: Icon(Icons.chevron_right),
              ),
            ],
          ),
          Text(
            s.text(
              kind == ExportKind.sheet ? 'sheetDimensions' : 'prismDimensions',
              {
                'count': perSheet,
                'rows': perSheet ~/ 2,
                'faces': layout.faces,
                'parts': s.text(layout.faces == 3 ? 'faces' : 'panels'),
                'width': layout.faceWidth.toInt(),
                'height': layout.faceHeight.toInt(),
              },
            ),
            style: TextStyle(fontSize: 12, color: muted),
          ),
          SizedBox(height: 6),
          Text(
            s.text('printInstructions', {
              'orientation': s.text(
                kind == ExportKind.sheet ? 'portrait' : 'landscape',
              ),
            }),
            style: TextStyle(fontSize: 12, color: muted),
          ),
          if (kind.isPrism) ...[
            SizedBox(height: 6),
            Text(
              assembly == Assembly.glue
                  ? s.text('glueInstructions')
                  : assembly == Assembly.lock
                  ? s.text('lockInstructions')
                  : s.text('noneInstructions'),
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ],
          TextButton.icon(
            onPressed: selected.isEmpty ? null : _enlargePage,
            icon: Icon(Icons.zoom_in),
            label: Text(s.text('enlarge')),
          ),
        ] else
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Color(0xFFF3F5F1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: EdgeInsets.fromLTRB(10, 10, 10, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 260),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: CustomPaint(painter: QrMatrixPainter(preview)),
                      ),
                    ),
                  ),
                  Text(
                    preview.label(russian),
                    key: Key('preview-label'),
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        SizedBox(height: 14),
        Row(
          children: [
            Icon(Icons.image_outlined, size: 16, color: muted),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                kind == ExportKind.png ? preview.fileName : layout.fileName,
                key: Key('output-name'),
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ),
            _Badge(kind == ExportKind.png ? 'PNG' : 'PDF · А4'),
          ],
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Divider(height: 1, color: line),
        ),
        CheckboxListTile(
          key: Key('russian-labels'),
          value: russian,
          onChanged: saving
              ? null
              : (value) => setState(() {
                  russian = value!;
                  message = null;
                }),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            s.text('russianLabels'),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'КП · СТАРТ · ФИНИШ · ОЧИСТКА',
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          s.text('labelsHint'),
          style: TextStyle(fontSize: 12, color: muted),
        ),
      ],
    ),
  );

  Widget _footer() => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 12,
    children: [
      TextButton.icon(
        onPressed: openReleases,
        icon: Icon(Icons.open_in_new, size: 16),
        label: Text(s.text('versionLink', {'version': appVersion})),
      ),
      Text(
        '$appDeveloper · $appOrganization',
        style: TextStyle(color: muted, fontSize: 11),
      ),
      TextButton.icon(
        onPressed: openRepository,
        icon: GitHubIcon(),
        label: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GitHub'),
            Text(
              s.text('sourceCode'),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _exportCard() => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(s.text('saveSet')),
        SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final destination = Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Color(0xFFF5F1E7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.folder_outlined, color: Color(0xFFA88843)),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folder ?? s.text('folderPrompt'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        s.text('folderWillCreate'),
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            );
            final actions = Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton(
                  onPressed: saving ? null : chooseFolder,
                  child: Text(s.text('chooseFolder')),
                ),
                FilledButton.icon(
                  key: Key('generate'),
                  onPressed: saving || selected.isEmpty ? null : generate,
                  icon: saving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.file_download_outlined, size: 20),
                  label: Text(
                    saving
                        ? s.text('progress', {
                            'done': completed,
                            'total': selected.length,
                          })
                        : '${s.text(kind == ExportKind.png ? 'createPng' : 'createPdf')} (${selected.length})',
                  ),
                ),
              ],
            );
            if (constraints.maxWidth < 800) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [destination, SizedBox(height: 18), actions],
              );
            }
            return Row(
              children: [
                Expanded(child: destination),
                SizedBox(width: 20),
                actions,
              ],
            );
          },
        ),
        if (saving)
          Padding(
            padding: EdgeInsets.only(top: 18),
            child: LinearProgressIndicator(
              value: completed / selected.length,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        if (message != null) ...[
          SizedBox(height: 14),
          Row(
            children: [
              Icon(
                error ? Icons.error_outline : Icons.check_circle_outline,
                size: 18,
                color: error ? Colors.red.shade700 : green,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  message!,
                  style: TextStyle(
                    color: error ? Colors.red.shade700 : green,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (savedFolder != null && !saving)
          TextButton.icon(
            onPressed: openFolder,
            icon: Icon(Icons.folder_open_outlined, size: 18),
            label: Text(s.text('openFolder')),
          ),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: line),
      boxShadow: [
        BoxShadow(
          color: ink.withValues(alpha: 0.025),
          blurRadius: 20,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Material(color: Colors.transparent, child: child),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
      color: muted,
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, {this.icon, super.key});
  final String text;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Color(0xFFEDF3ED),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: green),
          SizedBox(width: 6),
        ],
        Text(
          text,
          style: TextStyle(
            color: green,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
