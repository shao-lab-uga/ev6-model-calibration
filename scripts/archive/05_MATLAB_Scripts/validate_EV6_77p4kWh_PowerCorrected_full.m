%% VALIDATE FULL RUN 004 — 2023 EV6 77.4-kWh POWER-CORRECTED MODEL
% Compares the following over the full Run 004 cycle after the first 5 s:
%   1. EV6 dynamometer data
%   2. Original 77.4-kWh Simulink model
%   3. Power-corrected 77.4-kWh Simulink model
%
% No Statistics and Machine Learning Toolbox is required.

clearvars -except D004
clc

%% File locations

projectFolder = [ ...
    'C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\Vehicles_24a\Vehicles\' ...
    'VehicleProjects\Bolt_EV'];

dynoFile = [ ...
    'C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\EV6_drivecycleData\' ...
    'standards_test_08142026_004.mat'];

originalFile = fullfile(projectFolder, ...
    'EV6_Run004_77p4kWh_Corrected_Full_Output.mat');

correctedFile = fullfile(projectFolder, ...
    'EV6_Run004_77p4kWh_PowerCorrected_Full_Output.mat');

figureFolder = fullfile(projectFolder,'Run004_Professor_Figures');

if ~isfolder(figureFolder)
    mkdir(figureFolder);
end

assert(isfile(dynoFile), ...
    'Run 004 dyno MAT-file was not found.');

assert(isfile(originalFile), ...
    'Original 77.4-kWh full-output MAT-file was not found.');

assert(isfile(correctedFile), ...
    'Power-corrected full-output MAT-file was not found.');

%% Load Run 004 dynamometer data

if ~exist('D004','var')
    loadedDyno = load(dynoFile);
    D004 = findDynoStructure(loadedDyno);
end

[dynoCurrentTime_s,dynoCurrent_A,currentSignalName] = ...
    getDynoSignal(D004,'VEH_batCurrent');

[dynoVoltageTime_s,dynoVoltage_V,voltageSignalName] = ...
    getDynoSignal(D004,'VEH_batVoltage');

fprintf('\n===== RUN 004 DYNO SIGNALS =====\n');
fprintf('Current signal = %s\n',currentSignalName);
fprintf('Voltage signal = %s\n',voltageSignalName);
fprintf('Current range = %.3f to %.3f A\n', ...
    min(dynoCurrent_A),max(dynoCurrent_A));
fprintf('Voltage range = %.3f to %.3f V\n', ...
    min(dynoVoltage_V),max(dynoVoltage_V));
fprintf('================================\n');

%% Load original and corrected SimulationOutput objects

loadedOriginal = load(originalFile);
loadedCorrected = load(correctedFile);

originalOutput = findSimulationOutput( ...
    loadedOriginal,'original 77.4-kWh output file');

correctedOutput = findSimulationOutput( ...
    loadedCorrected,'power-corrected output file');

%% Extract original-model signals

[tOriginalCurrent_s,originalCurrent_A] = ...
    getSimulationSignal(originalOutput,'battery_current');

[tOriginalPower_s,originalPowerRaw] = ...
    getSimulationSignal(originalOutput,'battery_power');

[originalPower_kW,originalPowerInterpretation] = ...
    convertPowerToKilowatts(originalPowerRaw);

originalVoltage_V = reconstructVoltage( ...
    tOriginalCurrent_s,originalCurrent_A, ...
    tOriginalPower_s,originalPower_kW);

fprintf('\nOriginal battery-power interpretation: %s\n', ...
    originalPowerInterpretation);

%% Extract power-corrected model signals

[tCorrectedCurrent_s,correctedCurrent_A] = ...
    getSimulationSignal(correctedOutput,'battery_current');

[tCorrectedPower_s,correctedPowerRaw] = ...
    getSimulationSignal(correctedOutput,'battery_power');

[correctedPower_kW,correctedPowerInterpretation] = ...
    convertPowerToKilowatts(correctedPowerRaw);

correctedVoltage_V = reconstructVoltage( ...
    tCorrectedCurrent_s,correctedCurrent_A, ...
    tCorrectedPower_s,correctedPower_kW);

[tCorrectionCurrent_s,correctionCurrent_A] = ...
    getSimulationSignal(correctedOutput,'EV6CurrentCorrection_A');

