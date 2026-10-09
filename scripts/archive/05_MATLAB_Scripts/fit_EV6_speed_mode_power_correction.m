%% FIT AND VALIDATE AN EV6 SPEED/MODE POWER CORRECTION
% Training: Runs 001-003
% Independent validation: Run 004
%
% Candidate equation:
%   corrected battery power = simulated battery power
%                           + correction(speed, operating mode)
%
% Operating mode is determined only from simulated battery power, so the
% method does not use dyno data during application. This script performs an
% offline diagnostic only. It does not change the Simulink model.

clear;
clc;

projectRoot = ['C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\Vehicles_24a\Vehicles\' ...
    'VehicleProjects\Bolt_EV'];

dynoRoot = ['C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\EV6_drivecycleData'];

outputFolder = fullfile(projectRoot,'Battery_Calibration');
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

runNumbers = (1:4).';
runLabels = "Run" + compose('%03d',runNumbers);

dynoFiles = strings(4,1);
simFiles = strings(4,1);

for k = 1:4
    runCode = compose('%03d',runNumbers(k));
    dynoFiles(k) = fullfile(dynoRoot, ...
        "standards_test_08142026_" + runCode + ".mat");
    simFiles(k) = fullfile(projectRoot, ...
        "EV6_Run" + runCode + ...
        "_77p4kWh_Corrected_Full_Output.mat");

    assert(isfile(dynoFiles(k)), ...
        'Dyno file was not found:\n%s',dynoFiles(k));
    assert(isfile(simFiles(k)), ...
        'Simulation output was not found:\n%s',simFiles(k));
end

comparisonStart_s = 5;
modeThreshold_kW = 0.5;
minimumTrainingSamples = 5000;
correctionScale = 0.50;

speedEdges_mps = [0 2.5 5 7.5 10 12.5 15 20 25 30];
speedCenters_mps = 0.5*(speedEdges_mps(1:end-1) + ...
    speedEdges_mps(2:end));

modeNames = ["Traction";"Regeneration";"Low-power/idle"];
numberOfModes = numel(modeNames);
numberOfBins = numel(speedCenters_mps);

correctionSum = zeros(numberOfModes,numberOfBins);
correctionCount = zeros(numberOfModes,numberOfBins);

fprintf('\n===== FITTING SPEED/MODE CORRECTION =====\n');
fprintf('Training runs: Run001, Run002, Run003\n');
fprintf('Development-check run: Run004\n');
fprintf('Correction-map scale: %.2f\n',correctionScale);

%% 1. Fit the map with Runs 001-003 only
for runIndex = 1:3
    fprintf('\nLoading %s training data...\n',runLabels(runIndex));

    data = loadAlignedRun(dynoFiles(runIndex), ...
        simFiles(runIndex),comparisonStart_s);

    requiredCorrection_kW = data.dynoPower_kW - data.simPower_kW;
    speedBin = discretize(data.speed_mps,speedEdges_mps);

    modeMasks = getModeMasks(data.simPower_kW,modeThreshold_kW);

    for modeIndex = 1:numberOfModes
        for binIndex = 1:numberOfBins
            selected = modeMasks{modeIndex} & speedBin == binIndex;
            correctionSum(modeIndex,binIndex) = ...
                correctionSum(modeIndex,binIndex) + ...
                sum(requiredCorrection_kW(selected));
            correctionCount(modeIndex,binIndex) = ...
                correctionCount(modeIndex,binIndex) + nnz(selected);
        end
    end

    fprintf('  Samples used = %d\n',numel(data.time_s));
end

rawCorrectionMap_kW = correctionSum./correctionCount;
rawCorrectionMap_kW(correctionCount < minimumTrainingSamples) = NaN;

correctionMap_kW = zeros(size(rawCorrectionMap_kW));

