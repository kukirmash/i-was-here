import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_was_here_client/agate/genome.dart';
import 'package:i_was_here_client/screens/info_screen.dart';

void main() {
  Future<void> pumpInfo(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: const InfoScreen(),
      ),
    );
    // Свечение редких камней пульсирует бесконечно, поэтому кадры
    // прокручиваем вручную, а не ждём полного покоя.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('все мутации подписаны на широком экране', (tester) async {
    await pumpInfo(tester, const Size(760, 2600));

    for (final mutation in mutationCatalog) {
      expect(find.text(mutation.title), findsOneWidget, reason: mutation.id);
      expect(find.text(mutation.description), findsOneWidget, reason: mutation.id);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('все мутации подписаны на узком экране', (tester) async {
    await pumpInfo(tester, const Size(390, 2600));

    for (final mutation in mutationCatalog) {
      expect(find.text(mutation.title), findsOneWidget, reason: mutation.id);
    }
    expect(tester.takeException(), isNull);
  });
}
