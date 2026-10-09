%% CREATE FINAL EV6 VALIDATION SUMMARY
% Combines the completed torque, speed, battery, energy,
% auxiliary-load, and dynamics-preservation results.
%
% No Simulink parameters are changed.

clear
clc

%% Locations

projectFolder = [ ...
    'C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\Vehicles_24a\Vehicles\' ...
    'VehicleProjects\Bolt_EV'];

figureFolder = fullfile(projectFolder, ...
    'Run004_Professor_Figures');

calibrationFolder = fullfile(projectFolder, ...
    'Battery_Calibration');

torqueFile = fullfile(figureFolder, ...
    'EV6_Run004_ThreeCase_Torque_Metrics.csv');

speedFile = fullfile(figureFolder, ...
    'EV6_Run004_ThreeCase_Speed_Metrics.csv');

electricalFile = fullfile(figureFolder, ...
    'EV6_Run004_77p4kWh_PowerCorrected_Full_ElectricalMetrics.csv');

energyFile = fullfile(figureFolder, ...
    'EV6_Run004_77p4kWh_PowerCorrected_Full_EnergyMetrics.csv');

dynamicsFile = fullfile(figureFolder, ...
    'EV6_Run004_PowerCorrection_DynamicsPreservation.csv');

auxiliaryFile = fullfile(calibrationFolder, ...
    'EV6_Stationary_Auxiliary_Load_Metrics.csv');

requiredFiles = [ ...
    string(torqueFile)
    string(speedFile)
    string(electricalFile)
    string(energyFile)
    string(dynamicsFile)
    string(auxiliaryFile)];

for k = 1:numel(requiredFiles)
    assert(isfile(requiredFiles(k)), ...
        'Required result file is missing:\n%s', ...
        requiredFiles(k));
end

%% Load results

TorqueMetrics = readtable(torqueFile);
SpeedMetrics = readtable(speedFile);
ElectricalMetrics = readtable(electricalFile);
EnergyMetrics = readtable(energyFile);
DynamicsMetrics = readtable(dynamicsFile);
AuxiliaryMetrics = readtable(auxiliaryFile);

TorqueMetrics.Model = string(TorqueMetrics.Model);
TorqueMetrics.Component = string(TorqueMetrics.Component);

SpeedMetrics.SpeedModel = ...
    string(SpeedMetrics.SpeedModel);

ElectricalMetrics.Signal = ...
    string(ElectricalMetrics.Signal);

ElectricalMetrics.Model = ...
    string(ElectricalMetrics.Model);

EnergyMetrics.Dataset = ...
    string(EnergyMetrics.Dataset);

DynamicsMetrics.Signal = ...
    string(DynamicsMetrics.Signal);

AuxiliaryMetrics.Run = ...
    string(AuxiliaryMetrics.Run);

%% Extract four-wheel torque metrics

torqueModels = [ ...
    "True pre-LUT"
    "LUT-only"
    "LUT + gains"];

torqueMAE_Nm = zeros(3,1);
torqueRMSE_Nm = zeros(3,1);
torqueCorrelation = zeros(3,1);

for k = 1:numel(torqueModels)

    row = ...
        TorqueMetrics.Model == torqueModels(k) & ...
        TorqueMetrics.Component == "Four-Wheel Total";

    assert(nnz(row) == 1, ...
        'Could not uniquely locate %s total-torque results.', ...
        torqueModels(k));

    torqueMAE_Nm(k) = TorqueMetrics.MAE_Nm(row);
    torqueRMSE_Nm(k) = TorqueMetrics.RMSE_Nm(row);
    torqueCorrelation(k) = TorqueMetrics.Correlation(row);
end

%% Extract speed metrics

speedRMSE_mps = zeros(3,1);
speedCorrelation = zeros(3,1);

for k = 1:numel(torqueModels)

    row = SpeedMetrics.SpeedModel == torqueModels(k);

    assert(nnz(row) == 1, ...
        'Could not uniquely locate %s speed results.', ...
        torqueModels(k));

    speedRMSE_mps(k) = SpeedMetrics.SpeedRMSE_mps(row);
    speedCorrelation(k) = ...
        SpeedMetrics.SpeedCorrelation(row);
end

%% Extract battery electrical metrics

originalCurrentRow = ...
    ElectricalMetrics.Signal == "Battery Current" & ...
    ElectricalMetrics.Model == "Original 77.4-kWh";

correctedCurrentRow = ...
    ElectricalMetrics.Signal == "Battery Current" & ...
    ElectricalMetrics.Model == ...
        "Power-corrected 77.4-kWh";

originalPowerRow = ...
    ElectricalMetrics.Signal == "Battery Power" & ...
    ElectricalMetrics.Model == "Original 77.4-kWh";

correctedPowerRow = ...
    ElectricalMetrics.Signal == "Battery Power" & ...
    ElectricalMetrics.Model == ...
        "Power-corrected 77.4-kWh";

