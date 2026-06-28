import 'package:flutter_test/flutter_test.dart';
import 'package:giova_player/main.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const GiovaPlayerApp());
    await tester.pump();
    expect(find.text('GiovaPlayer'), findsOneWidget);
  });
}
