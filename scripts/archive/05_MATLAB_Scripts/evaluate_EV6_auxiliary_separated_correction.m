%% EVALUATE EXPLICIT AUXILIARY LOAD + RESIDUAL POWERTRAIN CORRECTION
% Offline evaluation only. No Simulink parameters are changed.
%
% Strategies compared:
%   1. Original 77.4-kWh model
%   2. Existing speed/mode correction map
%   3. Fixed auxiliary power only
%   4. Fixed auxiliary power + residual traction/regen map
%
% Runs 001-003 are training runs. Run 004 is a development check.

clear
clc

%% Locations

projectFolder = [ ...
    'C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\Vehicles_24a\Vehicles\' ...
    'VehicleProjects\Bolt_EV'];

dynoFolder = [ ...
    'C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\EV6_drivecycleData'];

calibrationFolder = fullfile(projectFolder,'Battery_Calibration');

mapFile = fullfile(calibrationFolder, ...
    'EV6_SpeedMode_PowerCorrection_Results.mat');

auxiliaryFile = fullfile(calibrationFolder, ...
    'EV6_Stationary_Auxiliary_Load_Diagnostic.mat');

assert(isfile(mapFile),'Power-correction map file was not found.');
assert(isfile(auxiliaryFile),'Auxiliary-load diagnostic file was not found.');

%% Load existing correction map and stationary auxiliary candidate

mapData = load(mapFile, ...
    'speedCenters_mps','correctionMap_kW','modeThreshold_kW');

auxiliaryData = load(auxiliaryFile, ...
    'candidateAuxiliaryPower_kW');

assert(isfield(mapData,'speedCenters_mps') && ...
       isfield(mapData,'correctionMap_kW') && ...
       isfield(mapData,'modeThreshold_kW'), ...
    'Required map variables are missing.');

assert(isfield(auxiliaryData,'candidateAuxiliaryPower_kW'), ...
    'candidateAuxiliaryPower_kW is missing.');

