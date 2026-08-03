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
        title: 'How to Read a Boyce Armory Trade Card',
        summary:
            'Every part of the card has a job. This lesson walks the entire card top to bottom so nothing on it is mystery.',
        featured: true,
        imageAssetPath: AssetPaths.learnHowToReadAlerts,
        imageTitle: 'Trade card anatomy',
        bullets: <String>[
          'TOP-RIGHT eyebrow: HOT TRADE means the team or scanner promoted this; ADMIN PICK pill = hand-picked by us, no pill = scanner-detected.',
          'MODE PILL (DAY / SWING / LEAPS): the timeframe the setup is built for. Mismatch your timeframe and the trade plan stops working.',
          'GRADE BADGE (A+ / A / B+ / B): conviction tier. A+ requires 95+ score AND 4-of-6 conviction lanes to fire; A is 88+; B is 78+. Below B doesn\'t alert.',
          'SCORE (0–100): raw quality measure. Two A-grade alerts at score 88 vs 92 are meaningfully different — higher = cleaner setup, less is being forgiven by the grader.',
          'CONFIDENCE: a derived 0–100 that blends grade + setup edge from backtest. It\'s the single number you check if you only check one number.',
          'ENTRY / TARGET / STOP: the plan in advance. Entry is where to take the trade, target is the first take-profit, stop is where the thesis is broken. If price hits stop, the alert was wrong.',
          'R-MULTIPLE (+X.XR): reward divided by risk. +2.0R means the target pays you twice what the stop costs you. Below +1.5R is usually skippable.',
          'CURRENT PRICE / VOLUME / DAY %: live snapshot at the time the card was published. If current price has already passed the target by the time you see the card, it\'s late.',
          'WHY THIS STOCK: a one-paragraph narrative explaining the setup in plain English — what the catalyst is, what makes this ticker stand out today.',
          'WHY THIS FIRED: the trigger snapshot — RSI, MACD, MTF (multi-timeframe alignment), VWAP, EMA stack. These are the technical signals the scanner saw before firing.',
          'HOW THIS SETUP WORKS: educational copy for the detector kind. Same setup type will always show the same copy here — it\'s the playbook.',
          'PLAN ROW: a clean three-cell strip showing Entry / Target / Stop side by side. The visual you trade from.',
          'ACTION BAR: Took / Watching / Pass buttons. These feed the learning loop — your real engagement makes the scanner smarter over time.',
          'WATCHLIST STAR: tap to add the ticker to your watchlist. Filter Hot Trades to your watchlist with the chip below the mode tabs.',
          'CHART BUTTON: opens the in-app candle chart for the ticker with entry / target / stop overlay lines pre-drawn.',
          'FOOTER (timestamp, win-rate chip, MTF tag): timestamp tells you how old the alert is; the win-rate chip shows backtest edge for THIS detector; MTF tag confirms the higher timeframe agrees.',
        ],
        body:
            'A trade card is dense by design — everything we know about a setup is on one screen so you never have to dig. Here is the order I read every card in:\n\n1) Eyebrow first. HOT TRADE or scanner card? Is the ADMIN PICK pill visible? That tells me whether this came from the team\'s hand or from the algorithm.\n\n2) Mode + Grade. SWING / LEAPS sets my mental timeframe. A+ vs B is the conviction floor — I size A+ bigger than B unless something on the chart shouts otherwise.\n\n3) The plan row. Entry → Target → Stop. If those three numbers don\'t make sense relative to each other, I skip. Usually I want +1.5R minimum.\n\n4) Why this stock. The narrative tells me the WHY. If it\'s a sector rotation play, I check the sector heatmap on home.\n\n5) Why this fired. The trigger snapshot is the WHAT — what the scanner actually saw. Multi-timeframe confirmation (MTF tag in the footer) is the most underrated chip on the card.\n\n6) Action. Took / Watching / Pass. Every tap feeds the learning loop, so it\'s worth being honest. If I pass, I tap Pass. The scanner learns from your real engagement.\n\nTwo last tips. First, the FOOTER win-rate chip is THE single best lens for "is this detector working lately?" — it\'s backtest edge, not vibes. Second, the score number matters more than people think. An A+ at 95 and an A+ at 99 are NOT the same trade. Train your eye on it.',
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
      LearnLesson(
        id: 'iv-rank-vs-percentile',
        title: 'IV Rank vs IV Percentile',
        summary:
            'Both measure how expensive options are today vs the last year. They tell you different things.',
        bullets: <String>[
          'IV Rank: where today\'s IV sits between the 52-week low and high. Pure scale.',
          'IV Percentile: what % of days in the last year had a LOWER IV. Distribution-aware.',
          'A stock that spiked once and is otherwise calm: high IV rank, but moderate percentile.',
          'For ENTERING long premium, prefer LOW values on either. For SHORT premium (spreads, condors), prefer HIGH values.',
        ],
        body:
            'Imagine SPY had an IV of 10 most of the year and one panic week at 40. Today\'s IV is 25. IV Rank says 50 (you\'re in the middle of the range), but IV Percentile says 95 (you\'re higher than 95% of days). Percentile is usually the better read because outliers don\'t fool it. The Boyce Armory IV-rank card on home reports both — when they disagree wildly, the stock has had a recent vol shock and the rank number is misleading.',
      ),
      LearnLesson(
        id: 'gamma-exposure',
        title: 'Gamma and Dealer Positioning',
        summary:
            'Options dealers hedge — and that hedging creates predictable price-action behavior at certain levels.',
        bullets: <String>[
          'Dealers sell calls/puts to retail and hedge by buying/selling the underlying.',
          'When dealers are short gamma (typical near OPEX): they buy as price rises, sell as it falls → moves get amplified.',
          'When dealers are long gamma: they sell into strength, buy weakness → moves get dampened.',
          'Knowing which side dealers sit on tells you whether a breakout will rip or chop.',
        ],
        body:
            'You don\'t need to compute gamma exposure yourself — sites like SpotGamma track it and publish daily levels. What you DO need to know: same setup chart, same RSI, same MACD will play very differently in a short-gamma vs long-gamma regime. Tuesdays/Wednesdays right before monthly OPEX are usually dampened (long gamma); the Friday after is usually choppy as positioning resets.',
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
      LearnLesson(
        id: 'scaling-out',
        title: 'Scaling Out: Locking in Profits',
        summary:
            'Selling part of a position at the first target turns a "right but greedy" trade into a guaranteed win.',
        bullets: <String>[
          'Sell 33-50% at the first target (T1 = 1R). This pays for the risk on the rest.',
          'After scaling, move your stop to break-even. The remainder is now a free trade.',
          'Take another 25-33% at T2 (2R). Let the final piece run on a trailing stop.',
          'Best trades come from the runners — but only if you protect the core first.',
        ],
        body:
            'The hardest skill in trading isn\'t getting in. It\'s getting out. Every trader has stories of options that went +200%, then expired worthless. The fix isn\'t a smarter exit signal — it\'s a mechanical scale-out rule baked in BEFORE you enter. Decide: how many contracts come off at T1, T2, T3? Write it on the alert card. Follow the script. The R-multiple shown on every Boyce Armory alert defines what 1R looks like for that specific trade, which is the trigger for your first partial exit.',
      ),
      LearnLesson(
        id: 'three-trade-plans',
        title: 'The Three Trade Plans',
        summary:
            'Every trade is one of three things. Knowing which one keeps you from blending strategies that shouldn\'t mix.',
        bullets: <String>[
          'CATALYST: a known event (earnings, FOMC, product launch) drives the move. Time-bounded.',
          'CONTINUATION: price is already trending and the setup says it will keep going. Stop is at the structure that defined the trend.',
          'MEAN REVERSION: price has overextended and is snapping back. Targets are at the moving average; stops are at the recent extreme.',
        ],
        body:
            'Most account-blow-up stories are someone trading a continuation playbook (chase strength, ride the breakout) on a mean-reversion setup (overextended into resistance), or vice versa. Boyce Armory alerts are tagged by setup kind — the "kind" field on the trade card (breakout, pullback, reversal, etc.) maps to one of these three plans. Match the plan to the setup BEFORE entry and you skip 80% of the mistakes new options traders make.',
      ),
      LearnLesson(
        id: 'tilt',
        title: 'Tilt: Recognizing the Death Spiral',
        summary:
            'Tilt is the moment emotion takes the controls. Recognize it in five seconds or you\'ll lose more than a single bad trade.',
        bullets: <String>[
          'Symptom 1: you take the next setup before reviewing the loss you just took.',
          'Symptom 2: position size creeps up to "make back" what you lost.',
          'Symptom 3: you start trading setups not in your playbook.',
          'Symptom 4: you\'re refreshing the chart every 30 seconds.',
        ],
        body:
            'Tilt isn\'t a character flaw. It\'s a neurological response to loss aversion and it happens to every trader, every level. The pros have a hard rule: after two consecutive losses OR a single loss bigger than 1.5R, you\'re done for the day. No exceptions. The single most expensive trade in your life will be the third revenge trade after two losses. Walk away — the market is open again tomorrow. The Boyce Armory shadow stats don\'t care if you trade today or not.',
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
        id: 'swing-vs-leap',
        title: 'Swing vs LEAP',
        summary:
            'Two scanners, two time horizons. Pick the one that fits your life.',
        featured: true,
        bullets: <String>[
          'Swing: days to weeks. Check the app once or twice a day.',
          'LEAP: months to 1-2 years. Set it and forget it; check weekly.',
          'You can follow both - or just one. There is no wrong choice.',
        ],
        body:
            'Swing is the realistic choice for most users - holds last days, you check twice a day, and the setup either works or hits the stop. LEAPs are for long-term thesis trades - low maintenance, but you tie up capital longer.',
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
        ],
        body:
            'Power hour is where the day s thesis gets confirmed or rejected. If SPY is up 1% all day and starts giving it back at 3:00, that tells you something about tomorrow - useful context for managing existing swing positions, not just for the closing bell.',
      ),
      LearnLesson(
        id: 'using-snooze',
        title: 'Snooze: Silence Everything for a Window',
        summary:
            'One tap to mute every push when you need focus — without rewriting all your prefs.',
        bullets: <String>[
          'Settings → Notifications → Snooze card has three chips: 1 hour, 8 hours, Until 8am.',
          'Tap a chip and EVERY push (scanner, hot, chat broadcasts, @mentions, premarket, recap, announcements) is suppressed until the timer expires.',
          'Snooze beats quiet-hours bypass. Even "truly emergent" admin pushes wait until snooze expires.',
          'When snooze is active, a gold strip appears on Home (and on Hot Trades and Scanner) showing "Notifications snoozed until 14:30 · 1h 12m left".',
          'Tap the strip from anywhere to jump back to Settings and extend or cancel.',
          'Cancel mid-window: open Settings → tap Cancel in the snooze card. Pushes resume immediately on the next fan-out.',
          'Snooze auto-clears when the timer hits zero — no manual cleanup needed.',
          'Your individual channel toggles, advanced filters, quiet hours, and per-room chat mutes are NOT touched. When snooze expires, your prefs are exactly how you left them.',
        ],
        body:
            'Snooze is the right tool when you need silence for a defined window — a meeting, a workout, deep focus on one trade. The mistake people make is to toggle every channel off individually, then forget which ones were on when they come back.\n\nSnooze keeps your prefs intact. You set a timer; everything goes quiet; the timer expires; pushes resume exactly as configured. There is no "undo my snooze and figure out what I had before" problem.\n\nThe gold indicator on Home is intentional. The cost of a missed quiet-hours window is at most one missed alert; the cost of forgetting you snoozed for 8 hours and then wondering why the app feels broken is much higher. Tap the indicator to extend (chips stay live while snoozed) or to cancel.\n\nA note on overlapping windows. If you have quiet hours 22:00-06:00 AND you snooze for 8 hours starting at 14:00, the snooze wins until 22:00 — at which point quiet hours take over. Pushes resume at 06:00. You do not need to do math here; the queue handles overlap and you will never get a push during either window.\n\nFinally, snooze is per-user, not per-device. Snoozing on your phone snoozes your iPad too. The user doc syncs across all your sessions on the next snapshot.',
      ),
      LearnLesson(
        id: 'using-the-chat',
        title: 'Using the Chat: Mentions, Mute, Search',
        summary:
            'Tag people, quiet rooms you do not need right now, and find old posts fast.',
        bullets: <String>[
          'Type @ to summon the user picker — pick a name and the message will buzz that person\'s phone.',
          'Admins can use @everyone to push to the whole roster. Regular users\' @everyone is silently dropped server-side.',
          'Each room tile on Chat home shows a gold unread count when there are messages newer than the last time you opened it.',
          'The Chat tab in the bottom nav shows a rollup badge — total unread across every room — so you do not have to open Chat to know something is waiting.',
          'Tap the bell icon in any room\'s AppBar to mute. Muted rooms still receive messages and still appear in the list — they just stop buzzing your phone and stop firing the badge.',
          'Tap the magnifier in any room\'s AppBar to filter the last ~100 messages by text or sender. Useful when you remember "X said something about NVDA" but cannot find it.',
          'On Chat home, when at least one room has unread messages, a gold strip appears with "Mark all read" — clears every badge in one tap.',
          'Settings → Notifications → "Chat broadcasts + @mentions" is the master kill switch for ALL chat-driven pushes. Mute that and you go silent across every room until you flip it back.',
        ],
        body:
            'Chat is meant to be useful, not noisy. The mute-per-room toggle is the most underrated tool in there — if you are deep in a trade and do not want ADMIN BUYS screenshots buzzing for the next 30 minutes, mute the room. The unread badge still shows, so you can catch up at your pace.\n\n@mentions are the opposite — they explicitly cut through. If someone tags you specifically, you get a push titled "@Sender mentioned you" even if the room itself is busy. Admins can broadcast @everyone, which fires a separate push to every active phone (still subject to each user\'s mute settings).\n\nThe search sheet is room-scoped on purpose. It only filters messages currently streamed into the room — meaning the last ~100 — but those load as soon as you open the room, so search is instant. For older history, scroll the room.\n\nFinally, a note on the badge counts. They are capped at 99 client-side so the chip stays readable. If you see 99+ for a long time, that just means real activity — not a stuck counter. Tap "Mark all read" or open each room to clear.',
      ),
    ],
  ),
];
