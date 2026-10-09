%% EV6 POWERTRAIN ENERGY CALIBRATION
% Training: Runs 001-003
% Validation: Run 004
%
% Model:
% Pcorrected =
%   tractionScale*max(Psim,0) +
%   regenScale*min(Psim,0) +
%   auxiliaryPower
%
% No Simulink parameters are changed by this script.

clearvars
clc

projectRoot = ['C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\Vehicles_24a\Vehicles\' ...
    'VehicleProjects\Bolt_EV'];

dynoRoot = ['C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\EV6_drivecycleData'];

calibrationFolder = fullfile( ...
    projectRoot,'Battery_Calibration');

if ~isfolder(calibrationFolder)
    mkdir(calibrationFolder);
end

runCodes = [
    "001"
    "002"
    "003"
    ];

runLabels = [
    "Run001"
    "Run002"
    "Run003"
    ];

numberOfRuns = numel(runCodes);

% Use every 100th sample for least squares.
% Original sampling is approximately 1000 Hz,
% producing approximately 10-Hz fitting data.
fitStride = 100;

%% Storage

timeData = cell(numberOfRuns,1);
dynoCurrentData = cell(numberOfRuns,1);
simCurrentData = cell(numberOfRuns,1);
dynoVoltageData = cell(numberOfRuns,1);
dynoPowerData = cell(numberOfRuns,1);
simPowerData = cell(numberOfRuns,1);

fitDynoPower = zeros(0,1);
fitSimPower = zeros(0,1);

fprintf('\n===== PREPARING POWERTRAIN TRAINING DATA =====\n');

%% 1. Load and align Runs 001-003

