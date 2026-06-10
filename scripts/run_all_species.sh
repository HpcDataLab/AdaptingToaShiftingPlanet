#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
METADATA="$REPO_DIR/data/species_metadata.csv"
RUNNER="$SCRIPT_DIR/run_kuenm_species.R"

if [[ ! -f "$METADATA" ]]; then
  echo "Missing metadata file: $METADATA" >&2
  exit 1
fi

if [[ $# -eq 0 ]]; then
  echo "No extra options supplied. The script will run the full KUENM workflow for each species." >&2
  echo "For validation only, run: bash scripts/run_all_species.sh --validate_only=true" >&2
fi

python3 - <<'PYCSV' "$METADATA" | while IFS=$'\t' read -r species_id species_name folder; do
import csv
import sys
with open(sys.argv[1], newline='', encoding='utf-8') as f:
    for row in csv.DictReader(f):
        print(f"{row['species_id']}\t{row['species_name']}\t{row['folder']}")
PYCSV
  species_dir="$REPO_DIR/data/species/$folder"

  if [[ ! -d "$species_dir" ]]; then
    echo "Skipping missing species directory: $species_dir" >&2
    continue
  fi

  echo "================================================================"
  echo "Running $species_name ($folder)"
  echo "================================================================"

  Rscript "$RUNNER" \
    --species_dir="$species_dir" \
    --species_name="$species_name" \
    --species_code="sp$species_id" \
    "$@"
done
