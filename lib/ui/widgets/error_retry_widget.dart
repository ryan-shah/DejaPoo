import 'package:dejapoo/ui/theme/tokens.dart';
import 'package:flutter/material.dart';

/// A centered "something went wrong" message with an optional retry button.
///
/// Used for async error states (e.g. a Riverpod `AsyncValue.error` branch)
/// across the home timeline and reports screens so error handling stays
/// consistent.
class ErrorRetryWidget extends StatelessWidget {
  const ErrorRetryWidget({
    required this.error,
    this.onRetry,
    super.key,
  });

  /// The error to display. Rendered via its `toString()`.
  final Object error;

  /// Called when the user taps "Retry". When null, no retry button is shown.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Something went wrong: $error',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: Spacing.md),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