for runIndex = 1:numberOfRuns

    runCode = runCodes(runIndex);

    %% Load dyno data

    dynoFile = fullfile( ...
        dynoRoot, ...
        "standards_test_08142026_" + runCode + ".mat");

    assert(isfile(dynoFile), ...
        'Dyno file was not found:\n%s',dynoFile);

    dynoLoaded = load(dynoFile);

    dynoStructureName = ...
        "standards_test_08142026_" + runCode;

    assert(isfield(dynoLoaded,char(dynoStructureName)), ...
        'Expected dyno structure was not found.');

    dynoData = dynoLoaded.(char(dynoStructureName));

    channelNames = erase( ...
        string({dynoData.Y.Name}),["<",">"]);

    currentIndex = find( ...
        channelNames == "VEH_batCurrent",1);

    voltageIndex = find( ...
        channelNames == "VEH_batVoltage",1);

    assert(~isempty(currentIndex), ...
        'Battery current was not found for %s.',runCode);

    assert(~isempty(voltageIndex), ...
        'Battery voltage was not found for %s.',runCode);

    currentTimeIndex = ...
        dynoData.Y(currentIndex).XIndex;

    voltageTimeIndex = ...
        dynoData.Y(voltageIndex).XIndex;

    tDynoCurrent = double( ...
        dynoData.X(currentTimeIndex).Data(:));

    dynoCurrent = double( ...
        dynoData.Y(currentIndex).Data(:));

    tDynoVoltage = double( ...
        dynoData.X(voltageTimeIndex).Data(:));

    dynoVoltage = double( ...
        dynoData.Y(voltageIndex).Data(:));

    %% Load corresponding SimulationOutput

    simulationFile = fullfile( ...
        projectRoot, ...
        "EV6_Run" + runCode + ...
        "_77p4kWh_Corrected_Full_Output.mat");

    assert(isfile(simulationFile), ...
        'Simulation file was not found:\n%s',simulationFile);

    simulationLoaded = load(simulationFile);
    simulationFields = fieldnames(simulationLoaded);

    foundSimulationOutput = false;
    simulationOutput = [];

    for fieldIndex = 1:numel(simulationFields)

        candidateOutput = ...
            simulationLoaded.(simulationFields{fieldIndex});

        if isa(candidateOutput,'Simulink.SimulationOutput')
            simulationOutput = candidateOutput;
            foundSimulationOutput = true;
            break
        end
    end

    assert(foundSimulationOutput, ...
        'No SimulationOutput was found for Run %s.',runCode);

    simulatedPowerTS = ...
        simulationOutput.get('battery_power');

    simulatedCurrentTS = ...
        simulationOutput.get('battery_current');

    assert(isa(simulatedPowerTS,'timeseries'), ...
        'battery_power is not a timeseries.');

    assert(isa(simulatedCurrentTS,'timeseries'), ...
        'battery_current is not a timeseries.');

    tSimPower = double(simulatedPowerTS.Time(:));
    simulatedPowerRaw = double(simulatedPowerTS.Data(:));

    tSimCurrent = double(simulatedCurrentTS.Time(:));
    simulatedCurrentRaw = double(simulatedCurrentTS.Data(:));

    % Simulation battery_power is stored in watts
    if max(abs(simulatedPowerRaw)) > 1000
        simulatedPower_kW = simulatedPowerRaw/1000;
    else
        simulatedPower_kW = simulatedPowerRaw;
    end

    %% Establish common time

    comparisonStart = 5;

    comparisonEnd = min([
        tDynoCurrent(end)
        tDynoVoltage(end)
        tSimPower(end)
        tSimCurrent(end)
        ]);

    comparisonMask = ...
        tDynoCurrent >= comparisonStart & ...
        tDynoCurrent <= comparisonEnd;

    commonTime = tDynoCurrent(comparisonMask);
    alignedDynoCurrent = dynoCurrent(comparisonMask);

    alignedDynoVoltage = interp1( ...
        tDynoVoltage,dynoVoltage, ...
        commonTime,'linear');

    alignedSimPower = interp1( ...
        tSimPower,simulatedPower_kW, ...
        commonTime,'linear');

    alignedSimCurrent = interp1( ...
        tSimCurrent,simulatedCurrentRaw, ...
        commonTime,'linear');

    valid = ...
        isfinite(commonTime) & ...
        isfinite(alignedDynoCurrent) & ...
        isfinite(alignedDynoVoltage) & ...
        isfinite(alignedSimPower) & ...
        isfinite(alignedSimCurrent);

    commonTime = commonTime(valid);
    alignedDynoCurrent = alignedDynoCurrent(valid);
    alignedDynoVoltage = alignedDynoVoltage(valid);
    alignedSimPower = alignedSimPower(valid);
    alignedSimCurrent = alignedSimCurrent(valid);

    alignedDynoPower = ...
        alignedDynoCurrent .* alignedDynoVoltage ./ 1000;

    %% Store full-resolution data

    timeData{runIndex} = commonTime;
    dynoCurrentData{runIndex} = alignedDynoCurrent;
    simCurrentData{runIndex} = alignedSimCurrent;
    dynoVoltageData{runIndex} = alignedDynoVoltage;
    dynoPowerData{runIndex} = alignedDynoPower;
    simPowerData{runIndex} = alignedSimPower;

    %% Add downsampled data to least-squares set

    fittingIndices = ...
        1:fitStride:numel(commonTime);

    fitDynoPower = [
        fitDynoPower
        alignedDynoPower(fittingIndices)
        ]; %#ok<AGROW>

    fitSimPower = [
        fitSimPower
        alignedSimPower(fittingIndices)
        ]; %#ok<AGROW>

    fprintf('%s:\n',runLabels(runIndex));
    fprintf('  Full samples = %d\n',numel(commonTime));
    fprintf('  Fitting samples = %d\n',numel(fittingIndices));
    fprintf('  Dyno net energy = %.6f kWh\n', ...
        trapz(commonTime,alignedDynoPower)/3600);
    fprintf('  Simulation net energy = %.6f kWh\n\n', ...
        trapz(commonTime,alignedSimPower)/3600);
end

fprintf('Total fitting samples = %d\n', ...
    numel(fitDynoPower));

fprintf('==============================================\n');

%% 2. Least-squares powertrain identification

simulatedTractionPower = max(fitSimPower,0);
simulatedRegenPower = min(fitSimPower,0);

