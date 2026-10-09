%% DIAGNOSE EV6 STATIONARY AUXILIARY BATTERY LOAD
% Uses completed Runs 001-004. No new Simulink simulation is performed.
%
% A stationary sample must satisfy:
%   dyno speed <= 0.10 m/s
%   |original simulated battery power| <= 1.0 kW
%   condition remains true for 1.0 s before and 0.5 s after the sample
%
% Positive missing power means the dyno vehicle consumed more battery
% power than the original Simulink model predicted.

clear
clc

%% Locations and settings

projectFolder = [ ...
    'C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\Vehicles_24a\Vehicles\' ...
    'VehicleProjects\Bolt_EV'];

dynoFolder = [ ...
    'C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\EV6_drivecycleData'];

resultsFolder = fullfile(projectFolder,'Battery_Calibration');

if ~isfolder(resultsFolder)
    mkdir(resultsFolder);
end

runLabels = ["Run001";"Run002";"Run003";"Run004"];
runNumbers = [1;2;3;4];

stationarySpeedThreshold_mps = 0.10;
stationarySimPowerThreshold_kW = 1.00;
comparisonStart_s = 5.0;
requiredPastDwell_s = 1.0;
requiredFutureDwell_s = 0.5;

%% Storage

numberOfRuns = numel(runNumbers);

stationarySamples = zeros(numberOfRuns,1);
stationaryDuration_s = zeros(numberOfRuns,1);
dynoPowerMean_kW = nan(numberOfRuns,1);
dynoPowerMedian_kW = nan(numberOfRuns,1);
originalPowerMean_kW = nan(numberOfRuns,1);
originalPowerMedian_kW = nan(numberOfRuns,1);
missingPowerMean_kW = nan(numberOfRuns,1);
missingPowerMedian_kW = nan(numberOfRuns,1);
missingPowerStd_kW = nan(numberOfRuns,1);
equivalentMissingCurrent_A = nan(numberOfRuns,1);
dynoCurrentMean_A = nan(numberOfRuns,1);
originalCurrentMean_A = nan(numberOfRuns,1);
meanDynoVoltage_V = nan(numberOfRuns,1);

stationaryData = cell(numberOfRuns,1);

fprintf('\n===== STATIONARY AUXILIARY-LOAD DIAGNOSTIC =====\n');
fprintf('Speed threshold = %.3f m/s\n', ...
    stationarySpeedThreshold_mps);
fprintf('Original simulation power threshold = %.3f kW\n', ...
    stationarySimPowerThreshold_kW);
fprintf('Required dwell = %.1f s before and %.1f s after\n', ...
    requiredPastDwell_s,requiredFutureDwell_s);
fprintf('=================================================\n');

%% Process Runs 001-004

