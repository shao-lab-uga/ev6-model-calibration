%% VALIDATE VEHICLE-DYNAMICS PRESERVATION
% Compares the original and power-corrected 77.4-kWh models.
% No Simulink simulation is performed.

clear
clc

%% File locations

projectFolder = [ ...
    'C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\Vehicles_24a\Vehicles\' ...
    'VehicleProjects\Bolt_EV'];

originalFile = fullfile(projectFolder, ...
    'EV6_Run004_77p4kWh_Corrected_Full_Output.mat');

correctedFile = fullfile(projectFolder, ...
    'EV6_Run004_77p4kWh_PowerCorrected_Full_Output.mat');

figureFolder = fullfile(projectFolder, ...
    'Run004_Professor_Figures');

assert(isfile(originalFile), ...
    'Original full-output file was not found.');

assert(isfile(correctedFile), ...
    'Power-corrected full-output file was not found.');

if ~isfolder(figureFolder)
    mkdir(figureFolder);
end

%% Load SimulationOutput objects

loadedOriginal = load(originalFile);
loadedCorrected = load(correctedFile);

originalOutput = findSimulationOutput( ...
    loadedOriginal,'original model');

correctedOutput = findSimulationOutput( ...
    loadedCorrected,'power-corrected model');

%% Extract vehicle speed and wheel torque

[tOriginalSpeed_s,originalSpeed] = ...
    getOutputMatrix(originalOutput,'Speed');

[tCorrectedSpeed_s,correctedSpeed] = ...
    getOutputMatrix(correctedOutput,'Speed');

[tOriginalTorque_s,originalAxlTrq] = ...
    getOutputMatrix(originalOutput,'AxlTrq');

[tCorrectedTorque_s,correctedAxlTrq] = ...
    getOutputMatrix(correctedOutput,'AxlTrq');

fprintf('\n===== OUTPUT DIMENSIONS =====\n');
fprintf('Original Speed = %d by %d\n',size(originalSpeed));
fprintf('Corrected Speed = %d by %d\n',size(correctedSpeed));
fprintf('Original AxlTrq = %d by %d\n',size(originalAxlTrq));
fprintf('Corrected AxlTrq = %d by %d\n',size(correctedAxlTrq));
fprintf('=============================\n');

assert(size(originalAxlTrq,2) >= 4, ...
    'Original AxlTrq does not contain four columns.');

assert(size(correctedAxlTrq,2) >= 4, ...
    'Corrected AxlTrq does not contain four columns.');

% If Speed contains multiple columns, use the first column.
originalSpeed = originalSpeed(:,1);
correctedSpeed = correctedSpeed(:,1);

originalAxlTrq = originalAxlTrq(:,1:4);
correctedAxlTrq = correctedAxlTrq(:,1:4);

%% Define common comparison period

comparisonStart_s = 5.0;

comparisonEnd_s = min([ ...
    tOriginalSpeed_s(end), ...
    tCorrectedSpeed_s(end), ...
    tOriginalTorque_s(end), ...
    tCorrectedTorque_s(end)]);

comparisonMask = ...
    tOriginalSpeed_s >= comparisonStart_s & ...
    tOriginalSpeed_s <= comparisonEnd_s;

tCompare_s = tOriginalSpeed_s(comparisonMask);

originalSpeedAligned = ...
    originalSpeed(comparisonMask);

correctedSpeedAligned = interpClean( ...
    tCorrectedSpeed_s,correctedSpeed,tCompare_s);

originalTorqueAligned = interpClean( ...
    tOriginalTorque_s,originalAxlTrq,tCompare_s);

correctedTorqueAligned = interpClean( ...
    tCorrectedTorque_s,correctedAxlTrq,tCompare_s);

originalTotalTorque = sum(originalTorqueAligned,2);
correctedTotalTorque = sum(correctedTorqueAligned,2);

fprintf('\n===== COMPARISON PERIOD =====\n');
fprintf('Start = %.3f seconds\n',tCompare_s(1));
fprintf('End = %.3f seconds\n',tCompare_s(end));
fprintf('Samples = %d\n',numel(tCompare_s));
fprintf('=============================\n');

%% Calculate preservation metrics

signalNames = [ ...
    "Vehicle Speed"
    "Left Front Wheel"
    "Right Front Wheel"
    "Left Rear Wheel"
    "Right Rear Wheel"
    "Four-Wheel Total"];