fitMatrix = [
    simulatedTractionPower, ...
    simulatedRegenPower, ...
    ones(size(fitSimPower))
    ];

identifiedParameters = fitMatrix \ fitDynoPower;

tractionPowerScale = identifiedParameters(1);
regenPowerScale = identifiedParameters(2);
auxiliaryPower_kW = identifiedParameters(3);

assert(all(isfinite(identifiedParameters)), ...
    'Least-squares fitting produced invalid parameters.');

fprintf('\n===== IDENTIFIED POWERTRAIN PARAMETERS =====\n');
fprintf('Traction-power scale = %.8f\n', ...
    tractionPowerScale);
fprintf('Regen-power scale = %.8f\n', ...
    regenPowerScale);
fprintf('Auxiliary power = %.8f kW\n', ...
    auxiliaryPower_kW);
fprintf('Fit-matrix condition number = %.4e\n', ...
    cond(fitMatrix));
fprintf('============================================\n');

%% 3. Evaluate each training run

DynoNetEnergy_kWh = zeros(numberOfRuns,1);
OriginalNetEnergy_kWh = zeros(numberOfRuns,1);
CorrectedNetEnergy_kWh = zeros(numberOfRuns,1);

OriginalEnergyError_pct = zeros(numberOfRuns,1);
CorrectedEnergyError_pct = zeros(numberOfRuns,1);

OriginalCurrentBias_A = zeros(numberOfRuns,1);
CorrectedCurrentBias_A = zeros(numberOfRuns,1);

OriginalCurrentMAE_A = zeros(numberOfRuns,1);
CorrectedCurrentMAE_A = zeros(numberOfRuns,1);

OriginalCurrentRMSE_A = zeros(numberOfRuns,1);
CorrectedCurrentRMSE_A = zeros(numberOfRuns,1);

OriginalCurrentCorrelation = zeros(numberOfRuns,1);
CorrectedCurrentCorrelation = zeros(numberOfRuns,1);

correctedPowerData = cell(numberOfRuns,1);
correctedCurrentData = cell(numberOfRuns,1);

for runIndex = 1:numberOfRuns

    currentTime = timeData{runIndex};
    dynoPower = dynoPowerData{runIndex};
    simPower = simPowerData{runIndex};

    dynoCurrent = dynoCurrentData{runIndex};
    simCurrent = simCurrentData{runIndex};
    dynoVoltage = dynoVoltageData{runIndex};

    correctedPower = ...
        tractionPowerScale*max(simPower,0) + ...
        regenPowerScale*min(simPower,0) + ...
        auxiliaryPower_kW;

    % Approximate the power correction as a battery-current correction.
    % Dyno voltage is used only for this offline diagnostic.
    correctedCurrent = simCurrent + ...
        1000*(correctedPower-simPower)./dynoVoltage;

    correctedPowerData{runIndex} = correctedPower;
    correctedCurrentData{runIndex} = correctedCurrent;

    DynoNetEnergy_kWh(runIndex) = ...
        trapz(currentTime,dynoPower)/3600;

    OriginalNetEnergy_kWh(runIndex) = ...
        trapz(currentTime,simPower)/3600;

    CorrectedNetEnergy_kWh(runIndex) = ...
        trapz(currentTime,correctedPower)/3600;

    OriginalEnergyError_pct(runIndex) = ...
        100*(OriginalNetEnergy_kWh(runIndex) - ...
        DynoNetEnergy_kWh(runIndex)) / ...
        abs(DynoNetEnergy_kWh(runIndex));

    CorrectedEnergyError_pct(runIndex) = ...
        100*(CorrectedNetEnergy_kWh(runIndex) - ...
        DynoNetEnergy_kWh(runIndex)) / ...
        abs(DynoNetEnergy_kWh(runIndex));

    originalCurrentError = simCurrent-dynoCurrent;
    correctedCurrentError = correctedCurrent-dynoCurrent;

    OriginalCurrentBias_A(runIndex) = ...
        mean(originalCurrentError);

    CorrectedCurrentBias_A(runIndex) = ...
        mean(correctedCurrentError);

    OriginalCurrentMAE_A(runIndex) = ...
        mean(abs(originalCurrentError));

    CorrectedCurrentMAE_A(runIndex) = ...
        mean(abs(correctedCurrentError));

    OriginalCurrentRMSE_A(runIndex) = ...
        sqrt(mean(originalCurrentError.^2));

    CorrectedCurrentRMSE_A(runIndex) = ...
        sqrt(mean(correctedCurrentError.^2));

    dynoCentered = dynoCurrent-mean(dynoCurrent);

    originalCentered = ...
        simCurrent-mean(simCurrent);

    correctedCentered = ...
        correctedCurrent-mean(correctedCurrent);

    OriginalCurrentCorrelation(runIndex) = ...
        sum(dynoCentered.*originalCentered) / ...
        sqrt(sum(dynoCentered.^2) * ...
        sum(originalCentered.^2));

    CorrectedCurrentCorrelation(runIndex) = ...
        sum(dynoCentered.*correctedCentered) / ...
        sqrt(sum(dynoCentered.^2) * ...
        sum(correctedCentered.^2));