for runIndex = 1:numberOfRuns

    runNumber = runNumbers(runIndex);
    runLabel = runLabels(runIndex);

    fprintf('\nProcessing %s...\n',runLabel);

    dynoFile = fullfile(dynoFolder,sprintf( ...
        'standards_test_08142026_%03d.mat',runNumber));

    simulationFile = fullfile(projectFolder,sprintf( ...
        'EV6_Run%03d_77p4kWh_Corrected_Full_Output.mat', ...
        runNumber));

    assert(isfile(dynoFile), ...
        'Dyno file was not found for %s.',runLabel);

    assert(isfile(simulationFile), ...
        'Original simulation output was not found for %s.',runLabel);

    loadedDyno = load(dynoFile);
    dynoRun = findDynoStructure(loadedDyno);

    [tSpeed_s,dynoSpeed_mps] = ...
        getDynoSignal(dynoRun,'VEH_vEgo');

    [tCurrent_s,dynoCurrent_A] = ...
        getDynoSignal(dynoRun,'VEH_batCurrent');

    [tVoltage_s,dynoVoltage_V] = ...
        getDynoSignal(dynoRun,'VEH_batVoltage');

    loadedSimulation = load(simulationFile);
    simulationOutput = findSimulationOutput(loadedSimulation,runLabel);

    [tSimPower_s,simPowerRaw] = ...
        getSimulationSignal(simulationOutput,'battery_power');

    [tSimCurrent_s,simCurrent_A] = ...
        getSimulationSignal(simulationOutput,'battery_current');

    simPower_kW = convertPowerToKilowatts(simPowerRaw);

    comparisonEnd_s = min([ ...
        tSpeed_s(end),tCurrent_s(end),tVoltage_s(end), ...
        tSimPower_s(end),tSimCurrent_s(end)]);

    comparisonMask = ...
        tCurrent_s >= comparisonStart_s & ...
        tCurrent_s <= comparisonEnd_s;

    tCompare_s = tCurrent_s(comparisonMask);
    dynoCurrentAligned_A = dynoCurrent_A(comparisonMask);

    dynoSpeedAligned_mps = interpClean( ...
        tSpeed_s,dynoSpeed_mps,tCompare_s);

    dynoVoltageAligned_V = interpClean( ...
        tVoltage_s,dynoVoltage_V,tCompare_s);

    simPowerAligned_kW = interpClean( ...
        tSimPower_s,simPower_kW,tCompare_s);

    simCurrentAligned_A = interpClean( ...
        tSimCurrent_s,simCurrent_A,tCompare_s);

    dynoPowerAligned_kW = ...
        dynoCurrentAligned_A .* dynoVoltageAligned_V / 1000;

    rawStationaryMask = ...
        abs(dynoSpeedAligned_mps) <= ...
            stationarySpeedThreshold_mps & ...
        abs(simPowerAligned_kW) <= ...
            stationarySimPowerThreshold_kW;

    medianStep_s = median(diff(tCompare_s));
    pastSamples = max(1,round(requiredPastDwell_s/medianStep_s));
    futureSamples = max(1,round(requiredFutureDwell_s/medianStep_s));

    stableStationaryMask = movmin( ...
        double(rawStationaryMask), ...
        [pastSamples futureSamples]) > 0.5;

    assert(nnz(stableStationaryMask) >= 2, ...
        'No usable stationary interval was found for %s.',runLabel);

    stationaryTime_s = tCompare_s(stableStationaryMask);
    stationaryDynoPower_kW = ...
        dynoPowerAligned_kW(stableStationaryMask);
    stationarySimPower_kW = ...
        simPowerAligned_kW(stableStationaryMask);
    stationaryDynoCurrent_A = ...
        dynoCurrentAligned_A(stableStationaryMask);
    stationarySimCurrent_A = ...
        simCurrentAligned_A(stableStationaryMask);
    stationaryVoltage_V = ...
        dynoVoltageAligned_V(stableStationaryMask);

    stationaryMissingPower_kW = ...
        stationaryDynoPower_kW-stationarySimPower_kW;

    stationarySamples(runIndex) = numel(stationaryTime_s);
    stationaryDuration_s(runIndex) = ...
        sum(diff(stationaryTime_s) <= 2*medianStep_s)*medianStep_s;

    dynoPowerMean_kW(runIndex) = mean(stationaryDynoPower_kW);
    dynoPowerMedian_kW(runIndex) = median(stationaryDynoPower_kW);
    originalPowerMean_kW(runIndex) = mean(stationarySimPower_kW);
    originalPowerMedian_kW(runIndex) = median(stationarySimPower_kW);
    missingPowerMean_kW(runIndex) = mean(stationaryMissingPower_kW);
    missingPowerMedian_kW(runIndex) = median(stationaryMissingPower_kW);
    missingPowerStd_kW(runIndex) = std(stationaryMissingPower_kW);
    meanDynoVoltage_V(runIndex) = mean(stationaryVoltage_V);

    equivalentMissingCurrent_A(runIndex) = ...
        1000*missingPowerMedian_kW(runIndex) / ...
        meanDynoVoltage_V(runIndex);

    dynoCurrentMean_A(runIndex) = mean(stationaryDynoCurrent_A);
    originalCurrentMean_A(runIndex) = mean(stationarySimCurrent_A);

    stationaryData{runIndex} = struct( ...
        'Time_s',stationaryTime_s, ...
        'DynoPower_kW',stationaryDynoPower_kW, ...
        'OriginalPower_kW',stationarySimPower_kW, ...
        'MissingPower_kW',stationaryMissingPower_kW, ...
        'DynoCurrent_A',stationaryDynoCurrent_A, ...
        'OriginalCurrent_A',stationarySimCurrent_A, ...
        'DynoVoltage_V',stationaryVoltage_V);

    fprintf('  Stationary duration = %.2f s\n', ...
        stationaryDuration_s(runIndex));
    fprintf('  Dyno median power = %.4f kW\n', ...
        dynoPowerMedian_kW(runIndex));
    fprintf('  Simulation median power = %.4f kW\n', ...
        originalPowerMedian_kW(runIndex));
    fprintf('  Median missing power = %.4f kW\n', ...
        missingPowerMedian_kW(runIndex));

