import 'package:flutter_test/flutter_test.dart';
import 'package:qistiraha/main.dart';
import 'package:qistiraha/features/auth/models/user_role.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const QistirahaApp(isLoggedIn: false, role: UserRole.consumer),
    );
    expect(find.byType(QistirahaApp), findsOneWidget);
  });
}
