# Repository File-Placement Guide

## Final repository layout

```text
ev6-model-calibration/
├── calibration/
│   ├── battery/
│   └── torque/
├── docs/
├── figures/
│   ├── 01-torque/
│   ├── 02-battery/
│   ├── 03-power-correction/
│   ├── 04-final-validation/
│   └── source/
├── models/
│   └── final/
├── report/
├── results/
│   ├── simulation_outputs/
│   └── validation/
├── scripts/
│   ├── archive/
│   └── initialization/
├── .gitignore
└── README.md
```

## Mapping from the original final package

| Original package location | Repository destination | Notes |
|---|---|---|
| `01_Final_Model/` | `models/final/` | Retain the final power-corrected `.slx` model |
| `02_Calibration/` torque files | `calibration/torque/` | Final 3-D LUT and combined gains |
| `02_Calibration/` battery and power files | `calibration/battery/` | Battery identification and speed/mode correction files |
| `03_Validation_Results/` | `results/validation/` | Small MAT files and validation summaries |
| `04_Figures_and_Metrics/` PNG figures | Appropriate `figures/` topic folder | Sort by torque, battery, correction, or final validation |
| `04_Figures_and_Metrics/` CSV files | `results/validation/` | Keep numeric results separate from images |
| `04_Figures_and_Metrics/` `.fig` files | `figures/source/` | Editable MATLAB figure sources |
| `05_MATLAB_Scripts/init_EV6_model.m` | `scripts/initialization/` | Primary initialization entry point |
| Other files in `05_MATLAB_Scripts/` | `scripts/archive/` | Development, diagnostic, plotting, and validation scripts |
| LaTeX report | `report/EV6_Model_Calibration_and_Validation_Report.tex` | Editable technical report source |
| Six Markdown guides | `docs/` | Repository documentation |

## Important calibration files

### Torque

```text
calibration/torque/EV6_axle_split_LUT_3D.mat
calibration/torque/EV6_CombinedTrainingCalibration.mat
```

### Battery and power correction

Keep the final battery and correction artifacts directly in:

```text
calibration/battery/
```

This includes files such as:

```text
EV6_Battery_LeastSquares_Results.mat
EV6_Powertrain_Energy_Calibration_Parameters.mat
EV6_SpeedMode_PowerCorrection_Map.csv
EV6_SpeedMode_PowerCorrection_Metrics.csv
EV6_SpeedMode_PowerCorrection_Results.mat
```

Supporting diagnostic CSV and smaller MAT files may remain in the same folder when they document how the retained calibration was selected.

## Clean up wrapper folders

If the GitHub upload currently contains these paths:

```text
calibration/battery/02_Calibration/
scripts/archive/05_MATLAB_Scripts/
results/validation/03_Validation_Results/
results/validation/04_Figures_and_Metrics/
```

move the files one level upward so that the package numbers do not become permanent repository subfolders. The files should end up directly in `calibration/battery/`, `scripts/archive/`, or `results/validation/`.

## Files intentionally excluded

### Raw dyno data

Original dynamometer MAT files should remain outside the public repository unless their ownership and distribution terms are confirmed. A local-only layout may use:

```text
data/raw/
```

This path should remain ignored by Git.

### Large simulation outputs

Generated simulation outputs are reproducible artifacts and can be very large. Keep them locally in:

```text
results/simulation_outputs/
```

Git does not preserve empty folders. To show this directory on GitHub, add a small `README.md` explaining that generated outputs are excluded.

### Oversized intermediate calibration files

Do not commit the approximately 197 MB `EV6_Auxiliary_Separated_Correction_Results.mat` through ordinary GitHub upload. It exceeds GitHub's standard per-file limit and is not required when smaller retained maps, metrics, and final calibration artifacts are already included.

## Files that should not be duplicated

- Keep one final model in `models/final/`.
- Keep the primary initialization script in `scripts/initialization/`.
- An archived copy of `init_EV6_model.m` may remain with the historical scripts if it reflects the original package, but the initialization folder is authoritative.
- Keep figures as PNG in their topic folders and editable `.fig` sources in `figures/source/`.
- Do not place the same validation CSV in both `figures/` and `results/validation/`.

## Path portability note

Moving files into a cleaner repository does not automatically update hard-coded MATLAB paths. Search archived scripts for references to the original package name, `Bolt_EV`, absolute OneDrive paths, or numbered package folders. Replace those paths with `fullfile` expressions relative to the repository root when preparing a standalone release.

