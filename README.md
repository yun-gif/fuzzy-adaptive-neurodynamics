# Fuzzy adaptive neurodynamics reproducibility materials

Reproducibility materials for **Takagi-Sugeno Fuzzy Adaptive Neurodynamics for Time-Varying Nonlinear Systems With Noise**.

This package contains MATLAB implementations, archived synthetic simulation results, summary metrics, and thirteen reference figure panels. No external empirical dataset is used. The simulations generate numerical-system, acoustic-localization, and connected-vehicle trajectories.

## Run

Open this directory in MATLAB, then use one of:

```matlab
run_reproduction("verify")   % Unit tests and metric recalculation from stored trajectories
run_reproduction("figures")  % Verification and all 13 single-panel plots
run_reproduction("rerun")    % All four experiment batches, metrics, and panels
```

Each command creates a separate working copy under `runs/`. Archived files in `matlab/results/` are not overwritten. The returned path contains a machine-readable validation report. Repeated runs consume additional disk space.

The wrapper must be on the MATLAB path. Avoid adding multiple historical versions of these functions to the same session. Use a fresh MATLAB session when comparing results across versions.

MATLAB R2025b on Windows is the local validation environment. Other MATLAB versions and GNU Octave have not been validated. The scripts use MATLAB tables, strings, and graphics export. Times New Roman is used for figure labels; font availability can change appearance. No toolbox-specific fuzzy inference object is used.

## Contents

- `matlab/`: experiment drivers, solver functions, metric definitions, plotting functions, and analytical metric tests.
- `matlab/results/`: four archived MAT files and six CSV tables.
- `reference_figures/`: the 13 PDF panels used by the manuscript.
- `DATA_DICTIONARY.md`: result structures, units, and manuscript mapping.
- `CHANGES.md`: release-only packaging changes.
- `MANIFEST.sha256`: file integrity hashes.
- `VALIDATION.json`: locally executed validation result, when available.

The historical `tfs` prefixes are retained to preserve function names. They do not indicate a current submission to that journal.

## Reproduction scope

`verify` recalculates steady-state metrics without integrating trajectories again. `figures` also redraws the panels. Only `rerun` performs new numerical integrations. The report records which path was executed; do not equate metric recalculation with full experiment reproduction.

CSV summaries report sample counts, errors, and shared steady-window endpoints. MAT files retain recorded trajectories and parameters. Random geometry uses an explicit fixed seed in the TDOA driver; this is reproducibility code, not manuscript text.

Each MATLAB plotting command exports individual panels. Panel labels and composite layouts belong in LaTeX, not in the MATLAB data plots. Archived PDFs are reference outputs; PDF bytes can differ after regeneration because of renderer metadata and fonts.

## Version and citation

Repository: https://github.com/yun-gif/fuzzy-adaptive-neurodynamics

Scientific release: **v1.0.0**, dated October 27, 2026. The current branch omits the author-list citation file. Historical commits and release assets have not been rewritten; they may still contain identifying metadata. The source code and simulation data are unchanged.

The release contains MATLAB source code, synthetic simulation data, CSV metrics, reference figures, and validation reports. A SHA-256 manifest is included. GitHub hosting and a version tag are not a DOI or an independent permanent archive. No DOI has been assigned.

No reuse license has been selected by the authors. Public availability should not be interpreted as an open-source license grant.

Generated working directories under `runs/`, local editor history, credentials, and the manuscript submission package are excluded from this repository. The public repository can identify the authors and must not be represented as an anonymous artifact.
