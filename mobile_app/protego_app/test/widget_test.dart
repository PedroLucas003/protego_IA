import 'package:flutter_test/flutter_test.dart';
import 'package:protego_app/main.dart';

void main() {
  testWidgets('App inicia com título Protego IA', (WidgetTester tester) async {
    await tester.pumpWidget(const ProtegoApp());
    await tester.pump();
    expect(find.text('Protego IA'), findsOneWidget);
  });
}
