import 'package:flutter_test/flutter_test.dart';
import 'package:qistiraha/main.dart';
import 'package:qistiraha/features/auth/services/auth_service.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const QistirahaApp(initialDestination: AuthDestination.loggedOut),
    );
    expect(find.byType(QistirahaApp), findsOneWidget);
  });
}
