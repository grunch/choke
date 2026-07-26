import 'package:flutter/material.dart';

/// The colours the full-screen board is painted in.
///
/// Two of them. The board is not a normal screen that can take the app's theme
/// and be done with it: it is a wall display read from across a mat, so every
/// surface, glow and alpha was chosen against one background. Swapping only the
/// background leaves white text on near-white and glows that do nothing.
///
/// [dark] is the original, which follows choke-scoreboard. [light] is design 3A
/// — the same structure and the same animations on a light surface, with the
/// athlete's colour carrying the accent instead of glowing in the dark.
class BoardPalette {
  const BoardPalette({
    required this.background,
    required this.text,
    required this.label,
    required this.loserVeil,
    required this.cardSurface,
    required this.cardBorder,
    required this.cardShadow,
    required this.cardShadowBlur,
    required this.cardShadowOffset,
    required this.vs,
    required this.advLabel,
    required this.advValue,
    required this.advSurface,
    required this.penLabel,
    required this.penValue,
    required this.penSurface,
    required this.liveText,
    required this.liveSurface,
    required this.waiting,
    required this.paused,
    required this.canceled,
    required this.neutralWinner,
    required this.edgeGlowAlpha,
    required this.scoreGlowAlpha,
    required this.dotGlowAlpha,
    required this.halfWashStrong,
    required this.halfWashFade,
    required this.halfWashFadeStop,
    required this.halfWashEndStop,
    required this.darkenWinner,
    required this.backLabel,
  });

  /// Behind everything.
  final Color background;

  /// Names, scores, the clock — whatever has to be read first.
  final Color text;

  /// Column headers and explanations.
  final Color label;

  /// Laid over the losing half. Carries its own alpha, because it is the
  /// background veiling what is under it: light on light, dark on dark.
  final Color loserVeil;

  /// The clock card and the winner banner.
  final Color cardSurface;
  final Color cardBorder;
  final Color cardShadow;
  final double cardShadowBlur;
  final Offset cardShadowOffset;

  /// The "VS" under the clock, which is meant to be barely there.
  final Color vs;

  final Color advLabel;
  final Color advValue;

  /// The colour the advantage chip's background and border are drawn from.
  final Color advSurface;

  final Color penLabel;
  final Color penValue;
  final Color penSurface;

  /// A running match: the pill's word, and the colour its background and border
  /// are drawn from — not the same green in the light theme.
  final Color liveText;
  final Color liveSurface;

  final Color waiting;
  final Color paused;
  final Color canceled;

  /// A finished match nobody won.
  final Color neutralWinner;

  /// How strongly a fighter's colour glows off the edge bar, the score and the
  /// name dot. A glow reads as light in the dark and as a shadow in daylight, so
  /// these are not the same numbers in both themes.
  final double edgeGlowAlpha;
  final double scoreGlowAlpha;
  final double dotGlowAlpha;

  /// The diagonal wash behind each half: [halfWashStrong] at the edge, through
  /// [halfWashFade] at [halfWashFadeStop], to nothing at [halfWashEndStop].
  final double halfWashStrong;
  final double halfWashFade;
  final double halfWashFadeStop;
  final double halfWashEndStop;

  /// Whether a fighter's colour needs darkening before it carries text.
  ///
  /// A gi colour picked to glow on black — 3A's own default is `#13c88a` — is
  /// too light to read as a word on white. The light theme darkens it; the dark
  /// theme wants it exactly as the fighter chose it.
  final bool darkenWinner;

  /// The back control, which sits over the wash rather than on a surface.
  final Color backLabel;

  static const dark = BoardPalette(
    background: Color(0xFF05070E),
    text: Colors.white,
    label: Color(0xFF5F6D8A),
    loserVeil: Color(0x9E05070E),
    cardSurface: Color(0x08FFFFFF),
    cardBorder: Color(0x17FFFFFF),
    cardShadow: Color(0x73000000),
    cardShadowBlur: 60,
    cardShadowOffset: Offset.zero,
    vs: Color(0x29FFFFFF),
    advLabel: Color(0xFFF4B400),
    advValue: Color(0xFFFFD451),
    advSurface: Color(0xFFF4B400),
    penLabel: Color(0xFFF87171),
    penValue: Color(0xFFFCA5A5),
    penSurface: Color(0xFFF87171),
    liveText: Color(0xFF2EE08A),
    liveSurface: Color(0xFF2EE08A),
    waiting: Color(0xFF8A97B2),
    paused: Color(0xFFF5B800),
    canceled: Color(0xFFF87171),
    neutralWinner: Colors.white,
    edgeGlowAlpha: .6,
    scoreGlowAlpha: .6,
    dotGlowAlpha: .6,
    halfWashStrong: .30,
    halfWashFade: .05,
    halfWashFadeStop: .55,
    halfWashEndStop: .78,
    darkenWinner: false,
    backLabel: Color(0x99FFFFFF),
  );

  /// Design 3A.
  static const light = BoardPalette(
    background: Color(0xFFF4F6FB),
    text: Color(0xFF0D1526),
    label: Color(0xFF68758F),
    // The veil is the background itself, so the losing half reads as washed out
    // rather than shaded.
    loserVeil: Color(0xB8F4F6FB),
    cardSurface: Colors.white,
    cardBorder: Color(0x1A0D1526),
    cardShadow: Color(0x240D1526),
    cardShadowBlur: 46,
    cardShadowOffset: Offset(0, 18),
    vs: Color(0x290D1526),
    advLabel: Color(0xFFA16207),
    advValue: Color(0xFF854D0E),
    advSurface: Color(0xFFCA8A04),
    penLabel: Color(0xFFDC2626),
    penValue: Color(0xFF991B1B),
    penSurface: Color(0xFFDC2626),
    // The pill's word and the surface under it are deliberately different
    // greens: the text has to carry contrast, the surface has to stay quiet.
    liveText: Color(0xFF0F9D58),
    liveSurface: Color(0xFF10B981),
    // Not specified by 3A. Taken from the palette's own vocabulary rather than
    // invented: the label grey for a match that has not begun, and the chip
    // colours for the two states already spoken in gold and red.
    waiting: Color(0xFF68758F),
    paused: Color(0xFFA16207),
    canceled: Color(0xFFDC2626),
    neutralWinner: Color(0xFF0D1526),
    edgeGlowAlpha: .32,
    scoreGlowAlpha: .30,
    dotGlowAlpha: .32,
    halfWashStrong: .22,
    halfWashFade: .05,
    halfWashFadeStop: .58,
    halfWashEndStop: .80,
    darkenWinner: true,
    backLabel: Color(0x990D1526),
  );

  /// The palette for whichever theme the app is in.
  static BoardPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? light : dark;

  /// A fighter's colour, ready to carry text.
  ///
  /// 3A takes each channel to 72%, which is what makes a gi colour chosen to
  /// glow on black legible as a word on white. The dark theme returns it
  /// untouched: there, the colour the fighter picked is the point.
  Color readable(Color color) {
    if (!darkenWinner) return color;
    return Color.from(
      alpha: color.a,
      red: color.r * 0.72,
      green: color.g * 0.72,
      blue: color.b * 0.72,
    );
  }
}
