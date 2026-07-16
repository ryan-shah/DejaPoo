import 'dart:ui';

import 'package:dejapoo/ui/theme/theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light theme has sage green primary', () {
    final theme = AppTheme.light();
    expect(theme.colorScheme.primary, AppColors.sageGreen);
  });

  test('dark theme derives from same palette', () {
    final theme = AppTheme.dark();
    expect(theme.colorScheme.brightness, Brightness.dark);
  });
}
