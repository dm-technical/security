"""Day-trading screener using Yahoo Finance data.

Pulls recent intraday and daily bars for each ticker, computes a handful of
transparent signals (gap, relative volume, ATR-based volatility, RSI), and
ranks the universe by a composite score.

This is a screener, not a prediction engine. Treat the output as a watchlist.
"""
from __future__ import annotations

from dataclasses import dataclass, asdict
from typing import Iterable

import numpy as np
import pandas as pd
import yfinance as yf


@dataclass
class Pick:
    ticker: str
    last_price: float
    gap_pct: float          # overnight gap vs prior close
    intraday_pct: float     # change since today's open
    rel_volume: float       # today's volume / 20d avg volume
    atr_pct: float          # 14d ATR as % of price
    rsi14: float
    score: float

    def as_dict(self) -> dict:
        d = asdict(self)
        for k, v in d.items():
            if isinstance(v, float):
                d[k] = round(v, 4)
        return d


def _rsi(series: pd.Series, period: int = 14) -> float:
    delta = series.diff().dropna()
    if len(delta) < period:
        return float("nan")
    gain = delta.clip(lower=0).rolling(period).mean()
    loss = (-delta.clip(upper=0)).rolling(period).mean()
    rs = gain / loss.replace(0, np.nan)
    rsi = 100 - (100 / (1 + rs))
    return float(rsi.iloc[-1])


def _atr_pct(daily: pd.DataFrame, period: int = 14) -> float:
    if len(daily) < period + 1:
        return float("nan")
    high, low, close = daily["High"], daily["Low"], daily["Close"]
    prev_close = close.shift(1)
    tr = pd.concat(
        [(high - low), (high - prev_close).abs(), (low - prev_close).abs()],
        axis=1,
    ).max(axis=1)
    atr = tr.rolling(period).mean().iloc[-1]
    return float(atr / close.iloc[-1])


def _analyze(ticker: str) -> Pick | None:
    t = yf.Ticker(ticker)
    daily = t.history(period="3mo", interval="1d", auto_adjust=False)
    if daily.empty or len(daily) < 20:
        return None

    intraday = t.history(period="1d", interval="5m", auto_adjust=False)
    if intraday.empty:
        return None

    last_price = float(intraday["Close"].iloc[-1])
    today_open = float(intraday["Open"].iloc[0])
    prior_close = float(daily["Close"].iloc[-2])

    gap_pct = (today_open - prior_close) / prior_close
    intraday_pct = (last_price - today_open) / today_open

    today_volume = float(intraday["Volume"].sum())
    avg_volume = float(daily["Volume"].tail(20).mean())
    rel_volume = today_volume / avg_volume if avg_volume > 0 else 0.0

    atr_pct = _atr_pct(daily)
    rsi14 = _rsi(daily["Close"])

    # Composite score: reward volatility + relative volume + clear directional move.
    # RSI extremes are penalized lightly to avoid chasing exhausted moves.
    move = abs(gap_pct) + abs(intraday_pct)
    rsi_penalty = 0.0
    if not np.isnan(rsi14):
        if rsi14 > 80 or rsi14 < 20:
            rsi_penalty = 0.5
    score = (
        (atr_pct or 0) * 100 * 1.0
        + rel_volume * 1.5
        + move * 100 * 1.2
        - rsi_penalty
    )

    return Pick(
        ticker=ticker,
        last_price=last_price,
        gap_pct=gap_pct,
        intraday_pct=intraday_pct,
        rel_volume=rel_volume,
        atr_pct=atr_pct if not np.isnan(atr_pct) else 0.0,
        rsi14=rsi14 if not np.isnan(rsi14) else 0.0,
        score=score,
    )


def screen(
    tickers: Iterable[str],
    *,
    min_price: float = 5.0,
    min_rel_volume: float = 0.5,
    top_n: int = 10,
) -> list[Pick]:
    """Return the top_n picks from `tickers`, filtered and ranked by composite score."""
    picks: list[Pick] = []
    for ticker in tickers:
        try:
            p = _analyze(ticker)
        except Exception as e:  # noqa: BLE001 - log and continue
            print(f"[skip] {ticker}: {e}")
            continue
        if p is None:
            continue
        if p.last_price < min_price:
            continue
        if p.rel_volume < min_rel_volume:
            continue
        picks.append(p)

    picks.sort(key=lambda x: x.score, reverse=True)
    return picks[:top_n]
