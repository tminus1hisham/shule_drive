import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shule_drive/providers/app_provider.dart';
import 'package:shule_drive/providers/auth_provider.dart';
import 'package:shule_drive/providers/trip_provider.dart';
import 'package:shule_drive/screens/trips/manage/manage_master_trips_screen.dart';
import 'package:shule_drive/widgets/ui/app_text_field.dart';

void main() {
  testWidgets('trip time picker preserves selection and cancellation', (
    tester,
  ) async {
    dotenv.testLoad(fileInput: 'API_BASE_URL=https://example.test');
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = MockClient((_) async => http.Response('[]', 200));
    addTearDown(client.close);

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppProvider()),
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => TripProvider()),
          ],
          child: const MaterialApp(home: ManageMasterTripsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final field = tester.widget<AppTextField>(
        find.byWidgetPredicate(
          (widget) => widget is AppTextField && widget.label == 'Trip Time',
        ),
      );
      field.controller!.text = '23:15';
      await tester.tap(find.byTooltip('Choose trip time'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TimePickerDialog>(find.byType(TimePickerDialog))
            .initialTime,
        const TimeOfDay(hour: 23, minute: 15),
      );
      Navigator.of(
        tester.element(find.byType(TimePickerDialog)),
      ).pop(const TimeOfDay(hour: 0, minute: 5));
      await tester.pumpAndSettle();
      expect(field.controller!.text, '12:05 AM');

      await tester.tap(find.byTooltip('Choose trip time'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TimePickerDialog>(find.byType(TimePickerDialog))
            .initialTime,
        const TimeOfDay(hour: 0, minute: 5),
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(field.controller!.text, '12:05 AM');
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });
}
