"""Default ticker universe for the screener.

Liquid US large-caps and high-volume ETFs that typically have tight spreads
and enough intraday range to be tradeable. Override with --tickers on the CLI.
"""

DEFAULT_UNIVERSE = [
    # Mega-cap tech
    "AAPL", "MSFT", "GOOGL", "AMZN", "META", "NVDA", "TSLA", "AMD", "AVGO", "NFLX",
    # Other large caps with decent intraday range
    "JPM", "BAC", "WFC", "GS", "MS",
    "XOM", "CVX", "OXY",
    "PFE", "MRNA", "LLY",
    "DIS", "BA", "CAT", "GE",
    "COIN", "MSTR", "PLTR", "SOFI", "RIVN", "LCID", "NIO",
    # Liquid ETFs
    "SPY", "QQQ", "IWM", "DIA",
    "XLF", "XLE", "XLK", "XLV",
    "TQQQ", "SQQQ", "SOXL", "SOXS",
]
