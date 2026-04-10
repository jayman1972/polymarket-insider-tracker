"""Forward risk assessments to DataBridge / Supabase ingestion (Alpha Scout)."""

from __future__ import annotations

import logging
from datetime import UTC, datetime

import httpx

from polymarket_insider_tracker.detector.models import RiskAssessment

logger = logging.getLogger(__name__)


def build_dedup_key(wallet_address: str, market_id: str, when: datetime) -> str:
    """Match AlertHistory dedup: wallet:market:YYYYMMDDHH (UTC)."""
    hour_str = when.strftime("%Y%m%d%H")
    return f"{wallet_address}:{market_id}:{hour_str}"


def _signal_names(assessment: RiskAssessment) -> list[str]:
    names: list[str] = []
    if assessment.fresh_wallet_signal:
        names.append("fresh_wallet")
    if assessment.size_anomaly_signal:
        names.append("size_anomaly")
        if assessment.size_anomaly_signal.is_niche_market:
            names.append("niche_market")
    return names


def build_webhook_payload(assessment: RiskAssessment) -> dict[str, object]:
    """JSON body for POST /polymarket/alert on DataBridge."""
    when = assessment.timestamp
    if when.tzinfo is None:
        when = when.replace(tzinfo=UTC)
    dedup = build_dedup_key(assessment.wallet_address, assessment.market_id, when.astimezone(UTC))
    te = assessment.trade_event
    return {
        "dedup_key": dedup,
        "wallet_address": assessment.wallet_address,
        "market_id": assessment.market_id,
        "trade_id": te.trade_id,
        "trade_side": te.side,
        "trade_price": str(te.price),
        "trade_size_usdc": str(te.notional_value),
        "risk_score": assessment.weighted_score,
        "signals_triggered": _signal_names(assessment),
        "assessment_id": assessment.assessment_id,
        "alerted_at": when.astimezone(UTC).isoformat(),
        "payload": assessment.to_dict(),
    }


async def forward_assessment_to_alphascout(
    assessment: RiskAssessment,
    *,
    webhook_url: str,
    webhook_secret: str,
    timeout_s: float = 15.0,
) -> None:
    """POST assessment to DataBridge; logs and swallows errors (non-fatal)."""
    body = build_webhook_payload(assessment)
    headers = {
        "Authorization": f"Bearer {webhook_secret}",
        "Content-Type": "application/json",
    }
    try:
        async with httpx.AsyncClient(timeout=timeout_s) as client:
            r = await client.post(webhook_url, json=body, headers=headers)
        if r.status_code >= 400:
            logger.warning(
                "Alpha Scout webhook returned %s: %s",
                r.status_code,
                (r.text or "")[:500],
            )
        else:
            logger.debug("Alpha Scout webhook ok: %s", r.status_code)
    except Exception as e:
        logger.warning("Alpha Scout webhook failed: %s", e)