end

TrainingMetrics = table( ...
    runLabels, ...
    DynoNetEnergy_kWh, ...
    OriginalNetEnergy_kWh, ...
    CorrectedNetEnergy_kWh, ...
    OriginalEnergyError_pct, ...
    CorrectedEnergyError_pct, ...
    OriginalCurrentBias_A, ...
    CorrectedCurrentBias_A, ...
    OriginalCurrentMAE_A, ...
    CorrectedCurrentMAE_A, ...
    OriginalCurrentRMSE_A, ...
    CorrectedCurrentRMSE_A, ...
    OriginalCurrentCorrelation, ...
    CorrectedCurrentCorrelation, ...
    'VariableNames',{ ...
    'Run', ...
    'DynoNetEnergy_kWh', ...
    'OriginalNetEnergy_kWh', ...
    'CorrectedNetEnergy_kWh', ...
    'OriginalEnergyError_pct', ...
    'CorrectedEnergyError_pct', ...
    'OriginalCurrentBias_A', ...
    'CorrectedCurrentBias_A', ...
    'OriginalCurrentMAE_A', ...
    'CorrectedCurrentMAE_A', ...
    'OriginalCurrentRMSE_A', ...
    'CorrectedCurrentRMSE_A', ...
    'OriginalCurrentCorrelation', ...
    'CorrectedCurrentCorrelation'});

fprintf('\n===== TRAINING-RUN RESULTS =====\n');
disp(TrainingMetrics);

%% 4. Independent validation on Run 004

run004ValidationFile = fullfile( ...
    projectRoot, ...
    'EV6_Run004_77p4kWh_Full_BatteryValidation.mat');

assert(isfile(run004ValidationFile), ...
    'Run 004 battery-validation MAT-file was not found.');

run004 = load(run004ValidationFile);

t004 = run004.tBattery;
dynoPower004 = run004.dynoPower_kW;
simPower004 = run004.simPower_kW;

dynoCurrent004 = run004.dynoCurrent;
simCurrent004 = run004.simCurrent;
dynoVoltage004 = run004.dynoVoltage;

correctedPower004 = ...
    tractionPowerScale*max(simPower004,0) + ...
    regenPowerScale*min(simPower004,0) + ...
    auxiliaryPower_kW;

correctedCurrent004 = simCurrent004 + ...
    1000*(correctedPower004-simPower004)./dynoVoltage004;

dynoEnergy004 = trapz(t004,dynoPower004)/3600;
originalEnergy004 = trapz(t004,simPower004)/3600;
correctedEnergy004 = trapz(t004,correctedPower004)/3600;

originalEnergyError004_pct = ...
    100*(originalEnergy004-dynoEnergy004) / ...
    abs(dynoEnergy004);

correctedEnergyError004_pct = ...
    100*(correctedEnergy004-dynoEnergy004) / ...
    abs(dynoEnergy004);

