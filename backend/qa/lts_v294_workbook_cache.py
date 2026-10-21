"""Read original OOXML cached cells without executing macros or recalculating formulas.

Read-only source inspection. Paths and requested rows are supplied by the caller;
no private workbook contents are committed with this generic helper.
"""
import argparse
import hashlib
import json
import posixpath
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta
from pathlib import Path
from zipfile import ZipFile

NS = {"s": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
REL = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("workbook", type=Path)
    parser.add_argument("--sheet")
    parser.add_argument("--rows", default="1:12")
    parser.add_argument("--columns", default="1:16384", help="Inclusive 1-based column numbers")
    parser.add_argument("--date-column")
    parser.add_argument("--year", type=int)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    data = args.workbook.read_bytes()
    result = {"name": args.workbook.name, "sha256": hashlib.sha256(data).hexdigest()}
    with ZipFile(args.workbook) as archive:
        book = ET.fromstring(archive.read("xl/workbook.xml"))
        rels = ET.fromstring(archive.read("xl/_rels/workbook.xml.rels"))
        paths = {}
        for rel in rels:
            target = rel.attrib["Target"]
            paths[rel.attrib["Id"]] = target.lstrip("/") if target.startswith("/") else posixpath.normpath(posixpath.join("xl", target))
        sheets = {s.attrib["name"]: paths[s.attrib[REL]] for s in book.find("s:sheets", NS)}
        result["sheets"] = list(sheets)
        if args.sheet:
            shared = []
            if "xl/sharedStrings.xml" in archive.namelist():
                tree = ET.fromstring(archive.read("xl/sharedStrings.xml"))
                shared = ["".join(si.itertext()) for si in tree]
            first, last = [int(x) for x in args.rows.split(":")]
            first_column, last_column = [int(x) for x in args.columns.split(":")]
            epoch = datetime(1899, 12, 30)
            properties = book.find("s:workbookPr", NS)
            if properties is not None and properties.attrib.get("date1904") == "1":
                epoch = datetime(1904, 1, 1)
            output = []
            with archive.open(sheets[args.sheet]) as stream:
                for _, row in ET.iterparse(stream, events=("end",)):
                    if row.tag != "{" + NS["s"] + "}row":
                        continue
                    row_number = int(row.attrib["r"])
                    if args.year is None and not first <= row_number <= last:
                        row.clear()
                        continue
                    cells = {}
                    for cell in row.findall("s:c", NS):
                        address = cell.attrib["r"]
                        column = 0
                        for letter in address.rstrip("0123456789"):
                            column = column * 26 + ord(letter) - 64
                        if not first_column <= column <= last_column:
                            continue
                        kind = cell.attrib.get("t", "n")
                        value = cell.find("s:v", NS)
                        formula = cell.find("s:f", NS)
                        text = value.text if value is not None else None
                        if kind == "s" and text is not None:
                            text = shared[int(text)]
                        elif kind == "inlineStr":
                            text = "".join(cell.find("s:is", NS).itertext())
                        if text is not None or formula is not None:
                            cells[address] = {"value": text, "type": kind}
                            if formula is not None:
                                cells[address]["formula"] = formula.text
                    eligible = first <= row_number <= last
                    if args.year is not None and args.date_column:
                        date_cell = cells.get(args.date_column + str(row_number), {})
                        try:
                            date = epoch + timedelta(days=float(date_cell["value"]))
                            eligible = date.year == args.year
                            if eligible:
                                cells["_date"] = date.strftime("%Y-%m-%d")
                        except (ValueError, TypeError, KeyError, OverflowError):
                            eligible = False
                    if eligible:
                        output.append({"row": row_number, "cells": cells})
                    row.clear()
            result["sheet"] = args.sheet
            result["rows"] = output
    rendered = json.dumps(result, ensure_ascii=False, indent=2)
    if args.output:
        args.output.write_text(rendered + "\n", encoding="utf-8")
        print(json.dumps({"output": str(args.output), "rows": len(result.get("rows", [])), "sha256": result["sha256"]}))
    else:
        print(rendered)


if __name__ == "__main__":
    main()
