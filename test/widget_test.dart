import 'package:flutter_test/flutter_test.dart';
import 'package:qistiraha/main.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const QistirahaApp(isLoggedIn: false));
    expect(find.byType(QistirahaApp), findsOneWidget);
  });
}
