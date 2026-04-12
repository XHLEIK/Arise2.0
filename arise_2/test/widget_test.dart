import 'package:flutter_test/flutter_test.dart';
import 'package:arise_2/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const AriseApp());
    expect(find.text('CMD_CENTER'), findsOneWidget);
  });
}