[tCorrectionPower_s,correctionPower_kW] = ...
    getSimulationSignal(correctedOutput,'EV6PowerCorrection_kW');

fprintf('Corrected battery-power interpretation: %s\n', ...
    correctedPowerInterpretation);

%% Establish common full-cycle comparison period

comparisonStart_s = 5.0;

comparisonEnd_s = min([ ...
    dynoCurrentTime_s(end), ...
    dynoVoltageTime_s(end), ...
    tOriginalCurrent_s(end), ...
    tOriginalPower_s(end), ...
    tCorrectedCurrent_s(end), ...
    tCorrectedPower_s(end)]);

comparisonMask = ...
    dynoCurrentTime_s >= comparisonStart_s & ...
    dynoCurrentTime_s <= comparisonEnd_s;

tCompare_s = dynoCurrentTime_s(comparisonMask);

assert(numel(tCompare_s) >= 2, ...
    'The common comparison period contains fewer than two samples.');

%% Align all signals to the dyno-current time base

dynoCurrentAligned_A = dynoCurrent_A(comparisonMask);

dynoVoltageAligned_V = interpClean( ...
    dynoVoltageTime_s,dynoVoltage_V,tCompare_s);

dynoPowerAligned_kW = ...
    dynoCurrentAligned_A .* dynoVoltageAligned_V / 1000;

originalCurrentAligned_A = interpClean( ...
    tOriginalCurrent_s,originalCurrent_A,tCompare_s);

originalPowerAligned_kW = interpClean( ...
    tOriginalPower_s,originalPower_kW,tCompare_s);

originalVoltageAligned_V = interpClean( ...
    tOriginalCurrent_s,originalVoltage_V,tCompare_s);

correctedCurrentAligned_A = interpClean( ...
    tCorrectedCurrent_s,correctedCurrent_A,tCompare_s);

correctedPowerAligned_kW = interpClean( ...
    tCorrectedPower_s,correctedPower_kW,tCompare_s);

correctedVoltageAligned_V = interpClean( ...
    tCorrectedCurrent_s,correctedVoltage_V,tCompare_s);

correctionCurrentAligned_A = interpClean( ...
    tCorrectionCurrent_s,correctionCurrent_A,tCompare_s);

correctionPowerAligned_kW = interpClean( ...
    tCorrectionPower_s,correctionPower_kW,tCompare_s);

fprintf('\n===== FULL-CYCLE COMPARISON PERIOD =====\n');
fprintf('Start time = %.3f seconds\n',tCompare_s(1));
fprintf('End time = %.3f seconds\n',tCompare_s(end));
fprintf('Samples = %d\n',numel(tCompare_s));
fprintf('========================================\n');

%% Calculate electrical-signal metrics

originalCurrentMetrics = calculateMetrics( ...
    originalCurrentAligned_A,dynoCurrentAligned_A);

correctedCurrentMetrics = calculateMetrics( ...
    correctedCurrentAligned_A,dynoCurrentAligned_A);

originalVoltageMetrics = calculateMetrics( ...
    originalVoltageAligned_V,dynoVoltageAligned_V);

correctedVoltageMetrics = calculateMetrics( ...
    correctedVoltageAligned_V,dynoVoltageAligned_V);

originalPowerMetrics = calculateMetrics( ...
    originalPowerAligned_kW,dynoPowerAligned_kW);

correctedPowerMetrics = calculateMetrics( ...
    correctedPowerAligned_kW,dynoPowerAligned_kW);

allMetrics = [ ...
    originalCurrentMetrics
    correctedCurrentMetrics
    originalVoltageMetrics
    correctedVoltageMetrics
    originalPowerMetrics
    correctedPowerMetrics];

ElectricalMetrics = table( ...
    ["Battery Current";"Battery Current"; ...
     "Battery Voltage";"Battery Voltage"; ...
     "Battery Power";"Battery Power"], ...
    ["Original 77.4-kWh";"Power-corrected 77.4-kWh"; ...
     "Original 77.4-kWh";"Power-corrected 77.4-kWh"; ...
     "Original 77.4-kWh";"Power-corrected 77.4-kWh"], ...
    ["A";"A";"V";"V";"kW";"kW"], ...
    allMetrics(:,1),allMetrics(:,2),allMetrics(:,3), ...
    allMetrics(:,4),allMetrics(:,5), ...
    'VariableNames',{ ...
    'Signal','Model','Unit','Bias','MAE','RMSE', ...
    'MaxAbsError','Correlation'});

