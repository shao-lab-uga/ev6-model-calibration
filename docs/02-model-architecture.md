# Model Architecture and Calibration Parameters

## System overview

The final model is a longitudinal MATLAB/Simulink vehicle model derived from a supplied Mach-E-based project and calibrated to a **2023 Kia EV6 Wind AWD**. Its main signal sequence is:

```text
Drive-cycle demand
    → longitudinal driver and supervisory controls
    → total signed axle-torque request
    → EV6 front/rear torque-distribution LUT
    → front and rear drivetrains
    → chassis and vehicle speed
    → motor electrical demand
    → battery-current summation
    → 77.4 kWh EV6 equivalent battery
```

The battery-side power correction branches from vehicle speed and operating mode, converts a requested power correction to current, and joins the battery-current summation before the pack model.

## Active drive-cycle and driver path

The active speed demand comes from the top-level `From Workspace` route used by the driver. The desired speed must be loaded into the active workspace variable before simulation. Inactive external pedal commands are held at zero unless a manual-command test is intentionally being performed.

The driver compares desired speed with chassis speed feedback and produces acceleration and braking commands. These pass through the supervisory-control routing before generating the axle-torque request.

## EV6 torque-distribution subsystem

The torque-distribution subsystem uses three inputs:

| Input | Units | Purpose |
|---|---|---|
| Vehicle speed | km/h in the torque LUT workflow | Locates the speed operating region |
| Longitudinal acceleration | m/s² | Distinguishes transient vehicle state |
| Signed total axle torque | N·m | Separates traction and regeneration and determines load |

The principal calibration arrays are stored in `calibration/torque/EV6_axle_split_LUT_3D.mat`:

| Variable | Size | Meaning |
|---|---:|---|
| `accel_bp_mps2` | 1 × 25 | Acceleration breakpoints |
| `speed_bp_kph` | 1 × 21 | Speed breakpoints |
| `total_torque_bp_Nm` | 1 × 28 | Signed torque breakpoints |
| `front_share_lut_3d` | 25 × 21 × 28 | Calibrated front share |
| `rear_share_lut_3d` | 25 × 21 × 28 | Calibrated rear share |
| `front_share_measured_3d` | 25 × 21 × 28 | Binned measured front share |
| `sample_count_3d` | 25 × 21 × 28 | Supporting sample count |

The output equations are:

```text
front_share = LUT(speed, acceleration, signed_total_torque)
rear_share  = 1 - front_share
front_axle_torque = front_share × total_axle_torque
rear_axle_torque  = rear_share  × total_axle_torque
```

The table contains 14,700 points. Its signed-torque axis contains 14 negative breakpoints, one zero breakpoint, and 13 positive breakpoints. The zero point is shared when the calibration is partitioned into regeneration and traction regions.

## Torque-magnitude calibration

The split controls axle allocation; separate gains correct the magnitude of requested torque:

| Mode | Gain |
|---|---:|
| Traction | 1.223989 |
| Regeneration | 1.348705 |

The combined torque calibration is stored in:

```text
calibration/torque/EV6_CombinedTrainingCalibration.mat
```

The LUT and gains were identified from Runs 001–003. Their effect was evaluated separately so that allocation improvements were not confused with overall torque scaling.

## Battery model

The battery represents the confirmed high-level vehicle specification:

| Parameter | Final value |
|---|---:|
| Usable/model energy target | 77.4 kWh |
| Nominal pack voltage | 697 V |
| Equivalent series/parallel topology | 192s2p |
| Modeled pack capacity | 111.047 Ah |
| Initial SOC | 0.638879 |
| Initial open-circuit voltage | 726.472 V |
| Effective identified pack resistance | 0.132764 Ω |
| Resistance-table scale | 1.84965 |

The 192s2p layout was chosen to make the inherited table-based battery model reproduce the EV6 voltage class. It is an **equivalent topology**, not verified production construction.

## Speed/mode power correction

The residual electrical error varies with both speed and operating mode. A one-dimensional global multiplier was therefore rejected. The final calibration uses three correction curves over nine speed points:

| Speed (m/s) | Traction (kW) | Regeneration (kW) | Low power/idle (kW) |
|---:|---:|---:|---:|
| 1.25 | 0.4175 | 1.7139 | 0.2676 |
| 3.75 | 0.3686 | 1.3892 | 0.1984 |
| 6.25 | 0.2347 | 0.7038 | 0.0601 |
| 8.75 | 0.0500 | −0.2403 | 0.0000 |
| 11.25 | −0.1524 | −0.7851 | 0.0000 |
| 13.75 | −0.2711 | −1.1063 | 0.0000 |
| 17.50 | −0.3477 | −1.0523 | 0.0000 |
| 22.50 | −0.4175 | −1.0197 | 0.0008 |
| 27.50 | −0.4812 | −0.7965 | 0.0008 |

These values already include the retained **0.50 map scale**. The map output is converted from kW to A using pack voltage:

```text
delta_current_A = 1000 * delta_power_kW / pack_voltage_V
```

Injecting the correction on the battery side ensures that current, voltage, power, SOC, and energy remain mutually consistent. It does not alter the torque request.

## Key logged signals

The model and associated scripts use signals such as:

- `VehSpdRef` — reference vehicle speed
- `VehAcc` — longitudinal acceleration
- `AxlTrq` — axle-torque output
- `MtrTrq_F_Mache` and `MtrTrq_R_Mache` — front and rear motor/axle torque channels retained from the base model naming
- Battery current, voltage, power, SOC, and speed/omega outputs
- `tout` and `logsout` — simulation time and signal logging containers

Signal names should be checked after any library-link or model-version change because inherited subsystem naming is not fully EV6-specific.

## Model boundaries

The model is calibrated for desktop longitudinal simulation. It does not presently claim:

- Verified production battery cell topology
- Individually identified motor, inverter, drivetrain, HVAC, or accessory losses
- Independent generalization beyond the four available dyno runs
- HIL deployment readiness
- Full lateral or thermal vehicle behavior