originalCurrentError004 = ...
    simCurrent004-dynoCurrent004;

correctedCurrentError004 = ...
    correctedCurrent004-dynoCurrent004;

originalCurrentBias004 = ...
    mean(originalCurrentError004);

correctedCurrentBias004 = ...
    mean(correctedCurrentError004);

originalCurrentMAE004 = ...
    mean(abs(originalCurrentError004));

correctedCurrentMAE004 = ...
    mean(abs(correctedCurrentError004));

originalCurrentRMSE004 = ...
    sqrt(mean(originalCurrentError004.^2));

correctedCurrentRMSE004 = ...
    sqrt(mean(correctedCurrentError004.^2));

dynoCurrentCentered004 = ...
    dynoCurrent004-mean(dynoCurrent004);

originalCurrentCentered004 = ...
    simCurrent004-mean(simCurrent004);

correctedCurrentCentered004 = ...
    correctedCurrent004-mean(correctedCurrent004);

originalCurrentCorrelation004 = ...
    sum(dynoCurrentCentered004.*originalCurrentCentered004) / ...
    sqrt(sum(dynoCurrentCentered004.^2) * ...
    sum(originalCurrentCentered004.^2));

correctedCurrentCorrelation004 = ...
    sum(dynoCurrentCentered004.*correctedCurrentCentered004) / ...
    sqrt(sum(dynoCurrentCentered004.^2) * ...
    sum(correctedCurrentCentered004.^2));

ValidationMetrics = table( ...
    "Run004", ...
    dynoEnergy004, ...
    originalEnergy004, ...
    correctedEnergy004, ...
    originalEnergyError004_pct, ...
    correctedEnergyError004_pct, ...
    originalCurrentBias004, ...
    correctedCurrentBias004, ...
    originalCurrentMAE004, ...
    correctedCurrentMAE004, ...
    originalCurrentRMSE004, ...
    correctedCurrentRMSE004, ...
    originalCurrentCorrelation004, ...
    correctedCurrentCorrelation004, ...
    'VariableNames',{ ...
    'Run', ...
    'DynoNetEnergy_kWh', ...
    'OriginalNetEnergy_kWh', ...
    'CorrectedNetEnergy_kWh', ...
    'OriginalEnergyError_pct', ...
    'CorrectedEnergyError_pct', ...
    'OriginalCurrentBias_A', ...
    'CorrectedCurrentBias_A', ...
    'OriginalCurrentMAE_A', ...
    'CorrectedCurrentMAE_A', ...
    'OriginalCurrentRMSE_A', ...
    'CorrectedCurrentRMSE_A', ...
    'OriginalCurrentCorrelation', ...
    'CorrectedCurrentCorrelation'});

fprintf('\n===== INDEPENDENT RUN 004 VALIDATION =====\n');
disp(ValidationMetrics);

%% 5. Create professor figure

allRunLabels = [
    runLabels
    "Run004"
    ];

allDynoEnergy = [
    DynoNetEnergy_kWh
    dynoEnergy004
    ];

allOriginalEnergy = [
    OriginalNetEnergy_kWh
    originalEnergy004
    ];

allCorrectedEnergy = [
    CorrectedNetEnergy_kWh
    correctedEnergy004
    ];

allOriginalCurrentMAE = [
    OriginalCurrentMAE_A
    originalCurrentMAE004
    ];

allCorrectedCurrentMAE = [
    CorrectedCurrentMAE_A
    correctedCurrentMAE004
    ];

figureHandle = figure( ...
    'Color','white', ...
    'Name','EV6 Powertrain Energy Calibration');

tiledlayout(2,2, ...
    'TileSpacing','compact', ...
    'Padding','compact');

nexttile;

bar(categorical(allRunLabels), ...
    [allDynoEnergy, ...
     allOriginalEnergy, ...
     allCorrectedEnergy]);

grid on;
ylabel('Net energy [kWh]');
title('Net battery energy');
legend( ...
    'EV6 dyno', ...
    'Original simulation', ...
    'Least-squares correction', ...
    'Location','best');

