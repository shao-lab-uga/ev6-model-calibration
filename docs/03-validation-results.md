# Validation Results

## Validation strategy

Runs 001–003 supplied the data used to construct the torque-distribution LUT, identify torque gains, estimate effective battery resistance, and build the residual power-correction map. Run 004 was used for final comparisons.

Because Run 004 was also used to choose the 0.50 correction-map scale, the results below are **development-validation results**. They demonstrate improvement on the available data but do not replace evaluation on a new untouched cycle.

Unless otherwise stated, electrical metrics use the common interval from 5.0 s to the end of Run 004 at 619.401 s.

## Mechanical results

| Metric | True pre-LUT baseline | Final torque model | Improvement |
|---|---:|---:|---:|
| Four-wheel torque MAE | 152.23 N·m | 91.373 N·m | 39.98% |
| Four-wheel torque RMSE | 252.63 N·m | 143.79 N·m | 43.08% |
| Vehicle-speed RMSE | 1.2511 m/s | 0.33211 m/s | 73.46% |

The LUT accounted for most of the axle-torque improvement. The traction and regenerative gains added a smaller, consistent improvement after the front/rear allocation was established.

## Full-cycle electrical results

| Signal | Model | Bias | MAE | RMSE | Correlation |
|---|---|---:|---:|---:|---:|
| Current (A) | Original 77.4 kWh | −0.5242 | 1.2219 | 2.1174 | 0.9740 |
| Current (A) | Power corrected | −0.0387 | 0.9713 | 1.8678 | 0.9784 |
| Voltage (V) | Original 77.4 kWh | −0.2797 | 0.6586 | 1.5988 | 0.6521 |
| Voltage (V) | Power corrected | 0.0145 | 0.2690 | 0.4150 | 0.9560 |
| Power (kW) | Original 77.4 kWh | −0.3826 | 0.8880 | 1.5419 | 0.9738 |
| Power (kW) | Power corrected | −0.0301 | 0.7058 | 1.3598 | 0.9782 |

Battery current is the primary electrical validation signal because EV pack voltage is comparatively constant. The corrected current retained the measured waveform shape while reducing both bias and absolute error.

## Energy results

| Dataset | Net energy (kWh) | Positive energy (kWh) | Regeneration magnitude (kWh) |
|---|---:|---:|---:|
| EV6 dyno | 0.28431 | 0.46074 | 0.17643 |
| Original 77.4 kWh model | 0.21902 | 0.41266 | 0.19364 |
| Power-corrected model | 0.27917 | 0.44817 | 0.16899 |

| Energy metric | Original | Final |
|---|---:|---:|
| Signed net-energy error | −22.965% | −1.8076% |
| Absolute net-energy error | 22.965% | 1.8076% |
| Final absolute difference from dyno | — | 5.139 Wh |

The final model reduced absolute net-energy error by **21.16 percentage points**, corresponding to a **92.13% relative reduction** in the original error. Final positive-energy error was −2.73%, and final regenerative-energy error was −4.21%.

## Dynamics-preservation check

The power correction was required to improve electrical behavior without changing requested motion. Comparing the original 77.4 kWh model with the power-corrected model gave:

| Comparison | Difference |
|---|---:|
| Vehicle-speed RMSE | 4.975 × 10⁻⁵ m/s |
| Four-wheel torque RMSE | 0.1665 N·m |
| Vehicle-speed correlation | 1.00000000 |
| Four-wheel torque correlation | 0.99999987 |

These differences are effectively numerical rather than physical changes in vehicle behavior.

## Primary conclusion

On Run 004, the final model:

- Improved front/rear torque behavior and total torque accuracy
- Reduced vehicle-speed error
- Increased battery-current correlation to 0.9784
- Reduced battery-current MAE by 20.51%
- Reduced battery-power MAE by 20.52%
- Predicted net energy within 1.81% of the measured result
- Preserved speed and torque after application of the battery-side correction

## Interpretation limits

The results support the final model as the best candidate produced by this development workflow. They do not prove independent generalization because the correction strength was selected using Run 004. A new dynamometer cycle should be used for the next formal validation.

