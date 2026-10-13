"""Offline synthetic contract tests. No connection, real user data or mutations.

The candidate CASE/aggregate expressions are extracted from the SQL and executed
in SQLite with a PostgreSQL-compatible regexp_replace shim for this bounded
pattern. This is not a full PostgreSQL integration or financial acceptance test.
"""
from pathlib import Path
import hashlib
import json
import re
import sqlite3
import unittest

ROOT = Path('backend')
ORIGINAL = (ROOT / "qa/v269_source_previous.sql").read_text()
CANDIDATE = (ROOT / "patches/v269/lts_card_source_rows_pre_v262.sql").read_text()


def regexp_replace(value, pattern, replacement, flags):
    pattern = pattern.replace("[[:space:]]", r"\s")
    return re.sub(pattern, replacement, value,
                  count=0 if "g" in flags else 1,
                  flags=re.I if "i" in flags else 0)


def db():
    c = sqlite3.connect(":memory:")
    c.create_function("regexp_replace", 4, regexp_replace)
    return c


def selection(source, values):
    fragment = source.split("), classified as (", 1)[1].split(
        " case when d.category_label is not null then case", 1)[0]
    fragment = fragment[fragment.index("coalesce(d.category_label"):].rstrip().rstrip(",")
    fragment = fragment.replace("::text", "")
    aliases = {
        "d": ("category_label", "beneficiary"),
        "ic": ("category", "person"),
        "ec": ("category", "person"),
        "sr": ("category", "person"),
        "nc": ("category",),
    }
    ctes, params = [], []
    for alias, names in aliases.items():
        ctes.append(f"{alias} AS (SELECT " + ",".join(f"? AS {n}" for n in names) + ")")
        params.extend(values.get(alias, {}).get(n) for n in names)
    query = "WITH " + ",".join(ctes) + " SELECT " + fragment + " FROM " + ",".join(aliases)
    with db() as c:
        return c.execute(query, params).fetchone()


def aggregate(cte, rows):
    source = CANDIDATE.split(f"), {cte} as materialized (", 1)[1].split(
        " from evidence where", 1)[0]
    source = re.sub(r"--[^\n]*", "", source).replace("::text", "").strip()
    with db() as c:
        c.execute("CREATE TABLE evidence(k TEXT, amount NUMERIC, category TEXT, person TEXT)")
        c.executemany("INSERT INTO evidence VALUES (?,?,?,?)", rows)
        return c.execute(source + (" FROM evidence GROUP BY k,amount" if cte == "exact_categories"
                                   else " FROM evidence GROUP BY k")).fetchall()


def complete_purchase_key(s):
    """Synthetic mirror of the documented unchanged V231 identity contract."""
    if (s.get("resource_type") != "card_transaction" or
        not re.fullmatch(r"[0-9]+", str(s.get("total_installments", ""))) or
        int(s["total_installments"]) <= 1 or not s.get("account") or not s.get("last4") or
        not re.match(r"^\d{4}-\d{2}-\d{2}T", s.get("purchase_timestamp", ""))):
        return None
    return tuple(s.get(x) for x in ("bank", "account", "last4", "purchase_timestamp",
                                    "merchant_key", "total_installments", "amount_cents"))


