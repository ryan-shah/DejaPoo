import 'package:dejapoo/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isVersionString', () {
    test('accepts the CI version format', () {
      expect(isVersionString('0.1.19'), isTrue);
      expect(isVersionString('1.0'), isTrue);
      expect(isVersionString('12'), isTrue);
    });

    test('accepts a leading v, as GitHub tags carry', () {
      expect(isVersionString('v0.1.19'), isTrue);
    });

    test('rejects the local dev build and other non-numeric versions', () {
      expect(isVersionString('dev'), isFalse);
      expect(isVersionString(''), isFalse);
      expect(isVersionString('0.1.19-beta'), isFalse);
      expect(isVersionString('0..1'), isFalse);
    });
  });

  group('compareVersions', () {
    test('orders by numeric component, not string order', () {
      // '0.1.9' > '0.1.19' as strings; the commit count makes this the common
      // case once the app passes build 9.
      expect(compareVersions('0.1.19', '0.1.9'), greaterThan(0));
      expect(compareVersions('0.1.9', '0.1.19'), lessThan(0));
    });

    test('compares major and minor before the build count', () {
      expect(compareVersions('1.0.0', '0.9.99'), greaterThan(0));
      expect(compareVersions('0.2.1', '0.10.1'), lessThan(0));
    });

    test('equal versions compare equal', () {
      expect(compareVersions('0.1.19', '0.1.19'), 0);
    });

    test('ignores a leading v on either side', () {
      expect(compareVersions('v0.1.19', '0.1.19'), 0);
      expect(compareVersions('v0.1.20', 'v0.1.19'), greaterThan(0));
    });

    test('treats missing components as zero', () {
      expect(compareVersions('0.1', '0.1.0'), 0);
      expect(compareVersions('0.1.1', '0.1'), greaterThan(0));
    });
  });
}
