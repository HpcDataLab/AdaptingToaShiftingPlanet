# Data

This directory contains standardized occurrence CSV files extracted from `species(2).zip` for the paper **“Adapting to a shifting planet: The future of Drosera species amidst global challenges and conservation imperatives”**.

The updated dataset now includes **39 species folders**, including `20_viridis`.

Each species folder contains, when available:

- `occurrences_clean.csv`: canonical cleaned occurrence records used by the generic KUENM script.
- `occurrences_independent.csv`: independent records for final model evaluation.
- `background_points.csv`: background points supplied for some rare species.
- `precomputed/occurrences_joint.csv`, `precomputed/occurrences_train.csv`, `precomputed/occurrences_test.csv`: original split files preserved for traceability.
- `additional_csv/`: non-canonical or additional CSV files from the upload, preserved but not used by default.
- `M_variables/`: placeholder for selected calibration-area variables.

See `species_metadata.csv` and `../docs/renaming_log.csv` for the exact mapping from original filenames to standardized names.

Complete data archive DOI: https://doi.org/10.5281/zenodo.20631938
Code repository: https://github.com/HpcDataLab/AdaptingToaShiftingPlanet