assert(nnz(originalCurrentRow) == 1);
assert(nnz(correctedCurrentRow) == 1);
assert(nnz(originalPowerRow) == 1);
assert(nnz(correctedPowerRow) == 1);

originalCurrentMAE_A = ...
    ElectricalMetrics.MAE(originalCurrentRow);

correctedCurrentMAE_A = ...
    ElectricalMetrics.MAE(correctedCurrentRow);

originalCurrentCorrelation = ...
    ElectricalMetrics.Correlation(originalCurrentRow);

correctedCurrentCorrelation = ...
    ElectricalMetrics.Correlation(correctedCurrentRow);

originalPowerMAE_kW = ...
    ElectricalMetrics.MAE(originalPowerRow);

correctedPowerMAE_kW = ...
    ElectricalMetrics.MAE(correctedPowerRow);

%% Extract energy results

dynoEnergyRow = ...
    EnergyMetrics.Dataset == "EV6 dyno";

originalEnergyRow = ...
    EnergyMetrics.Dataset == "Original 77.4-kWh";

correctedEnergyRow = ...
    EnergyMetrics.Dataset == ...
        "Power-corrected 77.4-kWh";

assert(nnz(dynoEnergyRow) == 1);
assert(nnz(originalEnergyRow) == 1);
assert(nnz(correctedEnergyRow) == 1);

dynoEnergy_kWh = ...
    EnergyMetrics.NetEnergy_kWh(dynoEnergyRow);

originalEnergy_kWh = ...
    EnergyMetrics.NetEnergy_kWh(originalEnergyRow);

correctedEnergy_kWh = ...
    EnergyMetrics.NetEnergy_kWh(correctedEnergyRow);

originalEnergyError_pct = ...
    EnergyMetrics.NetEnergyError_pct(originalEnergyRow);

correctedEnergyError_pct = ...
    EnergyMetrics.NetEnergyError_pct(correctedEnergyRow);

%% Extract dynamics-preservation results

speedPreservationRow = ...
    DynamicsMetrics.Signal == "Vehicle Speed";

torquePreservationRow = ...
    DynamicsMetrics.Signal == "Four-Wheel Total";

speedChangeRMSE_mps = ...
    DynamicsMetrics.RMSE(speedPreservationRow);

torqueChangeRMSE_Nm = ...
    DynamicsMetrics.RMSE(torquePreservationRow);

speedPreservationCorrelation = ...
    DynamicsMetrics.Correlation(speedPreservationRow);

torquePreservationCorrelation = ...
    DynamicsMetrics.Correlation(torquePreservationRow);

%% Extract auxiliary-load result

trainingAuxiliaryRows = ismember( ...
    AuxiliaryMetrics.Run, ...
    ["Run001","Run002","Run003"]);

auxiliaryPower_kW = median( ...
    AuxiliaryMetrics.MissingPowerMedian_kW( ...
        trainingAuxiliaryRows));

auxiliaryCurrent_A = median( ...
    AuxiliaryMetrics.EquivalentMissingCurrent_A( ...
        trainingAuxiliaryRows));

%% Calculate improvements

torqueMAEImprovement_pct = 100 * ...
    (torqueMAE_Nm(1)-torqueMAE_Nm(3)) / ...
    torqueMAE_Nm(1);

torqueRMSEImprovement_pct = 100 * ...
    (torqueRMSE_Nm(1)-torqueRMSE_Nm(3)) / ...
    torqueRMSE_Nm(1);

speedRMSEImprovement_pct = 100 * ...
    (speedRMSE_mps(1)-speedRMSE_mps(3)) / ...
    speedRMSE_mps(1);

currentMAEImprovement_pct = 100 * ...
    (originalCurrentMAE_A-correctedCurrentMAE_A) / ...
    originalCurrentMAE_A;

powerMAEImprovement_pct = 100 * ...
    (originalPowerMAE_kW-correctedPowerMAE_kW) / ...
    originalPowerMAE_kW;

energyErrorImprovement_pct = 100 * ...
    (abs(originalEnergyError_pct) - ...
     abs(correctedEnergyError_pct)) / ...
    abs(originalEnergyError_pct);

%% Create final summary table

FinalSummary = table( ...
    [ ...
    "Four-wheel torque MAE"
    "Four-wheel torque RMSE"
    "Vehicle-speed RMSE"
    "Battery-current MAE"
    "Battery-power MAE"
    "Absolute net-energy error"], ...
    [ ...
    torqueMAE_Nm(1)
    torqueRMSE_Nm(1)
    speedRMSE_mps(1)
    originalCurrentMAE_A
    originalPowerMAE_kW
    abs(originalEnergyError_pct)], ...
    [ ...
    torqueMAE_Nm(3)
    torqueRMSE_Nm(3)
    speedRMSE_mps(3)
    correctedCurrentMAE_A
    correctedPowerMAE_kW
    abs(correctedEnergyError_pct)], ...
    [ ...
    "N*m"
    "N*m"
    "m/s"
    "A"
    "kW"
    "%"], ...
    [ ...
    torqueMAEImprovement_pct
    torqueRMSEImprovement_pct
    speedRMSEImprovement_pct
    currentMAEImprovement_pct
    powerMAEImprovement_pct
    energyErrorImprovement_pct], ...
    'VariableNames',{ ...
    'Metric','InitialValue','FinalValue', ...
    'Unit','Improvement_pct'});

