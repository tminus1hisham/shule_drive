import 'package:flutter_test/flutter_test.dart';
import 'package:shule_drive/widgets/ui/staggered_entrance.dart';

void main() {
  test('every list item, however deep, finishes fully visible', () {
    for (final index in [0, 1, 8, 10, 11, 50]) {
      expect(StaggeredEntrance.progress(0, index), 0, reason: 'index $index');
      expect(StaggeredEntrance.progress(1, index), 1, reason: 'index $index');
    }
  });

  test('later items start later', () {
    expect(
      StaggeredEntrance.progress(0.3, 0),
      greaterThan(StaggeredEntrance.progress(0.3, 3)),
    );
  });
}