signalUnits = [ ...
    "m/s"
    "N*m"
    "N*m"
    "N*m"
    "N*m"
    "N*m"];

allMetrics = zeros(6,5);

allMetrics(1,:) = calculateMetrics( ...
    correctedSpeedAligned,originalSpeedAligned);

for wheelIndex = 1:4
    allMetrics(wheelIndex+1,:) = calculateMetrics( ...
        correctedTorqueAligned(:,wheelIndex), ...
        originalTorqueAligned(:,wheelIndex));
end

allMetrics(6,:) = calculateMetrics( ...
    correctedTotalTorque,originalTotalTorque);

DynamicsMetrics = table( ...
    signalNames,signalUnits, ...
    allMetrics(:,1), ...
    allMetrics(:,2), ...
    allMetrics(:,3), ...
    allMetrics(:,4), ...
    allMetrics(:,5), ...
    'VariableNames',{ ...
    'Signal','Unit','Bias','MAE','RMSE', ...
    'MaxAbsDifference','Correlation'});

fprintf('\n===== DYNAMICS-PRESERVATION METRICS =====\n');
fprintf('Difference = power-corrected minus original model\n\n');
disp(DynamicsMetrics);

%% Acceptance check

speedRMSE_mps = allMetrics(1,3);
speedCorrelation = allMetrics(1,5);

totalTorqueRMSE_Nm = allMetrics(6,3);
totalTorqueCorrelation = allMetrics(6,5);

candidatePasses = ...
    speedRMSE_mps <= 0.01 && ...
    totalTorqueRMSE_Nm <= 5.0 && ...
    speedCorrelation >= 0.9999 && ...
    totalTorqueCorrelation >= 0.999;

fprintf('\n===== ACCEPTANCE CHECK =====\n');
fprintf('Speed RMSE difference = %.8f m/s\n', ...
    speedRMSE_mps);
fprintf('Speed correlation = %.8f\n', ...
    speedCorrelation);
fprintf('Total-torque RMSE difference = %.8f N*m\n', ...
    totalTorqueRMSE_Nm);
fprintf('Total-torque correlation = %.8f\n', ...
    totalTorqueCorrelation);

if candidatePasses
    fprintf(['RESULT: PASS. Battery correction preserved ' ...
        'vehicle speed and wheel torque.\n']);
else
    fprintf(['RESULT: REVIEW. Inspect the dynamics differences ' ...
        'before finalizing the model.\n']);
end

fprintf('No Simulink parameters were changed.\n');
fprintf('============================\n');

%% Create figure

figureHandle = figure( ...
    'Color','w', ...
    'Name','EV6 Power-Correction Dynamics Preservation', ...
    'Position',[70 60 1600 850]);

plotLayout = tiledlayout(2,2, ...
    'TileSpacing','compact', ...
    'Padding','compact');

title(plotLayout, ...
    'Run 004: Effect of Battery-Power Correction on Vehicle Dynamics', ...
    'FontWeight','bold');

nexttile;

plot(tCompare_s,originalSpeedAligned, ...
    'k','LineWidth',1.1);
hold on;

plot(tCompare_s,correctedSpeedAligned, ...
    'r','LineWidth',0.9);

grid on;
xlabel('Time [s]');
ylabel('Vehicle speed [m/s]');
title('Vehicle speed');
legend('Original 77.4-kWh', ...
    'Power-corrected 77.4-kWh', ...
    'Location','best');

nexttile;

plot(tCompare_s, ...
    correctedSpeedAligned-originalSpeedAligned, ...
    'b','LineWidth',0.9);

yline(0,'k--');
grid on;
xlabel('Time [s]');
ylabel('Corrected - original [m/s]');
title('Vehicle-speed difference');

nexttile;

plot(tCompare_s,originalTotalTorque, ...
    'k','LineWidth',1.1);
hold on;

plot(tCompare_s,correctedTotalTorque, ...
    'r','LineWidth',0.9);

grid on;
xlabel('Time [s]');
ylabel('Four-wheel torque [N*m]');
title('Four-wheel total torque');
legend('Original 77.4-kWh', ...
    'Power-corrected 77.4-kWh', ...
    'Location','best');

nexttile;

plot(tCompare_s, ...
    correctedTotalTorque-originalTotalTorque, ...
    'b','LineWidth',0.9);

yline(0,'k--');
grid on;
xlabel('Time [s]');
ylabel('Corrected - original [N*m]');
title('Four-wheel-torque difference');

%% Save outputs

