import 'package:flutter/foundation.dart' show listEquals;

/// A semantic version, as far as announcement targeting needs one.
///
/// Two things this parses, and one it deliberately refuses:
///
/// - The app's own version, which `package_info_plus` reports as the pubspec
///   version **without** the build number — `2.0.1`, never `2.0.1+454`.
/// - A `min_version` / `max_version` bound written by the sender, which may be
///   shorter (`2.1`) or carry a pre-release suffix (`2.1.0-beta.1`).
/// - **Build metadata is rejected**, not ignored. Semver excludes it from
///   precedence, so `2.1.0+454` and `2.1.0` compare equal — accepting the
///   bound would mean silently dropping the part the sender clearly meant
///   something by. An unreadable bound invalidates the announcement (§2.1),
///   which is the loud failure that gets it fixed.
///
/// See docs/specs/announcement-channel.md §2.1.
class AppVersion implements Comparable<AppVersion> {
  final int major;
  final int minor;
  final int patch;

  /// The dot-separated identifiers after `-`, empty for a release version.
  final List<String> preRelease;

  const AppVersion._(this.major, this.minor, this.patch, this.preRelease);

  static final RegExp _numeric = RegExp(r'^\d+$');
  static final RegExp _identifier = RegExp(r'^[0-9A-Za-z-]+$');

  /// The version in [raw], or null if it is not one.
  ///
  /// Null rather than throwing: every caller of this is reading a value some
  /// human typed into a tag, which is not a programming error.
  static AppVersion? tryParse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    // Build metadata: rejected outright, before anything else can make sense
    // of the rest. See the class comment.
    if (text.contains('+')) return null;

    final dash = text.indexOf('-');
    final core = dash == -1 ? text : text.substring(0, dash);
    final suffix = dash == -1 ? '' : text.substring(dash + 1);

    final numbers = core.split('.');
    if (numbers.isEmpty || numbers.length > 3) return null;
    for (final part in numbers) {
      if (!_numeric.hasMatch(part)) return null;
    }

    final List<String> preRelease;
    if (dash == -1) {
      preRelease = const [];
    } else {
      // A trailing `-` or an empty identifier (`2.1.0-beta..1`) is malformed,
      // not an empty pre-release.
      if (suffix.isEmpty) return null;
      preRelease = suffix.split('.');
      for (final identifier in preRelease) {
        if (identifier.isEmpty) return null;
        if (!_identifier.hasMatch(identifier)) return null;
      }
    }

    int at(int index) => index < numbers.length ? int.parse(numbers[index]) : 0;

    return AppVersion._(at(0), at(1), at(2), List.unmodifiable(preRelease));
  }

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);

    // A pre-release precedes its own release: 2.1.0-beta.1 < 2.1.0.
    if (preRelease.isEmpty && other.preRelease.isEmpty) return 0;
    if (preRelease.isEmpty) return 1;
    if (other.preRelease.isEmpty) return -1;

    final shared = preRelease.length < other.preRelease.length
        ? preRelease.length
        : other.preRelease.length;
    for (var i = 0; i < shared; i++) {
      final result = _compareIdentifiers(preRelease[i], other.preRelease[i]);
      if (result != 0) return result;
    }

    // Every shared identifier is equal, so the longer set wins:
    // 2.1.0-alpha < 2.1.0-alpha.1.
    return preRelease.length.compareTo(other.preRelease.length);
  }

  /// Semver's rule for two pre-release identifiers: numeric ones compare
  /// numerically, everything else compares ASCII, and numeric always ranks
  /// below non-numeric.
  static int _compareIdentifiers(String a, String b) {
    final aNumeric = _numeric.hasMatch(a);
    final bNumeric = _numeric.hasMatch(b);
    if (aNumeric && bNumeric) return int.parse(a).compareTo(int.parse(b));
    if (aNumeric) return -1;
    if (bNumeric) return 1;
    return a.compareTo(b);
  }

  bool operator <(AppVersion other) => compareTo(other) < 0;
  bool operator <=(AppVersion other) => compareTo(other) <= 0;
  bool operator >(AppVersion other) => compareTo(other) > 0;
  bool operator >=(AppVersion other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is AppVersion &&
      other.major == major &&
      other.minor == minor &&
      other.patch == patch &&
      listEquals(other.preRelease, preRelease);

  @override
  int get hashCode =>
      Object.hash(major, minor, patch, Object.hashAll(preRelease));

  @override
  String toString() {
    final core = '$major.$minor.$patch';
    return preRelease.isEmpty ? core : '$core-${preRelease.join('.')}';
  }
}