for modeIndex = 1:numberOfModes
    row = rawCorrectionMap_kW(modeIndex,:);
    row = fillMapRow(row,speedCenters_mps);
    row = movmean(row,3,'Endpoints','shrink');

    if modeIndex == 1
        % Keep the traction adjustment modest and physically stable.
        row = min(max(row,-2),2);
    elseif modeIndex == 2
        % Regen has larger residuals, but prevent extreme extrapolation.
        row = min(max(row,-4),4);
    else
        % Low-power correction represents a possible missing auxiliary load.
        % It cannot remove power or exceed 1 kW in this candidate.
        row = min(max(row,0),1);
    end

    correctionMap_kW(modeIndex,:) = row;
end

% Apply conservative half-strength correction
correctionMap_kW = correctionScale*correctionMap_kW;

CorrectionMapTable = table(speedCenters_mps.', ...
    correctionCount(1,:).',rawCorrectionMap_kW(1,:).', ...
    correctionMap_kW(1,:).', ...
    correctionCount(2,:).',rawCorrectionMap_kW(2,:).', ...
    correctionMap_kW(2,:).', ...
    correctionCount(3,:).',rawCorrectionMap_kW(3,:).', ...
    correctionMap_kW(3,:).', ...
    'VariableNames',{ ...
    'Speed_mps', ...
    'TractionSamples','TractionRawCorrection_kW', ...
    'TractionCandidateCorrection_kW', ...
    'RegenSamples','RegenRawCorrection_kW', ...
    'RegenCandidateCorrection_kW', ...
    'LowPowerSamples','LowPowerRawCorrection_kW', ...
    'LowPowerCandidateCorrection_kW'});

fprintf('\n===== CANDIDATE CORRECTION MAP =====\n');
disp(CorrectionMapTable);

%% 2. Evaluate training runs and independent Run 004 validation
resultRows = cell(4,21);
run004Data = struct;

for runIndex = 1:4
    fprintf('\nEvaluating %s...\n',runLabels(runIndex));

    data = loadAlignedRun(dynoFiles(runIndex), ...
        simFiles(runIndex),comparisonStart_s);

    appliedCorrection_kW = applyCorrectionMap( ...
        data.speed_mps,data.simPower_kW, ...
        speedCenters_mps,correctionMap_kW,modeThreshold_kW);

    correctedPower_kW = data.simPower_kW + appliedCorrection_kW;

    simulatedVoltageEstimate_V = estimateSimVoltage( ...
        data.time_s,data.simPower_kW,data.simCurrent_A);

    correctedCurrent_A = data.simCurrent_A + ...
        1000*appliedCorrection_kW./simulatedVoltageEstimate_V;

    originalPowerMetrics = calculateMetrics( ...
        data.simPower_kW,data.dynoPower_kW);
    correctedPowerMetrics = calculateMetrics( ...
        correctedPower_kW,data.dynoPower_kW);
    originalCurrentMetrics = calculateMetrics( ...
        data.simCurrent_A,data.dynoCurrent_A);
    correctedCurrentMetrics = calculateMetrics( ...
        correctedCurrent_A,data.dynoCurrent_A);

    dynoEnergy_kWh = trapz(data.time_s,data.dynoPower_kW)/3600;
    originalEnergy_kWh = trapz(data.time_s,data.simPower_kW)/3600;
    correctedEnergy_kWh = trapz(data.time_s,correctedPower_kW)/3600;

    originalEnergyError_pct = 100* ...
        (originalEnergy_kWh-dynoEnergy_kWh)/abs(dynoEnergy_kWh);
    correctedEnergyError_pct = 100* ...
        (correctedEnergy_kWh-dynoEnergy_kWh)/abs(dynoEnergy_kWh);

    role = "Training";
    if runIndex == 4
        role = "Validation";
    end

    resultRows(runIndex,:) = { ...
        runLabels(runIndex),role,numel(data.time_s), ...
        dynoEnergy_kWh,originalEnergy_kWh,correctedEnergy_kWh, ...
        originalEnergyError_pct,correctedEnergyError_pct, ...
        originalPowerMetrics.Bias,correctedPowerMetrics.Bias, ...
        originalPowerMetrics.MAE,correctedPowerMetrics.MAE, ...
        originalPowerMetrics.RMSE,correctedPowerMetrics.RMSE, ...
        originalCurrentMetrics.Bias,correctedCurrentMetrics.Bias, ...
        originalCurrentMetrics.MAE,correctedCurrentMetrics.MAE, ...
        originalCurrentMetrics.RMSE,correctedCurrentMetrics.RMSE, ...
        correctedCurrentMetrics.Correlation};

    if runIndex == 4
        run004Data = data;
        run004Data.correctedPower_kW = correctedPower_kW;
        run004Data.correctedCurrent_A = correctedCurrent_A;
        run004Data.appliedCorrection_kW = appliedCorrection_kW;
    end
