/// Plain-English explanation of why each setup kind tends to work.
/// Surfaced in the expanded scanner card so users learn the system as they
/// scroll the feed.
///
/// Every entry deliberately includes:
///   1. What the pattern actually is (mechanical description).
///   2. Why it works (the underlying market behavior).
///   3. The entry/risk logic (what to watch for to know if it's invalidated).
class SetupEducation {
  SetupEducation._();

  static const Map<String, String> _byKind = <String, String>{
    // -------------------- Trend continuation --------------------
    'bull_flag':
        'A bull flag prints when a stock makes a sharp move higher, then '
            'consolidates tight before continuing. The pause shakes out weak '
            'hands and gives institutions a clean re-entry zone; the break of '
            'the flag high is where momentum picks back up. Stop sits below '
            'the flag low — if that breaks, the pattern is invalidated and '
            'the trade is wrong.',
    'bear_flag':
        'A bear flag is the inverse of a bull flag — a sharp drop followed by '
            'a tight, upward-drifting pause. The drift is short sellers being '
            'temporarily squeezed before the next leg down. The break of the '
            'flag low is the continuation trigger; stop above the flag high.',
    'breakout':
        'Breakouts happen when price clears a known resistance level with '
            'real volume (≥1.5× average). The clean break tells you new buyers '
            'are taking control above a level where sellers used to win. The '
            'best breakouts come off a tight base (low volatility before the '
            'move) and run further when SPY is also trending up.',
    'breakdown':
        'Breakdowns are the mirror image of breakouts — price losing a '
            'support level on volume, signalling sellers have taken over the '
            'zone where buyers used to defend. The cleanest ones come after '
            'a long base just above support, then crack with volume.',
    'high_volume_move':
        'A move on ≥2× average volume is institutional participation, not '
            'random noise. Direction matters more than size when the volume '
            'shows up. Watch for the next bar to confirm — the first big-vol '
            'bar can be a false move, the second bar in the same direction '
            'is the real signal.',

    // -------------------- Mean reversion --------------------
    'oversold_bounce':
        'When RSI(14) drops below 30 the stock is statistically stretched to '
            'the downside. A reclaim of a key moving average (20EMA) is the '
            'early signal that buyers are stepping back in. Don\'t catch the '
            'falling knife — wait for the reclaim, then enter with a stop '
            'below the recent swing low.',
    'overbought_fade':
        'When RSI(14) runs above 70 the stock is statistically stretched up. '
            'Losing a key moving average from above is the early tell that '
            'profit-taking is winning. Best fades happen at confluence — '
            'overbought RSI + at a prior resistance level + bearish candle.',

    // -------------------- Reversal family (Sprint 2) --------------------
    'oversold_reversal_long':
        'Three or more days of RSI < 30 plus a higher low today plus a '
            'decisive bullish candle (≥60% body) on above-average volume — '
            'AND price closed above the prior three-day high. This is the '
            '"catch the bottom on confirmation" play: you don\'t pick the low '
            'tick, you wait for the first higher high after the capitulation. '
            'Stop just below today\'s low.',
    'overbought_reversal_short':
        'Three or more days of RSI > 70 plus a lower high today plus a '
            'decisive bearish candle on volume — and today closed below the '
            'prior three-day low. The "second mouse gets the cheese" short — '
            'wait for the first lower low after the blow-off top.',
    'failed_breakdown_long':
        'Yesterday broke below 20-bar support (the bear trap) but today '
            'closed back ABOVE yesterday\'s high — a bullish reclaim on '
            'volume. These are the highest win-rate reversal setups because '
            'they catch trapped shorts being squeezed. Stop below yesterday\'s '
            'low; momentum often runs hard once the shorts cover.',
    'failed_breakout_short':
        'Mirror — yesterday spiked above resistance (the bull trap), today '
            'closed below yesterday\'s low. Trapped longs unwind into the '
            'short. Stop above yesterday\'s high.',
    'bullish_engulfing_long':
        'Today\'s bullish body completely engulfs yesterday\'s bearish body '
            '— and it\'s ≥10% larger. Happens within 3% of the 20-bar low. '
            'The pattern signals a sentiment flip at support: yesterday\'s '
            'sellers had no follow-through, today\'s buyers overwhelmed them. '
            'Volume confirmation makes it tradeable.',
    'bearish_engulfing_short':
        'Mirror near the 20-bar high. Sellers overwhelmed the prior day\'s '
            'buyers in a single decisive candle. Often marks a swing top.',

    // -------------------- Sprint 5 additions (shared with swing) --------------------
    'stop_hunt_reversal_long':
        'A liquidity sweep: price wicked below the 20-bar low (running '
            'stop-loss orders), then closed back above on volume. Whoever '
            'placed stops just under support got run, and the algos that '
            'caused it now have inventory to push price higher. Best '
            'reversal setup in the day scanner; stop is just below the '
            'wick low.',
    'stop_hunt_reversal_short':
        'Mirror at resistance — a wick that pierced the 20-bar high and '
            'rejected. Trapped longs and stop-runs above the prior high '
            'fuel the move down. Stop above the wick high.',
    'hammer_at_support':
        'A single-bar capitulation candle near the 20-bar low — small body '
            'in the top third of the range, long lower wick, little to no '
            'upper wick. Sellers tried, failed, buyers stepped in '
            'aggressively into the close. The hammer is the signal, the '
            'NEXT bar\'s close above the hammer high is the trigger.',
    'shooting_star_at_resistance':
        'Mirror at the 20-bar high. Small body, long upper wick. Buyers '
            'tried, sellers overwhelmed them. Confirmation on the next bar '
            'closing below the star low.',

    // -------------------- Compression / coiled-spring family (May 2026) ----
    'nr7_compression_long':
        'NR7 = today\'s range is the narrowest of the last 7 sessions. '
            'Combined with stacked EMAs and price holding the 20EMA, this is '
            'a coiled spring in an uptrend. The breakout from compression '
            'tends to be cleaner than chasing a stock already running. Stop '
            'below the NR7 low.',
    'nr7_compression_short':
        'Mirror in a downtrend: narrowest bar in 7 sessions with EMAs '
            'stacked down and price capped at the 20EMA. The break of the '
            'NR7 low triggers the directional move; stop above the NR7 '
            'high.',
    'inside_bar_at_resistance':
        'Inside bar within 1% of the 20-bar high with price above the '
            '20EMA. Coiled at resistance — volatility contraction followed '
            'by an expansion through prior highs. Entry on break of '
            'yesterday\'s high, stop below the inside bar low.',
    'inside_bar_at_support':
        'Mirror at the 20-bar low: inside bar within 1% of recent lows '
            'with price under the 20EMA. The break of yesterday\'s low '
            'triggers; stop above the inside bar high.',

    // -------------------- Generic fallbacks --------------------
    'support_bounce':
        'Buyers tend to defend price levels they have defended before. '
            'Tagging support with a rejection wick and volume is the cleanest '
            'entry pattern in trend trading. Stop below the wick low.',
    'resistance_rejection':
        'Sellers defend overhead levels the same way buyers defend support. '
            'A failed test of resistance with a long upper wick is a high '
            'probability short / put setup.',
    'pullback_entry':
        'Inside a healthy trend, pullbacks to a moving average offer the '
            'best risk-to-reward. You enter with the trend, not against it, '
            'and place stops just below the swing low.',
    'range_break':
        'The longer a stock stays in a tight range, the more energy it builds. '
            'A clean break of the range with volume usually runs at least the '
            'width of the range itself.',
    'reversal':
        'Reversals require a clear prior trend. A higher low after a '
            'downtrend (or lower high after an uptrend) plus volume divergence '
            'is the tell that structure is flipping.',
    'manual':
        'This setup was hand-picked by the desk because the combination of '
            'price action, volume, and market context lines up with how we '
            'trade.',
  };

  /// Returns an educational paragraph for [kind]. Falls back to a generic
  /// explanation if the kind is unknown.
  static String forKind(String kind) {
    return _byKind[kind] ??
        'This is a recognised pattern in our scoring system. The combination '
            'of price, volume, and momentum lines up with the rules we use '
            'to grade quality. Use the entry/stop/target plan as a guide and '
            'manage risk based on your account size.';
  }
}
