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
      LearnLesson(
        id: 'reading-spy-qqq-vix',
        title: 'Reading SPY, QQQ, and the VIX',
        summary:
            'Before you trade any stock, check what the market is doing.',
        bullets: <String>[
          'SPY tracks the S&P 500 - the broad market mood.',
          'QQQ tracks the Nasdaq 100 - tech and growth.',
          'When SPY and QQQ both trend up, calls work easier. When both trend down, puts work easier.',
          'VIX above 20 = fear and choppy markets. VIX below 15 = calm and trend-friendly.',
        ],
        body:
            'Trading a stock against the market is fighting the current. If SPY is down 1% and your ticker is also down, that is the market, not your setup. If your ticker is up while SPY is down, you have relative strength - and that is one of the most reliable edges in trading. The Market Pulse card on your home screen shows all three at a glance.',
      ),
      LearnLesson(
        id: 'sector-rotation',
        title: 'Sector Rotation Basics',
        summary:
            'Money flows between sectors. Knowing where it is going matters more than picking the right stock.',
        bullets: <String>[
          'On any given day, some sectors lead and others lag.',
          'Tech leading = risk-on. Utilities and consumer staples leading = risk-off.',
          'Trade with the leading sector, not against it.',
          'The sector heatmap on your home screen shows the current rotation in real time.',
        ],
        body:
            'A great setup on a tech stock when tech is dead-last that day is going to struggle. A mediocre setup in the leading sector often works because the whole sector is pulling everything up. Sector context is free alpha - it costs nothing to check and it filters out a lot of bad trades.',
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
        imageAssetPath: AssetPaths.learnStrikesExpiration,
        imageTitle: 'Strikes & expiration',
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
        imageAssetPath: AssetPaths.learnOptionPricing,
        imageTitle: 'What moves an option price',
        bullets: <String>[
          'Direction (delta): how much the option moves per \$1 in the stock.',
          'Time (theta): how much value the option loses every day.',
          'Volatility (vega): how much expected movement is priced in.',
          'If you are right on direction but volatility crashes, you can still lose.',
        ],
      ),
      LearnLesson(
        id: 'the-greeks',
        title: 'The Greeks: Delta, Theta, Gamma',
        summary:
            'Greeks measure how an option price reacts to the world around it.',
        imageAssetPath: AssetPaths.learnGreeks,
        imageTitle: 'Delta · Theta · Gamma',
        bullets: <String>[
          'Delta (0 to 1): for every \$1 the stock moves, the option moves this much. A 0.50 delta call gains ~\$0.50 if the stock goes up \$1.',
          'Theta: dollars lost per day to time decay. Higher near expiration.',
          'Gamma: how fast delta changes as the stock moves. Big near the strike.',
          'A high-delta in-the-money option behaves more like the stock. A low-delta out-of-the-money option behaves more like a lottery ticket.',
        ],
        body:
            'You do not need to do Greek math in your head. You just need to know which lever you are pulling. Buying a 0.70 delta call means you mostly care about direction and barely about IV. Buying a 0.20 delta weekly means you need a big move fast or theta eats you alive. Pick the Greek profile that matches your thesis.',
      ),
      LearnLesson(
        id: 'implied-volatility',
        title: 'What is Implied Volatility?',
        summary:
            'IV is the market\'s guess at how much a stock will move. It directly sets option prices.',
        bullets: <String>[
          'High IV = expensive options. The market expects big moves.',
          'Low IV = cheap options. The market expects calm.',
          'IV usually pumps before earnings and crashes the moment results come out (IV crush).',
          'Buying options into earnings often loses even when you are right on direction.',
        ],
        body:
            'Two traders can buy the same call at the same strike on the same day and one wins, one loses - because of what IV does next. If you buy when IV is at the high end of its range, you are paying a premium for a move the market already expects. If you buy when IV is at the low end, you are getting a discount. The Boyce Armory scanner avoids alerting calls right before earnings for exactly this reason.',
      ),
      LearnLesson(
        id: 'why-leaps',
        title: 'Why Long-Dated Options? (LEAPs)',
        summary:
            'LEAPs are options with 6+ months to expiration. They let you bet on a thesis without buying the whole stock.',
        bullets: <String>[
          'A 1-year LEAP costs a fraction of buying 100 shares but gives similar upside.',
          'Theta decay is slow on long-dated options - you have time to be right.',
          'Best for stocks you believe in long-term but do not want to commit full capital to.',
          'Trade-off: less leverage than short-dated options, but much higher probability.',
        ],
        body:
            'A LEAP on NVDA at 0.70 delta with 1 year to expiration is essentially a leveraged long-term position with built-in downside cap (you only lose what you paid). Pros use them to play multi-month themes - AI, energy transition, biotech breakthroughs. The Boyce Armory LEAP scanner runs once a day after close and only fires on the highest-conviction setups.',
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
        imageAssetPath: AssetPaths.learnPositionSizing,
        imageTitle: 'Position sizing',
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
        id: 'earnings-risk',
        title: 'Earnings Risk',
        summary:
            'Holding options through earnings is a coin flip. The scanner avoids it for a reason.',
        bullets: <String>[
          'Earnings reports come quarterly and can move a stock 10-30% overnight.',
          'IV spikes before earnings (you pay a premium), then crashes after (you lose value).',
          'Even a great earnings beat can cause the stock to drop if guidance disappoints.',
          'Best practice: close positions before earnings, re-enter after the IV crush.',
        ],
        body:
            'The Boyce Armory scanner flags earnings risk and avoids alerting setups when an earnings event is within the holding window. You can still trade through earnings - but treat it as a separate skill with its own rules, not as a normal swing or day trade. The expected value of buying calls into earnings on a typical large-cap is negative once IV crush is factored in.',
      ),
      LearnLesson(
        id: 'drawdown-recovery',
        title: 'Drawdown and Position Recovery',
        summary:
            'The math of losing trades is brutal. A 50% drawdown needs a 100% gain to recover.',
        bullets: <String>[
          'Lose 10% → need 11.1% to break even. Manageable.',
          'Lose 25% → need 33.3% to break even. Hard.',
          'Lose 50% → need 100% to break even. Years of work.',
          'This is why small position sizes and tight stops matter more than picking winners.',
        ],
        body:
            'Every trader who blows up an account does so the same way: oversized positions, no stops, hope. The asymmetry of drawdown math means the best traders are obsessed with not losing big, not with catching every move. Survive long enough and the winners compound. Take one catastrophic loss and you are starting over from a hole you may never climb out of.',
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
  LearnSection(
    id: 'execution',
    title: 'Using Boyce Armory',
    subtitle: 'How to actually use the scanner, alerts, and grading.',
    track: LearnTrack.execution,
    lessons: <LearnLesson>[
      LearnLesson(
        id: 'using-the-scanner',
        title: 'How to Use the Boyce Armory Scanner',
        summary:
            'The scanner does the work of finding setups. Your job is to filter, size, and execute.',
        featured: true,
        bullets: <String>[
          'Open the Scanner tab during market hours - the list refreshes every minute.',
          'Each card shows ticker, direction, grade, setup type, entry, stop, and targets.',
          'Tap any card for the full breakdown: why this stock, what confirms, what invalidates.',
          'A+ setups also push to your phone. A/B/Watch live in the app only.',
        ],
        body:
            'The scanner is not a buy button. It is a filter. It compresses thousands of tickers into a short list of setups that meet our criteria right now. You still pick which ones fit your style, account size, and risk tolerance. A great scanner with bad execution still loses money. Use the alerts as starting points, not commands.',
      ),
      LearnLesson(
        id: 'grade-meaning',
        title: 'A+, A, B, Watch - What the Grades Mean',
        summary:
            'Every alert gets a letter grade. Higher grade = cleaner setup, not bigger gain.',
        featured: true,
        bullets: <String>[
          'A+ (90-100): every box checked - trend, volume, structure, market context. Rare. Pushes to your phone.',
          'A (80-89): strong setup, one minor confirmation missing. Visible in app, no push.',
          'B (70-79): tradeable but needs your own confirmation. Visible in app.',
          'Watch (60-69): forming, not confirmed. Watch the level.',
        ],
        body:
            'Grade is about setup quality, not profit potential. A B-grade breakout in a strong stock can outperform an A+ in a choppy one. Treat grades as confidence in the setup mechanics, not predictions about return. Over a large sample, A+ trades win more often than A, which win more often than B. Single trades can do anything.',
      ),
      LearnLesson(
        id: 'day-vs-swing-vs-leap',
        title: 'Day Trader vs Swing vs LEAP',
        summary:
            'Three scanners, three time horizons. Pick the one that fits your life.',
        featured: true,
        bullets: <String>[
          'Day Trader: minutes to hours. Requires screen time during market open.',
          'Swing: days to weeks. Check the app once or twice a day.',
          'LEAP: months to 1-2 years. Set it and forget it; check weekly.',
          'You can follow all three - or just one. There is no wrong choice.',
        ],
        body:
            'Most people get hurt trying to day trade when their job won t let them watch the market. If you can t look at the app between 9:30 and 13:30 ET, ignore the Day Trader feed. Swing is the realistic choice for most users - holds last days, you check twice a day, and the setup either works or hits the stop. LEAPs are for long-term thesis trades - low maintenance, but you tie up capital longer.',
      ),
      LearnLesson(
        id: 'scaling-out',
        title: 'Scaling Out: T1, T2, T3',
        summary:
            'Every alert has three targets. You sell into strength, not all at once.',
        featured: true,
        bullets: <String>[
          'T1 = 1R (matches your risk). Sell 1/3 of position, lock in profit, move stop to breakeven.',
          'T2 = 2R. Sell another 1/3. Now any further move is house money.',
          'T3 = 3R. Sell the rest, or trail the stop to ride a runner.',
          'You almost never get T3. The goal is to bank consistent T1/T2 winners.',
        ],
        body:
            'Selling all-or-nothing is how good trades become bad ones. The market hits your target, you do not take it because "it might go higher," it reverses, you exit at breakeven or worse. Scaling out forces you to bank profit while keeping skin in the game. Over 100 trades, a scaled-out trader almost always beats an all-in trader using the same signals.',
      ),
      LearnLesson(
        id: 'order-types',
        title: 'Order Types: Why You Always Use Limit Orders',
        summary:
            'The wrong order type silently costs you 2-5% on every trade. Limit orders fix it.',
        featured: true,
        bullets: <String>[
          'Market order: buy at whatever price someone will sell. Fast, but you pay the worst price on the book.',
          'Limit order: set the price you are willing to pay. Slower fills, but no surprises.',
          'On options, the bid-ask spread can be \$0.10-\$0.50 wide. A market order pays the full spread instantly.',
          'Use limit orders at the midpoint. If it does not fill in 30 seconds, walk it up a penny at a time.',
        ],
        body:
            'This is the single biggest hidden cost in retail options trading. A \$2.00 / \$2.20 option (\$0.20 spread) bought with a market order costs you \$0.20 per contract right at entry - that is a 10% loss before the trade has moved. The same trade with a limit at \$2.10 (the midpoint) often fills in seconds and saves you that 10%. Over a year of trades, the difference between using limits and using markets can be the entire difference between profitable and unprofitable. Always. Use. Limits.',
      ),
      LearnLesson(
        id: 'pre-market-checklist',
        title: 'Pre-Market Checklist',
        summary:
            'The 5 minutes before market open decide how the next 4 hours go.',
        bullets: <String>[
          'Open the app at 9:25 ET. Check Market Pulse: SPY, QQQ, VIX direction.',
          'Read the top headlines on the news ticker. Earnings? Fed? Geopolitics?',
          'Scan the watchlist - any positions from yesterday near your stop or target?',
          'Set a daily loss limit. If you hit it, the day is over. No exceptions.',
        ],
        body:
            'Pre-market is the cheapest time you spend on trading because no money is moving yet. Skip it and you walk into chaos blind. Two minutes of context now saves you from being on the wrong side of a 1% SPY gap. The discipline of doing the same 4 things every morning is itself an edge.',
      ),
      LearnLesson(
        id: 'power-hour',
        title: 'Power Hour Playbook',
        summary:
            'The last hour (3:00-4:00 ET) is the second most active window of the day.',
        bullets: <String>[
          'Volume picks up as institutional traders close positions.',
          'Breakouts that hold past 3:30 ET often run into the close.',
          'Failed breakouts in power hour tend to flush hard - good for shorts.',
          'Day-trade alerts stop at 13:30 ET so you have time to manage existing positions, not chase new ones.',
        ],
        body:
            'Power hour is where the day s thesis gets confirmed or rejected. If SPY is up 1% all day and starts giving it back at 3:00, that tells you something about tomorrow. The scanner does not fire new day-trade alerts in power hour intentionally - this is when you should be managing trades, not opening new ones unless they are exceptional.',
      ),
    ],
  ),
];
