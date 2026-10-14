"""Unit tests for bronze CSV validation. No AWS credentials required.

Extra/unknown columns fail on purpose so the landing zone matches
bed-occupancy-pipeline bronze encounters.csv exactly.
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "lambda"))

from validate import is_valid, validate_csv  # noqa: E402

FIXTURES = Path(__file__).parent / "fixtures"


def test_happy_path_fixture() -> None:
    text = (FIXTURES / "good.csv").read_text(encoding="utf-8")
    assert is_valid(text)
    assert validate_csv(text) == []


def test_missing_column_fixture() -> None:
    text = (FIXTURES / "bad.csv").read_text(encoding="utf-8")
    errors = validate_csv(text)
    assert errors
    assert any("missing columns" in e for e in errors)


def test_empty_file() -> None:
    assert validate_csv("") == ["file is empty"]
    assert validate_csv("   \n") == ["file is empty"]


def test_bad_date() -> None:
    text = (
        "encounter_id,patient_id,department,admission_date,discharge_date,encounter_type\n"
        "e1,p1,ICU,not-a-date,2024-01-02,inpatient\n"
    )
    errors = validate_csv(text)
    assert any("admission_date" in e for e in errors)


def test_extra_column_rejected() -> None:
    text = (
        "encounter_id,patient_id,department,admission_date,discharge_date,encounter_type,junk\n"
        "e1,p1,ICU,2024-01-01,2024-01-02,inpatient,x\n"
    )
    errors = validate_csv(text)
    assert any("unknown columns" in e for e in errors)
