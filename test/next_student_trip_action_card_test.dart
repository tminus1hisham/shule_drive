import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shule_drive/utils/student_trip_logic.dart';
import 'package:shule_drive/widgets/next_student_trip_action_card.dart';

void main() {
  testWidgets('shows next pickup student with valid pickup actions', (
    tester,
  ) async {
    var picked = false;
    var absent = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NextStudentTripActionCard(
            student: const NextStudentTripTarget(
              id: '42',
              name: 'Amina Otieno',
              status: 'pending',
              destinationLabel: 'Kilimani',
            ),
            mode: StudentTripActionMode.pickup,
            distanceMeters: 85,
            onPickedUp: () => picked = true,
            onAbsent: () => absent = true,
            onDroppedOff: () {},
          ),
        ),
      ),
    );

    expect(find.text('Next pickup'), findsOneWidget);
    expect(find.text('Amina Otieno'), findsOneWidget);
    expect(find.text('85 m away'), findsOneWidget);

    await tester.tap(find.text('Picked up'));
    await tester.tap(find.text('Absent'));

    expect(picked, isTrue);
    expect(absent, isTrue);

    final dropButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Dropped off'),
    );
    expect(dropButton.onPressed, isNull);
  });

  testWidgets('shows next drop-off student with only drop-off enabled', (
    tester,
  ) async {
    var dropped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NextStudentTripActionCard(
            student: const NextStudentTripTarget(
              id: '42',
              name: 'Amina Otieno',
              status: 'picked',
              destinationLabel: 'Saved home destination',
            ),
            mode: StudentTripActionMode.dropoff,
            distanceMeters: 42,
            onPickedUp: () {},
            onAbsent: () {},
            onDroppedOff: () => dropped = true,
          ),
        ),
      ),
    );

    expect(find.text('Next drop-off'), findsOneWidget);

    await tester.tap(find.text('Dropped off'));
    expect(dropped, isTrue);

    final pickButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Picked up'),
    );
    final absentButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Absent'),
    );

    expect(pickButton.onPressed, isNull);
    expect(absentButton.onPressed, isNull);
  });
}

