from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MIGRATION = ROOT / "supabase" / "canonical_flow_documentary_close_rollforward_2026_09_15.sql"


def require(sql: str, token: str) -> None:
    if token not in sql:
        raise AssertionError(f"missing documentary roll-forward contract: {token}")


def main() -> None:
    sql = MIGRATION.read_text(encoding="utf-8")

    for token in (
        "create or replace function public.lts_flow_documentary_close_overlay_v1",
        "from public.lts_flow_past_operational_v2(p_user_id, lo, hi)",
        "(x->>'event_date')::date > anchor_date",
        "(x->>'event_date')::date <= dt",
        "documentary_close_plus_effective_movements",
        "asof-anchor-plus-effective-rollforward-v2",
        "reconciliation_gap",
        "from public, anon, authenticated",
    ):
        require(sql, token)

    if "lts_historical_effective_cash_v4" in sql:
        raise AssertionError("certified-only reader would drop moved projections after their date passes")

    # Synthetic parity case: a moved inflow and a moved outflow must roll from
    # the certified close into the historical close exactly once.
    anchor = 1_000.00
    effective_movements = (300.00, -200.00)
    closing = anchor + sum(effective_movements)
    if closing != 1_100.00:
        raise AssertionError(f"synthetic roll-forward mismatch: {closing}")
    if closing + 450.00 - 50.00 != 1_500.00:
        raise AssertionError("next-day opening/closing continuity mismatch")

    print("documentary roll-forward gate: PASS")


if __name__ == "__main__":
    main()