fprintf('\n===== FULL RUN 004 ELECTRICAL METRICS =====\n');
disp(ElectricalMetrics);

%% Calculate energy results

dynoNetEnergy_kWh = ...
    trapz(tCompare_s,dynoPowerAligned_kW)/3600;

originalNetEnergy_kWh = ...
    trapz(tCompare_s,originalPowerAligned_kW)/3600;

correctedNetEnergy_kWh = ...
    trapz(tCompare_s,correctedPowerAligned_kW)/3600;

dynoPositiveEnergy_kWh = ...
    trapz(tCompare_s,max(dynoPowerAligned_kW,0))/3600;

originalPositiveEnergy_kWh = ...
    trapz(tCompare_s,max(originalPowerAligned_kW,0))/3600;

correctedPositiveEnergy_kWh = ...
    trapz(tCompare_s,max(correctedPowerAligned_kW,0))/3600;

dynoRegenEnergy_kWh = ...
    trapz(tCompare_s,max(-dynoPowerAligned_kW,0))/3600;

originalRegenEnergy_kWh = ...
    trapz(tCompare_s,max(-originalPowerAligned_kW,0))/3600;

correctedRegenEnergy_kWh = ...
    trapz(tCompare_s,max(-correctedPowerAligned_kW,0))/3600;

netEnergyValues_kWh = [ ...
    dynoNetEnergy_kWh
    originalNetEnergy_kWh
    correctedNetEnergy_kWh];

positiveEnergyValues_kWh = [ ...
    dynoPositiveEnergy_kWh
    originalPositiveEnergy_kWh
    correctedPositiveEnergy_kWh];

regenEnergyValues_kWh = [ ...
    dynoRegenEnergy_kWh
    originalRegenEnergy_kWh
    correctedRegenEnergy_kWh];

netEnergyError_pct = 100 * ...
    (netEnergyValues_kWh - dynoNetEnergy_kWh) / ...
    abs(dynoNetEnergy_kWh);

positiveEnergyError_pct = 100 * ...
    (positiveEnergyValues_kWh - dynoPositiveEnergy_kWh) / ...
    dynoPositiveEnergy_kWh;

regenEnergyError_pct = 100 * ...
    (regenEnergyValues_kWh - dynoRegenEnergy_kWh) / ...
    dynoRegenEnergy_kWh;

EnergyMetrics = table( ...
    ["EV6 dyno";"Original 77.4-kWh"; ...
     "Power-corrected 77.4-kWh"], ...
    netEnergyValues_kWh, ...
    positiveEnergyValues_kWh, ...
    regenEnergyValues_kWh, ...
    1000*(netEnergyValues_kWh-dynoNetEnergy_kWh), ...
    netEnergyError_pct, ...
    positiveEnergyError_pct, ...
    regenEnergyError_pct, ...
    'VariableNames',{ ...
    'Dataset','NetEnergy_kWh','PositiveEnergy_kWh', ...
    'RegenEnergyMagnitude_kWh','NetEnergyError_Wh', ...
    'NetEnergyError_pct','PositiveEnergyError_pct', ...
    'RegenEnergyError_pct'});

fprintf('\n===== FULL RUN 004 ENERGY RESULTS =====\n');
disp(EnergyMetrics);

%% Improvement and acceptance checks

currentMAEImprovement_pct = 100 * ...
    (originalCurrentMetrics(2)-correctedCurrentMetrics(2)) / ...
    originalCurrentMetrics(2);

powerMAEImprovement_pct = 100 * ...
    (originalPowerMetrics(2)-correctedPowerMetrics(2)) / ...
    originalPowerMetrics(2);

originalAbsoluteEnergyError_pct = abs(netEnergyError_pct(2));
correctedAbsoluteEnergyError_pct = abs(netEnergyError_pct(3));

energyImprovement_points = ...
    originalAbsoluteEnergyError_pct - ...
    correctedAbsoluteEnergyError_pct;

