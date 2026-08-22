import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rent_track/main.dart';

void main() {
  testWidgets('RentTrackApp launches to the Home tab',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const RentTrackApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('RentTrack'), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
