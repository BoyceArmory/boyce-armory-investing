import '../../../core/constants/asset_paths.dart';
import 'lesson_models.dart';

/// Static lesson catalog. Lessons whose topics ship with hero artwork in
/// `assets/learn/` set [LearnLesson.imageAssetPath] so the detail screen
/// renders the image at the top.
const List<LearnSection> learnSections = <LearnSection>[
  LearnSection(
    id: 'foundations',
    title: 'Foundations',
    subtitle: 'How markets, brokers, and prices actually work.',
    track: LearnTrack.foundations,
    lessons: <LearnLesson>[
      LearnLesson(
        id: 'how-to-read-alerts',
        title: 'How to Read a Boyce Armory Alert',
        summary:
            'Every alert has the same anatomy. Once you know the parts, the system feels obvious.',
        featured: true,
        imageAssetPath: AssetPaths.learnHowToReadAlerts,
        imageTitle: 'Alert anatomy',
        bullets: <String>[
          'Ticker, direction, and grade tell you what kind of trade it is.',
          'Entry / target / stop define the plan in advance.',
          'The setup type tells you why we think this works.',
          'The score reflects confidence - the higher, the cleaner.',
        ],
      ),
      LearnLesson(
        id: 'how-markets-work',
        title: 'How the Market Actually Works',
        summary:
            'Buyers, sellers, exchanges, and how price gets set in real time.',
        bullets: <String>[
          'Price is set when a buyer and seller agree on a number.',
          'Bid is what someone will pay; ask is what someone will sell for.',
          'The spread is the gap between bid and ask - tighter is better.',
          'Volume shows how many shares are actually changing hands.',
        ],
        body:
            'Every quote you see on a chart is just the last trade. Stocks dont move because of magic - they move because someone hit the bid or lifted the ask. Understanding this single fact changes how you read every chart.',
      ),
      LearnLesson(
        id: 'volume-basics',
        title: 'Volume: The Hidden Story',
        summary:
            'Volume confirms moves. A breakout on no volume is a trap.',
        imageAssetPath: AssetPaths.learnVolume,
        imageTitle: 'Volume confirmation',
        bullets: <String>[
          'Up moves on heavy volume are healthier than up moves on no volume.',
          'Reversal candles with above-average volume mean something.',
          'Compare current bar volume to the 20-bar average.',
        ],
      ),
    ],
  ),
  LearnSection(
    id: 'options',
    title: 'Options 101',
    subtitle: 'Calls, puts, strikes, expirations - in plain English.',
    track: LearnTrack.options,
    lessons: <LearnLesson>[
      LearnLesson(
        id: 'calls-vs-puts',
        title: 'Calls vs Puts',
        summary:
            'Calls bet the stock goes up. Puts bet it goes down. Everything else builds on that.',
        featured: true,
        imageAssetPath: AssetPaths.learnCallsVsPuts,
        imageTitle: 'Calls vs Puts',
        bullets: <String>[
          'A CALL gives you the right to buy at the strike price.',
          'A PUT gives you the right to sell at the strike price.',
          'You profit when the stock moves your way faster than time decays the contract.',
          'You can sell anytime - you do not have to hold to expiration.',
        ],
      ),
      LearnLesson(
        id: 'strikes-and-expiration',
        title: 'Strikes and Expiration',
        summary:
            'Choosing a strike and an expiration IS the trade.',
        bullets: <String>[
          'In-the-money: already profitable; behaves like the stock.',
          'At-the-money: closest to current price; most sensitive.',
          'Out-of-the-money: cheap; needs a real move to profit.',
          'Shorter expiration = faster decay. Longer = more breathing room.',
        ],
      ),
      LearnLesson(
        id: 'option-pricing-basics',
        title: 'What Moves an Option Price',
        summary:
            'Three things drive option prices: direction, time, and volatility.',
        bullets: <String>[
          'Direction (delta): how much the option moves per \$1 in the stock.',
          'Time (theta): how much value the option loses every day.',
          'Volatility (vega): how much expected movement is priced in.',
          'If you are right on direction but volatility crashes, you can still lose.',
        ],
      ),
    ],
  ),
  LearnSection(
    id: 'technicals',
    title: 'Setups & Technicals',
    subtitle: 'The patterns we trade, why they work, and how to spot them.',
    track: LearnTrack.technicals,
    lessons: <LearnLesson>[
      LearnLesson(
        id: 'support-resistance',
        title: 'Support & Resistance',
        summary:
            'Levels where price has reacted before tend to react again.',
        featured: true,
        imageAssetPath: AssetPaths.learnSupportResistance,
        imageTitle: 'Support & Resistance zones',
        bullets: <String>[
          'Support = where buyers showed up before.',
          'Resistance = where sellers showed up before.',
          'A level becomes stronger every time it holds.',
          'A broken level often flips role: old resistance becomes new support.',
        ],
      ),
      LearnLesson(
        id: 'support-bounce',
        title: 'Support Bounce',
        summary:
            'Buying the test of a strong support level, with confirmation.',
        imageAssetPath: AssetPaths.learnSupportBounce,
        imageTitle: 'Support bounce',
        bullets: <String>[
          'Wait for price to tag the level - dont front-run it.',
          'Look for a rejection candle (long lower wick, strong close).',
          'Volume should pick up on the bounce.',
          'Stop goes just below the support level.',
        ],
      ),
      LearnLesson(
        id: 'resistance-rejection',
        title: 'Resistance Rejection',
        summary:
            'The mirror of a support bounce - sellers defending overhead.',
        imageAssetPath: AssetPaths.learnResistanceRejection,
        imageTitle: 'Resistance rejection',
        bullets: <String>[
          'Look for price tagging a known resistance and stalling.',
          'A long upper wick with weak close is the tell.',
          'Often a short / put setup if downside structure agrees.',
          'Stop goes just above the rejected level.',
        ],
      ),
      LearnLesson(
        id: 'ema-stack',
        title: 'The 9 / 20 / 50 EMA Stack',
        summary:
            'When fast EMAs are above slow EMAs, the trend is up. Simple.',
        imageAssetPath: AssetPaths.learnEma,
        imageTitle: 'EMA stack',
        bullets: <String>[
          'Stacked up (9 > 20 > 50) is a clean uptrend.',
          'Stacked down (9 < 20 < 50) is a clean downtrend.',
          'Crosses are noisy - wait for confirmation.',
          'Trade with the stack, not against it.',
        ],
      ),
      LearnLesson(
        id: 'vwap-anchor',
        title: 'VWAP: The Institutional Anchor',
        summary:
            'Volume Weighted Average Price - where the big money is positioned.',
        imageAssetPath: AssetPaths.learnVwap,
        imageTitle: 'VWAP behavior',
        bullets: <String>[
          'Above VWAP = bullish bias for the session.',
          'Below VWAP = bearish bias for the session.',
          'Reclaims and rejections of VWAP are high-conviction levels.',
          'Pair with structure - never trade VWAP alone.',
        ],
      ),
      LearnLesson(
        id: 'bull-flag',
        title: 'The Bull Flag Setup',
        summary:
            'A strong move, a tight pause, then continuation. The Armory bread and butter.',
        featured: true,
        imageAssetPath: AssetPaths.learnBullFlag,
        imageTitle: 'Bull flag anatomy',
        bullets: <String>[
          'Look for a sharp upward move on volume.',
          'Wait for a tight, sideways or slightly down consolidation.',
          'Enter on the break of the flag high.',
          'Stop goes below the flag low.',
        ],
      ),
      LearnLesson(
        id: 'breakout',
        title: 'Breakouts',
        summary:
            'Price clearing a known level with conviction. Often the start of a new leg.',
        imageAssetPath: AssetPaths.learnBreakout,
        imageTitle: 'Breakout pattern',
        bullets: <String>[
          'Look for tight consolidation before the break.',
          'Volume should expand on the break - silent breakouts fail more.',
          'Enter on the close above the level, not the wick.',
          'Stop goes back inside the consolidation.',
        ],
      ),
      LearnLesson(
        id: 'breakdown',
        title: 'Breakdowns',
        summary: 'The bearish mirror of a breakout.',
        imageAssetPath: AssetPaths.learnBreakdown,
        imageTitle: 'Breakdown pattern',
        bullets: <String>[
          'Look for failed bounces inside a range.',
          'A close below support with volume is the trigger.',
          'Enter on the breakdown candle or the first weak retest.',
          'Stop goes back above the broken level.',
        ],
      ),
      LearnLesson(
        id: 'fake-breakout',
        title: 'Spotting a Fake Breakout',
        summary:
            'The trap that punishes impatient traders. Learn the tell.',
        imageAssetPath: AssetPaths.learnFakeBreakout,
        imageTitle: 'Fake breakout',
        bullets: <String>[
          'A break of resistance that immediately reverses back inside the range.',
          'Often accompanied by a long upper wick and a red close.',
          'The reversal back inside is itself a tradable short setup.',
          'This is why we wait for the close, not the wick.',
        ],
      ),
      LearnLesson(
        id: 'reversal',
        title: 'Reversal Setups',
        summary: 'Trading the change of trend when structure flips.',
        imageAssetPath: AssetPaths.learnReversal,
        imageTitle: 'Reversal anatomy',
        bullets: <String>[
          'Reversals require a clear prior trend to reverse FROM.',
          'Look for a higher low after a downtrend (or lower high after an uptrend).',
          'Volume divergence on the final push is a strong tell.',
          'Stop goes beyond the extreme of the prior trend.',
        ],
      ),
      LearnLesson(
        id: 'pullback-entry',
        title: 'The Pullback Entry',
        summary:
            'Buying a healthy dip inside a trend - the highest R:R setup we trade.',
        imageAssetPath: AssetPaths.learnPullbackEntry,
        imageTitle: 'Pullback entry',
        bullets: <String>[
          'Only trade pullbacks INSIDE a confirmed trend.',
          'Wait for a 38% / 50% / 61% retrace to a moving average or level.',
          'Enter on the first sign of trend resumption (bullish engulfing, hammer).',
          'Stop goes below the swing low of the pullback.',
        ],
      ),
      LearnLesson(
        id: 'range-break',
        title: 'Range Break',
        summary: 'Price escaping a tight range often runs hard.',
        imageAssetPath: AssetPaths.learnRangeBreak,
        imageTitle: 'Range break',
        bullets: <String>[
          'Ranges build energy - the longer the range, the bigger the move.',
          'Trade in the direction of the break, not the bounce.',
          'Use the range width as your initial target.',
          'A failed break often runs the same distance the other way.',
        ],
      ),
      LearnLesson(
        id: 'trend-continuation',
        title: 'Trend Continuation',
        summary: 'The trend is your friend until it bends. Ride it.',
        imageAssetPath: AssetPaths.learnTrendContinuation,
        imageTitle: 'Trend continuation',
        bullets: <String>[
          'Higher highs and higher lows = trend is intact.',
          'Each pullback to a moving average is an entry.',
          'Trail stops under each new higher low.',
          'Exit only when structure breaks, not on noise.',
        ],
      ),
    ],
  ),
  LearnSection(
    id: 'risk',
    title: 'Risk & Psychology',
    subtitle: 'The skill that decides whether you survive year two.',
    track: LearnTrack.risk,
    lessons: <LearnLesson>[
      LearnLesson(
        id: 'discipline',
        title: 'Discipline > Strategy',
        summary:
            'A great strategy you wont follow is worse than an average one you will.',
        featured: true,
        imageAssetPath: AssetPaths.learnDiscipline,
        imageTitle: 'Discipline first',
        bullets: <String>[
          'Decide the plan BEFORE entering - never after.',
          'If the setup doesnt match the playbook, dont take it.',
          'One trade is just data. Edge shows up over 30+ trades.',
          'The biggest losses come from breaking your own rules.',
        ],
      ),
      LearnLesson(
        id: 'position-sizing',
        title: 'Position Sizing',
        summary:
            'Pick the size before the trade so emotion never picks it for you.',
        bullets: <String>[
          'Risk a fixed percent of your account per trade (1-2% is standard).',
          'Position size = risk amount / (entry - stop).',
          'Smaller size in choppy markets, larger size in clean trends.',
          'Big positions feel great until they dont.',
        ],
      ),
      LearnLesson(
        id: 'stop-loss',
        title: 'Where to Put a Stop',
        summary:
            'Stops belong at the level that proves you are wrong, not at a round number.',
        bullets: <String>[
          'Put the stop just beyond structure (under support, over resistance).',
          'If the stop is too tight, the trade has no room to work.',
          'If the stop is too wide, the loss is too painful to take.',
          'Never move a stop further away. Ever.',
        ],
      ),
      LearnLesson(
        id: 'fomo',
        title: 'Beating FOMO',
        summary:
            'The chase costs more than the trade you miss ever would.',
        imageAssetPath: AssetPaths.learnFomo,
        imageTitle: 'FOMO trap',
        bullets: <String>[
          'If you missed the entry, the trade is over for you.',
          'The next setup is always closer than you think.',
          'Chasing means buying after the move is already paid for.',
          'The mistake of doing nothing is small. The mistake of chasing is big.',
        ],
      ),
      LearnLesson(
        id: 'overtrading',
        title: 'Overtrading',
        summary:
            'Most retail accounts die from too many trades, not too few.',
        imageAssetPath: AssetPaths.learnOvertrading,
        imageTitle: 'Overtrading',
        bullets: <String>[
          'More trades = more commissions, more spread, more variance.',
          'A profitable system might only signal 1-3 trades a day.',
          'If you cant articulate the setup, dont take the trade.',
          'Boredom is not a setup.',
        ],
      ),
      LearnLesson(
        id: 'trade-journal',
        title: 'Why You Need a Journal',
        summary:
            'You will repeat any mistake you do not write down.',
        bullets: <String>[
          'Log entry, exit, size, and reason for every trade.',
          'Tag each trade with the setup type.',
          'Review weekly: which setups make money, which lose money.',
          'Cut the losing setups, double the winners.',
        ],
      ),
    ],
  ),
];