end

%% Summary table

AuxiliaryLoadMetrics = table( ...
    runLabels,stationarySamples,stationaryDuration_s, ...
    dynoPowerMean_kW,dynoPowerMedian_kW, ...
    originalPowerMean_kW,originalPowerMedian_kW, ...
    missingPowerMean_kW,missingPowerMedian_kW, ...
    missingPowerStd_kW,equivalentMissingCurrent_A, ...
    dynoCurrentMean_A,originalCurrentMean_A,meanDynoVoltage_V, ...
    'VariableNames',{ ...
    'Run','StationarySamples','StationaryDuration_s', ...
    'DynoPowerMean_kW','DynoPowerMedian_kW', ...
    'OriginalPowerMean_kW','OriginalPowerMedian_kW', ...
    'MissingPowerMean_kW','MissingPowerMedian_kW', ...
    'MissingPowerStd_kW','EquivalentMissingCurrent_A', ...
    'DynoCurrentMean_A','OriginalCurrentMean_A', ...
    'MeanDynoVoltage_V'});

fprintf('\n===== STATIONARY AUXILIARY-LOAD RESULTS =====\n');
disp(AuxiliaryLoadMetrics);

%% Training-only auxiliary-load candidate

trainingRunMask = ismember(runLabels,["Run001","Run002","Run003"]);

candidateAuxiliaryPower_kW = max(0,median( ...
    missingPowerMedian_kW(trainingRunMask),'omitnan'));

candidateAuxiliaryCurrent_A = ...
    1000*candidateAuxiliaryPower_kW / ...
    mean(meanDynoVoltage_V(trainingRunMask),'omitnan');

trainingSpread_kW = ...
    max(missingPowerMedian_kW(trainingRunMask)) - ...
    min(missingPowerMedian_kW(trainingRunMask));

fprintf('\n===== TRAINING-ONLY AUXILIARY CANDIDATE =====\n');
fprintf('Runs used = Run001, Run002, Run003\n');
fprintf('Candidate auxiliary power = %.4f kW\n', ...
    candidateAuxiliaryPower_kW);
fprintf('Equivalent auxiliary current = %.4f A\n', ...
    candidateAuxiliaryCurrent_A);
fprintf('Across-run median-power spread = %.4f kW\n', ...
    trainingSpread_kW);

if trainingSpread_kW <= 0.25
    fprintf(['Interpretation: stationary load is reasonably consistent; ' ...
        'a fixed auxiliary-power parameter is plausible.\n']);
else
    fprintf(['Interpretation: stationary load varies across runs; ' ...
        'treat a fixed auxiliary load cautiously.\n']);
end

fprintf('No Simulink parameters were changed.\n');
fprintf('=============================================\n');

%% Optional: check how much corrected Run 004 captures

correctedRun004File = fullfile(projectFolder, ...
    'EV6_Run004_77p4kWh_PowerCorrected_Full_Output.mat');

CorrectedRun004StationaryMetrics = table;