speedCenters_mps = double(mapData.speedCenters_mps(:).');
existingMap_kW = double(mapData.correctionMap_kW);
modeThreshold_kW = double(mapData.modeThreshold_kW);
auxiliaryPower_kW = double(auxiliaryData.candidateAuxiliaryPower_kW);

assert(isequal(size(existingMap_kW),[3 numel(speedCenters_mps)]), ...
    'Expected a 3-by-N correction map.');

% Row order used by the existing subsystem:
%   1 = traction, 2 = regeneration, 3 = low-power/idle

% Decomposition:
% - Auxiliary power is applied in every mode.
% - It is subtracted from traction and regen residual maps so their total
%   corrections remain unchanged.
% - Low-power residual is set to zero, so low-power operation receives the
%   physically measured fixed auxiliary load instead of an empirical map.

residualMap_kW = existingMap_kW;
residualMap_kW(1,:) = existingMap_kW(1,:) - auxiliaryPower_kW;
residualMap_kW(2,:) = existingMap_kW(2,:) - auxiliaryPower_kW;
residualMap_kW(3,:) = 0;

auxiliarySeparatedTotalMap_kW = residualMap_kW + auxiliaryPower_kW;

conversionVoltage_V = 726.5;
comparisonStart_s = 5.0;

fprintf('\n===== AUXILIARY-SEPARATED CORRECTION SETUP =====\n');
fprintf('Fixed auxiliary power = %.6f kW\n',auxiliaryPower_kW);
fprintf('Equivalent current at %.1f V = %.6f A\n', ...
    conversionVoltage_V,1000*auxiliaryPower_kW/conversionVoltage_V);
fprintf('Mode threshold = %.3f kW\n',modeThreshold_kW);
fprintf('No Simulink parameters will be changed.\n');
fprintf('================================================\n');

%% Process Runs 001-004

runLabels = ["Run001";"Run002";"Run003";"Run004"];
runRoles = ["Training";"Training";"Training";"Development check"];
strategyNames = [ ...
    "Original 77.4-kWh"
    "Existing speed/mode map"
    "Fixed auxiliary only"
    "Auxiliary + residual map"];

numberOfRuns = numel(runLabels);
numberOfStrategies = numel(strategyNames);
numberOfRows = numberOfRuns*numberOfStrategies;

resultRun = strings(numberOfRows,1);
resultRole = strings(numberOfRows,1);
resultStrategy = strings(numberOfRows,1);
sampleCount = zeros(numberOfRows,1);
dynoEnergy_kWh = zeros(numberOfRows,1);
predictedEnergy_kWh = zeros(numberOfRows,1);
energyError_pct = zeros(numberOfRows,1);
powerBias_kW = zeros(numberOfRows,1);
powerMAE_kW = zeros(numberOfRows,1);
powerRMSE_kW = zeros(numberOfRows,1);
currentBias_A = zeros(numberOfRows,1);
currentMAE_A = zeros(numberOfRows,1);
currentRMSE_A = zeros(numberOfRows,1);
currentCorrelation = zeros(numberOfRows,1);

runResults = cell(numberOfRuns,1);
outputRow = 0;

for runIndex = 1:numberOfRuns

    runNumber = runIndex;
    runLabel = runLabels(runIndex);

    fprintf('\nLoading %s...\n',runLabel);

    dynoFile = fullfile(dynoFolder,sprintf( ...
        'standards_test_08142026_%03d.mat',runNumber));

    simulationFile = fullfile(projectFolder,sprintf( ...
        'EV6_Run%03d_77p4kWh_Corrected_Full_Output.mat', ...
        runNumber));

    assert(isfile(dynoFile),'Dyno file missing for %s.',runLabel);
    assert(isfile(simulationFile), ...
        'Original simulation file missing for %s.',runLabel);

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

    originalPower_kW = convertPowerToKilowatts(simPowerRaw);

    comparisonEnd_s = min([ ...
        tSpeed_s(end),tCurrent_s(end),tVoltage_s(end), ...
        tSimPower_s(end),tSimCurrent_s(end)]);

    useSamples = ...
        tCurrent_s >= comparisonStart_s & ...
        tCurrent_s <= comparisonEnd_s;

    tCompare_s = tCurrent_s(useSamples);
    measuredCurrent_A = dynoCurrent_A(useSamples);

    measuredVoltage_V = interpClean( ...
        tVoltage_s,dynoVoltage_V,tCompare_s);
    speed_mps = interpClean(tSpeed_s,dynoSpeed_mps,tCompare_s);
    basePower_kW = interpClean( ...
        tSimPower_s,originalPower_kW,tCompare_s);
    baseCurrent_A = interpClean( ...
        tSimCurrent_s,simCurrent_A,tCompare_s);

    measuredPower_kW = ...
        measuredCurrent_A.*measuredVoltage_V/1000;

    existingCorrection_kW = evaluateModeMap( ...
        speed_mps,basePower_kW,speedCenters_mps, ...
        existingMap_kW,modeThreshold_kW);

    residualCorrection_kW = evaluateModeMap( ...
        speed_mps,basePower_kW,speedCenters_mps, ...
        residualMap_kW,modeThreshold_kW);

    auxiliaryCorrection_kW = ...
        auxiliaryPower_kW*ones(size(tCompare_s));

    separatedCorrection_kW = ...
        auxiliaryCorrection_kW + residualCorrection_kW;

    strategyCorrection_kW = [ ...
        zeros(size(tCompare_s)), ...
        existingCorrection_kW, ...
        auxiliaryCorrection_kW, ...
        separatedCorrection_kW];

    strategyPower_kW = basePower_kW + strategyCorrection_kW;
    strategyCurrent_A = baseCurrent_A + ...
        1000*strategyCorrection_kW/conversionVoltage_V;

    measuredNetEnergy_kWh = ...
        trapz(tCompare_s,measuredPower_kW)/3600;

    for strategyIndex = 1:numberOfStrategies

        outputRow = outputRow+1;

        powerMetrics = calculateMetrics( ...
            strategyPower_kW(:,strategyIndex),measuredPower_kW);
        currentMetrics = calculateMetrics( ...
            strategyCurrent_A(:,strategyIndex),measuredCurrent_A);

        strategyEnergy_kWh = trapz( ...
            tCompare_s,strategyPower_kW(:,strategyIndex))/3600;

        resultRun(outputRow) = runLabel;
        resultRole(outputRow) = runRoles(runIndex);
        resultStrategy(outputRow) = strategyNames(strategyIndex);
        sampleCount(outputRow) = numel(tCompare_s);
        dynoEnergy_kWh(outputRow) = measuredNetEnergy_kWh;
        predictedEnergy_kWh(outputRow) = strategyEnergy_kWh;
        energyError_pct(outputRow) = 100 * ...
            (strategyEnergy_kWh-measuredNetEnergy_kWh) / ...
            abs(measuredNetEnergy_kWh);
        powerBias_kW(outputRow) = powerMetrics(1);
        powerMAE_kW(outputRow) = powerMetrics(2);
        powerRMSE_kW(outputRow) = powerMetrics(3);
        currentBias_A(outputRow) = currentMetrics(1);
        currentMAE_A(outputRow) = currentMetrics(2);
        currentRMSE_A(outputRow) = currentMetrics(3);
        currentCorrelation(outputRow) = currentMetrics(4);

    end

    runResults{runIndex} = struct( ...
        'Time_s',tCompare_s, ...
        'MeasuredPower_kW',measuredPower_kW, ...
        'MeasuredCurrent_A',measuredCurrent_A, ...
        'Speed_mps',speed_mps, ...
        'StrategyPower_kW',strategyPower_kW, ...
        'StrategyCurrent_A',strategyCurrent_A, ...
        'ExistingCorrection_kW',existingCorrection_kW, ...
        'SeparatedCorrection_kW',separatedCorrection_kW);

end

%% Results table

AuxiliarySeparatedMetrics = table( ...
    resultRun,resultRole,resultStrategy,sampleCount, ...
    dynoEnergy_kWh,predictedEnergy_kWh,energyError_pct, ...
    powerBias_kW,powerMAE_kW,powerRMSE_kW, ...
    currentBias_A,currentMAE_A,currentRMSE_A,currentCorrelation, ...
    'VariableNames',{ ...
    'Run','Role','Strategy','Samples','DynoEnergy_kWh', ...
    'PredictedEnergy_kWh','EnergyError_pct','PowerBias_kW', ...
    'PowerMAE_kW','PowerRMSE_kW','CurrentBias_A', ...
    'CurrentMAE_A','CurrentRMSE_A','CurrentCorrelation'});

fprintf('\n===== AUXILIARY-SEPARATED OFFLINE RESULTS =====\n');
disp(AuxiliarySeparatedMetrics);

%% Acceptance summary

trainingMask = AuxiliarySeparatedMetrics.Role == "Training";
existingMask = AuxiliarySeparatedMetrics.Strategy == ...
    "Existing speed/mode map";
separatedMask = AuxiliarySeparatedMetrics.Strategy == ...
    "Auxiliary + residual map";
run004Mask = AuxiliarySeparatedMetrics.Run == "Run004";

existingTrainingEnergyError = mean(abs( ...
    AuxiliarySeparatedMetrics.EnergyError_pct( ...
    trainingMask & existingMask)));

separatedTrainingEnergyError = mean(abs( ...
    AuxiliarySeparatedMetrics.EnergyError_pct( ...
    trainingMask & separatedMask)));

existingTrainingCurrentMAE = mean( ...
    AuxiliarySeparatedMetrics.CurrentMAE_A( ...
    trainingMask & existingMask));

separatedTrainingCurrentMAE = mean( ...
    AuxiliarySeparatedMetrics.CurrentMAE_A( ...
    trainingMask & separatedMask));

existingRun004EnergyError = abs( ...
    AuxiliarySeparatedMetrics.EnergyError_pct( ...
    run004Mask & existingMask));

separatedRun004EnergyError = abs( ...
    AuxiliarySeparatedMetrics.EnergyError_pct( ...
    run004Mask & separatedMask));

candidatePasses = ...
    separatedTrainingEnergyError <= existingTrainingEnergyError + 0.5 && ...
    separatedTrainingCurrentMAE <= existingTrainingCurrentMAE + 0.10 && ...
    separatedRun004EnergyError < existingRun004EnergyError;

fprintf('\n===== CANDIDATE DECISION =====\n');
fprintf('Existing-map mean absolute training energy error = %.3f %%\n', ...
    existingTrainingEnergyError);
fprintf('Separated-candidate training energy error = %.3f %%\n', ...
    separatedTrainingEnergyError);
fprintf('Existing-map mean training current MAE = %.4f A\n', ...
    existingTrainingCurrentMAE);
fprintf('Separated-candidate training current MAE = %.4f A\n', ...
    separatedTrainingCurrentMAE);
fprintf('Existing-map Run 004 absolute energy error = %.3f %%\n', ...
    existingRun004EnergyError);
fprintf('Separated Run 004 absolute energy error = %.3f %%\n', ...
    separatedRun004EnergyError);

if candidatePasses
    fprintf(['RESULT: PASS. Build a separate auxiliary-separated ' ...
        'Simulink candidate and perform a 60-second check.\n']);
else
    fprintf(['RESULT: REVIEW. Keep the existing corrected model and ' ...
        'do not change Simulink yet.\n']);
end

fprintf('No Simulink parameters were changed.\n');
fprintf('==============================\n');

%% Figure

figureHandle = figure( ...
    'Color','w','Name','EV6 Auxiliary-Separated Correction Evaluation', ...
    'Position',[60 60 1600 850]);

plotLayout = tiledlayout(2,2, ...
    'TileSpacing','compact','Padding','compact');

title(plotLayout, ...
    'EV6 Explicit Auxiliary Load and Residual-Map Evaluation', ...
    'FontWeight','bold');

energyErrorMatrix = reshape(energyError_pct, ...
    numberOfStrategies,numberOfRuns).';
currentMAEMatrix = reshape(currentMAE_A, ...
    numberOfStrategies,numberOfRuns).';

nexttile;
bar(categorical(runLabels),energyErrorMatrix);
yline(0,'k--');
grid on;
ylabel('Net-energy error [%]');
title('Net-energy prediction');
legend(strategyNames,'Location','best');

nexttile;
bar(categorical(runLabels),currentMAEMatrix);
grid on;
ylabel('Battery-current MAE [A]');
title('Current agreement');
legend(strategyNames,'Location','best');

nexttile;
run004 = runResults{4};
plot(run004.Time_s, ...
    1000*cumtrapz(run004.Time_s,run004.MeasuredPower_kW)/3600, ...
    'k','LineWidth',1.2);
hold on;
plotColors = lines(numberOfStrategies);
for strategyIndex = 1:numberOfStrategies
    plot(run004.Time_s,1000*cumtrapz( ...
        run004.Time_s,run004.StrategyPower_kW(:,strategyIndex))/3600, ...
        'Color',plotColors(strategyIndex,:),'LineWidth',0.9);
end
grid on;
xlabel('Time [s]');
ylabel('Cumulative net energy [Wh]');
title('Run 004 cumulative energy');
legend(["EV6 dyno";strategyNames],'Location','best');

nexttile;
plot(speedCenters_mps,existingMap_kW(3,:), ...
    'o-','LineWidth',1.2,'MarkerSize',5);
hold on;
plot(speedCenters_mps, ...
    auxiliarySeparatedTotalMap_kW(3,:), ...
    's-','LineWidth',1.2,'MarkerSize',5);
grid on;
xlabel('Vehicle speed [m/s]');
ylabel('Total low-power correction [kW]');
title('Low-power correction: empirical versus explicit auxiliary');
legend('Existing low-power map', ...
    'Fixed auxiliary load','Location','best');

%% Save

metricsFile = fullfile(calibrationFolder, ...
    'EV6_Auxiliary_Separated_Correction_Metrics.csv');

mapFileOut = fullfile(calibrationFolder, ...
    'EV6_Auxiliary_Separated_Correction_Maps.csv');

figureFile = fullfile(calibrationFolder, ...
    'EV6_Auxiliary_Separated_Correction_Evaluation.png');

resultsFile = fullfile(calibrationFolder, ...
    'EV6_Auxiliary_Separated_Correction_Results.mat');

AuxiliarySeparatedMapTable = table( ...
    speedCenters_mps(:), ...
    existingMap_kW(1,:).',existingMap_kW(2,:).', ...
    existingMap_kW(3,:).', ...
    residualMap_kW(1,:).',residualMap_kW(2,:).', ...
    residualMap_kW(3,:).', ...
    auxiliarySeparatedTotalMap_kW(1,:).', ...
    auxiliarySeparatedTotalMap_kW(2,:).', ...
    auxiliarySeparatedTotalMap_kW(3,:).', ...
    'VariableNames',{ ...
    'Speed_mps','ExistingTraction_kW','ExistingRegen_kW', ...
    'ExistingLowPower_kW','ResidualTraction_kW', ...
    'ResidualRegen_kW','ResidualLowPower_kW', ...
    'TotalTractionWithAux_kW','TotalRegenWithAux_kW', ...
    'TotalLowPowerWithAux_kW'});

writetable(AuxiliarySeparatedMetrics,metricsFile);
writetable(AuxiliarySeparatedMapTable,mapFileOut);
exportgraphics(figureHandle,figureFile,'Resolution',200);

save(resultsFile, ...
    'AuxiliarySeparatedMetrics','AuxiliarySeparatedMapTable', ...
    'auxiliaryPower_kW','speedCenters_mps','existingMap_kW', ...
    'residualMap_kW','auxiliarySeparatedTotalMap_kW', ...
    'modeThreshold_kW','conversionVoltage_V','candidatePasses', ...
    'runResults','-v7.3');

fprintf('\n===== OFFLINE EVALUATION COMPLETE =====\n');
fprintf('Metrics:\n%s\n\n',metricsFile);
fprintf('Maps:\n%s\n\n',mapFileOut);
fprintf('Figure:\n%s\n\n',figureFile);
fprintf('MAT results:\n%s\n',resultsFile);
fprintf('=======================================\n');

%% Local functions

function correction_kW = evaluateModeMap( ...
    speed_mps,basePower_kW,speedCenters_mps,map_kW,threshold_kW)

boundedSpeed_mps = min(max( ...
    speed_mps,speedCenters_mps(1)),speedCenters_mps(end));

modeIndex = 3*ones(size(basePower_kW));
modeIndex(basePower_kW > threshold_kW) = 1;
modeIndex(basePower_kW < -threshold_kW) = 2;

correction_kW = zeros(size(basePower_kW));

for mode = 1:3
    useMode = modeIndex == mode;
    correction_kW(useMode) = interp1( ...
        speedCenters_mps,map_kW(mode,:), ...
        boundedSpeed_mps(useMode),'linear');
end

end

function dynoStructure = findDynoStructure(loadedData)

fieldNames = fieldnames(loadedData);

for k = 1:numel(fieldNames)
    candidate = loadedData.(fieldNames{k});
    if isstruct(candidate) && ...
            isfield(candidate,'X') && isfield(candidate,'Y')
        dynoStructure = candidate;
        return;
    end
end

error('No structure containing X and Y was found.');

end

function [time_s,data] = getDynoSignal(dynoStructure,requestedName)

signalNames = erase(string({dynoStructure.Y.Name}),["<",">"]);
signalIndex = find(strcmpi(signalNames,requestedName),1,'first');
assert(~isempty(signalIndex),'Dyno signal %s was not found.',requestedName);

timeIndex = dynoStructure.Y(signalIndex).XIndex;
time_s = double(dynoStructure.X(timeIndex).Data(:));
data = double(dynoStructure.Y(signalIndex).Data(:));

valid = isfinite(time_s) & isfinite(data);
time_s = time_s(valid);
data = data(valid);
[time_s,indices] = unique(time_s,'stable');
data = data(indices);

end

function output = findSimulationOutput(loadedData,fileDescription)

fieldNames = fieldnames(loadedData);

for k = 1:numel(fieldNames)
    candidate = loadedData.(fieldNames{k});
    if isa(candidate,'Simulink.SimulationOutput')
        output = candidate;
        fprintf('  SimulationOutput = %s\n',fieldNames{k});
        return;
    end
end

error('No SimulationOutput found in %s.',fileDescription);

end

function [time_s,data] = getSimulationSignal(output,signalName)

availableNames = string(output.who);
assert(any(availableNames == string(signalName)), ...
    'Signal %s was not found.',signalName);

value = output.get(signalName);

if isa(value,'Simulink.SimulationData.Signal')
    value = value.Values;
end

if isa(value,'timeseries')
    time_s = double(value.Time(:));
    data = double(squeeze(value.Data));
    data = data(:);
elseif isstruct(value) && isfield(value,'time')
    time_s = double(value.time(:));
    data = double(value.signals.values(:));
elseif isnumeric(value)
    data = double(value(:));
    time_s = double(output.get('tout'));
    time_s = time_s(:);
else
    error('Unsupported data type for %s.',signalName);
end

assert(numel(time_s) == numel(data), ...
    'Time/data size mismatch for %s.',signalName);

valid = isfinite(time_s) & isfinite(data);
time_s = time_s(valid);
data = data(valid);
[time_s,indices] = unique(time_s,'stable');
data = data(indices);

end

function power_kW = convertPowerToKilowatts(powerRaw)

if max(abs(powerRaw),[],'omitnan') > 500
    power_kW = powerRaw/1000;
else
    power_kW = powerRaw;
end

end

function dataOut = interpClean(timeIn,dataIn,timeOut)

timeIn = double(timeIn(:));
dataIn = double(dataIn(:));
timeOut = double(timeOut(:));

valid = isfinite(timeIn) & isfinite(dataIn);
timeIn = timeIn(valid);
dataIn = dataIn(valid);
[timeIn,indices] = unique(timeIn,'stable');
dataIn = dataIn(indices);

dataOut = interp1(timeIn,dataIn,timeOut,'linear','extrap');
dataOut = dataOut(:);

end

function metrics = calculateMetrics(predicted,measured)

predicted = double(predicted(:));
measured = double(measured(:));
valid = isfinite(predicted) & isfinite(measured);
predicted = predicted(valid);
measured = measured(valid);
errorValue = predicted-measured;

x = predicted-mean(predicted);
y = measured-mean(measured);
denominator = sqrt(sum(x.^2)*sum(y.^2));

if denominator > eps
    correlation = sum(x.*y)/denominator;
else
    correlation = NaN;
end

metrics = [ ...
    mean(errorValue), ...
    mean(abs(errorValue)), ...
    sqrt(mean(errorValue.^2)), ...
    correlation];

end