end

ValidationMetrics = cell2table(resultRows, ...
    'VariableNames',{ ...
    'Run','Role','Samples', ...
    'DynoEnergy_kWh','OriginalEnergy_kWh','CorrectedEnergy_kWh', ...
    'OriginalEnergyError_pct','CorrectedEnergyError_pct', ...
    'OriginalPowerBias_kW','CorrectedPowerBias_kW', ...
    'OriginalPowerMAE_kW','CorrectedPowerMAE_kW', ...
    'OriginalPowerRMSE_kW','CorrectedPowerRMSE_kW', ...
    'OriginalCurrentBias_A','CorrectedCurrentBias_A', ...
    'OriginalCurrentMAE_A','CorrectedCurrentMAE_A', ...
    'OriginalCurrentRMSE_A','CorrectedCurrentRMSE_A', ...
    'CorrectedCurrentCorrelation'});

fprintf('\n===== SPEED/MODE CORRECTION RESULTS =====\n');
disp(ValidationMetrics);

run004Row = ValidationMetrics(ValidationMetrics.Run == "Run004",:);

energyImprovement_pctPoints = abs(run004Row.OriginalEnergyError_pct) - ...
    abs(run004Row.CorrectedEnergyError_pct);
currentMAEChange_A = run004Row.CorrectedCurrentMAE_A - ...
    run004Row.OriginalCurrentMAE_A;

fprintf('\n===== RUN 004 ACCEPTANCE CHECK =====\n');
fprintf('Absolute energy-error improvement = %.3f percentage points\n', ...
    energyImprovement_pctPoints);
fprintf('Current-MAE change = %+.4f A\n',currentMAEChange_A);
fprintf('Corrected current correlation = %.5f\n', ...
    run004Row.CorrectedCurrentCorrelation);

candidatePasses = abs(run004Row.CorrectedEnergyError_pct) <= 10 && ...
    currentMAEChange_A <= 0 && ...
    run004Row.CorrectedCurrentCorrelation >= 0.95;

if candidatePasses
    fprintf(['RESULT: PASS as an offline candidate. Validate a 60-second ' ...
        'Simulink implementation next.\n']);
else
    fprintf(['RESULT: DO NOT IMPLEMENT. The candidate did not improve ' ...
        'energy while preserving current accuracy.\n']);
end
fprintf('====================================\n');

%% 3. Plot fitted maps and independent Run 004 validation
figure('Color','w','Name','EV6 speed-mode correction maps');
tiledlayout(3,1,'TileSpacing','compact','Padding','compact');

for modeIndex = 1:numberOfModes
    nexttile;
    plot(speedCenters_mps,rawCorrectionMap_kW(modeIndex,:), ...
        'o--','LineWidth',1,'DisplayName','Raw training mean');
    hold on;
    plot(speedCenters_mps,correctionMap_kW(modeIndex,:), ...
        's-','LineWidth',1.5,'DisplayName','Bounded candidate');
    yline(0,'k:','HandleVisibility','off');
    grid on;
    ylabel('Correction [kW]');
    title(modeNames(modeIndex));
    if modeIndex == 1
        legend('Location','best');
    end
    if modeIndex == numberOfModes
        xlabel('Vehicle speed [m/s]');
    end
end

sgtitle('EV6 speed/mode battery-power correction: Runs 001-003');

