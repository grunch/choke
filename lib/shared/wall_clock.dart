/// How long until just past the next wall-clock second.
///
/// Match clocks are derived from `startAt`, which is whole unix seconds, so
/// their true value flips exactly on second boundaries. A periodic timer
/// started at an arbitrary moment repaints that flip up to a full second late —
/// and each screen late by its own phase is how two screens showing the same
/// match read visibly different clocks. Ticking just past the boundary puts a
/// display within milliseconds of the derived truth, and every display that
/// does so agrees with every other, leaving only device clock skew between
/// them.
///
/// The guard exists because timers promise "not before", never "exactly at": a
/// marginally-early fire would land in the old second and paint a stale value
/// for a full extra one.
Duration untilNextClockFlip(int nowMs, {int guardMs = 40}) {
  final intoSecond = nowMs % 1000;
  return Duration(milliseconds: (1000 - intoSecond) + guardMs);
}
