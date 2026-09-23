"""Read-only audit of saved daily cash cells in the original Excel workbook.

No source files are modified. A bank's first *documented* activity date must be
supplied by the caller: reused spreadsheet cells are not evidence of an account.

Example:
  python audit_original_daily_balances.py original.xlsm \
    --bank 'Itaú:5:7:53:165:2013-10-10' \
    --bank 'Bradesco:167:169:176:198:2022-04-13' \
    --bank 'C6:200:202:210:221:2024-05-12'
"""

import argparse
import collections
import datetime as dt
import json
import sys
import xml.etree.ElementTree as ET
import zipfile
from decimal import Decimal, InvalidOperation


MAIN = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
REL = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}"
EXCEL_EPOCH = dt.date(1899, 12, 30)


def column_number(ref):
    digits = ref.rstrip("0123456789")
    number = 0
    for char in digits:
        number = number * 26 + ord(char) - ord("A") + 1
    return number


def sheet_member(archive, name):
    workbook = ET.fromstring(archive.read("xl/workbook.xml"))
    relations = ET.fromstring(archive.read("xl/_rels/workbook.xml.rels"))
    targets = {item.get("Id"): item.get("Target") for item in relations}
    for item in workbook.iter(MAIN + "sheet"):
        if item.get("name") == name:
            target = targets[item.get(REL + "id")].lstrip("/")
            return target if target.startswith("xl/") else "xl/" + target
    raise ValueError("Worksheet not found: " + name)


def saved_rows(archive, member, selected):
    rows = collections.defaultdict(dict)
    with archive.open(member) as stream:
        for _, cell in ET.iterparse(stream, events=("end",)):
            if cell.tag != MAIN + "c":
                continue
            ref = cell.get("r")
            row = int(ref.lstrip("ABCDEFGHIJKLMNOPQRSTUVWXYZ"))
            if row in selected:
                value = cell.find(MAIN + "v")
                rows[row][column_number(ref)] = (
                    value.text if value is not None else None,
                    cell.get("t"),
                )
            cell.clear()
    return rows


def decimal(cell):
    if not cell or cell[0] is None or cell[1] == "e":
        return None
    try:
        return Decimal(cell[0])
    except InvalidOperation:
        return None


def date(cell):
    value = decimal(cell)
    if value is None:
        return None
    try:
        return EXCEL_EPOCH + dt.timedelta(days=int(value))
    except (OverflowError, ValueError):
        return None


def cents(value):
    return int((value * 100).quantize(Decimal("1")))


def audit(rows, specs, limit, through, min_delta_cents):
    dated = {col: date(raw) for col, raw in rows[3].items()}
    output = {"date_errors": sum(1 for raw in rows[3].values() if raw[1] == "e"), "banks": {}}
    for name, opening, income, expense, closing, active in specs:
        start = dt.date.fromisoformat(active)
        result = {"first_documented_activity": active, "complete_days": 0,
                  "pre_activity_nonzero_saved_days": 0, "invalid_cells_after_activity": 0,
                  "arithmetic_breaks": [], "continuity_breaks": []}
        previous = None
        for col, day in sorted(dated.items()):
            if day is None or day > through:
                continue
            values = [decimal(rows[r].get(col)) for r in (opening, income, expense, closing)]
            if day < start:
                result["pre_activity_nonzero_saved_days"] += any(
                    value is not None and cents(value) != 0 for value in values
                )
                continue
            if any(value is None for value in values):
                result["invalid_cells_after_activity"] += 1
                previous = None
                continue
            result["complete_days"] += 1
            a, inn, out, z = map(cents, values)
            if abs(z - a - inn + out) >= min_delta_cents and len(result["arithmetic_breaks"]) < limit:
                result["arithmetic_breaks"].append({"date": day.isoformat(), "column": col, "delta_cents": z - a - inn + out})
            if previous and (day - previous[0]).days == 1 and abs(a - previous[1]) >= min_delta_cents and len(result["continuity_breaks"]) < limit:
                result["continuity_breaks"].append({"date": day.isoformat(), "column": col, "delta_cents": a - previous[1]})
            previous = (day, z)
        output["banks"][name] = result
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("workbook")
    parser.add_argument("--bank", action="append", required=True,
                        help="name:opening-row:income-row:expense-row:closing-row:YYYY-MM-DD")
    parser.add_argument("--limit", type=int, default=10)
    parser.add_argument("--through", default="2026-07-08", help="Last source date, excluding projections")
    parser.add_argument("--min-delta-cents", type=int, default=2, help="Ignore independent rounding of fractional cents")
    args = parser.parse_args()
    specs = []
    for raw in args.bank:
        name, opening, income, expense, closing, active = raw.split(":")
        specs.append((name, int(opening), int(income), int(expense), int(closing), active))
    selected = {3} | {row for _, *numbers, _ in specs for row in numbers}
    with zipfile.ZipFile(args.workbook) as archive:
        rows = saved_rows(archive, sheet_member(archive, "Fluxo de Caixa"), selected)
    json.dump(audit(rows, specs, args.limit, dt.date.fromisoformat(args.through), args.min_delta_cents), sys.stdout, ensure_ascii=False, indent=2)
    print()


if __name__ == "__main__":
    main()
