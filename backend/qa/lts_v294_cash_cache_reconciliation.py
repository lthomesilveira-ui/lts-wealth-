"""Compare cached original workbook cash cells with another source and actual API days.

No spreadsheet edits, recalculation, source promotion or inferred balancing entries.
Numeric cached values are read as Decimal; a missing position remains missing.
"""
import argparse
import json
from datetime import datetime, timedelta
from decimal import Decimal, InvalidOperation
from pathlib import Path

FIELDS = {"opening": 5, "income": 7, "expense": 53, "closing": 165}
TOLERANCE = Decimal("0.005")


def numeric(cell):
    if not cell or cell.get("type") not in ("n", None):
        return None
    try:
        number = Decimal(str(cell["value"]))
        return number if number.is_finite() else None
    except (KeyError, InvalidOperation):
        return None


def inspect(original, companion, api, year):
    rows = {r["row"]: r["cells"] for r in original["rows"]}
    other = {r["row"]: r["cells"] for r in companion["rows"]}
    days = {d["date"]: d for d in api}
    if len(days) != len(api):
        raise ValueError("Duplicate API date")
    summary = {"year": year, "original_sha256": original["sha256"],
               "companion_sha256": companion["sha256"], "source_days": 0,
               "source_arithmetic_errors": [], "source_differences": [],
               "api_position_differences": [], "api_missing_positions": [],
               "api_matching_positions": 0}
    seen = set()
    for address, cell in rows[3].items():
        serial = numeric(cell)
        if serial is None:
            continue
        date = (datetime(1899, 12, 30) + timedelta(days=float(serial))).strftime("%Y-%m-%d")
        if int(date[:4]) != year:
            continue
        if date in seen:
            raise ValueError("Duplicate source date")
        seen.add(date)
        column = address.rstrip("0123456789")
        values = {key: numeric(rows.get(row, {}).get(column + str(row))) for key, row in FIELDS.items()}
        summary["source_days"] += 1
        if any(value is None for value in values.values()):
            summary["source_arithmetic_errors"].append({"date": date, "reason": "missing_numeric_input"})
            continue
        gap = values["closing"] - values["opening"] - values["income"] + values["expense"]
        if abs(gap) >= TOLERANCE:
            summary["source_arithmetic_errors"].append({"date": date, "gap": str(gap)})
        for key, row in FIELDS.items():
            value = numeric(other.get(row, {}).get(column + str(row)))
            if value is None or abs(values[key] - value) >= TOLERANCE:
                summary["source_differences"].append({"date": date, "field": key,
                    "original": str(values[key]), "companion": str(value) if value is not None else None})
        actual = days.get(date, {}).get("itau", {})
        balance = actual.get("balance")
        if balance is None:
            summary["api_missing_positions"].append({"date": date, "basis": actual.get("balance_basis")})
        elif abs(Decimal(str(balance)) - values["closing"]) >= TOLERANCE:
            summary["api_position_differences"].append({"date": date,
                "source_closing": str(values["closing"]), "api_closing": balance,
                "basis": actual.get("balance_basis")})
        else:
            summary["api_matching_positions"] += 1
    summary["does_not_certify_complete_bank_statements"] = True
    summary["pass"] = (summary["source_days"] > 0
        and not any(summary[key] for key in ("source_arithmetic_errors", "source_differences",
                    "api_position_differences", "api_missing_positions"))
        and summary["api_matching_positions"] == summary["source_days"])
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("original", type=Path)
    parser.add_argument("companion", type=Path)
    parser.add_argument("api_days", type=Path)
    parser.add_argument("--year", required=True, type=int)
    args = parser.parse_args()
    sources = [json.loads(path.read_text(encoding="utf-8")) for path in (args.original, args.companion, args.api_days)]
    print(json.dumps(inspect(*sources, args.year), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