mapFigureFile = fullfile(outputFolder, ...
    'EV6_SpeedMode_PowerCorrection_Map.png');
exportgraphics(gcf,mapFigureFile,'Resolution',200);

figure('Color','w','Name','EV6 Run 004 correction validation');
tiledlayout(4,1,'TileSpacing','compact','Padding','compact');

nexttile;
plot(run004Data.time_s,run004Data.dynoPower_kW,'k', ...
    'DisplayName','EV6 dyno');
hold on;
plot(run004Data.time_s,run004Data.simPower_kW,'b', ...
    'DisplayName','Original model');
plot(run004Data.time_s,run004Data.correctedPower_kW,'r', ...
    'DisplayName','Speed/mode corrected');
grid on;
ylabel('Power [kW]');
title('Independent Run 004 battery power');
legend('Location','best');

nexttile;
plot(run004Data.time_s,run004Data.dynoCurrent_A,'k', ...
    'DisplayName','EV6 dyno');
hold on;
plot(run004Data.time_s,run004Data.simCurrent_A,'b', ...
    'DisplayName','Original model');
plot(run004Data.time_s,run004Data.correctedCurrent_A,'r', ...
    'DisplayName','Speed/mode corrected');
grid on;
ylabel('Current [A]');
title('Independent Run 004 battery current');

nexttile;
dynoCumulative_Wh = cumtrapz( ...
    run004Data.time_s,run004Data.dynoPower_kW)/3.6;
simCumulative_Wh = cumtrapz( ...
    run004Data.time_s,run004Data.simPower_kW)/3.6;
correctedCumulative_Wh = cumtrapz( ...
    run004Data.time_s,run004Data.correctedPower_kW)/3.6;
plot(run004Data.time_s,dynoCumulative_Wh,'k', ...
    'DisplayName','EV6 dyno');
hold on;
plot(run004Data.time_s,simCumulative_Wh,'b', ...
    'DisplayName','Original model');
plot(run004Data.time_s,correctedCumulative_Wh,'r', ...
    'DisplayName','Speed/mode corrected');
grid on;
ylabel('Energy [Wh]');
title('Cumulative net battery energy');

nexttile;
plot(run004Data.time_s,run004Data.appliedCorrection_kW, ...
    'Color',[0.45 0 0.75]);
yline(0,'k:');
grid on;
xlabel('Time [s]');
ylabel('Correction [kW]');
title('Applied power correction');

sgtitle('EV6 Run 004: independent speed/mode correction validation');

validationFigureFile = fullfile(outputFolder, ...
    'EV6_Run004_SpeedMode_PowerCorrection_Validation.png');
mapCsvFile = fullfile(outputFolder, ...
    'EV6_SpeedMode_PowerCorrection_Map.csv');
metricsCsvFile = fullfile(outputFolder, ...
    'EV6_SpeedMode_PowerCorrection_Metrics.csv');
resultsMatFile = fullfile(outputFolder, ...
    'EV6_SpeedMode_PowerCorrection_Results.mat');

exportgraphics(gcf,validationFigureFile,'Resolution',200);
writetable(CorrectionMapTable,mapCsvFile);
writetable(ValidationMetrics,metricsCsvFile);
save(resultsMatFile,'CorrectionMapTable','ValidationMetrics', ...
    'speedEdges_mps','speedCenters_mps','rawCorrectionMap_kW', ...
    'correctionMap_kW','modeThreshold_kW','candidatePasses');

fprintf('\n===== FILES SAVED =====\n');
fprintf('Map figure:\n%s\n\n',mapFigureFile);
fprintf('Run 004 figure:\n%s\n\n',validationFigureFile);
fprintf('Map CSV:\n%s\n\n',mapCsvFile);
fprintf('Metrics CSV:\n%s\n\n',metricsCsvFile);
fprintf('MAT results:\n%s\n',resultsMatFile);
fprintf('No Simulink parameters were changed.\n');
fprintf('=======================\n');

