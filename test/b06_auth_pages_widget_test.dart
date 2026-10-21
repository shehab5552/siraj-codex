import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/app/app_bootstrap.dart';
import 'package:siraj/features/auth/login_page.dart';
import 'package:siraj/features/auth/signup_page.dart';
import 'package:siraj/features/auth/startup_session_resolver.dart';

void main() {
  testWidgets('Signup without approved KDF is entirely disabled', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SignupPage()));
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('signup-username')))
          .enabled,
      false,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('signup-submit')))
          .onPressed,
      isNull,
    );
    expect(find.textContaining('غير مفعّلة'), findsOneWidget);
  });

  testWidgets('Login without approved KDF is entirely disabled', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('login-password')))
          .enabled,
      false,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('login-submit')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('Signup rejects mismatched confirmation before callback', (
    tester,
  ) async {
    var called = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SignupPage(
          onCreateAccount:
              ({
                required username,
                required password,
                required confirmation,
              }) async {
                called = true;
              },
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('signup-username')), 'Student');
    await tester.enterText(
      find.byKey(const Key('signup-password')),
      'secret-A',
    );
    await tester.enterText(
      find.byKey(const Key('signup-confirmation')),
      'secret-B',
    );
    await tester.ensureVisible(find.byKey(const Key('signup-submit')));
    await tester.tap(find.byKey(const Key('signup-submit')));
    await tester.pump();
    expect(called, false);
    expect(find.text('كلمتا المرور غير متطابقتين'), findsOneWidget);
  });

  testWidgets('Signup delegates only validated data to supplied handler', (
    tester,
  ) async {
    String? capturedUsername;
    String? capturedPassword;
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SignupPage(
          onCreateAccount:
              ({
                required username,
                required password,
                required confirmation,
              }) async {
                capturedUsername = username;
                capturedPassword = password;
              },
          onCompleted: () => completed = true,
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('signup-username')),
      '  Student  ',
    );
    await tester.enterText(
      find.byKey(const Key('signup-password')),
      'sample-password',
    );
    await tester.enterText(
      find.byKey(const Key('signup-confirmation')),
      'sample-password',
    );
    await tester.ensureVisible(find.byKey(const Key('signup-submit')));
    await tester.tap(find.byKey(const Key('signup-submit')));
    await tester.pumpAndSettle();
    expect(capturedUsername, 'Student');
    expect(capturedPassword, 'sample-password');
    expect(completed, true);
  });

  testWidgets('Login rejects missing username before callback', (tester) async {
    var called = false;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          onLogin: ({required username, required password}) async {
            called = true;
          },
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('login-password')), 'sample');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();
    expect(called, false);
    expect(find.text('اسم المستخدم مطلوب'), findsOneWidget);
  });

  testWidgets('Login calls injected handler and completion', (tester) async {
    String? capturedUsername;
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          onLogin: ({required username, required password}) async {
            capturedUsername = username;
          },
          onCompleted: () => completed = true,
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('login-username')),
      ' student ',
    );
    await tester.enterText(find.byKey(const Key('login-password')), 'sample');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(capturedUsername, 'student');
    expect(completed, true);
  });

  testWidgets('Startup without account shows locked SignupPage', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppBootstrap(
          loadStartupForTesting: () async =>
              const StartupDecision(StartupStatus.accountRequired),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SignupPage), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('signup-submit')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('Startup requiring login shows locked LoginPage', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppBootstrap(
          loadStartupForTesting: () async =>
              const StartupDecision(StartupStatus.loginRequired),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('login-submit')))
          .onPressed,
      isNull,
    );
  });
}
