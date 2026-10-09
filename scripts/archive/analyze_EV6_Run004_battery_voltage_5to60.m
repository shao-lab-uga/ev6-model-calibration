%% RUN 004 BATTERY-VOLTAGE COMPARISON: 5-60 SECONDS

projectRoot = ['C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\Vehicles_24a\Vehicles\' ...
    'VehicleProjects\Bolt_EV'];

outputFolder = fullfile(projectRoot,'Run004_Professor_Figures');

if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

%% Load Run 004 dyno data

run004File = ['C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\EV6_drivecycleData\' ...
    'standards_test_08142026_004.mat'];

if ~exist('D004','var')
    loadedRun004 = load(run004File);
    D004 = loadedRun004.standards_test_08142026_004;
end

channelNames004 = erase(string({D004.Y.Name}),["<",">"]);

voltageChannel = find( ...
    channelNames004 == "VEH_batVoltage",1,'first');

assert(~isempty(voltageChannel), ...
    'VEH_batVoltage was not found in Run 004.');

voltageTimeIndex = D004.Y(voltageChannel).XIndex;

dynoTime = double(D004.X(voltageTimeIndex).Data(:));
dynoVoltage = double(D004.Y(voltageChannel).Data(:));

timeMask = ...
    dynoTime >= 5 & ...
    dynoTime <= 60 & ...
    isfinite(dynoTime) & ...
    isfinite(dynoVoltage);

comparisonTime = dynoTime(timeMask);
comparisonDynoVoltage = dynoVoltage(timeMask);

%% Models being compared

runNames = [
    "Run004_FourWheel_Baseline"
    "Run004_FourWheel_CalibratedCandidate"
    "Run004_EV6Battery84kWh_Corrected_60s"
    ];

modelLabels = [
    "LUT-only, original battery"
    "LUT + gains, original battery"
    "LUT + gains, 84-kWh battery"
    ];

numberOfModels = numel(runNames);

simulatedVoltage = nan( ...
    numel(comparisonTime),numberOfModels);

matchedSignals = strings(numberOfModels,1);

allRunIDs = Simulink.sdi.getAllRunIDs;

%% Extract voltage from each SDI run

for modelIndex = 1:numberOfModels

    selectedRunID = [];

    % The last match is used in case duplicate runs exist
    for runIndex = 1:numel(allRunIDs)

        currentRun = Simulink.sdi.getRun( ...
            allRunIDs(runIndex));

        if string(currentRun.Name) == ...
                runNames(modelIndex)

            selectedRunID = allRunIDs(runIndex);
        end
    end

    assert(~isempty(selectedRunID), ...
        'SDI run was not found: %s', ...
        runNames(modelIndex));

    selectedRun = Simulink.sdi.getRun( ...
        selectedRunID);

    signalIDs = selectedRun.getAllSignalIDs;
    signalNames = strings(numel(signalIDs),1);

    for signalIndex = 1:numel(signalIDs)

        currentSignal = Simulink.sdi.getSignal( ...
            signalIDs(signalIndex));

        signalNames(signalIndex) = ...
            string(currentSignal.Name);
    end

    preferredNames = [
        "SimMonitor.Veh.Batt.BattVolt"
        "<BattVolt>"
        "BattVolt"
        ];

    selectedSignalIndex = [];

    for nameIndex = 1:numel(preferredNames)

        selectedSignalIndex = find( ...
            strcmpi(signalNames, ...
            preferredNames(nameIndex)), ...
            1,'first');

        if ~isempty(selectedSignalIndex)
            break
        end
    end

    if isempty(selectedSignalIndex)

        selectedSignalIndex = find( ...
            contains(lower(signalNames), ...
            "battvolt"),1,'first');
    end

    assert(~isempty(selectedSignalIndex), ...
        'Battery-voltage signal was not found in %s.', ...
        runNames(modelIndex));

    voltageSignal = Simulink.sdi.getSignal( ...
        signalIDs(selectedSignalIndex));

    matchedSignals(modelIndex) = ...
        signalNames(selectedSignalIndex);

    voltageValues = voltageSignal.Values;

    simulatedTime = double( ...
        voltageValues.Time(:));

    simulatedData = double( ...
        voltageValues.Data(:));

    validSimulationData = ...
        isfinite(simulatedTime) & ...
        isfinite(simulatedData);

    simulatedTime = ...
        simulatedTime(validSimulationData);

    simulatedData = ...
        simulatedData(validSimulationData);

    [simulatedTime,uniqueIndices] = ...
        unique(simulatedTime,'stable');

    simulatedData = ...
        simulatedData(uniqueIndices);

    simulatedVoltage(:,modelIndex) = ...
        interp1( ...
        simulatedTime, ...
        simulatedData, ...
        comparisonTime, ...
        'linear',NaN);
