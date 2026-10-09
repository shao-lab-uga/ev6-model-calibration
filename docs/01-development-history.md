# Chronological Development History

This document records how the supplied MATLAB/Simulink vehicle model was converted into the final calibrated model of a **2023 Kia EV6 Wind AWD**. The work was performed in MATLAB/Simulink R2024a using four chassis-dynamometer datasets.

## Starting point

The project began with a supplied Mach-E-based vehicle model rather than a clean EV6 model. The original asset was preserved, and separate copies were created for each development branch. This made it possible to compare every major change against a known baseline without overwriting the supplied model.

The measured data consisted of four approximately 1 ms-sampled dynamometer runs:

| Run | Samples | Duration (s) | Primary use |
|---|---:|---:|---|
| 001 | 1,433,737 | 1,433.793 | Calibration and map development |
| 002 | 1,428,146 | 1,428.202 | Calibration and map development |
| 003 | 621,577 | 621.601 | Calibration and map development |
| 004 | 619,377 | 619.401 | Development validation and final evaluation |

Runs 001–003 were used to identify calibration parameters. Run 004 was initially reserved for validation, but it later influenced selection of the final power-correction scale. It must therefore be described as a **development-validation cycle**, not an untouched independent test set.

## Stage 1 — Inspect the data and preserve the baseline

The dyno channels, units, sample timing, wheel torques, pack current, pack voltage, speed, and drive-cycle demand were inspected first. The supplied model was copied before modification. Separate candidates were retained for the true pre-LUT baseline, LUT-only model, torque-gain model, battery candidates, and final power-corrected model.

This preserved traceability: each retained modification could be tied to a targeted diagnostic or measurable improvement.

## Stage 2 — Identify and correct the active speed-demand source

The first battery comparison was invalid because the simulation was not following the same speed cycle as the dyno vehicle. During an early 5–60 s test:

- Simulated reference-speed maximum: **21.279 m/s**
- Dyno speed maximum: **7.759 m/s**
- Speed RMSE: **12.273 m/s**

The active top-level `From Workspace` block was different from the internal compatibility signal that had initially been assumed. The signal routing was traced through the driver and supervisory-control path, and the Run 004 demand was assigned to the active speed source.

After correction, the reference-speed trace matched the dyno exactly in the short diagnostic:

- Reference-speed RMSE: **0 m/s**
- Reference-speed correlation: **1.000000**
- Actual-speed RMSE: **0.215 m/s**
- Actual-speed correlation: **0.999891**

No battery parameter was accepted until this input-routing issue was corrected.

## Stage 3 — Establish the true pre-LUT baseline

An early baseline copy produced zero motor command because the manual/automatic routing selected inactive external pedal channels. The route was traced from the subsystem inputs through the auto-pilot switches, and the active driver path was restored.

The repaired pre-LUT model completed Run 004 and established the valid mechanical baseline:

| Metric | True pre-LUT result |
|---|---:|
| Four-wheel torque MAE | 152.23 N·m |
| Four-wheel torque RMSE | 252.63 N·m |
| Vehicle-speed RMSE | 1.2511 m/s |

## Stage 4 — Develop the EV6 torque-distribution model

Measured front- and rear-axle behavior was used to replace the inherited torque allocation with an EV6-specific three-dimensional lookup table. The LUT inputs are:

1. Vehicle speed
2. Longitudinal acceleration
3. Signed total axle torque

The LUT contains **25 × 21 × 28 = 14,700 operating points**. It covers traction from 0 to 1300 N·m and regeneration from −1400 to 0 N·m. Front share is read from the table and rear share is calculated as `1 - front_share`.

Separate torque gains were then identified:

- Traction gain: **1.223989**
- Regeneration gain: **1.348705**

The LUT alone reduced four-wheel torque MAE by 36.97%. Adding the gains increased the total MAE reduction to 39.98%.

## Stage 5 — Diagnose the battery-voltage architecture

The supplied battery used 96 series cells, three parallel branches, a 60 Ah branch capacity, and 0.90 initial SOC. Its modeled initial open-circuit voltage was approximately **390.817 V**, while the dyno pack was near **726 V**. The voltage ratio of 1.858 showed that resistance tuning could not repair the mismatch; the series-cell architecture had to change.

