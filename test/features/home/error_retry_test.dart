import 'package:dejapoo/ui/widgets/error_retry_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the error message', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ErrorRetryWidget(error: 'boom'),
        ),
      ),
    );

    expect(find.text('Something went wrong: boom'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('shows a retry button that invokes the callback when onRetry is set',
      (WidgetTester tester) async {
    int retryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorRetryWidget(
            error: 'boom',
            onRetry: () => retryCount++,
          ),
        ),
      ),
    );

    expect(find.text('Something went wrong: boom'), findsOneWidget);
    final Finder retryButton = find.widgetWithText(OutlinedButton, 'Retry');
    expect(retryButton, findsOneWidget);

    await tester.tap(retryButton);
    await tester.pump();

    expect(retryCount, 1);
  });
}