if isfile(correctedRun004File)

    loadedCorrected = load(correctedRun004File);
    correctedOutput = findSimulationOutput( ...
        loadedCorrected,"corrected Run004");

    [tCorrectedPower_s,correctedPowerRaw] = ...
        getSimulationSignal(correctedOutput,'battery_power');

    [tCorrectedCurrent_s,correctedCurrent_A] = ...
        getSimulationSignal(correctedOutput,'battery_current');

    correctedPower_kW = convertPowerToKilowatts(correctedPowerRaw);

    run004Data = stationaryData{4};
    stationaryTime004_s = run004Data.Time_s;

    correctedPowerStationary_kW = interpClean( ...
        tCorrectedPower_s,correctedPower_kW,stationaryTime004_s);

    correctedCurrentStationary_A = interpClean( ...
        tCorrectedCurrent_s,correctedCurrent_A,stationaryTime004_s);

    correctedPowerError_kW = ...
        correctedPowerStationary_kW-run004Data.DynoPower_kW;

    originalPowerError_kW = ...
        run004Data.OriginalPower_kW-run004Data.DynoPower_kW;

    CorrectedRun004StationaryMetrics = table( ...
        ["Original 77.4-kWh";"Power-corrected 77.4-kWh"], ...
        [mean(run004Data.OriginalPower_kW); ...
         mean(correctedPowerStationary_kW)], ...
        [mean(originalPowerError_kW); ...
         mean(correctedPowerError_kW)], ...
        [mean(abs(originalPowerError_kW)); ...
         mean(abs(correctedPowerError_kW))], ...
        [mean(run004Data.OriginalCurrent_A); ...
         mean(correctedCurrentStationary_A)], ...
        'VariableNames',{ ...
        'Model','MeanStationaryPower_kW','MeanPowerError_kW', ...
        'PowerMAE_kW','MeanStationaryCurrent_A'});

    fprintf('\n===== CORRECTED RUN 004 STATIONARY CHECK =====\n');
    disp(CorrectedRun004StationaryMetrics);

end

%% Figure

figureHandle = figure( ...
    'Color','w', ...
    'Name','EV6 Stationary Auxiliary-Load Diagnostic', ...
    'Position',[80 80 1500 800]);

plotLayout = tiledlayout(2,2, ...
    'TileSpacing','compact','Padding','compact');

title(plotLayout, ...
    'EV6 Stationary Auxiliary Battery-Load Diagnostic', ...
    'FontWeight','bold');

nexttile;
bar(categorical(runLabels), ...
    [dynoPowerMedian_kW originalPowerMedian_kW]);
grid on;
ylabel('Median stationary power [kW]');
title('Dyno versus original simulation');
legend('EV6 dyno','Original model','Location','best');

nexttile;
bar(categorical(runLabels), ...
    [missingPowerMean_kW missingPowerMedian_kW]);
hold on;
yline(candidateAuxiliaryPower_kW,'k--','Training candidate');
grid on;
ylabel('Missing battery power [kW]');
title('Estimated unmodeled stationary load');
legend('Mean','Median','Location','best');

nexttile;
bar(categorical(runLabels),equivalentMissingCurrent_A);
grid on;
ylabel('Equivalent missing current [A]');
title('Auxiliary-current equivalent');

nexttile;
run004Data = stationaryData{4};
histogram(run004Data.MissingPower_kW,80, ...
    'FaceColor',[0.20 0.55 0.75], ...
    'EdgeColor','none');
hold on;
xline(missingPowerMedian_kW(4),'r--','Run 004 median');
xline(candidateAuxiliaryPower_kW,'k--','Training candidate');
grid on;
xlabel('Dyno power - original simulated power [kW]');
ylabel('Samples');
title('Run 004 stationary missing-power distribution');

%% Save outputs

metricsFile = fullfile(resultsFolder, ...
    'EV6_Stationary_Auxiliary_Load_Metrics.csv');

correctedMetricsFile = fullfile(resultsFolder, ...
    'EV6_Run004_Corrected_Stationary_Load_Metrics.csv');

figureFile = fullfile(resultsFolder, ...
    'EV6_Stationary_Auxiliary_Load_Diagnostic.png');

matFile = fullfile(resultsFolder, ...
    'EV6_Stationary_Auxiliary_Load_Diagnostic.mat');

writetable(AuxiliaryLoadMetrics,metricsFile);

if ~isempty(CorrectedRun004StationaryMetrics)
    writetable(CorrectedRun004StationaryMetrics,correctedMetricsFile);
end

exportgraphics(figureHandle,figureFile,'Resolution',200);

save(matFile, ...
    'AuxiliaryLoadMetrics', ...
    'CorrectedRun004StationaryMetrics', ...
    'candidateAuxiliaryPower_kW', ...
    'candidateAuxiliaryCurrent_A', ...
    'trainingSpread_kW', ...
    'stationarySpeedThreshold_mps', ...
    'stationarySimPowerThreshold_kW', ...
    'stationaryData','-v7.3');

fprintf('\n===== AUXILIARY-LOAD DIAGNOSTIC COMPLETE =====\n');
fprintf('Metrics:\n%s\n\n',metricsFile);
if ~isempty(CorrectedRun004StationaryMetrics)
    fprintf('Corrected Run 004 metrics:\n%s\n\n', ...
        correctedMetricsFile);
