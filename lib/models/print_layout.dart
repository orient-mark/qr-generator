import '../course_qr.dart';

enum ExportKind {
  png('QR · PNG'),
  sheet('QR на А4 · PDF'),
  largePrism('Большая призма · PDF'),
  smallPrism('Маленькие призмы · PDF');

  const ExportKind(this.label);
  final String label;
  bool get isPrism => this == largePrism || this == smallPrism;
}

enum Assembly {
  glue('С клеем', 'Glue'),
  lock('Без клея', 'Lock'),
  none('Без крепления', 'None');

  const Assembly(this.label, this.fileTag);
  final String label;
  final String fileTag;
}

/// All layout distances are millimetres. One immutable choice per export.
class PrintLayout {
  const PrintLayout({
    required this.kind,
    this.perSheet = 4,
    this.assembly = Assembly.glue,
  }) : assert(perSheet == 4 || perSheet == 6 || perSheet == 8);

  final ExportKind kind;
  final int perSheet;
  final Assembly assembly;
  bool get small => kind == ExportKind.smallPrism;
  int get capacity => kind == ExportKind.sheet ? perSheet : (small ? 2 : 1);
  double get pageWidth => kind == ExportKind.sheet ? 210 : 297;
  double get pageHeight => kind == ExportKind.sheet ? 297 : 210;
  int get faces => small && assembly != Assembly.glue ? 4 : 3;
  double get faceWidth => small
      ? (assembly == Assembly.glue ? 86 : 65)
      : (assembly == Assembly.lock ? 86 : 90);
  double get faceHeight => small ? 90 : 140;
  double get blankWidth => !small && assembly == Assembly.lock ? 12 : 0;
  double get glueWidth => assembly == Assembly.glue ? 12 : 0;
  double get tabWidth => assembly == Assembly.lock ? 11 : 0;
  double get netWidth => blankWidth + faces * faceWidth + glueWidth + tabWidth;
  double get netLeft => (pageWidth - netWidth) / 2;
  double get slitX => small ? netLeft + faceWidth : netLeft + blankWidth;
  String get fileName => kind == ExportKind.sheet
      ? 'OrientMark_QR_A4_$perSheet.pdf'
      : 'OrientMark_Prisms_${small ? 'Small' : 'Large'}_${assembly.fileTag}_A4.pdf';
  String get dimensions => kind == ExportKind.sheet
      ? '$perSheet кода на листе · 2 × ${perSheet ~/ 2}'
      : '$faces ${faces == 3 ? 'грани' : 'панели'} · ${faceWidth.toInt()} × ${faceHeight.toInt()} мм';
  int pageCount(int itemCount) => (itemCount + capacity - 1) ~/ capacity;
  List<CourseQr> pageItems(List<CourseQr> items, int index) =>
      items.skip(index * capacity).take(capacity).toList(growable: false);
}
