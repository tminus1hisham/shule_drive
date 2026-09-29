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
    await tester.pump(const Duration(seconds: 1)); // let entrance animations start (flutter_animate)
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
    await tester.pump(const Duration(seconds: 1)); // let entrance animations start (flutter_animate)
  });

  testWidgets('student proximity popup shows trip roster and quick actions', (
    tester,
  ) async {
    String? pickedStudentId;
    var openedChat = false;
    var openedStudents = false;
    var openedNotify = false;

    const amina = NextStudentTripTarget(
      id: '42',
      name: 'Amina Otieno',
      status: 'pending',
      destinationLabel: 'Kilimani stop',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Center(
                child: ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) {
                        return SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: NextStudentTripActionCard(
                              student: amina,
                              students: const [
                                amina,
                                NextStudentTripTarget(
                                  id: '43',
                                  name: 'Brian Mwangi',
                                  status: 'picked',
                                  destinationLabel: 'Saved home destination',
                                ),
                                NextStudentTripTarget(
                                  id: '44',
                                  name: 'Chao Njeri',
                                  status: 'dropped',
                                  destinationLabel: 'Lavington',
                                ),
                              ],
                              mode: StudentTripActionMode.pickup,
                              distanceMeters: 35,
                              modeForStudent: (student) =>
                                  student.status == 'picked'
                                  ? StudentTripActionMode.dropoff
                                  : StudentTripActionMode.pickup,
                              distanceForStudent: (student) =>
                                  student.id == '42' ? 35 : null,
                              onPickedUpStudent: (student) {
                                pickedStudentId = student.id;
                              },
                              onChat: () {
                                openedChat = true;
                              },
                              onStudents: () {
                                openedStudents = true;
                              },
                              onNotify: () {
                                openedNotify = true;
                              },
                              maxRosterHeight: 420,
                            ),
                          ),
                        );
                      },
                    );
                  },
                  child: const Text('Open proximity popup'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open proximity popup'));
    await tester.pumpAndSettle();

    expect(find.text('Trip students'), findsOneWidget);
    expect(
      find.text('3 total - 1 waiting - 1 picked - 1 dropped'),
      findsOneWidget,
    );
    expect(find.text('Amina Otieno'), findsOneWidget);
    expect(find.text('Brian Mwangi'), findsOneWidget);
    expect(find.text('35 m away'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Students'), findsOneWidget);
    expect(find.text('Notify'), findsOneWidget);

    await tester.tap(find.text('Notify'));
    await tester.tap(find.text('Chat'));
    await tester.tap(find.text('Students'));
    await tester.tap(find.widgetWithText(FilledButton, 'Picked up').first);

    expect(openedNotify, isTrue);
    expect(openedChat, isTrue);
    expect(openedStudents, isTrue);
    expect(pickedStudentId, '42');

    // The roster is taller than its viewport, so later students are only built
    // once they are scrolled into view.
    await tester.scrollUntilVisible(
      find.text('Chao Njeri'),
      200,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Chao Njeri'), findsOneWidget);
  });
}
