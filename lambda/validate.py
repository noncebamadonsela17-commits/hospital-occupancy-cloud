"""Validate bronze encounter CSVs against the occupancy pipeline contract."""
from __future__ import annotations

import csv
import io
from datetime import datetime
from typing import Iterable

REQUIRED_COLUMNS = (
    "encounter_id",
    "patient_id",
    "department",
    "admission_date",
    "discharge_date",
    "encounter_type",
)

DATE_FORMAT = "%Y-%m-%d"


def validate_csv(text: str) -> list[str]:
    """Return a list of error strings. Empty list means the CSV is valid."""
    errors: list[str] = []
    if not text.strip():
        return ["file is empty"]

    reader = csv.DictReader(io.StringIO(text))
    if reader.fieldnames is None:
        return ["missing header row"]

    headers = [h.strip() for h in reader.fieldnames]
    missing = [c for c in REQUIRED_COLUMNS if c not in headers]
    extra = [h for h in headers if h not in REQUIRED_COLUMNS]
    if missing:
        errors.append("missing columns: " + ", ".join(missing))
    if extra:
        errors.append("unknown columns: " + ", ".join(extra))
    if errors:
        return errors

    rows = list(reader)
    if not rows:
        return ["no data rows"]

    for i, row in enumerate(rows, start=2):
        errors.extend(_row_errors(i, row))
    return errors


def _row_errors(line_no: int, row: dict[str, str]) -> Iterable[str]:
    if not (row.get("encounter_id") or "").strip():
        yield f"line {line_no}: encounter_id is empty"
    if not (row.get("patient_id") or "").strip():
        yield f"line {line_no}: patient_id is empty"
    if not (row.get("department") or "").strip():
        yield f"line {line_no}: department is empty"
    if not (row.get("encounter_type") or "").strip():
        yield f"line {line_no}: encounter_type is empty"

    admission = (row.get("admission_date") or "").strip()
    if not _is_date(admission):
        yield f"line {line_no}: admission_date must be YYYY-MM-DD"

    discharge = (row.get("discharge_date") or "").strip()
    if discharge and not _is_date(discharge):
        yield f"line {line_no}: discharge_date must be YYYY-MM-DD or empty"


def _is_date(value: str) -> bool:
    try:
        datetime.strptime(value, DATE_FORMAT)
        return True
    except ValueError:
        return False


def is_valid(text: str) -> bool:
    return not validate_csv(text)
