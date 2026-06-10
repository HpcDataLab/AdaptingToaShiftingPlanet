#!/usr/bin/env Rscript
# -----------------------------------------------------------------------------
# Generic KUENM / MaxEnt workflow for Drosera species distribution models
# Aligned with: Olivares-Pinto et al., 2025, Anthropocene 49, 100466
#
# Standardized species folder:
#   data/species/<NN_species>/
#   ├── occurrences_clean.csv
#   ├── occurrences_independent.csv
#   ├── background_points.csv              # optional
#   ├── precomputed/                       # uploaded legacy/precomputed splits
#   ├── M_variables/                       # selected calibration variables, Set_1/
#   ├── G_variables/                       # optional current/future projection variables
#   └── maxent.jar                         # or pass --maxent_path
#
# Example:
#   Rscript scripts/run_kuenm_species.R \
#     --species_dir="data/species/03_montana" \
#     --species_name="Drosera montana" \
#     --species_code="sp03" \
#     --replicates=500
# -----------------------------------------------------------------------------

parse_args <- function() {
  raw_args <- commandArgs(trailingOnly = TRUE)
  parsed <- list()
  i <- 1
  while (i <= length(raw_args)) {
    item <- raw_args[[i]]
    if (startsWith(item, "--")) {
      item <- sub("^--", "", item)
      if (grepl("=", item, fixed = TRUE)) {
        parts <- strsplit(item, "=", fixed = TRUE)[[1]]
        key <- parts[[1]]
        value <- paste(parts[-1], collapse = "=")
      } else {
        key <- item
        if (i < length(raw_args) && !startsWith(raw_args[[i + 1]], "--")) {
          value <- raw_args[[i + 1]]
          i <- i + 1
        } else {
          value <- "true"
        }
      }
      key <- gsub("-", "_", key)
      parsed[[key]] <- value
    }
    i <- i + 1
  }
  parsed
}

get_arg <- function(args, name, default = NULL) {
  if (!is.null(args[[name]])) args[[name]] else default
}

parse_bool <- function(value, default = FALSE) {
  if (is.null(value)) return(default)
  value <- tolower(trimws(as.character(value)))
  if (value %in% c("true", "t", "1", "yes", "y")) return(TRUE)
  if (value %in% c("false", "f", "0", "no", "n")) return(FALSE)
  stop(sprintf("Invalid logical value: %s", value))
}

parse_int <- function(value, default) {
  if (is.null(value)) return(default)
  out <- suppressWarnings(as.integer(value))
  if (is.na(out)) stop(sprintf("Invalid integer value: %s", value))
  out
}

parse_num_vector <- function(value, default) {
  if (is.null(value)) return(default)
  vals <- trimws(strsplit(value, ",", fixed = TRUE)[[1]])
  out <- suppressWarnings(as.numeric(vals))
  if (any(is.na(out))) stop(sprintf("Invalid numeric vector: %s", value))
  out
}

parse_chr_vector <- function(value, default) {
  if (is.null(value)) return(default)
  trimws(strsplit(value, ",", fixed = TRUE)[[1]])
}

assert_file <- function(path, label) {
  if (!file.exists(path)) stop(sprintf("Missing %s: %s", label, path))
}

assert_dir <- function(path, label) {
  if (!dir.exists(path)) stop(sprintf("Missing %s: %s", label, path))
}

infer_species_slug <- function(species_dir) {
  x <- basename(normalizePath(species_dir, mustWork = FALSE))
  x <- sub("^[0-9]+[_\\.\\- ]*", "", x)
  x <- gsub("_+", " ", x)
  tolower(trimws(x))
}

infer_species_code <- function(species_dir, fallback) {
  x <- basename(normalizePath(species_dir, mustWork = FALSE))
  m <- regmatches(x, regexpr("^[0-9]+", x))
  if (length(m) == 1 && nzchar(m)) return(sprintf("sp%02d", as.integer(m)))
  fallback
}

check_variable_sets <- function(m_var_dir) {
  if (!dir.exists(m_var_dir)) return(FALSE)
  dirs <- list.dirs(m_var_dir, recursive = FALSE, full.names = FALSE)
  length(dirs) > 0 && any(grepl("^Set_", dirs, ignore.case = TRUE))
}

# ------------------------------ configuration --------------------------------
args <- parse_args()

species_dir <- normalizePath(get_arg(args, "species_dir", getwd()), mustWork = FALSE)
species_slug <- infer_species_slug(species_dir)
species_name <- get_arg(args, "species_name", paste("Drosera", species_slug))
species_code <- get_arg(args, "species_code", infer_species_code(species_dir, gsub(" ", "_", species_slug)))

