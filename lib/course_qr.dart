import 'dart:convert';

enum PointKind { checkpoint, start, finish, clear }

class CourseQr {
  const CourseQr._(this.id, this.kind, this.point, [this.number]);
  factory CourseQr.checkpoint(int number) {
    if (number < 31 || number > 99) throw RangeError.range(number, 31, 99);
    return CourseQr._('CP_$number', PointKind.checkpoint, {
      'checkpoint': number,
    }, number);
  }
  static const start = CourseQr._('START', PointKind.start, 'start');
  static const finish = CourseQr._('FINISH', PointKind.finish, 'finish');
  static const clear = CourseQr._('CLEAR', PointKind.clear, 'cleaning');
  static final List<CourseQr> all = List.unmodifiable([
    for (var number = 31; number <= 99; number++) CourseQr.checkpoint(number),
    start,
    finish,
    clear,
  ]);
  final String id;
  final PointKind kind;
  final Object point;
  final int? number;
  String get fileName => '$id.png';
  String get payload => jsonEncode({'point': point});
  String label(bool russian) => switch (kind) {
    PointKind.checkpoint => '${russian ? 'КП' : 'CP'} $number',
    PointKind.start => russian ? 'СТАРТ' : 'START',
    PointKind.finish => russian ? 'ФИНИШ' : 'FINISH',
    PointKind.clear => russian ? 'ОЧИСТКА' : 'CLEAR',
  };
}
