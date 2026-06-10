# Adapting to a shifting planet: The future of Drosera species amidst global challenges and conservation imperatives

**Associated paper:** *Adapting to a shifting planet: The future of Drosera species amidst global challenges and conservation imperatives*  
**Journal:** Anthropocene, 49, 100466  
**Article DOI:** https://doi.org/10.1016/j.ancene.2025.100466  
**Dataset DOI:** https://doi.org/10.5281/zenodo.20631938  

This repository contains the data, metadata, and source code associated with the paper *Adapting to a shifting planet: The future of Drosera species amidst global challenges and conservation imperatives*. The study evaluates current and future habitat suitability for 39 South American *Drosera* species using species distribution models, bioclimatic predictors, MaxEnt, and the KUENM workflow. The paper describes projections for 2050 and 2070 under SSP5–8.5 using HadGEM2-AO and MRI-CGCM3 general circulation models.

## Paper

Olivares-Pinto, U., Santiago Lopes, J. C., Ruiz-Aguilar, C., Oki, Y., & Fernandes, G. W. (2025). *Adapting to a shifting planet: The future of Drosera species amidst global challenges and conservation imperatives*. **Anthropocene, 49**, 100466. https://doi.org/10.1016/j.ancene.2025.100466

## Repository scope

This repository is organized for reproducibility of the species-level ecological niche modeling workflow. It includes standardized occurrence CSV files, metadata, and generic scripts that avoid hardcoded local paths or species-specific filenames.


## Directory structure

```text
Drosera_Species_Climate_Impact/
├── README.md
├── PAPER.md
├── LICENSE.md
├── CITATION.cff
├── data/
│   ├── README.md
│   ├── species_metadata.csv
│   └── species/
│       ├── 01_intermedia/
│       │   ├── occurrences_clean.csv
│       │   ├── occurrences_independent.csv
│       │   ├── precomputed/
│       │   └── M_variables/
│       ├── 02_communis/
│       └── ...
├── scripts/
│   ├── run_kuenm_species.R
│   ├── run_all_species.sh
│   └── prepare_species_csvs.py
```

## Standardized species files

Each species folder uses the following naming convention:

```text
occurrences_clean.csv          # cleaned occurrence records
occurrences_independent.csv    # independent occurrence records for final evaluation
background_points.csv          # rare-species background points, when available
precomputed/occurrences_*.csv  # uploaded split files preserved for traceability
M_variables/                   # selected environmental variable sets, e.g. Set_1/
```

The original uploaded split files (`drosera_joint.csv`, `drosera_train.csv`, `drosera_test.csv`) were preserved under `precomputed/`. They are not used by default because the generic script regenerates paper-aligned 75% calibration / 25% testing splits from `occurrences_clean.csv`.

## Important data note

The updated archive contains **39 species folders**, matching the species count described in the associated paper. The previously missing species ID `20` is now included as `20_viridis`. The file `docs/missing_species.csv` is retained for traceability and currently contains no missing species entries.

## Methodological alignment

The generic script follows the paper-level workflow:

1. Read cleaned occurrence records.
2. Split occurrences into 75% calibration and 25% testing records.
3. Use selected calibration-area variables from `M_variables/`.
4. Calibrate candidate MaxEnt models using KUENM.
5. Evaluate candidate models with partial ROC, omission rate, and AICc.
6. Generate final models with bootstrap replicates and logistic output.
7. Project models to current and future scenarios when `G_variables/` is available.
8. Evaluate final models with independent occurrence records.
9. Summarize projections, estimate projection changes, and run MOP extrapolation-risk analyses.

## Running one species

Example:

```bash
Rscript scripts/run_kuenm_species.R \
  --species_dir="data/species/03_montana" \
  --species_name="Drosera montana" \
  --species_code="sp03" \
  --maxent_path="data/species/03_montana" \
  --replicates=500
```

For a quick test that only validates files and does not run MaxEnt/KUENM:

```bash
Rscript scripts/run_kuenm_species.R \
  --species_dir="data/species/03_montana" \
  --validate_only=true
```

To regenerate only the occurrence split files in paper-aligned 75/25 format:

```bash
Rscript scripts/run_kuenm_species.R \
  --species_dir="data/species/03_montana" \
  --split_occurrences=true \
  --overwrite_split=true \
  --calibrate=false \
  --evaluate_candidates=false \
  --run_final_models=false \
  --run_final_evaluation=false \
  --run_summaries=false \
  --run_mop=false
```

## Running all species

```bash
bash scripts/run_all_species.sh --validate_only=true
```

or, once `M_variables/`, `G_variables/`, and `maxent.jar` are available:

```bash
bash scripts/run_all_species.sh --replicates=500
```

## Required software

- R
- Java Runtime Environment
- MaxEnt 3.4.4 or compatible `maxent.jar`
- KUENM R package
- Optional: `devtools` to install KUENM

Install KUENM with:

```r
install.packages("devtools")
devtools::install_github("marlonecobos/kuenm")
```

## Data availability

The complete research data archive is available through Zenodo:

```text
Zenodo DOI: 10.5281/zenodo.20631938
Zenodo record: https://doi.org/10.5281/zenodo.20631938
```

The source code, metadata, validation notes, and reproducible KUENM/MaxEnt scripts are maintained in the GitHub repository:

```text
Repository: https://github.com/HpcDataLab/AdaptingToaShiftingPlanet
```

A copy-paste-ready Zenodo description is available in `docs/zenodo_description_for_upload.txt`, and a Markdown version is available in `docs/zenodo_data_description.md`.

## Citation

If you use this repository or dataset, cite the associated paper and the archived Zenodo dataset DOI.

Olivares-Pinto, U., Santiago Lopes, J. C., Ruiz-Aguilar, C., Oki, Y., & Fernandes, G. W. (2025). *Adapting to a shifting planet: The future of Drosera species amidst global challenges and conservation imperatives*. Anthropocene, 49, 100466. https://doi.org/10.1016/j.ancene.2025.100466

## Data update notes

This version was regenerated from `species(2).zip`. The update adds the previously missing `20_viridis` species folder and retains the paper-aligned standardized structure for all **39** *Drosera* species. Canonical filenames were standardized while preserving non-canonical extra CSVs under `additional_csv/`.

Canonical clean occurrence selection follows this priority when multiple candidates exist: `final` > `newN` > `new` > `_joint`. See `docs/renaming_log.csv` and `data/species_metadata.csv` for exact mappings and row counts.
