import 'package:flutter_test/flutter_test.dart';
import 'package:shule_drive/api/services/auth_service.dart';
import 'package:shule_drive/widgets/mandatory_password_dialog.dart';

void main() {
  group('login mustChangePassword flag', () {
    Map<String, dynamic> body(Map<String, dynamic> extra) => {
      'token': 'x.eyJzdWIiOiIxIn0.y',
      'userType': 'driver',
      'userId': '1',
      ...extra,
    };

    test('read from the response, also inside data', () {
      expect(
        LoginResponse.fromJson(body({'mustChangePassword': true}))
            .mustChangePassword,
        isTrue,
      );
      expect(
        LoginResponse.fromJson({'data': body({'isFirstLogin': 'true'})})
            .mustChangePassword,
        isTrue,
      );
    });

    test('defaults to false when the backend does not send it', () {
      expect(LoginResponse.fromJson(body({})).mustChangePassword, isFalse);
    });
  });

  test('classifies change-password errors', () {
    expect(
      classifyPasswordChangeError('Current password is incorrect'),
      PasswordChangeFailure.wrongPassword,
    );
    expect(
      classifyPasswordChangeError('HTTP error 500: NullReferenceException'),
      PasswordChangeFailure.savedDespiteServerError,
    );
    expect(
      classifyPasswordChangeError('No internet'),
      PasswordChangeFailure.other,
    );
  });
}