candidatePasses = ...
    correctedAbsoluteEnergyError_pct < ...
        originalAbsoluteEnergyError_pct && ...
    correctedCurrentMetrics(2) <= ...
        originalCurrentMetrics(2) + 0.10 && ...
    correctedCurrentMetrics(5) >= 0.95;

fprintf('\n===== FULL-CYCLE IMPROVEMENT =====\n');
fprintf('Current MAE improvement = %.3f %%\n', ...
    currentMAEImprovement_pct);
fprintf('Power MAE improvement = %.3f %%\n', ...
    powerMAEImprovement_pct);
fprintf('Original net-energy error = %.3f %%\n', ...
    netEnergyError_pct(2));
fprintf('Corrected net-energy error = %.3f %%\n', ...
    netEnergyError_pct(3));
fprintf('Absolute energy-error improvement = %.3f percentage points\n', ...
    energyImprovement_points);
fprintf('Corrected current correlation = %.5f\n', ...
    correctedCurrentMetrics(5));
fprintf('==================================\n');

if candidatePasses
    fprintf(['RESULT: PASS. The physical Simulink correction improves ' ...
        'full-cycle energy while preserving current agreement.\n']);
else
    fprintf(['RESULT: REVIEW. Do not retune yet; inspect the printed ' ...
        'energy and current metrics first.\n']);
end

%% Create full-cycle validation figure

figureHandle = figure( ...
    'Color','w', ...
    'Name','Run 004 Full Power-Corrected Battery Validation', ...
    'Position',[50 40 1700 950]);

plotLayout = tiledlayout(3,2, ...
    'TileSpacing','compact', ...
    'Padding','compact');

title(plotLayout, ...
    'Run 004: Full-Cycle 2023 EV6 77.4-kWh Battery Validation', ...
    'FontWeight','bold');

nexttile;
plot(tCompare_s,dynoCurrentAligned_A,'k','LineWidth',1.0);
hold on;
plot(tCompare_s,originalCurrentAligned_A, ...
    'Color',[0.00 0.45 0.74],'LineWidth',0.9);
plot(tCompare_s,correctedCurrentAligned_A, ...
    'Color',[0.85 0.10 0.10],'LineWidth',0.9);
grid on;
xlabel('Time [s]');
ylabel('Current [A]');
title('Battery current');
legend('EV6 dyno','Original 77.4-kWh', ...
    'Power-corrected 77.4-kWh','Location','best');

nexttile;
plot(tCompare_s,originalCurrentAligned_A-dynoCurrentAligned_A, ...
    'Color',[0.00 0.45 0.74],'LineWidth',0.8);
hold on;
plot(tCompare_s,correctedCurrentAligned_A-dynoCurrentAligned_A, ...
    'Color',[0.85 0.10 0.10],'LineWidth',0.8);
yline(0,'k--');
grid on;
xlabel('Time [s]');
ylabel('Simulation - dyno [A]');
title('Battery-current error');
legend('Original','Power-corrected','Location','best');

nexttile;
plot(tCompare_s,dynoPowerAligned_kW,'k','LineWidth',1.0);
hold on;
plot(tCompare_s,originalPowerAligned_kW, ...
    'Color',[0.00 0.45 0.74],'LineWidth',0.9);
plot(tCompare_s,correctedPowerAligned_kW, ...
    'Color',[0.85 0.10 0.10],'LineWidth',0.9);
grid on;
xlabel('Time [s]');
ylabel('Power [kW]');
title('Battery power');
legend('EV6 dyno','Original 77.4-kWh', ...
    'Power-corrected 77.4-kWh','Location','best');

nexttile;
plot(tCompare_s,dynoVoltageAligned_V,'k','LineWidth',1.0);
hold on;
plot(tCompare_s,originalVoltageAligned_V, ...
    'Color',[0.00 0.45 0.74],'LineWidth',0.9);
plot(tCompare_s,correctedVoltageAligned_V, ...
    'Color',[0.85 0.10 0.10],'LineWidth',0.9);
grid on;
xlabel('Time [s]');
ylabel('Voltage [V]');
title('Battery voltage reconstructed from P/I');
legend('EV6 dyno','Original 77.4-kWh', ...
    'Power-corrected 77.4-kWh','Location','best');

nexttile;
dynoCumulativeEnergy_Wh = ...
    1000*cumtrapz(tCompare_s,dynoPowerAligned_kW)/3600;
