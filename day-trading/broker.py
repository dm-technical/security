"""Minimal Alpaca REST client for placing day-trade orders.

Defaults to the paper-trading endpoint. Real-money trading requires explicitly
setting ALPACA_BASE_URL=https://api.alpaca.markets and confirming with --live.

We talk to the REST API directly (no SDK) so the dependency footprint stays small.
Docs: https://docs.alpaca.markets/reference/
"""
from __future__ import annotations

import os
from dataclasses import dataclass

import requests

PAPER_URL = "https://paper-api.alpaca.markets"


class AlpacaError(RuntimeError):
    pass


@dataclass
class Broker:
    api_key: str
    secret_key: str
    base_url: str = PAPER_URL

    @classmethod
    def from_env(cls) -> "Broker":
        key = os.environ.get("ALPACA_API_KEY")
        secret = os.environ.get("ALPACA_SECRET_KEY")
        base = os.environ.get("ALPACA_BASE_URL", PAPER_URL)
        if not key or not secret:
            raise AlpacaError(
                "ALPACA_API_KEY / ALPACA_SECRET_KEY not set. Copy .env.example to .env."
            )
        return cls(api_key=key, secret_key=secret, base_url=base.rstrip("/"))

    @property
    def is_paper(self) -> bool:
        return "paper" in self.base_url

    def _headers(self) -> dict:
        return {
            "APCA-API-KEY-ID": self.api_key,
            "APCA-API-SECRET-KEY": self.secret_key,
        }

    def _request(self, method: str, path: str, **kwargs) -> dict:
        url = f"{self.base_url}{path}"
        resp = requests.request(method, url, headers=self._headers(), timeout=15, **kwargs)
        if resp.status_code >= 400:
            raise AlpacaError(f"{method} {path} -> {resp.status_code}: {resp.text}")
        return resp.json() if resp.content else {}

    def account(self) -> dict:
        return self._request("GET", "/v2/account")

    def clock(self) -> dict:
        return self._request("GET", "/v2/clock")

    def positions(self) -> list[dict]:
        return self._request("GET", "/v2/positions")  # type: ignore[return-value]

    def submit_bracket_order(
        self,
        symbol: str,
        qty: int,
        side: str,
        take_profit_pct: float,
        stop_loss_pct: float,
        last_price: float,
    ) -> dict:
        """Submit a market bracket order with attached take-profit and stop-loss legs.

        Bracket orders close the position automatically when either leg fills,
        which is the right default for day trading where you don't want to be
        glued to the screen.
        """
        if side not in ("buy", "sell"):
            raise ValueError("side must be 'buy' or 'sell'")
        if qty <= 0:
            raise ValueError("qty must be positive")

        if side == "buy":
            tp_price = round(last_price * (1 + take_profit_pct), 2)
            sl_price = round(last_price * (1 - stop_loss_pct), 2)
        else:
            tp_price = round(last_price * (1 - take_profit_pct), 2)
            sl_price = round(last_price * (1 + stop_loss_pct), 2)

        payload = {
            "symbol": symbol,
            "qty": str(qty),
            "side": side,
            "type": "market",
            "time_in_force": "day",
            "order_class": "bracket",
            "take_profit": {"limit_price": str(tp_price)},
            "stop_loss": {"stop_price": str(sl_price)},
        }
        return self._request("POST", "/v2/orders", json=payload)
