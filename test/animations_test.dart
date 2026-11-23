import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s3_bank/animations/animations.dart';
import 'package:s3_bank/providers/savings_provider.dart';

void main() {
  group('formatBrl', () {
    test('usa ponto nos milhares e vírgula nos centavos', () {
      expect(formatBrl(1234.5), '1.234,50');
      expect(formatBrl(0), '0,00');
      expect(formatBrl(-1234567.891), '-1.234.567,89');
      expect(formatBrl(999.999), '1.000,00');
    });
  });

  group('animações', () {
    testWidgets('FadeSlideIn começa invisível e termina totalmente visível',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FadeSlideIn(
            delay: Duration(milliseconds: 100),
            child: Text('oi'),
          ),
        ),
      );

      final fade = find.descendant(
        of: find.byType(FadeSlideIn),
        matching: find.byType(FadeTransition),
      );
      expect(tester.widget<FadeTransition>(fade).opacity.value, 0);

      await tester.pumpAndSettle();
      expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
    });

    testWidgets('AnimatedCounter termina no valor formatado', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AnimatedCounter(value: 1234.5))),
      );
      await tester.pumpAndSettle();
      expect(find.text('R\$ 1.234,50'), findsOneWidget);
    });

    testWidgets('TapScale não atrapalha o clique do botão filho',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TapScale(
                child: OutlinedButton(
                  onPressed: () => taps++,
                  child: const Text('Guardar valor'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Guardar valor'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });

  group('SavingsProvider (centavos)', () {
    test('somar 0,10 + 0,20 dá exatamente 0,30', () {
      final savings = SavingsProvider()..resetForNewAccount();
      savings.createGoal(
        name: 'Teste',
        icon: Icons.savings_outlined,
        targetAmount: 10,
      );
      final id = savings.goals.first.id;

      savings.deposit(id, 0.1);
      savings.deposit(id, 0.2);

      expect(savings.goals.first.currentAmount, 0.3);
    });

    test('valores zero ou negativos são ignorados', () {
      final savings = SavingsProvider()..resetForNewAccount();
      savings.createGoal(
        name: 'Teste',
        icon: Icons.savings_outlined,
        targetAmount: 10,
      );
      final id = savings.goals.first.id;

      savings.deposit(id, 0);
      savings.deposit(id, -5);
      expect(savings.goals.first.currentAmount, 0);
      expect(savings.withdraw(id, -5), 0);
    });
  });
}
