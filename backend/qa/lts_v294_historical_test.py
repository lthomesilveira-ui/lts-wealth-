"""Synthetic regression only; no bank or private workbook fixtures."""
import copy
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from zipfile import ZipFile

from lts_v294_cash_cache_reconciliation import inspect


def fixture():
    rows = [{"row": row, "cells": {"B" + str(row): {"type": "n", "value": value}}}
            for row, value in [(3, "43467"), (5, "100.10"), (7, "50.20"), (53, "20.05"), (165, "130.25")]]
    source = {"sha256": "a" * 64, "rows": rows}
    return source, copy.deepcopy(source), [{"date": "2019-01-02", "itau": {"balance": 130.25}}]


class HistoricalTest(unittest.TestCase):
    def test_exact_cash_and_source_match(self):
        r = inspect(*fixture(), 2019)
        self.assertTrue(r["pass"])
        self.assertEqual(r["api_matching_positions"], 1)
        self.assertTrue(r["does_not_certify_complete_bank_statements"])

    def test_source_difference_is_not_hidden(self):
        a, b, api = fixture()
        b["rows"][-1]["cells"]["B165"]["value"] = "130.26"
        r = inspect(a, b, api, 2019)
        self.assertFalse(r["pass"])
        self.assertEqual(len(r["source_differences"]), 1)

    def test_arithmetic_difference_is_not_balancing_entry(self):
        a, b, api = fixture()
        a["rows"][-1]["cells"]["B165"]["value"] = "130.27"
        r = inspect(a, b, api, 2019)
        self.assertFalse(r["pass"])
        self.assertEqual(len(r["source_arithmetic_errors"]), 1)

    def test_missing_position_does_not_become_zero(self):
        a, b, api = fixture()
        api[0]["itau"]["balance"] = None
        r = inspect(a, b, api, 2019)
        self.assertFalse(r["pass"])
        self.assertEqual(len(r["api_missing_positions"]), 1)

    def test_zero_is_a_real_position(self):
        a, b, api = fixture()
        for s in (a, b):
            for row in s["rows"]:
                if row["row"] != 3:
                    row["cells"]["B" + str(row["row"])]["value"] = "0"
        api[0]["itau"]["balance"] = 0
        self.assertTrue(inspect(a, b, api, 2019)["pass"])

    def test_error_cache_is_not_numeric_zero(self):
        a, b, api = fixture()
        a["rows"][1]["cells"]["B5"] = {"type": "e", "value": "#NAME?"}
        self.assertFalse(inspect(a, b, api, 2019)["pass"])

    def test_empty_year_is_not_a_pass(self):
        self.assertFalse(inspect(*fixture(), 2020)["pass"])

    def test_duplicate_api_day_is_rejected(self):
        a, b, api = fixture()
        with self.assertRaises(ValueError):
            inspect(a, b, api * 2, 2019)

    def test_original_formula_cache_not_recalculated_or_executed(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "synthetic.xlsm"
            with ZipFile(source, "w") as z:
                z.writestr("xl/workbook.xml", '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Cash" sheetId="1" r:id="r1"/></sheets></workbook>')
                z.writestr("xl/_rels/workbook.xml.rels", '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="r1" Target="worksheets/sheet1.xml"/></Relationships>')
                z.writestr("xl/worksheets/sheet1.xml", '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row r="1"><c r="B1"><f>NONEXISTENT_MACRO()</f><v>12.340000000001</v></c><c r="C1" t="e"><v>#NAME?</v></c></row></sheetData></worksheet>')
            helper = Path(__file__).with_name("lts_v294_workbook_cache.py")
            raw = subprocess.check_output([sys.executable, str(helper), str(source), "--sheet", "Cash", "--rows", "1:1", "--columns", "2:3"])
            cells = json.loads(raw)["rows"][0]["cells"]
            self.assertEqual(cells["B1"]["value"], "12.340000000001")
            self.assertEqual(cells["B1"]["formula"], "NONEXISTENT_MACRO()")
            self.assertEqual(cells["C1"]["value"], "#NAME?")


if __name__ == "__main__":
    unittest.main()
