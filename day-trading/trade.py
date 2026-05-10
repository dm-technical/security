"""CLI: screen for day-trade picks and optionally submit bracket orders.

Examples:
  # Just print today's top 10 picks from the default universe.
  python trade.py screen

  # Screen a custom watchlist.
  python trade.py screen --tickers AAPL,MSFT,NVDA,TSLA

  # Screen and place paper-trade bracket orders for the top 3.
  python trade.py trade --top 3 --notional 1000

  # Send to live trading (requires ALPACA_BASE_URL=https://api.alpaca.markets).
  python trade.py trade --top 3 --notional 1000 --live
"""
from __future__ import annotations

import argparse
import json
import sys
from typing import Iterable

from dotenv import load_dotenv

from broker import Broker, AlpacaError
from screener import Pick, screen
from universe import DEFAULT_UNIVERSE


def _parse_tickers(arg: str | None) -> list[str]:
    if not arg:
        return list(DEFAULT_UNIVERSE)
    return [t.strip().upper() for t in arg.split(",") if t.strip()]


def _print_picks(picks: Iterable[Pick]) -> None:
    rows = [p.as_dict() for p in picks]
    if not rows:
        print("No picks matched the filters.")
        return
    cols = ["ticker", "last_price", "gap_pct", "intraday_pct",
            "rel_volume", "atr_pct", "rsi14", "score"]
    widths = {c: max(len(c), max(len(str(r[c])) for r in rows)) for c in cols}
    header = "  ".join(c.ljust(widths[c]) for c in cols)
    print(header)
    print("-" * len(header))
    for r in rows:
        print("  ".join(str(r[c]).ljust(widths[c]) for c in cols))


def cmd_screen(args: argparse.Namespace) -> int:
    tickers = _parse_tickers(args.tickers)
    picks = screen(
        tickers,
        min_price=args.min_price,
        min_rel_volume=args.min_rel_volume,
        top_n=args.top,
    )
    if args.json:
        print(json.dumps([p.as_dict() for p in picks], indent=2))
    else:
        _print_picks(picks)
    return 0


def cmd_trade(args: argparse.Namespace) -> int:
    broker = Broker.from_env()
    if not broker.is_paper and not args.live:
        print(
            "Refusing to trade: ALPACA_BASE_URL points at the live endpoint but "
            "--live was not passed. Aborting.",
            file=sys.stderr,
        )
        return 2

    clock = broker.clock()
    if not clock.get("is_open"):
        print(f"Market is closed (next open: {clock.get('next_open')}). Aborting.",
              file=sys.stderr)
        return 3

    tickers = _parse_tickers(args.tickers)
    picks = screen(
        tickers,
        min_price=args.min_price,
        min_rel_volume=args.min_rel_volume,
        top_n=args.top,
    )
    if not picks:
        print("No picks to trade.")
        return 0

    print(f"Trading on {'PAPER' if broker.is_paper else 'LIVE'} account:")
    _print_picks(picks)
    print()

    for p in picks:
        # Direction: ride the dominant intraday move. RSI extremes flipped to mean-revert.
        if p.rsi14 >= 75:
            side = "sell"
        elif p.rsi14 <= 25:
            side = "buy"
        else:
            side = "buy" if (p.gap_pct + p.intraday_pct) >= 0 else "sell"

        qty = max(1, int(args.notional // p.last_price))
        try:
            order = broker.submit_bracket_order(
                symbol=p.ticker,
                qty=qty,
                side=side,
                take_profit_pct=args.take_profit,
                stop_loss_pct=args.stop_loss,
                last_price=p.last_price,
            )
            print(f"  {side.upper():4} {qty:>4} {p.ticker:<6} "
                  f"@~${p.last_price:.2f}  order_id={order.get('id')}")
        except AlpacaError as e:
            print(f"  FAIL {p.ticker}: {e}", file=sys.stderr)

    return 0


def main(argv: list[str] | None = None) -> int:
    load_dotenv()
    parser = argparse.ArgumentParser(description="Day-trading screener + Alpaca executor.")
    sub = parser.add_subparsers(dest="cmd", required=True)

    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--tickers", help="Comma-separated symbols (default: built-in universe)")
    common.add_argument("--top", type=int, default=10, help="Top N picks (default 10)")
    common.add_argument("--min-price", type=float, default=5.0)
    common.add_argument("--min-rel-volume", type=float, default=0.5,
                        help="Min today_volume / 20d_avg (default 0.5)")

    p_screen = sub.add_parser("screen", parents=[common], help="Print picks, no orders.")
    p_screen.add_argument("--json", action="store_true")
    p_screen.set_defaults(func=cmd_screen)

    p_trade = sub.add_parser("trade", parents=[common], help="Place bracket orders for top picks.")
    p_trade.add_argument("--notional", type=float, default=1000.0,
                         help="Approx $ per position (default 1000)")
    p_trade.add_argument("--take-profit", type=float, default=0.01,
                         help="Take-profit as decimal (default 0.01 = 1%%)")
    p_trade.add_argument("--stop-loss", type=float, default=0.005,
                         help="Stop-loss as decimal (default 0.005 = 0.5%%)")
    p_trade.add_argument("--live", action="store_true",
                         help="Required acknowledgement when ALPACA_BASE_URL is the live endpoint.")
    p_trade.set_defaults(func=cmd_trade)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
