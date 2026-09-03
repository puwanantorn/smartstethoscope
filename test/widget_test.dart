// Basic smoke test for the Smart Stethoscope app.

import 'package:flutter_test/flutter_test.dart';

import 'package:smartstethoscope/main.dart';

void main() {
  testWidgets('App launches and shows the home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartStethoscopeApp());
    await tester.pump();

    expect(find.text('Smart Stethoscope'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Records'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
