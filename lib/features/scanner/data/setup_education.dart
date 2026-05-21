/// Short, plain-English explanation of why each setup kind tends to work.
/// Surfaced in the expanded scanner card so users learn the system as they
/// scroll the feed.
class SetupEducation {
  SetupEducation._();

  static const Map<String, String> _byKind = <String, String>{
    'bull_flag':
        'A bull flag prints when a stock makes a sharp move higher, then '
            'consolidates tight before continuing. The pause shakes out weak '
            'hands; the break of the flag high is where momentum picks back up.',
    'bear_flag':
        'A bear flag is the inverse of a bull flag - a sharp drop followed by '
            'a tight, upward-drifting pause. The break of the flag low is the '
            'continuation trigger.',
    'breakout':
        'Breakouts happen when price clears a known resistance level with '
            'volume. The clean break tells you new buyers are taking control '
            'above a level where sellers used to win.',
    'breakdown':
        'Breakdowns are the mirror image of breakouts - price losing a '
            'support level on volume, signalling sellers have taken over the '
            'zone where buyers used to defend.',
    'oversold_bounce':
        'When RSI drops below 30 the stock is statistically stretched to the '
            'downside. A reclaim of a key moving average is the early signal '
            'that buyers are stepping back in.',
    'overbought_fade':
        'When RSI runs above 70 the stock is statistically stretched up. '
            'Losing a key moving average from above is the early tell that '
            'profit-taking is winning.',
    'high_volume_move':
        'A move on 2x+ average volume is institutional participation, not '
            'random noise. Direction matters more than size when the volume '
            'shows up.',
    'support_bounce':
        'Buyers tend to defend price levels they have defended before. Tagging '
            'support with a rejection wick and volume is the cleanest entry '
            'pattern in trend trading.',
    'resistance_rejection':
        'Sellers defend overhead levels the same way buyers defend support. '
            'A failed test of resistance with a long upper wick is a high '
            'probability short / put setup.',
    'pullback_entry':
        'Inside a healthy trend, pullbacks to a moving average offer the best '
            'risk-to-reward. You enter with the trend, not against it, and '
            'place stops just below the swing low.',
    'range_break':
        'The longer a stock stays in a tight range, the more energy it builds. '
            'A clean break of the range with volume usually runs at least the '
            'width of the range itself.',
    'reversal':
        'Reversals require a clear prior trend. A higher low after a downtrend '
            '(or lower high after an uptrend) plus volume divergence is the '
            'tell that structure is flipping.',
    'manual':
        'This setup was hand-picked by the desk because the combination of '
            'price action, volume, and market context lines up with how we '
            'trade.',
  };

  /// Returns an educational paragraph for [kind]. Falls back to a generic
  /// explanation if the kind is unknown.
  static String forKind(String kind) {
    final String key = kind.trim().toLowerCase();
    return _byKind[key] ??
        'This setup combines price action, volume, and trend structure into '
            'a high-probability entry. Read the full reason for what triggered '
            'this specific alert.';
  }
}
