# day-trading

A small Python tool that screens for day-trading candidates using Yahoo Finance
data and (optionally) executes bracket orders via the Alpaca trading API.

It is a screener + executor, not a prediction engine. Treat the picks as a
ranked watchlist driven by transparent signals (gap, relative volume, ATR,
RSI), not a "buy these" list.

## Setup

```bash
cd day-trading
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# edit .env with your Alpaca keys (paper-trading by default)
```

Get free Alpaca paper-trading keys at https://app.alpaca.markets.

## Usage

Print the top 10 picks from the built-in universe:

```bash
python trade.py screen
```

Use a custom watchlist and emit JSON:

```bash
python trade.py screen --tickers AAPL,MSFT,NVDA,TSLA,SPY --json
```

Place paper bracket orders for the top 3 picks (~$1000 each, 1% take-profit,
0.5% stop-loss):

```bash
python trade.py trade --top 3 --notional 1000
```

Live trading requires explicitly pointing `ALPACA_BASE_URL` at
`https://api.alpaca.markets` *and* passing `--live`:

```bash
ALPACA_BASE_URL=https://api.alpaca.markets python trade.py trade --top 3 --live
```

## How the score works

For each ticker the screener computes:

- **gap_pct** — overnight gap (today's open vs prior close)
- **intraday_pct** — change since today's open
- **rel_volume** — today's volume vs the 20-day average
- **atr_pct** — 14-day ATR as a percentage of price (volatility)
- **rsi14** — 14-day RSI, used to dampen exhausted moves

The composite score rewards volatility, relative volume, and clear directional
moves; it lightly penalizes RSI > 80 / < 20. When executing, RSI extremes flip
the side to a mean-reversion trade; otherwise the side follows the dominant
intraday direction.

## Files

- `screener.py` — pulls Yahoo Finance bars, computes signals, ranks picks
- `broker.py` — minimal Alpaca REST client (account, clock, bracket orders)
- `trade.py` — CLI entry point
- `universe.py` — default ticker list

## Disclaimer

This is sample software. Day trading is risky and most retail day traders lose
money. Run on paper for a long time before considering real capital, and
understand every line of `screener.py` before trusting its picks.
