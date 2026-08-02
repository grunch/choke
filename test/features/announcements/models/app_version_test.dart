import 'package:flutter_test/flutter_test.dart';
import 'package:choke/features/announcements/models/app_version.dart';

void main() {
  group('tryParse', () {
    test('parses the three-component form the app itself produces', () {
      // Arrange + Act
      final version = AppVersion.tryParse('2.0.1');

      // Assert
      expect(version, isNotNull);
      expect(version!.major, 2);
      expect(version.minor, 0);
      expect(version.patch, 1);
      expect(version.preRelease, isEmpty);
    });

    test('treats missing components as zero', () {
      // Arrange + Act — a sender writing "2.1" means 2.1.0
      final short = AppVersion.tryParse('2.1');
      final bare = AppVersion.tryParse('2');

      // Assert
      expect(short, AppVersion.tryParse('2.1.0'));
      expect(bare, AppVersion.tryParse('2.0.0'));
    });

    test('parses a pre-release suffix into its identifiers', () {
      // Arrange + Act
      final version = AppVersion.tryParse('2.1.0-beta.1');

      // Assert
      expect(version, isNotNull);
      expect(version!.patch, 0);
      expect(version.preRelease, ['beta', '1']);
    });

    test('rejects build metadata rather than ignoring it', () {
      // Arrange + Act — semver excludes build metadata from precedence, so
      // accepting it would mean silently dropping part of what the sender
      // wrote (§2.1)

      // Assert
      expect(AppVersion.tryParse('2.1.0+454'), isNull);
      expect(AppVersion.tryParse('2.1.0-beta.1+454'), isNull);
    });

    test('rejects anything that is not a version', () {
      // Assert
      expect(AppVersion.tryParse(''), isNull);
      expect(AppVersion.tryParse('   '), isNull);
      expect(AppVersion.tryParse('latest'), isNull);
      expect(AppVersion.tryParse('2.x'), isNull);
      expect(AppVersion.tryParse('2.1.0.3'), isNull);
      expect(AppVersion.tryParse('-1.0.0'), isNull);
      expect(AppVersion.tryParse('2.1.0-'), isNull);
      expect(AppVersion.tryParse('2.1.0-beta..1'), isNull);
    });

    test('tolerates surrounding whitespace', () {
      // Arrange + Act
      final version = AppVersion.tryParse('  2.0.1  ');

      // Assert
      expect(version, AppVersion.tryParse('2.0.1'));
    });
  });

  group('ordering', () {
    test('orders by major, then minor, then patch', () {
      // Arrange
      final versions = [
        AppVersion.tryParse('2.0.1')!,
        AppVersion.tryParse('10.0.0')!,
        AppVersion.tryParse('2.1.0')!,
        AppVersion.tryParse('2.0.10')!,
      ]..sort();

      // Assert — 2.0.10 after 2.0.1 is the case a string compare gets wrong
      expect(
        versions.map((v) => v.toString()).toList(),
        ['2.0.1', '2.0.10', '2.1.0', '10.0.0'],
      );
    });

    test('a pre-release precedes its own release', () {
      // Arrange
      final beta = AppVersion.tryParse('2.1.0-beta.1')!;
      final release = AppVersion.tryParse('2.1.0')!;

      // Assert
      expect(beta.compareTo(release), lessThan(0));
      expect(release.compareTo(beta), greaterThan(0));
    });

    test('orders pre-release identifiers the way semver does', () {
      // Arrange — numeric identifiers compare numerically, alphanumeric ones
      // lexically, numeric ranks below alphanumeric, and a longer set of
      // identifiers wins a tie on the shared prefix
      final ordered = [
        '2.1.0-alpha',
        '2.1.0-alpha.1',
        '2.1.0-alpha.2',
        '2.1.0-alpha.10',
        '2.1.0-alpha.beta',
        '2.1.0-beta',
        '2.1.0',
      ].map((raw) => AppVersion.tryParse(raw)!).toList();

      // Act
      final shuffled = ordered.reversed.toList()..sort();

      // Assert
      expect(shuffled, ordered);
    });

    test('equal versions compare equal and hash alike', () {
      // Arrange
      final a = AppVersion.tryParse('2.1.0-beta.1')!;
      final b = AppVersion.tryParse('2.1.0-beta.1')!;

      // Assert
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.compareTo(b), 0);
    });
  });

  group('toString', () {
    test('round-trips through tryParse', () {
      // Arrange + Act + Assert
      for (final raw in ['2.0.1', '2.1.0-beta.1', '0.0.0']) {
        expect(AppVersion.tryParse(raw).toString(), raw);
      }
    });
  });
}
