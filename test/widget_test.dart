import 'package:flutter_test/flutter_test.dart';
import 'package:worthit_app/main.dart';

void main() {
  testWidgets('App renders dashboard smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const WorthItApp());

    // Verify that the greeting text is rendered
    expect(find.textContaining('Hello'), findsOneWidget);
  });
}
