#!/usr/bin/env python3
"""
Prepare standardized Drosera species CSV folders from an uploaded species ZIP.

Canonical output:
- occurrences_clean.csv
- occurrences_independent.csv
- background_points.csv, when available
- precomputed/occurrences_joint.csv, occurrences_train.csv, occurrences_test.csv
Additional non-canonical CSVs are preserved under additional_csv/.
"""
from __future__ import annotations

import argparse
import re
import shutil
import zipfile
from pathlib import Path

import pandas as pd

CORRECTIONS = {"sipiralis": "spiralis", "sipirocalyx": "spirocalyx"}


def parse_folder(name: str) -> tuple[int, str]:
    m = re.match(r"^\s*(\d+)\.?\s*(.+?)\s*$", name)
    if not m:
        raise ValueError(f"Cannot parse species folder: {name}")
    species_id = int(m.group(1))
    slug = re.sub(r"[^a-z0-9_]+", "", re.sub(r"\s+", "_", m.group(2).strip().lower()))
    slug = CORRECTIONS.get(slug, slug)
    return species_id, slug


def clean_csv(src: Path, dst: Path) -> None:
    df = pd.read_csv(src)
    df.columns = [str(c).strip() for c in df.columns]
    rename = {}
    for col in df.columns:
        key = col.lower().strip()
        if key in {"sp", "species", "taxon", "species_id"}:
            rename[col] = "sp"
        elif key in {"x", "longitude", "lon", "long", "decimal_longitude", "decimallongitude"}:
            rename[col] = "x"
        elif key in {"y", "latitude", "lat", "decimal_latitude", "decimallatitude"}:
            rename[col] = "y"
    df = df.rename(columns=rename)
    for col in df.select_dtypes(include=["object"]).columns:
        df[col] = df[col].astype(str).str.strip()
    for col in ["x", "y"]:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")
    preferred = [c for c in ["sp", "x", "y"] if c in df.columns]
    df = df[preferred + [c for c in df.columns if c not in preferred]]
    dst.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(dst, index=False)


def role_for_file(name: str) -> str:
    low = name.lower()
    if low == "drosera_joint.csv": return "precomputed/occurrences_joint.csv"
    if low == "drosera_train.csv": return "precomputed/occurrences_train.csv"
    if low == "drosera_test.csv": return "precomputed/occurrences_test.csv"
    if "background" in low or re.search(r"(^|_)back\.csv$", low): return "background_points.csv"
    if re.match(r"^d_.*testind\.csv$", low) or re.match(r"^d_.*ind\.csv$", low): return "occurrences_independent.csv"
    if low.startswith("d_") and (re.search(r"new\d*\.csv$", low) or re.search(r"final\.csv$", low) or re.search(r"_joint\.csv$", low)):
        return "occurrences_clean.csv"
    return "additional_csv/" + re.sub(r"[^A-Za-z0-9_.-]+", "_", name)


def priority(name: str) -> int:
    low = name.lower()
    if "final" in low: return 1000
    m = re.search(r"new(\d*)\.csv$", low)
    if m: return 900 + (int(m.group(1)) if m.group(1) else 0)
    if re.search(r"_joint\.csv$", low): return 100
    return 0


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--zip", required=True)
    parser.add_argument("--out", required=True, help="Output data directory, e.g. data/")
    args = parser.parse_args()

    zip_path = Path(args.zip)
    out = Path(args.out)
    tmp = out.parent / "_species_extract_tmp"
    if tmp.exists(): shutil.rmtree(tmp)
    tmp.mkdir(parents=True)
    with zipfile.ZipFile(zip_path) as zf: zf.extractall(tmp)

    species_root = tmp / "species"
    out_species = out / "species"
    if out_species.exists(): shutil.rmtree(out_species)
    out_species.mkdir(parents=True, exist_ok=True)

    for folder in sorted([p for p in species_root.iterdir() if p.is_dir()], key=lambda p: parse_folder(p.name)[0]):
        species_id, slug = parse_folder(folder.name)
        dst_folder = out_species / f"{species_id:02d}_{slug}"
        dst_folder.mkdir(parents=True, exist_ok=True)
        files = [p for p in folder.iterdir() if p.is_file() and p.name.lower().endswith(".csv")]
        seen = {}
        for src in sorted(files, key=lambda p: priority(p.name), reverse=True):
            rel = role_for_file(src.name)
            if rel in seen:
                rel = "additional_csv/" + re.sub(r"[^A-Za-z0-9_.-]+", "_", src.name)
            seen[rel] = True
            clean_csv(src, dst_folder / rel)
        (dst_folder / "M_variables").mkdir(exist_ok=True)
    shutil.rmtree(tmp)


if __name__ == "__main__":
    main()
