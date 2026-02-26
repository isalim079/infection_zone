import 'package:flutter_test/flutter_test.dart';

import 'package:infection_zone_app/main.dart';

void main() {
  testWidgets('renders menu title', (WidgetTester tester) async {
    await tester.pumpWidget(const InfectionZoneApp());

    expect(find.text('INFECTION ZONE'), findsOneWidget);
  });
}
