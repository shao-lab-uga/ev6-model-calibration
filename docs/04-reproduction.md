# Reproduction Guide

## Purpose and current reproduction boundary

This guide describes the intended sequence for reproducing the packaged desktop simulation and Run 004 validation. The original development environment used **MATLAB/Simulink R2024a Update 9**.

The repository preserves the final model, calibration artifacts, analysis scripts, figures, and reported validation results. A clean standalone clone has not yet been demonstrated on a computer without the original project dependencies. Complete reproducibility may require supplied model libraries, data dictionaries, custom blocks, RealSim components, or other files whose distribution rights must be confirmed.

## Minimum repository files

The following files are required for the final candidate:

```text
models/final/EV6_LUT_FourWheel_EV6Battery77p4kWh_PowerCorrected.slx
scripts/initialization/init_EV6_model.m
calibration/torque/EV6_axle_split_LUT_3D.mat
calibration/torque/EV6_CombinedTrainingCalibration.mat
calibration/battery/EV6_SpeedMode_PowerCorrection_Results.mat
```

Run 004 source data and the applicable preparation and validation scripts are additionally required to rerun the published validation. Raw dyno data are not committed to the public repository by default.

## Recommended preparation

1. Install MATLAB and Simulink R2024a Update 9 or document the exact version used instead.
2. Obtain authorized copies of the original supporting model libraries, data dictionaries, and custom dependencies.
3. Clone or download the repository.
4. Place authorized raw dyno MAT files in a local data directory that is excluded by `.gitignore`.
5. Open MATLAB and set the repository root as the working directory.
6. Add required original-project folders to the MATLAB path without permanently adding unrelated directories.

## Initialization sequence

Run:

```matlab
run(fullfile('scripts','initialization','init_EV6_model.m'))
```

Then load the calibration files if the initialization script does not already load them:

```matlab
load(fullfile('calibration','torque','EV6_axle_split_LUT_3D.mat'))
load(fullfile('calibration','torque','EV6_CombinedTrainingCalibration.mat'))
load(fullfile('calibration','battery','EV6_SpeedMode_PowerCorrection_Results.mat'))
```

The exact variable-loading sequence should be verified against the final model workspace and any data dictionary used by the supplied base model.

## Prepare Run 004

Use the archived preparation script corresponding to Run 004, currently named:

```text
scripts/archive/prepare_EV6_Run004.m
```

Confirm that:

- The active top-level speed-demand variable contains the Run 004 trace
- Time is strictly increasing and uses seconds
- Vehicle speed uses the units expected by the active driver block
- Unused external acceleration, brake, and steering commands are zeroed
- Automatic driver routing is active
- The simulation stop time matches the desired 60 s diagnostic or full 619.401 s cycle

## Model loading and update

In MATLAB:

```matlab
model = 'EV6_LUT_FourWheel_EV6Battery77p4kWh_PowerCorrected';
load_system(fullfile('models','final',[model '.slx']));
set_param(model,'SimulationCommand','update');
```

If MATLAB reports a missing data dictionary such as `DdPassengerEv.sldd`, locate the authorized dictionary from the supplied project and add its containing folder to the MATLAB path. Do not replace bus objects with guessed definitions merely to suppress the error.

## Validation sequence

Run the short check first:

```text
scripts/archive/run_EV6_77p4kWh_PowerCorrected_Run004_60s.m
scripts/archive/validate_EV6_77p4kWh_PowerCorrected_60s.m
```

Verify that the reference speed follows the dyno cycle before interpreting battery results. Then run the full cycle:

```text
scripts/archive/run_EV6_77p4kWh_PowerCorrected_Run004_full.m
scripts/archive/validate_EV6_77p4kWh_PowerCorrected_full.m
```

Finally, verify that the battery correction does not alter mechanical behavior:

```text
scripts/archive/validate_EV6_power_corrected_vehicle_dynamics.m
```

## Metric definitions

For measured signal `y` and modeled signal `ŷ` evaluated on a common time base:

```text
bias = mean(ŷ - y)
MAE  = mean(abs(ŷ - y))
RMSE = sqrt(mean((ŷ - y).^2))
```

Battery power and net energy are:

```text
P_batt_kW = V_pack_V .* I_pack_A / 1000
E_net_kWh = trapz(time_s, P_batt_kW) / 3600
```

The sign convention used in the report treats positive pack power as net battery discharge and negative pack power as regenerative charging. Confirm the sign against the logged Simulink power signal before comparing results.

## Expected Run 004 checkpoints

| Checkpoint | Expected value |
|---|---:|
| Dyno net energy | 0.28431 kWh |
| Final simulated net energy | 0.27917 kWh |
| Final net-energy error | −1.8076% |
| Final current MAE | 0.97128 A |
| Final current correlation | 0.9784 |
| Final voltage MAE | 0.26896 V |
| Final power MAE | 0.70579 kW |
| Final speed RMSE | 0.33211 m/s |
| Final four-wheel torque MAE | 91.373 N·m |

Small differences may occur because of MATLAB release changes, solver settings, interpolation, or dependency versions. Large differences usually indicate a wrong input route, missing calibration variable, incorrect unit conversion, or unresolved model dependency.

## Known warnings and dependencies

The original desktop model updated despite warnings involving:

- `dsrt.tlc`
- RealSim system objects
- Disabled or unresolved library links
- Model-workspace or data-dictionary bus definitions

These warnings must be resolved before claiming a clean standalone release or HIL deployment readiness.

## Reproduction checklist

- [ ] MATLAB/Simulink version recorded
- [ ] Required libraries and data dictionary available
- [ ] Initialization completed without missing variables
- [ ] Torque and power calibration MAT files loaded
- [ ] Active speed demand verified against Run 004
- [ ] 60 s diagnostic completed
- [ ] Full-cycle simulation completed
- [ ] Metrics calculated over the common 5 s-to-end interval
- [ ] Energy sign convention confirmed
- [ ] Dynamics-preservation comparison completed
- [ ] Generated outputs stored outside Git unless intentionally small