occurrence_file <- get_arg(args, "occurrence_file", "occurrences_clean.csv")
independent_file <- get_arg(args, "independent_file", "occurrences_independent.csv")

split_prefix <- get_arg(args, "split_prefix", "occurrences")
joint_file <- get_arg(args, "joint_file", paste0(split_prefix, "_joint.csv"))
train_file <- get_arg(args, "train_file", paste0(split_prefix, "_train.csv"))
test_file <- get_arg(args, "test_file", paste0(split_prefix, "_test.csv"))

m_var_dir <- get_arg(args, "m_var_dir", "M_variables")
raw_var_dir <- get_arg(args, "raw_var_dir", "Vars")
g_var_dir <- get_arg(args, "g_var_dir", "G_variables")

calibration_batch <- get_arg(args, "calibration_batch", "calibration_script")
final_batch <- get_arg(args, "final_batch", "final_models")
candidate_dir <- get_arg(args, "candidate_dir", "Candidate_models")
calibration_results_dir <- get_arg(args, "calibration_results_dir", "Calibration_results")
final_models_dir <- get_arg(args, "final_models_dir", "Final_models")
final_stats_dir <- get_arg(args, "final_stats_dir", "Final_Model_Stats")
projection_changes_dir <- get_arg(args, "projection_changes_dir", "Projection_changes")
variation_dir <- get_arg(args, "variation_dir", "Variation_from_sources")
mop_results_dir <- get_arg(args, "mop_results_dir", "MOP_results")
mop_agreement_dir <- get_arg(args, "mop_agreement_dir", "MOP_agreement")
final_eval_dir <- get_arg(args, "final_eval_dir", "F_models_evaluation")

train_proportion <- as.numeric(get_arg(args, "train_proportion", "0.75"))
seed <- parse_int(get_arg(args, "seed", NULL), 1)
min_variables <- parse_int(get_arg(args, "min_variables", NULL), 7)

reg_mult <- parse_num_vector(
  get_arg(args, "reg_mult", NULL),
  c(seq(0.1, 1, 0.1), seq(2, 6, 1), 8, 10)
)
feature_classes <- parse_chr_vector(get_arg(args, "feature_classes", NULL), c("all"))
projection_scenarios <- parse_chr_vector(
  get_arg(args, "projection_scenarios", NULL),
  c("current", "hd50", "hd70", "mg50", "mg70")
)
future_scenarios <- parse_chr_vector(
  get_arg(args, "future_scenarios", NULL),
  c("hd50", "hd70", "mg50", "mg70")
)

threshold <- parse_int(get_arg(args, "threshold", NULL), 5)
rand_percent <- parse_int(get_arg(args, "rand_percent", NULL), 50)
iterations <- parse_int(get_arg(args, "iterations", NULL), 500)
replicates <- parse_int(get_arg(args, "replicates", NULL), 500)
max_memory_cal <- parse_int(get_arg(args, "max_memory_cal", NULL), 9000)
max_memory_final <- parse_int(get_arg(args, "max_memory_final", NULL), 70000)
n_cores <- parse_int(get_arg(args, "n_cores", NULL), 1)

# The paper describes logistic outputs for final models.
out_format <- get_arg(args, "out_format", "logistic")

validate_only <- parse_bool(get_arg(args, "validate_only", NULL), FALSE)
make_variable_sets <- parse_bool(get_arg(args, "make_variable_sets", NULL), FALSE)
split_occurrences <- parse_bool(get_arg(args, "split_occurrences", NULL), TRUE)
calibrate <- parse_bool(get_arg(args, "calibrate", NULL), TRUE)
run_candidate_models <- parse_bool(get_arg(args, "run_candidate_models", NULL), TRUE)
evaluate_candidates <- parse_bool(get_arg(args, "evaluate_candidates", NULL), TRUE)
run_final_models <- parse_bool(get_arg(args, "run_final_models", NULL), TRUE)
run_final_evaluation <- parse_bool(get_arg(args, "run_final_evaluation", NULL), TRUE)
run_summaries <- parse_bool(get_arg(args, "run_summaries", NULL), TRUE)
run_mop <- parse_bool(get_arg(args, "run_mop", NULL), TRUE)
project_models <- parse_bool(get_arg(args, "project", NULL), TRUE)
overwrite_split <- parse_bool(get_arg(args, "overwrite_split", NULL), FALSE)
parallel_eval <- parse_bool(get_arg(args, "parallel_eval", NULL), FALSE)