originalCumulativeEnergy_Wh = ...
    1000*cumtrapz(tCompare_s,originalPowerAligned_kW)/3600;
correctedCumulativeEnergy_Wh = ...
    1000*cumtrapz(tCompare_s,correctedPowerAligned_kW)/3600;

plot(tCompare_s,dynoCumulativeEnergy_Wh,'k','LineWidth',1.2);
hold on;
plot(tCompare_s,originalCumulativeEnergy_Wh, ...
    'Color',[0.00 0.45 0.74],'LineWidth',1.0);
plot(tCompare_s,correctedCumulativeEnergy_Wh, ...
    'Color',[0.85 0.10 0.10],'LineWidth',1.0);
grid on;
xlabel('Time [s]');
ylabel('Net energy [Wh]');
title('Cumulative net battery energy');
legend('EV6 dyno','Original 77.4-kWh', ...
    'Power-corrected 77.4-kWh','Location','best');

nexttile;
yyaxis left;
plot(tCompare_s,correctionCurrentAligned_A, ...
    'Color',[0.20 0.55 0.20],'LineWidth',0.9);
ylabel('Correction current [A]');

yyaxis right;
plot(tCompare_s,correctionPowerAligned_kW, ...
    'Color',[0.55 0.20 0.70],'LineWidth',0.9);
ylabel('Correction power [kW]');

grid on;
xlabel('Time [s]');
title('Applied Simulink correction');
legend('Current correction','Power correction','Location','best');

%% Save results

figureFile = fullfile(figureFolder, ...
    'EV6_Run004_77p4kWh_PowerCorrected_Full_BatteryValidation.png');

electricalMetricsFile = fullfile(figureFolder, ...
    'EV6_Run004_77p4kWh_PowerCorrected_Full_ElectricalMetrics.csv');

energyMetricsFile = fullfile(figureFolder, ...
    'EV6_Run004_77p4kWh_PowerCorrected_Full_EnergyMetrics.csv');

validationResultsFile = fullfile(projectFolder, ...
    'EV6_Run004_77p4kWh_PowerCorrected_Full_Validation.mat');

exportgraphics(figureHandle,figureFile,'Resolution',200);
writetable(ElectricalMetrics,electricalMetricsFile);
writetable(EnergyMetrics,energyMetricsFile);

FullValidation = struct;
FullValidation.Time_s = tCompare_s;
FullValidation.DynoCurrent_A = dynoCurrentAligned_A;
FullValidation.OriginalCurrent_A = originalCurrentAligned_A;
FullValidation.CorrectedCurrent_A = correctedCurrentAligned_A;
FullValidation.DynoVoltage_V = dynoVoltageAligned_V;
FullValidation.OriginalVoltage_V = originalVoltageAligned_V;
FullValidation.CorrectedVoltage_V = correctedVoltageAligned_V;
FullValidation.DynoPower_kW = dynoPowerAligned_kW;
FullValidation.OriginalPower_kW = originalPowerAligned_kW;
FullValidation.CorrectedPower_kW = correctedPowerAligned_kW;
FullValidation.CorrectionCurrent_A = correctionCurrentAligned_A;
FullValidation.CorrectionPower_kW = correctionPowerAligned_kW;
FullValidation.ElectricalMetrics = ElectricalMetrics;
FullValidation.EnergyMetrics = EnergyMetrics;
FullValidation.CandidatePasses = candidatePasses;

save(validationResultsFile, ...
    'FullValidation','ElectricalMetrics','EnergyMetrics', ...
    'candidatePasses','-v7.3');

fprintf('\n===== FULL VALIDATION COMPLETE =====\n');
fprintf('Figure:\n%s\n\n',figureFile);
fprintf('Electrical metrics:\n%s\n\n',electricalMetricsFile);
fprintf('Energy metrics:\n%s\n\n',energyMetricsFile);
fprintf('MAT results:\n%s\n',validationResultsFile);
fprintf('====================================\n');

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

error('No structure containing X and Y was found in the dyno MAT-file.');

end

function [time_s,data,matchedName] = ...
    getDynoSignal(dynoStructure,requestedName)

signalNames = erase(string({dynoStructure.Y.Name}),["<",">"]);

signalIndex = find( ...
    strcmpi(signalNames,requestedName),1,'first');