%% Local functions
function data = loadAlignedRun(dynoFile,simFile,comparisonStart_s)
    loadedDyno = load(dynoFile);
    dynoNames = fieldnames(loadedDyno);
    dynoStruct = [];

    for fieldIndex = 1:numel(dynoNames)
        candidate = loadedDyno.(dynoNames{fieldIndex});
        if isstruct(candidate) && ...
                isfield(candidate,'X') && isfield(candidate,'Y')
            dynoStruct = candidate;
            break;
        end
    end

    assert(~isempty(dynoStruct), ...
        'No dyno structure with X and Y fields was found in %s.',dynoFile);

    [tDyno_s,dynoCurrent_A] = getDynoChannel( ...
        dynoStruct,"VEH_batCurrent");
    [tVoltage_s,dynoVoltage_V] = getDynoChannel( ...
        dynoStruct,"VEH_batVoltage");
    [tSpeed_s,dynoSpeed_mps] = getDynoChannel( ...
        dynoStruct,"VEH_vEgo");

    dynoVoltage_V = alignSignal( ...
        tVoltage_s,dynoVoltage_V,tDyno_s);
    dynoSpeed_mps = alignSignal( ...
        tSpeed_s,dynoSpeed_mps,tDyno_s);
    dynoSpeed_mps = max(dynoSpeed_mps,0);
    dynoPower_kW = dynoCurrent_A.*dynoVoltage_V/1000;

    loadedSim = load(simFile);
    simulationOutput = findSimulationOutput(loadedSim);

    [tSimPower_s,simPowerRaw] = getOutputTimeseries( ...
        simulationOutput,'battery_power');
    [tSimCurrent_s,simCurrent_A] = getOutputTimeseries( ...
        simulationOutput,'battery_current');

    simPower_kW = double(simPowerRaw(:));
    finitePower = abs(simPower_kW(isfinite(simPower_kW)));
    assert(~isempty(finitePower), ...
        'The simulated battery-power signal contains no finite values.');

    if max(finitePower) > 1000
        simPower_kW = simPower_kW/1000;
    end

    simPower_kW = alignSignal(tSimPower_s,simPower_kW,tDyno_s);
    simCurrent_A = alignSignal(tSimCurrent_s,simCurrent_A,tDyno_s);

    valid = tDyno_s >= comparisonStart_s & ...
        isfinite(dynoCurrent_A) & isfinite(dynoVoltage_V) & ...
        isfinite(dynoPower_kW) & isfinite(dynoSpeed_mps) & ...
        isfinite(simPower_kW) & isfinite(simCurrent_A);

    data.time_s = tDyno_s(valid);
    data.speed_mps = dynoSpeed_mps(valid);
    data.dynoCurrent_A = dynoCurrent_A(valid);
    data.dynoVoltage_V = dynoVoltage_V(valid);
    data.dynoPower_kW = dynoPower_kW(valid);
    data.simCurrent_A = simCurrent_A(valid);
    data.simPower_kW = simPower_kW(valid);
end

function modeMasks = getModeMasks(simPower_kW,threshold_kW)
    modeMasks = { ...
        simPower_kW > threshold_kW, ...
        simPower_kW < -threshold_kW, ...
        abs(simPower_kW) <= threshold_kW};
end

function row = fillMapRow(row,speedCenters)
    valid = isfinite(row);
    assert(any(valid),'No populated bins were available for this mode.');

    if nnz(valid) == 1
        row(:) = row(valid);
        return;
    end

    firstValid = find(valid,1,'first');
    lastValid = find(valid,1,'last');
    row(1:firstValid-1) = row(firstValid);
    row(lastValid+1:end) = row(lastValid);

    missingInside = ~isfinite(row);
    row(missingInside) = interp1( ...
        speedCenters(valid),row(valid), ...
        speedCenters(missingInside),'linear');
end

