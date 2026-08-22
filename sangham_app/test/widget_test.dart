import 'package:flutter_test/flutter_test.dart';
import 'package:sangham_app/main.dart';
import 'package:sangham_app/screens/auth/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app starts on splash then shows login screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const SanghamApp());
    await tester.pump();

    expect(find.byType(SanghamApp), findsOneWidget);

    // Let the splash init delay fire, then run navigation and its fade transition.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
