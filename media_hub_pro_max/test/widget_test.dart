import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_hub_pro_max/main.dart';

void main() {
  testWidgets('App démarre correctement', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MediaHubApp()));
    await tester.pumpAndSettle();
    expect(find.text('Media Hub Pro MAX'), findsOneWidget);
  });
}