class OriginTests(unittest.TestCase):
    def test_reproduces_original_cross_origin_person_bug(self):
        inputs = {"d": {"category_label": "Presentes"},
                  "ec": {"category": "Saúde", "person": "Benjamin"}}
        self.assertEqual(selection(ORIGINAL, inputs), ("Presentes", "Benjamin"))
        self.assertEqual(selection(CANDIDATE, inputs), ("Presentes", None))

    def test_exact_category_null_person_blocks_same_purchase_person(self):
        self.assertEqual(selection(CANDIDATE, {"d": {"category_label": "Presentes"},
                          "ic": {"category": "Saúde", "person": "Larissa"}}), ("Presentes", None))

    def test_exact_category_null_person_blocks_rule_person(self):
        self.assertEqual(selection(CANDIDATE, {"d": {"category_label": "Presentes"},
                          "sr": {"category": "Saúde", "person": "Larissa"}}), ("Presentes", None))

    def test_explicit_person_only_decision_is_preserved(self):
        self.assertEqual(selection(CANDIDATE, {"d": {"beneficiary": "Benjamin"},
                          "ec": {"category": "Saúde", "person": "Larissa"}}), ("Saúde", "Benjamin"))

    def test_explicit_owner_and_named_decisions_are_preserved(self):
        for person in ("Lucas", "Larissa", "Benjamin", "Rafiki"):
            with self.subTest(person=person):
                self.assertEqual(selection(CANDIDATE, {"d": {"category_label": "Saúde", "beneficiary": person},
                                  "ic": {"category": "Presentes", "person": "Lucas"}}), ("Saúde", person))

    def test_same_complete_purchase_inherits_person(self):
        self.assertEqual(selection(CANDIDATE, {"ic": {"category": "Saúde", "person": "Benjamin"},
                          "ec": {"category": "Presentes", "person": "Lucas"}}), ("Saúde", "Benjamin"))

    def test_same_purchase_null_person_does_not_borrow(self):
        self.assertEqual(selection(CANDIDATE, {"ic": {"category": "Saúde"},
                          "ec": {"category": "Saúde", "person": "Benjamin"},
                          "sr": {"category": "Saúde", "person": "Larissa"}}), ("Saúde", None))

    def test_broad_merchant_amount_never_supplies_person(self):
        self.assertEqual(selection(CANDIDATE, {"ec": {"category": "Saúde", "person": "Benjamin"},
                          "sr": {"category": "Saúde", "person": "Larissa"}}), ("Saúde", None))

    def test_rule_person_only_when_rule_category_wins(self):
        self.assertEqual(selection(CANDIDATE, {"sr": {"category": "Saúde", "person": "Larissa"}}),
                         ("Saúde", "Larissa"))

    def test_rule_with_ambiguous_category_cannot_supply_person(self):
        self.assertEqual(selection(CANDIDATE, {"sr": {"person": "Benjamin"},
                          "nc": {"category": "Farmácia"}}), ("Farmácia", None))

    def test_category_precedence_is_unchanged(self):
        columns = [("d", "category_label"), ("ic", "category"), ("ec", "category"),
                   ("sr", "category"), ("nc", "category")]
        for mask in range(32):
            values = {alias: {column: f"Category{idx}"} for idx, (alias, column) in enumerate(columns)
                      if mask & (1 << idx)}
            self.assertEqual(selection(ORIGINAL, values)[0], selection(CANDIDATE, values)[0])

    def test_marketplace_amount_does_not_leak_embedded_person(self):
        for person in ("Lucas", "Larissa", "Benjamin", "Rafiki"):
            for dash in ("-", "—", "–"):
                rows = aggregate("exact_categories", [("marketplace", 100, person + f" {dash} Saúde", person)])
                self.assertEqual(rows, [("marketplace", 100, "Saúde", None)])

    def test_bare_name_does_not_become_broad_category(self):
        for name in ("Lucas", "Larissa", "Benjamin", "Rafiki"):
            self.assertEqual(aggregate("exact_categories", [("store", 100, name, name)])[0][2:], (None, None))
            self.assertEqual(aggregate("nature_categories", [("store", 100, name, name)])[0][1], None)

    def test_ambiguous_exact_categories_stay_ambiguous(self):
        self.assertEqual(aggregate("exact_categories", [("store", 100, "Saúde", "Benjamin"),
                          ("store", 100, "Presentes", "Benjamin")])[0][2:], (None, None))

    def test_nature_aggregation_removes_supported_prefix_only(self):
        self.assertEqual(aggregate("nature_categories", [("store", 100, "Larissa — Saúde", "Larissa"),
                          ("store", 100, "Benjamin — Saúde", "Benjamin")]), [("store", "Saúde")])

    def test_no_taxonomy_synonyms_are_merged(self):
        for category in ("Despesas Organon", "Reembolso Organon", "Company Car", "Vestuário",
                         "Imagem e cuidados pessoais", "Mercado", "Supermercado", "Saúde", "Presentes"):
            self.assertEqual(aggregate("exact_categories", [("store", 100, category, None)])[0][2], category)

    def test_complete_installment_identity_contract(self):
        row = {"resource_type": "card_transaction", "bank": "TEST", "account": "TEST-ACCOUNT",
               "last4": "0000", "purchase_timestamp": "2026-01-02T15:30:00Z", "merchant_key": "fixture",
               "total_installments": "3", "amount_cents": -10000}
        key = complete_purchase_key(row)
        self.assertIsNotNone(key)
        for column in ("bank", "account", "last4", "purchase_timestamp", "merchant_key", "amount_cents"):
            altered = {**row, column: (row[column] + 1 if isinstance(row[column], int) else str(row[column]) + "X")}
            self.assertNotEqual(key, complete_purchase_key(altered))
        for column, value in (("account", ""), ("last4", ""), ("purchase_timestamp", "2026-01-02"),
                              ("total_installments", "1"), ("total_installments", "bad")):
            self.assertIsNone(complete_purchase_key({**row, column: value}))

    def test_no_broadened_installment_join_or_financial_changes(self):
        for start, end in (("with installment_decisions", "), evidence as materialized"),
                           ("), src as materialized", "), classified as ("),
                           ("), provider_classification as (", "$function$")):
            before = ORIGINAL.split(start, 1)[1].split(end, 1)[0]
            after = CANDIDATE.split(start, 1)[1].split(end, 1)[0]
            self.assertEqual(before, after)
        self.assertIn("ic.purchase_key=s.purchase_key", CANDIDATE)
        self.assertEqual(hashlib.sha256(ORIGINAL.encode()).hexdigest(),
                         "20bb4abff815f5f000a517c690dab2b9bbca925fd410e5c31da09668fb3f3d7b")


if __name__ == "__main__":
    unittest.main(verbosity=2)