end

%% Calculate voltage metrics without corr()

Bias_V = nan(numberOfModels,1);
MAE_V = nan(numberOfModels,1);
RMSE_V = nan(numberOfModels,1);
MaxAbsError_V = nan(numberOfModels,1);
Correlation = nan(numberOfModels,1);
SimulatedMin_V = nan(numberOfModels,1);
SimulatedMax_V = nan(numberOfModels,1);

for modelIndex = 1:numberOfModels

    simulation = simulatedVoltage(:,modelIndex);
    measurement = comparisonDynoVoltage;

    valid = ...
        isfinite(simulation) & ...
        isfinite(measurement);

    simulation = simulation(valid);
    measurement = measurement(valid);

    errorVoltage = simulation - measurement;

    Bias_V(modelIndex) = mean(errorVoltage);
    MAE_V(modelIndex) = mean(abs(errorVoltage));
    RMSE_V(modelIndex) = sqrt(mean(errorVoltage.^2));
    MaxAbsError_V(modelIndex) = max(abs(errorVoltage));

    SimulatedMin_V(modelIndex) = min(simulation);
    SimulatedMax_V(modelIndex) = max(simulation);

    simulationCentered = ...
        simulation - mean(simulation);

    measurementCentered = ...
        measurement - mean(measurement);

    Correlation(modelIndex) = ...
        sum(simulationCentered .* measurementCentered) / ...
        sqrt( ...
        sum(simulationCentered.^2) * ...
        sum(measurementCentered.^2));
end

VoltageMetrics = table( ...
    modelLabels, ...
    matchedSignals, ...
    SimulatedMin_V, ...
    SimulatedMax_V, ...
    Bias_V, ...
    MAE_V, ...
    RMSE_V, ...
    MaxAbsError_V, ...
    Correlation, ...
    'VariableNames',{ ...
    'Model', ...
    'MatchedSignal', ...
    'SimulatedMin_V', ...
    'SimulatedMax_V', ...
    'Bias_V', ...
    'MAE_V', ...
    'RMSE_V', ...
    'MaxAbsError_V', ...
    'Correlation'});

fprintf('\n===== RUN 004 BATTERY VOLTAGE: 5-60 SECONDS =====\n');
fprintf('Dyno voltage range = %.3f to %.3f V\n\n', ...
    min(comparisonDynoVoltage), ...
    max(comparisonDynoVoltage));

disp(VoltageMetrics);

%% Create figure

figureHandle = figure( ...
    'Color','white', ...
    'Name','Run 004 Battery Voltage Comparison');

layout = tiledlayout(2,1, ...
    'TileSpacing','compact', ...
    'Padding','compact');

title(layout, ...
    'Run 004: EV6 Battery-Voltage Validation');

colors = [
    0.0000 0.4470 0.7410
    0.8500 0.3250 0.0980
    0.4660 0.6740 0.1880
    ];

nexttile;

plot(comparisonTime,comparisonDynoVoltage, ...
    'k','LineWidth',1.3);

hold on;

for modelIndex = 1:numberOfModels

    plot(comparisonTime, ...
        simulatedVoltage(:,modelIndex), ...
        'Color',colors(modelIndex,:), ...
        'LineWidth',1.0);
end

grid on;
xlabel('Time [s]');
ylabel('Voltage [V]');
title('Battery voltage');

legend( ...
    ["EV6 dyno";modelLabels], ...
    'Location','best');

nexttile;

for modelIndex = 1:numberOfModels

    plot(comparisonTime, ...
        simulatedVoltage(:,modelIndex) - ...
        comparisonDynoVoltage, ...
        'Color',colors(modelIndex,:), ...
        'LineWidth',1.0);

    hold on;
end

yline(0,'k--');
grid on;
xlabel('Time [s]');
ylabel('Simulation - dyno [V]');
title('Battery-voltage error');
legend(modelLabels,'Location','best');

%% Save results

figureFile = fullfile( ...
    outputFolder, ...
    'EV6_Run004_BatteryVoltage_ThreeCase_5to60s.png');

metricsFile = fullfile( ...
    outputFolder, ...
    'EV6_Run004_BatteryVoltage_ThreeCase_5to60s.csv');

exportgraphics(figureHandle,figureFile, ...
    'Resolution',300);

writetable(VoltageMetrics,metricsFile);

fprintf('\n===== VOLTAGE ANALYSIS COMPLETE =====\n');
fprintf('Figure:\n%s\n\n',figureFile);
fprintf('Metrics:\n%s\n',metricsFile);
fprintf('=====================================\n');