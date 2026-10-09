# EV6 Vehicle Model Calibration and Validation

**Sam Lim · UGA Mobility Systems Controls Laboratory**

Development of a MATLAB/Simulink longitudinal vehicle model for a **2023 Kia EV6 Wind AWD**, starting from a supplied Mach-E-based model and progressively incorporating measured EV6 torque distribution, battery behavior, and energy consumption.

The project follows an engineering sequence: establish valid inputs and a working baseline, calibrate mechanical behavior, correct the battery representation, investigate remaining power bias, and validate the final model.

> **Package status:** This repository contains the final Simulink model, MATLAB development and validation scripts, torque and battery calibration files, validation metrics, exported figures, project documentation, and the editable LaTeX report. Raw dynamometer datasets and large intermediate simulation outputs are excluded because of distribution restrictions and repository size limits. Reported results were produced during the documented MATLAB/Simulink development workflow.

## Main results

| Comparison | Metric | Before | After |
| --- | --- | ---: | ---: |
| True pre-LUT → calibrated torque model | Four-wheel torque MAE | 152.23 N·m | 91.373 N·m |
| True pre-LUT → calibrated torque model | Four-wheel torque RMSE | 252.63 N·m | 143.79 N·m |
| True pre-LUT → calibrated torque model | Vehicle-speed RMSE | 1.2511 m/s | 0.33211 m/s |
| Uncorrected 77.4-kWh → power-corrected model | Battery-current MAE | 1.2219 A | 0.97128 A |
| Uncorrected 77.4-kWh → power-corrected model | Battery-power MAE | 0.88796 kW | 0.70579 kW |
| Uncorrected 77.4-kWh → power-corrected model | Absolute net-energy error | 22.965% | 1.8076% |

Final Run004 battery-current correlation: **0.9784**. The battery correction changed speed by only **4.975 × 10⁻⁵ m/s RMSE** and wheel torque by **0.1665 N·m RMSE** relative to the uncorrected 77.4-kWh model.

**Validation boundary:** Runs001–003 supported calibration. Run004 also influenced selection of the final power-map scale, so these are development-validation results, not performance on an untouched independent test set.

## Read this repository

- [Chronological development history](docs/01-development-history.md): what changed, why, and what was learned.
- [Model architecture and parameters](docs/02-model-architecture.md): signal paths, units, and calibration decisions.
- [Validation results](docs/03-validation-results.md): baselines, metrics, and limitations.
- [Reproduction guide](docs/04-reproduction.md): environment, loading sequence, and remaining portability checks.
- [File-placement guide](docs/05-file-placement.md): where to put existing project files and figures.
- [Next steps](docs/06-next-steps.md): independent validation and subsequent Python exploration.
- [LaTeX technical report](report/EV6_Model_Calibration_and_Validation_Report.tex).

## Development at a glance

| Stage | Work completed | Reason |
| --- | --- | --- |
| 1 | Inspected EV6 dyno data and the supplied model | Establish signals, units, and starting assumptions |
| 2 | Developed speed/acceleration and then signed-torque LUTs | Represent changing front/rear torque allocation |
| 3 | Integrated traction/regen paths and debugged driver routing | Make the controller operate on valid commands |
| 4 | Verified the active speed demand and true pre-LUT baseline | Make comparisons meaningful |
| 5 | Compared LUT-only and torque-gain candidates | Separate allocation improvements from torque scaling |
| 6 | Diagnosed battery voltage architecture | Explain the large voltage mismatch |
| 7 | Tested 84-kWh, then finalized 77.4-kWh equivalent pack | Match the confirmed vehicle specification |
| 8 | Audited power integration and stationary demand | Identify why energy still disagreed |
| 9 | Added a speed/mode residual power correction | Reduce sustained electrical bias |
| 10 | Checked energy components and dynamics preservation | Confirm improvements without changing motion |
| 11 | Organized the final package and documented the model | Preserve results and support reproduction |

## Intended folder layout

| Folder | Contents |
| --- | --- |
| `docs/` | Explanations, decisions, reproduction, file mapping |
| `models/baseline/` | Preserved supplied model and verified pre-LUT model |
| `models/development/` | Selected intermediate candidates |
| `models/final/` | Final power-corrected model |
| `scripts/` | Initialization, preprocessing, LUT building, calibration, validation, plotting |
| `calibration/` | Final LUTs, torque gains, battery and power maps |
| `data/raw/` | Original dyno runs; excluded from Git by default |
| `results/` | Small CSV summaries and locally stored simulation outputs |
| `figures/` | Clean exported figures grouped by topic |
| `report/` | Existing editable LaTeX report |

The proposed folder layout is for repository organization. Existing scripts may assume the original `Bolt_EV` directory structure; moving files alone does not make their paths portable. Follow the reproduction guide before claiming a standalone release.

## Software and scope

The project used MATLAB/Simulink R2024a; the development history records Update 9. Exact toolbox, custom-library, RealSim, and target dependencies must be captured from the working installation. Desktop model update succeeded in the original project environment. A clean standalone clone and HIL deployment have not been demonstrated.

The battery topology is an **equivalent 192s2p representation**, not a verified description of production cell construction. The residual power correction is empirical; it does not separately identify individual motor, inverter, or accessory losses.

## Attribution and availability

The supplied vehicle model and dyno data came from the research workflow. Record their source and applicable distribution terms when adding them. This package does not assign a new license to supplied models, data, or third-party dependencies.