figureFile = fullfile(figureFolder, ...
    'EV6_Run004_PowerCorrection_DynamicsPreservation.png');

metricsFile = fullfile(figureFolder, ...
    'EV6_Run004_PowerCorrection_DynamicsPreservation.csv');

resultsFile = fullfile(projectFolder, ...
    'EV6_Run004_PowerCorrection_DynamicsPreservation.mat');

exportgraphics(figureHandle, ...
    figureFile,'Resolution',200);

writetable(DynamicsMetrics,metricsFile);

DynamicsComparison = struct;
DynamicsComparison.Time_s = tCompare_s;
DynamicsComparison.OriginalSpeed_mps = originalSpeedAligned;
DynamicsComparison.CorrectedSpeed_mps = correctedSpeedAligned;
DynamicsComparison.OriginalAxlTrq_Nm = originalTorqueAligned;
DynamicsComparison.CorrectedAxlTrq_Nm = correctedTorqueAligned;
DynamicsComparison.OriginalTotalTorque_Nm = originalTotalTorque;
DynamicsComparison.CorrectedTotalTorque_Nm = correctedTotalTorque;
DynamicsComparison.Metrics = DynamicsMetrics;
DynamicsComparison.CandidatePasses = candidatePasses;

save(resultsFile, ...
    'DynamicsComparison', ...
    'DynamicsMetrics', ...
    'candidatePasses', ...
    '-v7.3');

fprintf('\n===== DYNAMICS VALIDATION COMPLETE =====\n');
fprintf('Figure:\n%s\n\n',figureFile);
fprintf('Metrics:\n%s\n\n',metricsFile);
fprintf('MAT results:\n%s\n',resultsFile);
fprintf('========================================\n');

%% Local functions

function output = findSimulationOutput(loadedData,description)

fieldNames = fieldnames(loadedData);

for k = 1:numel(fieldNames)

    candidate = loadedData.(fieldNames{k});

    if isa(candidate,'Simulink.SimulationOutput')
        output = candidate;

        fprintf('SimulationOutput found for %s: %s\n', ...
            description,fieldNames{k});

        return;
    end
end

error('No SimulationOutput was found for %s.',description);

end

function [time_s,data] = getOutputMatrix(output,signalName)

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

elseif isstruct(value) && ...
        isfield(value,'time') && ...
        isfield(value,'signals')

    time_s = double(value.time(:));
    data = double(value.signals.values);

elseif isnumeric(value)

    data = double(value);
    time_s = double(output.get('tout'));
    time_s = time_s(:);

else
    error('Unsupported storage type for %s.',signalName);
end

if isvector(data)
    data = data(:);
end

if size(data,1) ~= numel(time_s) && ...
        size(data,2) == numel(time_s)
    data = data.';
end

assert(size(data,1) == numel(time_s), ...
    'Time and data sizes do not agree for %s.',signalName);

validTime = isfinite(time_s);
time_s = time_s(validTime);
data = data(validTime,:);

[time_s,uniqueIndices] = unique(time_s,'stable');
data = data(uniqueIndices,:);

end

function dataOut = interpClean(timeIn,dataIn,timeOut)

timeIn = double(timeIn(:));
timeOut = double(timeOut(:));
dataIn = double(dataIn);

validTime = isfinite(timeIn);
timeIn = timeIn(validTime);
dataIn = dataIn(validTime,:);

[timeIn,uniqueIndices] = unique(timeIn,'stable');
dataIn = dataIn(uniqueIndices,:);

dataOut = interp1( ...
    timeIn,dataIn,timeOut,'linear','extrap');

end

function metrics = calculateMetrics(corrected,original)

corrected = double(corrected(:));
original = double(original(:));

valid = isfinite(corrected) & isfinite(original);

corrected = corrected(valid);
original = original(valid);

difference = corrected-original;

biasValue = mean(difference);
maeValue = mean(abs(difference));
rmseValue = sqrt(mean(difference.^2));
maximumDifference = max(abs(difference));

correctedCentered = corrected-mean(corrected);
originalCentered = original-mean(original);

denominator = sqrt( ...
    sum(correctedCentered.^2) * ...
    sum(originalCentered.^2));

if denominator > eps
    correlationValue = sum( ...
        correctedCentered.*originalCentered) / denominator;
else
    correlationValue = NaN;
end

metrics = [ ...
    biasValue, ...
    maeValue, ...
    rmseValue, ...
    maximumDifference, ...
    correlationValue];

end