assert(~isempty(signalIndex), ...
    'Dyno signal %s was not found.',requestedName);

timeIndex = dynoStructure.Y(signalIndex).XIndex;

time_s = double(dynoStructure.X(timeIndex).Data(:));
data = double(dynoStructure.Y(signalIndex).Data(:));
matchedName = char(signalNames(signalIndex));

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
        fprintf('\nSimulationOutput found in %s: %s\n', ...
            fileDescription,fieldNames{k});
        return;
    end
end

error('No Simulink.SimulationOutput was found in the %s.', ...
    fileDescription);

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

elseif istimetable(signalValue)
    time_s = seconds( ...
        signalValue.Properties.RowTimes - ...
        signalValue.Properties.RowTimes(1));
    time_s = double(time_s(:));
    data = double(signalValue.Variables);
    data = data(:);

elseif isstruct(signalValue) && ...
        isfield(signalValue,'time') && ...
        isfield(signalValue,'signals')
    time_s = double(signalValue.time(:));
    data = double(signalValue.signals.values(:));

elseif isnumeric(signalValue)
    data = double(signalValue(:));

    availableNames = string(simulationOutput.who);
    assert(any(availableNames == "tout"), ...
        'tout is required for numeric signal %s.',signalName);

    timeValue = simulationOutput.get('tout');

    if isa(timeValue,'timeseries')
        time_s = double(timeValue.Data(:));
    else
        time_s = double(timeValue(:));
    end

else
    error('Unsupported storage type for signal %s.',signalName);
end

assert(numel(time_s) == numel(data), ...
    'Time and data sizes differ for signal %s.',signalName);

valid = isfinite(time_s) & isfinite(data);
time_s = time_s(valid);
data = data(valid);

[time_s,uniqueIndices] = unique(time_s,'stable');
data = data(uniqueIndices);

end

function [power_kW,interpretation] = ...
    convertPowerToKilowatts(powerRaw)

maximumMagnitude = max(abs(powerRaw),[],'omitnan');

if maximumMagnitude > 500
    power_kW = powerRaw/1000;
    interpretation = 'W divided by 1000';
else
    power_kW = powerRaw;
    interpretation = 'already expressed in kW';
end

end

function voltage_V = reconstructVoltage( ...
    currentTime_s,current_A,powerTime_s,power_kW)

powerAtCurrentTime_kW = interpClean( ...
    powerTime_s,power_kW,currentTime_s);

rawVoltage_V = 1000*powerAtCurrentTime_kW ./ current_A;

validVoltage = ...
    isfinite(rawVoltage_V) & ...
    abs(current_A) >= 0.05 & ...
    rawVoltage_V >= 600 & ...
    rawVoltage_V <= 850;

assert(nnz(validVoltage) >= 2, ...
    'Not enough valid samples were available to reconstruct voltage.');

voltage_V = interp1( ...
    currentTime_s(validVoltage), ...
    rawVoltage_V(validVoltage), ...
    currentTime_s,'linear','extrap');

voltage_V = voltage_V(:);

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
    'At least two valid samples are required for interpolation.');

interpolatedData = interp1( ...
    sourceTime_s,sourceData,targetTime_s,'linear','extrap');

interpolatedData = interpolatedData(:);

end

function metrics = calculateMetrics(simulated,measured)

simulated = double(simulated(:));
measured = double(measured(:));

valid = isfinite(simulated) & isfinite(measured);
simulated = simulated(valid);
measured = measured(valid);

errorValues = simulated-measured;

biasValue = mean(errorValues);
maeValue = mean(abs(errorValues));
rmseValue = sqrt(mean(errorValues.^2));
maximumError = max(abs(errorValues));
correlationValue = manualCorrelation(simulated,measured);

metrics = [ ...
    biasValue,maeValue,rmseValue, ...
    maximumError,correlationValue];

end

function correlationValue = manualCorrelation(x,y)

x = double(x(:));
y = double(y(:));

valid = isfinite(x) & isfinite(y);
x = x(valid);
y = y(valid);

xCentered = x-mean(x);
yCentered = y-mean(y);

denominator = sqrt( ...
    sum(xCentered.^2)*sum(yCentered.^2));

if denominator <= eps
    correlationValue = NaN;
else
    correlationValue = ...
        sum(xCentered.*yCentered)/denominator;
end

end