maxent_path <- normalizePath(get_arg(args, "maxent_path", species_dir), mustWork = FALSE)
if (basename(maxent_path) == "maxent.jar") {
  maxent_path <- dirname(maxent_path)
}

# ------------------------------ sanity checks --------------------------------
assert_dir(species_dir, "species directory")
old_wd <- getwd()
on.exit(setwd(old_wd), add = TRUE)
setwd(species_dir)

assert_file(occurrence_file, "cleaned occurrence CSV")
occ_preview <- read.csv(occurrence_file, nrows = 5)
names(occ_preview) <- trimws(names(occ_preview))
needed <- c("sp", "x", "y")
if (!all(needed %in% names(occ_preview))) {
  stop(sprintf(
    "Occurrence file must contain columns sp, x, y. Found: %s",
    paste(names(occ_preview), collapse = ", ")
  ))
}

has_independent <- file.exists(independent_file)
if (has_independent) {
  ind_preview <- read.csv(independent_file, nrows = 5)
  names(ind_preview) <- trimws(names(ind_preview))
  if (!all(needed %in% names(ind_preview))) {
    stop(sprintf(
      "Independent file must contain columns sp, x, y. Found: %s",
      paste(names(ind_preview), collapse = ", ")
    ))
  }
}

message("Species directory: ", species_dir)
message("Species name:      ", species_name)
message("Species code:      ", species_code)
message("Occurrence file:   ", occurrence_file)
message("Independent file:  ", ifelse(has_independent, independent_file, "not available"))
message("Train proportion:  ", train_proportion)
message("Projection mode:   ", project_models)

if (validate_only) {
  occ_count <- nrow(read.csv(occurrence_file))
  message("Validation OK. Cleaned occurrence rows: ", occ_count)
  if (has_independent) {
    message("Independent occurrence rows: ", nrow(read.csv(independent_file)))
  }
  quit(save = "no", status = 0)
}

suppressPackageStartupMessages({
  if (!requireNamespace("kuenm", quietly = TRUE)) {
    stop("Package 'kuenm' is required. Install it with: devtools::install_github('marlonecobos/kuenm')")
  }
  library(kuenm)
})

if (!file.exists(file.path(maxent_path, "maxent.jar"))) {
  warning(sprintf("maxent.jar was not found in %s. KUENM calibration/final modeling may fail.", maxent_path))
}

if (project_models && !dir.exists(g_var_dir)) {
  warning(sprintf("%s not found. Final models will run without projections unless --project=false was intended.", g_var_dir))
  project_models <- FALSE
}

needs_m_variables <- make_variable_sets || calibrate || run_final_models || run_summaries || run_mop
if (needs_m_variables) {
  if (make_variable_sets) {
    assert_dir(raw_var_dir, "raw variables directory")
  } else {
    assert_dir(m_var_dir, "M variables directory")
    if (!check_variable_sets(m_var_dir)) {
      stop(sprintf(
        "%s exists but no variable set folder such as Set_1 was found. Add the selected calibration variables or run with --make_variable_sets=true if Vars/ is available.",
        m_var_dir
      ))
    }
  }
}

# -------------------------- 1. occurrence partition ---------------------------
if (split_occurrences) {
  split_outputs <- c(joint_file, train_file, test_file)
  split_exists <- all(file.exists(split_outputs))

  if (split_exists && !overwrite_split) {
    message("Skipping occurrence split; split files already exist. Use --overwrite_split=true to regenerate.")
  } else {
    message("Splitting occurrences: ", train_proportion * 100, "% calibration / ", (1 - train_proportion) * 100, "% testing")
    occs <- read.csv(occurrence_file)
    names(occs) <- trimws(names(occs))
    set.seed(seed)
    kuenm_occsplit(
      occ = occs,
      train.proportion = train_proportion,
      method = "random",
      save = TRUE,
      name = split_prefix
    )
  }
}

assert_file(joint_file, "joint occurrence CSV")
assert_file(train_file, "training occurrence CSV")
assert_file(test_file, "testing occurrence CSV")

# -------------------------- 2. variable combinations --------------------------
if (make_variable_sets) {
  message("Creating M variable combinations from: ", raw_var_dir)
  kuenm_varcomb(
    var.dir = raw_var_dir,
    out.dir = m_var_dir,
    min.number = min_variables,
    in.format = "ascii",
    out.format = "ascii"
  )
}

# -------------------------- 3. candidate calibration --------------------------
if (calibrate) {
  message("Creating candidate MaxEnt models: ", candidate_dir)
  kuenm_cal(
    occ.joint = joint_file,
    occ.tra = train_file,
    M.var.dir = m_var_dir,
    batch = calibration_batch,
    out.dir = candidate_dir,
    max.memory = max_memory_cal,
    reg.mult = reg_mult,
    f.clas = feature_classes,
    args = NULL,
    maxent.path = maxent_path,
    wait = FALSE,
    run = run_candidate_models
  )
}

