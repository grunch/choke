import 'dart:convert';
import 'dart:io';

import 'announcement_draft.dart';

/// Validate an announcement draft and print the unsigned event to sign.
///
/// ```sh
/// dart run tool/announce.dart --template --out draft.json
/// # edit draft.json — all four locales, an expiry in the future
/// dart run tool/announce.dart draft.json --out event.json
/// nak event --sec <the offline key of §3.1> < event.json | nak publish wss://…
/// ```
///
/// It does not sign and does not publish, and that is the point: the key of
/// §3.1 lives offline, not on the machine that writes the copy. What this
/// removes is the *other* risk — that a malformed announcement goes out and
/// nothing anywhere says so, because the reader's failure mode is silence
/// (§6).
///
/// See docs/specs/announcement-channel.md.
Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln(_usage);
    return;
  }

  // `dart run` prints its own progress to stdout in a package with native
  // assets, so anything meant to be redirected has to be written to a file
  // rather than piped. --out is not a convenience; it is the only way to get
  // clean JSON out of this.
  final outIndex = args.indexOf('--out');
  // A trailing `--out` names no file. Falling back to stdout there would put
  // the JSON exactly where the flag exists to keep it out of.
  if (outIndex != -1 && outIndex + 1 >= args.length) {
    stderr.writeln(_usage);
    exitCode = 64; // EX_USAGE
    return;
  }
  final out = outIndex == -1 ? null : args[outIndex + 1];

  if (args.contains('--template')) {
    await _emit(_template, out);
    return;
  }

  // By position, not by value: `announce.dart draft.json --out draft.json` is a
  // sender overwriting their own draft, not an argument to drop.
  final paths = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (outIndex != -1 && (i == outIndex || i == outIndex + 1)) continue;
    if (args[i].startsWith('-')) continue;
    paths.add(args[i]);
  }
  if (paths.length != 1) {
    stderr.writeln(_usage);
    exitCode = 64; // EX_USAGE
    return;
  }

  final file = File(paths.single);
  if (!file.existsSync()) {
    stderr.writeln('No such draft: ${paths.single}');
    exitCode = 66; // EX_NOINPUT
    return;
  }

  final Object? parsed;
  try {
    parsed = jsonDecode(await file.readAsString());
  } catch (e) {
    stderr.writeln('${paths.single} is not JSON: $e');
    exitCode = 65; // EX_DATAERR
    return;
  }
  if (parsed is! Map<String, dynamic>) {
    stderr.writeln('${paths.single} must hold a JSON object');
    exitCode = 65;
    return;
  }

  try {
    final draft = AnnouncementDraft.fromJson(parsed);
    final event = draft.toUnsignedEvent(now: DateTime.now());
    final written = await _emit(
      const JsonEncoder.withIndent('  ').convert(event),
      out,
    );
    for (final warning in draft.warnings) {
      stderr.writeln('Warning: $warning');
    }
    // Only once the event is somewhere the sender can reach: a draft that
    // validated and then failed to land is not something to call done.
    if (written) {
      stderr.writeln(
        'Valid. Sign it, publish it, and check that it arrives — nothing '
        'downstream will tell you if it does not.',
      );
    }
  } on DraftErrors catch (errors) {
    stderr.writeln('This announcement would be dropped by the app:');
    stderr.writeln(errors);
    exitCode = 65;
  }
}

/// Where the JSON goes: a file if one was named, stdout otherwise. False if
/// the caller should not go on to claim success.
Future<bool> _emit(String content, String? out) async {
  if (out == null) {
    stdout.writeln(content);
    return true;
  }
  try {
    await File(out).writeAsString('$content\n');
    stderr.writeln('Wrote $out');
    return true;
  } on FileSystemException catch (e) {
    // A missing directory or a read-only path is a thing a person typed, not
    // a bug worth a stack trace.
    stderr.writeln('Could not write $out: ${e.osError?.message ?? e.message}');
    exitCode = 73; // EX_CANTCREAT
    return false;
  }
}

const String _usage = '''
Validate an announcement draft and print the unsigned event.

  dart run tool/announce.dart --template --out draft.json
  dart run tool/announce.dart draft.json --out event.json

Use --out rather than a shell redirect: `dart run` prints its own progress to
stdout in this package, and it would land in the file.

Signing and publishing are deliberately somebody else's job: the announcement
key lives offline (docs/specs/announcement-channel.md §3.1).

  --out FILE   write the JSON there instead of stdout
  --template   a draft with all four locales filled in
  --help       this
''';

const String _template = '''
{
  "d": "release-2-1",
  "expires_at": "2026-09-01T00:00:00Z",
  "url": "https://bjjscore.live/notes/2-1",
  "max_version": "2.1.0",
  "locales": {
    "en": {
      "title": "Version 2.1 is out",
      "body": "The match clock no longer drifts on long matches."
    },
    "es": {
      "title": "Ya salió la versión 2.1",
      "body": "El reloj ya no se desfasa en luchas largas."
    },
    "pt": {
      "title": "A versão 2.1 chegou",
      "body": "O relógio não atrasa mais em lutas longas."
    },
    "ja": {
      "title": "Version 2.1",
      "body": "Replace this with the Japanese copy before publishing."
    }
  }
}
''';
