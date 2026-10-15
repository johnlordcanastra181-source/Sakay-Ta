import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakay_ta/pages/admin/widgets/admin_widgets.dart';

void main() {
  testWidgets('a failed admin read stays an error and Retry can show real zero',
      (tester) async {
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdminDataStreamBuilder<int>(
          section: 'total_rides',
          streamFactory: () {
            attempts++;
            return attempts == 1
                ? Stream<int>.error(StateError('remote read failed'))
                : Stream<int>.value(0);
          },
          builder: (context, snapshot) => Text('${snapshot.requireData}'),
        ),
      ),
    ));

    await tester.pump();
    expect(find.textContaining('Unable to load this data right now.'),
        findsOneWidget);
    expect(find.text('0'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(attempts, 2);
    expect(find.text('0'), findsOneWidget);
  });
}
