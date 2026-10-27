# Data dictionary and manuscript mapping

## Manuscript outputs

| Output | Archived evidence | Driver |
|---|---|---|
| Figure 1, Table 1: fuzzy rule definitions | Parameters in code and MAT configuration | plot_tfs_fuzzy_figures |
| Figure 2, Table 2: numerical benchmark | tfs_numerical_results.mat; summary_metrics.csv | run_tfs_numerical_metrics |
| Table 3: mechanism ablation | mechanism_ablation_results.mat; mechanism_ablation_metrics.csv | run_tfs_mechanism_ablation |
| Figure 3, TDOA rows of Table 4 | tdoa_results.mat; tdoa_metrics.csv | run_tfs_tdoa_metrics |
| Figure 4, vehicle rows of Table 4 | vehicle_results.mat; vehicle_metrics.csv | run_tfs_vehicle_metrics |

Rule-activity CSVs provide operating-rule summaries for the application runs. Figures use panels a-c for Figures 1-3 and a-d for Figure 4.

## MAT layout

- Numerical: `results.<noise>.<method>`, `summary`, `cfg`.
- Mechanism ablation: `results.<variant>`, `ablation`, `cfg`.
- TDOA: `results.<noise>.<method>`, `rows`, `activity_rows`, `P`, `cfg`.
- Vehicle: `results.<method>`, `rows`, `activity_rows`, `cfg`.

MATLAB field names replace punctuation with valid identifier characters. The `method` fields and CSV columns retain display names.

Common trajectory fields include `t` (recorded physical time in seconds), `x` (state columns at corresponding times), `tau` (integration step in seconds), `phi` (dimensionless fuzzy or baseline factor), `r` and `d` (normalized regulator inputs), and `rule_strengths` (3-by-3 rule activation over time). Non-fuzzy methods may contain NaNs for non-applicable fuzzy quantities. Each result records a termination `status`.

Numerical data include `x_star`, `error_series`, `error_norm`, and `residual_norm`. TDOA data include position errors in metres and sensor coordinates `P` in metres. Vehicle data include observer-relative position, velocity, and acceleration error norms in metres, metres per second, and metres per second squared. Consult each driver's state construction for the exact ordering of internal state components.

## Metrics

- `samples`: recorded integration samples, including the initial sample; not wall-clock runtime.
- `final_*`: last recorded in-horizon quantity, not necessarily interpolated to the nominal endpoint.
- `settling_time`: first recorded time after which all remaining residual values stay at or below the configured tolerance; NaN means not attained.
- `steady_*`: metrics from the final tenth of the nominal simulation horizon, clipped to the shared recorded endpoint within the comparison group.
- `steady_window_start`, `steady_window_end`, `nominal_T`, `record_end`: time boundaries in seconds.
- `steady_metric_valid`: whether the shared window supports the reported metric.
- `steady_metric_definition`: the stored definition identifier.

The implementation integrates the squared piecewise-linear error exactly over the shared window, rather than taking an unweighted mean over irregular time samples. The numerical vector error metric is normalized per component; application scalar error norms keep their stated units. No endpoint extrapolation is introduced.

The numerical batch uses noise-free, constant, and time-varying conditions. TDOA uses constant and time-varying conditions. The vehicle pair uses its prescribed sinusoidal disturbance. Disturbance definitions and initial states are in the drivers.