# ------------------------- 4. candidate model evaluation ----------------------
if (evaluate_candidates) {
  assert_dir(candidate_dir, "candidate models directory")
  message("Evaluating candidate models: ", calibration_results_dir)
  kuenm_ceval(
    path = candidate_dir,
    occ.joint = joint_file,
    occ.tra = train_file,
    occ.test = test_file,
    batch = calibration_batch,
    out.eval = calibration_results_dir,
    threshold = threshold,
    rand.percent = rand_percent,
    iterations = iterations,
    kept = TRUE,
    selection = "OR_AICc",
    parallel.proc = parallel_eval
  )
}

# ------------------------- 5. final models and projections --------------------
if (run_final_models) {
  assert_dir(calibration_results_dir, "calibration results directory")
  message("Creating final models: ", final_models_dir)
  kuenm_mod(
    occ.joint = joint_file,
    M.var.dir = m_var_dir,
    out.eval = calibration_results_dir,
    batch = final_batch,
    rep.n = replicates,
    rep.type = "Bootstrap",
    jackknife = TRUE,
    out.dir = final_models_dir,
    max.memory = max_memory_final,
    out.format = out_format,
    project = project_models,
    G.var.dir = if (project_models) g_var_dir else NULL,
    ext.type = "all",
    write.mess = FALSE,
    write.clamp = FALSE,
    maxent.path = maxent_path,
    args = NULL,
    wait = TRUE,
    run = TRUE
  )
}

# ------------------------- 6. independent evaluation --------------------------
if (run_final_evaluation) {
  if (!has_independent) {
    warning("Independent occurrence file was not found; skipping final model evaluation with independent data.")
  } else {
    assert_dir(final_models_dir, "final models directory")
    message("Evaluating final models with independent occurrences: ", final_eval_dir)
    kuenm_feval(
      path = final_models_dir,
      occ.joint = joint_file,
      occ.ind = independent_file,
      replicates = TRUE,
      out.eval = final_eval_dir,
      threshold = threshold,
      rand.percent = rand_percent,
      iterations = iterations,
      parallel.proc = parallel_eval
    )
  }
}

# ------------------------- 7. summaries and change analysis -------------------
if (run_summaries) {
  assert_dir(final_models_dir, "final models directory")
  message("Calculating final model statistics: ", final_stats_dir)
  kuenm_modstats(
    sp.name = species_code,
    fmod.dir = final_models_dir,
    format = "asc",
    project = project_models,
    statistics = c("med"),
    replicated = TRUE,
    proj.scenarios = projection_scenarios,
    ext.type = c("E", "EC", "NE"),
    out.dir = final_stats_dir
  )

  if (project_models) {
    message("Detecting projection changes: ", projection_changes_dir)
    kuenm_projchanges(
      occ = joint_file,
      fmod.stats = final_stats_dir,
      threshold = threshold,
      current = "current",
      emi.scenarios = future_scenarios,
      ext.type = c("EC"),
      out.dir = projection_changes_dir
    )

    message("Estimating variation from sources: ", variation_dir)
    kuenm_modvar(
      sp.name = species_code,
      fmod.dir = final_models_dir,
      is.swd = FALSE,
      replicated = TRUE,
      format = "asc",
      project = TRUE,
      current = "current",
      emi.scenarios = future_scenarios,
      ext.type = c("EC"),
      split.length = 100,
      out.dir = variation_dir
    )
  }
}

# ------------------------- 8. MOP extrapolation risk --------------------------
if (run_mop) {
  if (!project_models) {
    warning("Projection variables are unavailable or project=false; skipping MOP analysis.")
  } else {
    message("Running MOP extrapolation risk analysis: ", mop_results_dir)
    kuenm_mmop(
      G.var.dir = g_var_dir,
      is.swd = FALSE,
      M.var.dir = m_var_dir,
      sets.var = c("Set_1"),
      out.mop = mop_results_dir,
      percent = 50,
      comp.each = 1000,
      parallel = n_cores > 1,
      n.cores = n_cores
    )

    message("Calculating MOP agreement: ", mop_agreement_dir)
    kuenm_mopagree(
      mop.dir = mop_results_dir,
      in.format = "GTiff",
      out.format = "GTiff",
      current = "current",
      emi.scenarios = future_scenarios,
      out.dir = mop_agreement_dir
    )
  }
}

message("Done: ", species_name)
