import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s3_bank/widgets/state_view.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('lista vazia mostra o título e a explicação, sem botão', (tester) async {
    await tester.pumpWidget(_wrap(StateView.empty(
      title: 'Sem movimentações',
      message: 'Suas entradas aparecem aqui.',
    )));
    expect(find.text('Sem movimentações'), findsOneWidget);
    expect(find.text('Suas entradas aparecem aqui.'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsNothing);
  });

  testWidgets('erro oferece tentar de novo e chama a ação', (tester) async {
    var tentativas = 0;
    await tester.pumpWidget(_wrap(StateView.error(
      message: 'Sem conexão com o servidor',
      onAction: () => tentativas++,
    )));
    expect(find.text('Não foi possível carregar'), findsOneWidget);
    await tester.tap(find.text('Tentar de novo'));
    expect(tentativas, 1);
  });

  testWidgets('carregando mostra o indicador de progresso', (tester) async {
    await tester.pumpWidget(_wrap(StateView.loading()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
