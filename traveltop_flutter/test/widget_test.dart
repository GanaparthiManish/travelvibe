import 'package:flutter_test/flutter_test.dart';
import 'package:traveltop_app/main.dart';

void main() {
  testWidgets('TravelTop home screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TravelTopApp());
    expect(find.text('Good morning'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
  });
}