nexttile;

bar(categorical(allRunLabels), ...
    [allOriginalCurrentMAE, ...
     allCorrectedCurrentMAE]);

grid on;
ylabel('Current MAE [A]');
title('Battery-current error');
legend('Original','Corrected','Location','best');

nexttile;

plot(t004,dynoCurrent004,'k','LineWidth',1);
hold on;
plot(t004,simCurrent004, ...
    'Color',[0.2 0.45 0.95]);
plot(t004,correctedCurrent004, ...
    'Color',[0.1 0.65 0.15]);

grid on;
xlabel('Time [s]');
ylabel('Current [A]');
title('Run 004 battery current');
legend( ...
    'EV6 dyno', ...
    'Original simulation', ...
    'Corrected prediction', ...
    'Location','best');

nexttile;

dynoCumulativeEnergy004_Wh = ...
    cumtrapz(t004,dynoPower004)/3.6;

originalCumulativeEnergy004_Wh = ...
    cumtrapz(t004,simPower004)/3.6;

correctedCumulativeEnergy004_Wh = ...
    cumtrapz(t004,correctedPower004)/3.6;

plot(t004,dynoCumulativeEnergy004_Wh, ...
    'k','LineWidth',1.2);

hold on;

plot(t004,originalCumulativeEnergy004_Wh, ...
    'Color',[0.2 0.45 0.95]);

plot(t004,correctedCumulativeEnergy004_Wh, ...
    'Color',[0.1 0.65 0.15]);

grid on;
xlabel('Time [s]');
ylabel('Net energy [Wh]');
title('Run 004 cumulative energy');

legend( ...
    'EV6 dyno', ...
    'Original simulation', ...
    'Corrected prediction', ...
    'Location','best');

sgtitle( ...
    '2023 EV6 Wind AWD: Powertrain-Energy Calibration');

%% 6. Save results

PowertrainEnergyCalibration = struct;

PowertrainEnergyCalibration.TractionPowerScale = ...
    tractionPowerScale;

PowertrainEnergyCalibration.RegenPowerScale = ...
    regenPowerScale;

PowertrainEnergyCalibration.AuxiliaryPower_kW = ...
    auxiliaryPower_kW;

PowertrainEnergyCalibration.TrainingRuns = ...
    runLabels;

PowertrainEnergyCalibration.ValidationRun = ...
    "Run004";

PowertrainEnergyCalibration.Equation = ...
    "Pcorrected = kTraction*max(Psim,0) + " + ...
    "kRegen*min(Psim,0) + Paux";

PowertrainEnergyCalibration.Note = ...
    "Offline identification only. No Simulink parameters changed.";

parameterFile = fullfile( ...
    calibrationFolder, ...
    'EV6_Powertrain_Energy_Calibration_Parameters.mat');

trainingMetricsFile = fullfile( ...
    calibrationFolder, ...
    'EV6_Powertrain_Energy_Training_Metrics.csv');

validationMetricsFile = fullfile( ...
    calibrationFolder, ...
    'EV6_Powertrain_Energy_Run004_Validation.csv');

figureFile = fullfile( ...
    calibrationFolder, ...
    'EV6_Powertrain_Energy_TrainingValidation.png');

save(parameterFile, ...
    'PowertrainEnergyCalibration', ...
    'TrainingMetrics', ...
    'ValidationMetrics', ...
    '-v7.3');

writetable(TrainingMetrics,trainingMetricsFile);
writetable(ValidationMetrics,validationMetricsFile);

exportgraphics(figureHandle, ...
    figureFile,'Resolution',200);

fprintf('\n===== POWERTRAIN IDENTIFICATION COMPLETE =====\n');
fprintf('No Simulink parameters were changed.\n\n');
fprintf('Parameters:\n%s\n\n',parameterFile);
fprintf('Training metrics:\n%s\n\n',trainingMetricsFile);
fprintf('Run 004 validation:\n%s\n\n',validationMetricsFile);
fprintf('Figure:\n%s\n',figureFile);
fprintf('===============================================\n');