function correction_kW = applyCorrectionMap(speed_mps,simPower_kW, ...
        speedCenters,correctionMap,threshold_kW)
    correction_kW = zeros(size(simPower_kW));
    modeMasks = getModeMasks(simPower_kW,threshold_kW);

    clippedSpeed = min(max(speed_mps,speedCenters(1)),speedCenters(end));

    for modeIndex = 1:3
        selected = modeMasks{modeIndex};
        correction_kW(selected) = interp1( ...
            speedCenters,correctionMap(modeIndex,:), ...
            clippedSpeed(selected),'linear');
    end
end

function voltage_V = estimateSimVoltage(time_s,power_kW,current_A)
    voltage_V = 1000*power_kW./current_A;
    validVoltage = abs(current_A) >= 0.2 & ...
        isfinite(voltage_V) & voltage_V >= 650 & voltage_V <= 800;

    if nnz(validVoltage) >= 2
        voltage_V = interp1(time_s(validVoltage), ...
            voltage_V(validVoltage),time_s,'linear',NaN);
        medianVoltage = median(voltage_V(isfinite(voltage_V)));
        voltage_V(~isfinite(voltage_V)) = medianVoltage;
    else
        voltage_V(:) = 727;
    end
end

function metrics = calculateMetrics(simulated,measured)
    error = simulated - measured;
    metrics.Bias = mean(error);
    metrics.MAE = mean(abs(error));
    metrics.RMSE = sqrt(mean(error.^2));
    metrics.MaxAbsError = max(abs(error));

    simulatedCentered = simulated - mean(simulated);
    measuredCentered = measured - mean(measured);
    denominator = sqrt(sum(simulatedCentered.^2)* ...
        sum(measuredCentered.^2));

    if denominator > 0
        metrics.Correlation = sum( ...
            simulatedCentered.*measuredCentered)/denominator;
    else
        metrics.Correlation = NaN;
    end
end

function [time_s,data] = getDynoChannel(dynoStruct,targetName)
    channelNames = erase(string({dynoStruct.Y.Name}),["<",">"]);
    channelIndex = find(channelNames == targetName,1,'first');
    assert(~isempty(channelIndex), ...
        'Dyno channel %s was not found.',targetName);

    timeIndex = dynoStruct.Y(channelIndex).XIndex;
    time_s = double(dynoStruct.X(timeIndex).Data(:));
    data = double(dynoStruct.Y(channelIndex).Data(:));

    valid = isfinite(time_s) & isfinite(data);
    time_s = time_s(valid);
    data = data(valid);
end

function alignedData = alignSignal(sourceTime,sourceData,targetTime)
    sourceTime = double(sourceTime(:));
    sourceData = double(sourceData(:));
    targetTime = double(targetTime(:));

    valid = isfinite(sourceTime) & isfinite(sourceData);
    sourceTime = sourceTime(valid);
    sourceData = sourceData(valid);

    [sourceTime,uniqueIndex] = unique(sourceTime,'stable');
    sourceData = sourceData(uniqueIndex);

    alignedData = interp1(sourceTime,sourceData,targetTime, ...
        'linear',NaN);
end

function simulationOutput = findSimulationOutput(loadedSim)
    variableNames = fieldnames(loadedSim);
    simulationOutput = [];

    for variableIndex = 1:numel(variableNames)
        candidate = loadedSim.(variableNames{variableIndex});
        if isa(candidate,'Simulink.SimulationOutput')
            simulationOutput = candidate;
            break;
        end
    end

    assert(~isempty(simulationOutput), ...
        ['No Simulink.SimulationOutput object was found in the saved ' ...
        'simulation MAT-file.']);
end

function [time_s,data] = getOutputTimeseries(simulationOutput,variableName)
    try
        value = simulationOutput.get(variableName);
    catch
        value = simulationOutput.(variableName);
    end

    if isa(value,'Simulink.SimulationData.Signal')
        value = value.Values;
    end

    assert(isa(value,'timeseries'), ...
        'Simulation output %s is not a timeseries.',variableName);

    time_s = double(value.Time(:));
    data = double(value.Data(:));

    assert(numel(time_s) == numel(data), ...
        'Time and data lengths do not match for %s.',variableName);
end
