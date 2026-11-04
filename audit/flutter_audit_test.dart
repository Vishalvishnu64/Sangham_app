// Audit probes: these characterize current defects, not desired behavior.
// Network is mocked; no requests reach production.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sangham_app/providers/auth_provider.dart';
import 'package:sangham_app/screens/admin/add_contribution_screen.dart';
import 'package:sangham_app/screens/admin/admin_shell.dart';
import 'package:sangham_app/screens/auth/login_screen.dart';
import 'package:sangham_app/screens/user/loan_details_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('AUDIT: real API interestRate type crashes loan detail', (tester) async {
    final errors = <FlutterErrorDetails>[];
    final original = FlutterError.onError;
    FlutterError.onError = errors.add;
    try {
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home:LoanDetailsScreen(loanId:'audit-loan')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds:100));
      final error = errors.map((e)=>e.exceptionAsString()).join('; ');
      // ignore: avoid_print
      print('AUDIT_LOAN_DETAILS: $error');
      expect(error.toString(), contains('num'));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },()=>MockClient((r) async=>http.Response(jsonEncode({
      'loanId':'audit-loan','remainingPrincipal':1000,'currentMonthInterest':10,
      'interestRate':'1% per month','status':'active','repayments':[],
      'principalAmount':1000,'totalInterestPaid':0,'issuedDate':'2026-11-01T00:00:00Z'
    }),200)));
    } finally { FlutterError.onError = original; }
  });
  testWidgets('AUDIT: contribution confirmation leaks formatter expression', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: AddContributionScreen()));
      await tester.pumpAndSettle();
      // Locate by callback because button icon varies with build revision.
      final submit = find.byWidgetPredicate((w) => w is ElevatedButton && w.onPressed != null);
      expect(submit, findsOneWidget);
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      final message = (dialog.content as Text).data!;
      // ignore: avoid_print
      print('AUDIT_CONFIRMATION: $message');
      expect(message, contains('.format(amount)'));
      final renderingError = tester.takeException();
      if (renderingError != null) {
        // ignore: avoid_print
        print('AUDIT_RENDERING: $renderingError');
      }
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((r) async => http.Response(jsonEncode(r.url.path.endsWith('/members')
        ? {'members':[{'_id':'audit-member','name':'Audit Member','phone':'9000000001','role':'user','balance':0}]}
        : {'paid':[],'notPaid':[]}),200)));
  });

  testWidgets('AUDIT: global unauthorized leaves admin navigation visible', (tester) async {
    final auth = AuthProvider();
    await http.runWithClient(() async {
      await auth.login('9000000001', 'audit-password');
      expect(auth.isLoggedIn, isTrue);
      await tester.pumpWidget(ChangeNotifierProvider.value(value:auth, child:const MaterialApp(home:AdminShell())));
      await tester.pump();
      await tester.pump(const Duration(seconds:1));
      expect(find.byType(AdminShell),findsOneWidget);
      expect(find.byType(LoginScreen),findsNothing);
      expect(auth.isLoggedIn, isFalse);
      // ignore: avoid_print
      print('AUDIT_401: AdminShell remains; login route absent');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }, () => MockClient((r) async => r.url.path.endsWith('/auth/login')
        ? http.Response('{"token":"audit-token","user":{"id":"audit-admin","name":"Audit Admin","phone":"9000000001","role":"admin"}}',200)
        : http.Response('{"message":"Session expired"}',401)));
    auth.dispose();
  });

  testWidgets('AUDIT: login overflow at large text and short viewport', (tester) async {
    tester.view.physicalSize = const Size(320,480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final errors = <FlutterErrorDetails>[];
    final original = FlutterError.onError;
    FlutterError.onError = errors.add;
    try {
      await tester.pumpWidget(ChangeNotifierProvider(create:(_)=>AuthProvider(),child:MaterialApp(
        builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:const TextScaler.linear(2)),child:child!),
        home:const LoginScreen(),
      )));
      await tester.pumpAndSettle();
      // ignore: avoid_print
      print('AUDIT_LARGE_TEXT: ${errors.map((e)=>e.exceptionAsString()).join('; ')}');
      await tester.pumpWidget(const SizedBox());
    } finally { FlutterError.onError = original; }
  });
}
