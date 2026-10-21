import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:orientmark_qr/course_qr.dart';

void main() {
  test('72 unique payloads follow the sportsman scanner contract', () {
    expect(CourseQr.all.length, 72);
    expect(CourseQr.all.map((item) => item.fileName).toSet().length, 72);
    for (var number = 31; number <= 99; number++) {
      final item = CourseQr.checkpoint(number);
      expect(jsonDecode(item.payload), {
        'point': {'checkpoint': number},
      });
      expect(item.label(true), 'КП $number');
      expect(item.label(false), 'CP $number');
    }
    expect(jsonDecode(CourseQr.start.payload), {'point': 'start'});
    expect(jsonDecode(CourseQr.finish.payload), {'point': 'finish'});
    expect(jsonDecode(CourseQr.clear.payload), {'point': 'cleaning'});
    expect(CourseQr.start.label(true), 'СТАРТ');
    expect(CourseQr.finish.label(true), 'ФИНИШ');
    expect(CourseQr.clear.label(true), 'ОЧИСТКА');
    expect(() => CourseQr.checkpoint(30), throwsRangeError);
    expect(() => CourseQr.checkpoint(100), throwsRangeError);
  });
}
