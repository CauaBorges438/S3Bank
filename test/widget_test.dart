import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:s3_bank/providers/auth_provider.dart';
import 'package:s3_bank/screens/auth/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Garante que a tela de login não estoura ("BOTTOM OVERFLOWED") em
/// telas pequenas nem com a fonte do sistema ampliada.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpLogin(
    WidgetTester tester, {
    required Size size,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final auth = (await tester.runAsync(
      () async => AuthProvider(connect: false),
    ))!;

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('login em tela média, sem overflow', (tester) async {
    await pumpLogin(tester, size: const Size(412, 892));
    expect(tester.takeException(), isNull);
    expect(find.text('ENTRAR'), findsOneWidget);
  });

  testWidgets('login em tela pequena, sem overflow', (tester) async {
    await pumpLogin(tester, size: const Size(320, 568));
    expect(tester.takeException(), isNull);
    expect(find.text('ENTRAR'), findsOneWidget);
  });

  testWidgets('login com fonte ampliada, sem overflow', (tester) async {
    await pumpLogin(tester, size: const Size(360, 640), textScale: 1.4);
    expect(tester.takeException(), isNull);
    expect(find.text('ENTRAR'), findsOneWidget);
  });
}