fprintf('\n===== FINAL EV6 VALIDATION SUMMARY =====\n');
disp(FinalSummary);

fprintf('\n===== KEY FINAL VALUES =====\n');
fprintf('Dyno net energy = %.5f kWh\n', ...
    dynoEnergy_kWh);

fprintf('Original model net energy = %.5f kWh\n', ...
    originalEnergy_kWh);

fprintf('Final model net energy = %.5f kWh\n', ...
    correctedEnergy_kWh);

fprintf('Final current correlation = %.5f\n', ...
    correctedCurrentCorrelation);

fprintf('Estimated stationary auxiliary power = %.4f kW\n', ...
    auxiliaryPower_kW);

fprintf('Equivalent stationary auxiliary current = %.4f A\n', ...
    auxiliaryCurrent_A);

fprintf('\nDynamics change caused by battery correction:\n');

fprintf('Speed RMSE difference = %.8f m/s\n', ...
    speedChangeRMSE_mps);

fprintf('Torque RMSE difference = %.6f N*m\n', ...
    torqueChangeRMSE_Nm);

fprintf('Speed preservation correlation = %.8f\n', ...
    speedPreservationCorrelation);

fprintf('Torque preservation correlation = %.8f\n', ...
    torquePreservationCorrelation);

fprintf('========================================\n');

%% Create final figure

figureHandle = figure( ...
    'Color','w', ...
    'Name','EV6 Final Validation Summary', ...
    'Position',[70 50 1550 850]);

plotLayout = tiledlayout(2,2, ...
    'TileSpacing','compact', ...
    'Padding','compact');

title(plotLayout, ...
    '2023 Kia EV6 Wind AWD: Final Model-Validation Summary', ...
    'FontWeight','bold');

nexttile;

bar(categorical(torqueModels), ...
    [torqueMAE_Nm torqueRMSE_Nm]);

grid on;
ylabel('Torque error [N*m]');
title('Four-wheel total-torque error');
legend('MAE','RMSE','Location','best');

nexttile;

bar(categorical(torqueModels),speedRMSE_mps);

grid on;
ylabel('Speed RMSE [m/s]');
title('Vehicle-speed tracking');

nexttile;

improvementLabels = categorical([ ...
    "Current MAE"
    "Power MAE"
    "Energy error"]);

bar(improvementLabels,[ ...
    currentMAEImprovement_pct
    powerMAEImprovement_pct
    energyErrorImprovement_pct]);

grid on;
ylabel('Improvement [%]');
title('Electrical and energy improvements');

nexttile;

energyLabels = categorical([ ...
    "EV6 dyno"
    "Original model"
    "Final corrected model"]);

bar(energyLabels,[ ...
    dynoEnergy_kWh
    originalEnergy_kWh
    correctedEnergy_kWh]);

grid on;
ylabel('Net battery energy [kWh]');
title('Run 004 net-energy prediction');

%% Save outputs

summaryFile = fullfile(figureFolder, ...
    'EV6_Final_Validation_Summary.csv');

figureFile = fullfile(figureFolder, ...
    'EV6_Final_Validation_Summary.png');

resultsFile = fullfile(projectFolder, ...
    'EV6_Final_Validation_Summary.mat');

writetable(FinalSummary,summaryFile);

exportgraphics(figureHandle, ...
    figureFile,'Resolution',200);

save(resultsFile, ...
    'FinalSummary', ...
    'torqueModels', ...
    'torqueMAE_Nm', ...
    'torqueRMSE_Nm', ...
    'speedRMSE_mps', ...
    'dynoEnergy_kWh', ...
    'originalEnergy_kWh', ...
    'correctedEnergy_kWh', ...
    'originalEnergyError_pct', ...
    'correctedEnergyError_pct', ...
    'originalCurrentMAE_A', ...
    'correctedCurrentMAE_A', ...
    'originalPowerMAE_kW', ...
    'correctedPowerMAE_kW', ...
    'auxiliaryPower_kW', ...
    'auxiliaryCurrent_A', ...
    'speedChangeRMSE_mps', ...
    'torqueChangeRMSE_Nm');

fprintf('\n===== FINAL SUMMARY COMPLETE =====\n');
fprintf('Summary table:\n%s\n\n',summaryFile);
fprintf('Figure:\n%s\n\n',figureFile);
fprintf('MAT results:\n%s\n',resultsFile);
fprintf('No Simulink parameters were changed.\n');
fprintf('==================================\n');