A provisional 84 kWh, 192s2p pack was created to verify the electrical signal path. Once the exact vehicle trim was confirmed, it was replaced by a 77.4 kWh equivalent pack consistent with the 2023 Kia EV6 Wind AWD specification.

| Battery stage | Series | Parallel | Pack capacity (Ah) | Initial SOC | Initial OCV (V) |
|---|---:|---:|---:|---:|---:|
| Supplied battery | 96 | 3 | 180.000 | 0.9000 | 390.817 |
| Provisional 84 kWh | 192 | 2 | 120.600 | 0.6389 | 726.472 |
| Final EV6 equivalent | 192 | 2 | 111.047 | 0.638879 | 726.472 |

Least-squares identification using Runs 001–003 produced an effective pack resistance of **0.132764 Ω**. A resistance-table scale of **1.84965** was applied. The 192s2p configuration is an equivalent simulation topology, not a claim about the production cell arrangement.

## Stage 6 — Audit the energy calculation

Current and voltage appeared close while cumulative energy remained incorrect, so the energy calculation was audited before more tuning. Four methods were compared:

- Direct `trapz`
- Explicit trapezoidal summation
- Final value of `cumtrapz`
- Positive energy minus regenerative-energy magnitude

All four methods produced the same Run 004 dyno result: **0.28431 kWh**.

The original model had an average power bias of **−0.3826 kW**. Integrated over 0.17067 h, this produced **−0.06530 kWh**, exactly matching the observed energy deficit. The problem was therefore a sustained power bias rather than an integration error.

## Stage 7 — Investigate stationary auxiliary demand

During stationary portions of the test, the dyno vehicle consumed approximately **0.364 kW**, whereas the simulation consumed almost zero. A training-only estimate gave 0.3643 kW, or approximately 0.499 A at the modeled pack voltage.

A separate constant auxiliary-load block was evaluated but not retained. The later speed/mode map already captured part of this behavior, so keeping both paths would have double-counted auxiliary energy.

## Stage 8 — Build the speed/mode power-correction map

Residual battery-power error was divided into traction, regeneration, and low-power/idle modes using a 0.5 kW mode threshold. Runs 001–003 were binned into nine speed regions. The average required corrections were smoothed and multiplied by a conservative scale of **0.50**.

An unscaled map was rejected because it over-corrected Run 004. The 0.50 scale gave the best development-validation balance.

## Stage 9 — Integrate the correction on the battery side

The map produces a power correction, `ΔP`. It is converted into current using:

```text
ΔI = 1000 ΔP / Vpack
```

The current correction is injected at the existing battery-current summation point. This changes battery current, voltage, power, SOC, and integrated energy consistently without modifying requested motor torque or vehicle motion.

## Stage 10 — Validate the final model

The final model improved mechanical, electrical, and energy predictions:

| Metric | Before | Final | Improvement |
|---|---:|---:|---:|
| Four-wheel torque MAE | 152.23 N·m | 91.373 N·m | 39.98% |
| Four-wheel torque RMSE | 252.63 N·m | 143.79 N·m | 43.08% |
| Vehicle-speed RMSE | 1.2511 m/s | 0.33211 m/s | 73.46% |
| Battery-current MAE | 1.2219 A | 0.97128 A | 20.51% |
| Battery-power MAE | 0.88796 kW | 0.70579 kW | 20.52% |
| Absolute net-energy error | 22.965% | 1.8076% | 92.13% relative reduction |

The battery-side correction preserved vehicle dynamics. Relative to the uncorrected 77.4 kWh model, the corrected model changed speed by only **4.975 × 10⁻⁵ m/s RMSE** and four-wheel torque by **0.1665 N·m RMSE**.

## Stage 11 — Organize the final deliverables

The final retained model is:

```text
EV6_LUT_FourWheel_EV6Battery77p4kWh_PowerCorrected.slx
```

The repository separates the final model, initialization script, archived development scripts, calibration files, validation results, figures, documentation, and report. Raw dyno files and large intermediate simulation outputs are intentionally excluded from the public repository.

