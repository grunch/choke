import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/match_sound_provider.dart';

/// The two cues the match clock makes: a bell when the fight starts, and a horn
/// when regulation time runs out.
///
/// Sound is a courtesy here, never a dependency — the clock and the scoreboard
/// are the truth, and a match must run identically on a device that cannot make
/// a sound at all. Every implementation therefore fails quietly: missing audio
/// hardware, a denied audio focus or an unregistered plugin gets logged and
/// dropped, never surfaced and never thrown at the caller.
abstract class MatchSounds {
  /// Decode and prepare both cues ahead of time.
  ///
  /// Optional — playing works without it — but a cue that has to load an asset
  /// first arrives after the moment it was meant to mark.
  Future<void> warmUp();

  /// The fight is on.
  Future<void> playStart();

  /// Regulation time is over.
  Future<void> playEnd();

  Future<void> dispose();
}

/// A [MatchSounds] that plays nothing.
///
/// The default for [MatchControlNotifier], which keeps tests off the platform
/// channels: constructing a real player in a test binding leaves an unhandled
/// `MissingPluginException` behind, and no test should have to know that the
/// match clock makes noise.
class SilentMatchSounds implements MatchSounds {
  const SilentMatchSounds();

  @override
  Future<void> warmUp() async {}

  @override
  Future<void> playStart() async {}

  @override
  Future<void> playEnd() async {}

  @override
  Future<void> dispose() async {}
}

/// Wraps another [MatchSounds] behind an on/off switch.
///
/// [enabled] is a plain field rather than something read from a provider,
/// because the thing being wrapped owns prepared audio players and must survive
/// the toggle: rebuilding it on every flick would tear those players down, and
/// doing so mid-match would mean a referee who muted and unmuted the app got
/// silence for the rest of the fight.
///
/// Warming up is deliberately never gated. The assets get loaded even while
/// muted, so that switching the sound back on is instant instead of costing the
/// next cue an asset decode.
class SwitchableMatchSounds implements MatchSounds {
  SwitchableMatchSounds(this._inner, {this.enabled = true});

  final MatchSounds _inner;

  /// Whether cues are audible. Safe to change at any time, including during a
  /// match.
  bool enabled;

  @override
  Future<void> warmUp() => _inner.warmUp();

  @override
  Future<void> playStart() => enabled ? _inner.playStart() : Future.value();

  @override
  Future<void> playEnd() => enabled ? _inner.playEnd() : Future.value();

  @override
  Future<void> dispose() => _inner.dispose();
}

/// Plays the bundled cues from `assets/audio/` through `audioplayers`.
class AudioPlayerMatchSounds implements MatchSounds {
  /// `audioplayers` resolves [AssetSource] paths under `assets/`, so these two
  /// are `assets/audio/…` on disk.
  static const startAsset = 'audio/match_start.wav';
  static const endAsset = 'audio/match_end.wav';

  /// Anything slower than this and the cue is late enough to be worse than
  /// none — give up and let the clock speak for itself.
  static const _playTimeout = Duration(seconds: 5);

  /// Audible over a gym even with the phone on silent: a referee who silenced
  /// their notifications did not mean to silence the match clock. It only ducks
  /// whatever else is playing rather than seizing the audio focus outright,
  /// which would be a rude way to spend a second and a half.
  static final AudioContext _context = AudioContextConfig(
    focus: AudioContextConfigFocus.duckOthers,
    respectSilence: false,
  ).build();

  /// One player per cue. Each is prepared once and replayed from its start,
  /// which is far quicker than loading an asset at the instant the clock hits
  /// zero; sharing a single player would also make the end horn wait for the
  /// start bell's source to be swapped out from under it.
  AudioPlayer? _startPlayer;
  AudioPlayer? _endPlayer;

  Future<void>? _warmingUp;

  /// Both cues are loaded and can be fired. Until then — and forever after a
  /// failed warm-up — playing is a no-op: a device whose audio stack refused to
  /// prepare an asset will not recover halfway through a match, and retrying on
  /// every whistle would only add stalls to a screen that must stay responsive.
  bool _ready = false;

  bool _disposed = false;

  @override
  Future<void> warmUp() => _warmingUp ??= _prepare();

  /// Whether the platform channels a player needs are reachable at all.
  ///
  /// Constructing an [AudioPlayer] reaches for them immediately, and does it
  /// inside a future nobody owns: with no binding up, the failure surfaces as
  /// an unhandled error that no `try` of ours can be wrapped around. So the
  /// question gets asked first, where it can still be answered with a `false`.
  static bool get _hasBinding {
    try {
      // Reading `instance` is the whole check — it throws when nothing has
      // called `ensureInitialized`.
      ServicesBinding.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _prepare() async {
    if (!_hasBinding) {
      debugPrint('MatchSounds: no platform binding, running silent');
      return;
    }

    try {
      final start = _startPlayer = AudioPlayer(playerId: 'choke_match_start');
      final end = _endPlayer = AudioPlayer(playerId: 'choke_match_end');

      await Future.wait([
        _prepareOne(start, startAsset),
        _prepareOne(end, endAsset),
      ]);

      _ready = !_disposed;
    } catch (e) {
      debugPrint('MatchSounds: audio unavailable, running silent: $e');
    }
  }

  Future<void> _prepareOne(AudioPlayer player, String asset) async {
    // Hold on to the decoded source once the cue finishes. These two are played
    // over and over across a session, and re-decoding every time is exactly how
    // a bell ends up landing after the fighters have already engaged.
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setAudioContext(_context);
    await player.setSource(AssetSource(asset));
  }

  @override
  Future<void> playStart() => _fire(_startPlayer, startAsset);

  @override
  Future<void> playEnd() => _fire(_endPlayer, endAsset);

  Future<void> _fire(AudioPlayer? player, String asset) async {
    if (!_ready || _disposed || player == null) return;
    try {
      // Rewind before resuming: a cue fired again while it is still ringing —
      // a referee restarting a match they just started — has to start over
      // rather than be swallowed as "already playing".
      await player.seek(Duration.zero).timeout(_playTimeout);
      await player.resume().timeout(_playTimeout);
    } catch (e) {
      debugPrint('MatchSounds: could not play $asset: $e');
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _ready = false;

    final players = [_startPlayer, _endPlayer].nonNulls.toList();
    _startPlayer = null;
    _endPlayer = null;

    for (final player in players) {
      try {
        await player.dispose();
      } catch (e) {
        debugPrint('MatchSounds: could not release a player: $e');
      }
    }
  }
}

/// The players themselves, behind their own provider so that a test can swap
/// them out without losing the switch wiring in [matchSoundsProvider].
///
/// Deliberately not scoped to a single match: they are prepared once and reused
/// for every match the referee runs, so only the first one of the day pays to
/// decode the assets.
final matchSoundsPlayerProvider = Provider<MatchSounds>((ref) {
  final player = AudioPlayerMatchSounds();
  ref.onDispose(player.dispose);
  return player;
});

/// The app-wide match cues, gated by the user's preference.
final matchSoundsProvider = Provider<MatchSounds>((ref) {
  final sounds = SwitchableMatchSounds(ref.watch(matchSoundsPlayerProvider));

  // The preference is pushed in rather than watched: watching would rebuild
  // this provider on every toggle, and with it the prepared players — silently
  // undoing the warm-up in the middle of a match.
  ref.listen<bool>(
    matchSoundEnabledProvider,
    (_, enabled) => sounds.enabled = enabled,
    fireImmediately: true,
  );

  return sounds;
});