end
fprintf('Figure:\n%s\n\n',figureFile);
fprintf('MAT results:\n%s\n',matFile);
fprintf('No Simulink parameters were changed.\n');
fprintf('==============================================\n');

%% Local functions

function dynoStructure = findDynoStructure(loadedData)

fieldNames = fieldnames(loadedData);

for k = 1:numel(fieldNames)
    candidate = loadedData.(fieldNames{k});

    if isstruct(candidate) && ...
            isfield(candidate,'X') && ...
            isfield(candidate,'Y')
        dynoStructure = candidate;
        return;
    end
end

error('No structure containing X and Y was found in the dyno file.');

end

function [time_s,data] = getDynoSignal(dynoStructure,requestedName)

signalNames = erase(string({dynoStructure.Y.Name}),["<",">"]);
signalIndex = find(strcmpi(signalNames,requestedName),1,'first');

assert(~isempty(signalIndex), ...
    'Dyno signal %s was not found.',requestedName);

timeIndex = dynoStructure.Y(signalIndex).XIndex;
time_s = double(dynoStructure.X(timeIndex).Data(:));
data = double(dynoStructure.Y(signalIndex).Data(:));

valid = isfinite(time_s) & isfinite(data);
time_s = time_s(valid);
data = data(valid);

[time_s,uniqueIndices] = unique(time_s,'stable');
data = data(uniqueIndices);

end

function simulationOutput = ...
    findSimulationOutput(loadedData,fileDescription)

fieldNames = fieldnames(loadedData);

for k = 1:numel(fieldNames)
    candidate = loadedData.(fieldNames{k});

    if isa(candidate,'Simulink.SimulationOutput')
        simulationOutput = candidate;
        fprintf('  SimulationOutput = %s\n',fieldNames{k});
        return;
    end
end

error('No SimulationOutput was found in %s.',fileDescription);

end

function [time_s,data] = ...
    getSimulationSignal(simulationOutput,signalName)

availableNames = string(simulationOutput.who);

assert(any(availableNames == string(signalName)), ...
    'Signal %s was not found in the SimulationOutput.',signalName);

signalValue = simulationOutput.get(signalName);

if isa(signalValue,'Simulink.SimulationData.Signal')
    signalValue = signalValue.Values;
end

if isa(signalValue,'timeseries')
    time_s = double(signalValue.Time(:));
    data = double(squeeze(signalValue.Data));
    data = data(:);

elseif isstruct(signalValue) && ...
        isfield(signalValue,'time') && ...
        isfield(signalValue,'signals')
    time_s = double(signalValue.time(:));
    data = double(signalValue.signals.values(:));

elseif isnumeric(signalValue)
    data = double(signalValue(:));
    assert(any(availableNames == "tout"), ...
        'tout is required for numeric signal %s.',signalName);
    time_s = double(simulationOutput.get('tout'));
    time_s = time_s(:);

else
    error('Unsupported data type for signal %s.',signalName);
end

assert(numel(time_s) == numel(data), ...
    'Time and data sizes differ for signal %s.',signalName);

valid = isfinite(time_s) & isfinite(data);
time_s = time_s(valid);
data = data(valid);

[time_s,uniqueIndices] = unique(time_s,'stable');
data = data(uniqueIndices);

end

function power_kW = convertPowerToKilowatts(powerRaw)

if max(abs(powerRaw),[],'omitnan') > 500
    power_kW = powerRaw/1000;
else
    power_kW = powerRaw;
end

end

function interpolatedData = interpClean( ...
    sourceTime_s,sourceData,targetTime_s)

sourceTime_s = double(sourceTime_s(:));
sourceData = double(sourceData(:));
targetTime_s = double(targetTime_s(:));

valid = isfinite(sourceTime_s) & isfinite(sourceData);
sourceTime_s = sourceTime_s(valid);
sourceData = sourceData(valid);

[sourceTime_s,uniqueIndices] = unique(sourceTime_s,'stable');
sourceData = sourceData(uniqueIndices);

assert(numel(sourceTime_s) >= 2, ...
    'At least two samples are required for interpolation.');

interpolatedData = interp1( ...
    sourceTime_s,sourceData,targetTime_s,'linear','extrap');
interpolatedData = interpolatedData(:);

end
