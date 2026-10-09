# Recommended Next Steps

## 1. Complete independent validation

The highest-priority technical task is to evaluate the frozen final model on a new dynamometer cycle that was not used for LUT construction, parameter identification, correction-map development, or scale selection.

Before running the new cycle:

1. Freeze the current model and calibration files.
2. Do not retune parameters using the new cycle.
3. Define the evaluation interval and signal preprocessing in advance.
4. Report torque, speed, current, voltage, power, and energy metrics using the same definitions as Run 004.

This will separate development performance from true generalization performance.

## 2. Test a clean clone

Clone the repository onto a different computer or into an empty directory and record every missing dependency. The test should identify:

- Required MATLAB and Simulink products
- Required version and update level
- Data dictionaries and bus objects
- Custom libraries and system objects
- RealSim or HIL-specific dependencies
- Hard-coded file paths
- Required raw-data variables

Update the reproduction guide after this test. Until it succeeds, describe the repository as a documented project package rather than a fully standalone release.

## 3. Make MATLAB paths portable

Replace absolute or machine-specific paths with repository-relative paths using `fullfile`. Consolidate repeated setup work in `scripts/initialization/init_EV6_model.m` and make the script detect missing dependencies with clear error messages.

Recommended checks include:

```matlab
assert(isfile(modelPath), 'Final model not found: %s', modelPath)
assert(isfile(lutPath), 'Torque LUT not found: %s', lutPath)
assert(isfile(powerMapPath), 'Power-correction map not found: %s', powerMapPath)
```

## 4. Add automated regression tests

Create a lightweight validation script that checks:

- Required calibration variables exist and have the expected dimensions
- Front and rear shares sum to one within tolerance
- LUTs contain no NaN or Inf values
- Torque breakpoint ordering is monotonic
- A short simulation completes
- Reference speed matches the requested drive cycle
- The final model stays within accepted metric tolerances
- Battery correction leaves speed and torque effectively unchanged

These checks will make future edits safer.

## 5. Separate empirical and physical losses

The speed/mode map corrects the observed residual power bias but does not identify each physical source. If component data become available, investigate explicit models for:

- Front and rear motor efficiency
- Inverter losses
- Gearbox and differential losses
- Tire and road-load losses
- HVAC and accessory power
- Pumps, control computers, and thermal-management loads

Retain the empirical correction as a benchmark while evaluating whether component-level models improve generalization.

## 6. Verify battery assumptions

The 192s2p representation should remain labeled as an equivalent topology. Future work should distinguish between:

- Official pack-level specifications
- Parameters inferred from terminal measurements
- Parameters introduced for compatibility with the inherited battery block
- Production construction that has not been independently verified

If cell-level or pack test data become available, re-identify capacity, resistance, OCV, temperature dependence, and SOC behavior.

## 7. Evaluate temperature and SOC sensitivity

The present validation is tied to the conditions represented in the available runs. Additional tests should examine:

- Different initial SOC values
- Low and high ambient temperatures
- Pack-temperature transients
- High-power acceleration
- Extended regenerative braking
- Longer cycles with greater net energy throughput

## 8. Prepare for HIL only after desktop portability

Resolve warnings related to `dsrt.tlc`, RealSim objects, disabled library links, and inherited model dependencies before claiming HIL readiness. Confirm solver configuration, execution rate, signal interfaces, and target compatibility after the desktop model reproduces cleanly.

## 9. Connect the MATLAB work to the Python exploration

The documented EV6 parameters and validation metrics provide a useful benchmark for exploring Python vehicle-dynamics frameworks. A future comparison can evaluate:

- Equivalent road-load and drivetrain parameters
- Reproduction of the Run 004 speed trace
- Wheel-speed and inertia assumptions
- Battery power and energy calculations
- Differences between block-diagram and equation-based simulation workflows

The Python model should be treated as a separate implementation and validated against the same measured signals rather than assumed equivalent because it uses similar vehicle parameters.

## 10. Repository completion checklist

- [ ] Add the six Markdown documents under `docs/`
- [ ] Add the LaTeX source under `report/`
- [ ] Update the README package-status statement
- [ ] Flatten unnecessary numbered wrapper folders
- [ ] Confirm all README links open correctly
- [ ] Confirm no raw restricted data are committed
- [ ] Confirm no individual file exceeds GitHub's standard limit
- [ ] Record software and dependency versions
- [ ] Perform a clean-clone test
- [ ] Add a new independent validation cycle when available

