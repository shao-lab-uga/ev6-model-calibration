%% RUN 004 BATTERY POWER AND ENERGY: 5-60 SECONDS
% Run the battery-voltage analysis first.
% No new Simulink simulation is required.

assert(exist('comparisonTime','var') == 1, ...
    'Run the battery-voltage analysis first.');

assert(exist('comparisonDynoVoltage','var') == 1, ...
    'Dyno voltage data is missing.');

assert(exist('simulatedVoltage','var') == 1, ...
    'Simulated voltage data is missing.');

assert(exist('D004','var') == 1, ...
    'D004 is missing. Run the voltage analysis again.');

projectRoot = ['C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\Vehicles_24a\Vehicles\' ...
    'VehicleProjects\Bolt_EV'];

outputFolder = fullfile(projectRoot,'Run004_Professor_Figures');

if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

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

%% Get dyno battery current

channelNames004 = erase(string({D004.Y.Name}),["<",">"]);

currentChannel = find( ...
    channelNames004 == "VEH_batCurrent",1,'first');

assert(~isempty(currentChannel), ...
    'VEH_batCurrent was not found.');

currentTimeIndex = D004.Y(currentChannel).XIndex;

dynoCurrentTime = double( ...
    D004.X(currentTimeIndex).Data(:));

dynoCurrentData = double( ...
    D004.Y(currentChannel).Data(:));

validDyno = ...
    isfinite(dynoCurrentTime) & ...
    isfinite(dynoCurrentData);

dynoCurrentTime = dynoCurrentTime(validDyno);
dynoCurrentData = dynoCurrentData(validDyno);

comparisonDynoCurrent = interp1( ...
    dynoCurrentTime, ...
    dynoCurrentData, ...
    comparisonTime, ...
    'linear',NaN);

%% Extract simulated current from the three SDI runs

simulatedCurrent = nan( ...
    numel(comparisonTime),numberOfModels);

allRunIDs = Simulink.sdi.getAllRunIDs;

for modelIndex = 1:numberOfModels

    selectedRunID = [];

    for runIndex = 1:numel(allRunIDs)

        currentRun = Simulink.sdi.getRun( ...
            allRunIDs(runIndex));

        if string(currentRun.Name) == runNames(modelIndex)
            selectedRunID = allRunIDs(runIndex);
        end
    end

    assert(~isempty(selectedRunID), ...
        'SDI run was not found: %s',runNames(modelIndex));

    selectedRun = Simulink.sdi.getRun(selectedRunID);

    signalIDs = selectedRun.getAllSignalIDs;
    signalNames = strings(numel(signalIDs),1);

    for signalIndex = 1:numel(signalIDs)

        currentSignal = Simulink.sdi.getSignal( ...
            signalIDs(signalIndex));

        signalNames(signalIndex) = ...
            string(currentSignal.Name);
    end

    preferredNames = [
        "SimMonitor.Veh.Batt.BattCurr"
        "<BattCurr>"
        "BattCurr"
        ];

    selectedSignalIndex = [];

    for nameIndex = 1:numel(preferredNames)

        selectedSignalIndex = find( ...
            strcmpi(signalNames,preferredNames(nameIndex)), ...
            1,'first');

        if ~isempty(selectedSignalIndex)
            break
        end
    end

    if isempty(selectedSignalIndex)

        selectedSignalIndex = find( ...
            contains(lower(signalNames),"battcurr"), ...
            1,'first');
    end

    assert(~isempty(selectedSignalIndex), ...
        'Battery current was not found in %s.', ...
        runNames(modelIndex));

    currentSignal = Simulink.sdi.getSignal( ...
        signalIDs(selectedSignalIndex));

    currentValues = currentSignal.Values;

    simulatedTime = double(currentValues.Time(:));
    simulatedData = double(currentValues.Data(:));

    validSimulation = ...
        isfinite(simulatedTime) & ...
        isfinite(simulatedData);

    simulatedTime = simulatedTime(validSimulation);
    simulatedData = simulatedData(validSimulation);

    [simulatedTime,uniqueIndices] = ...
        unique(simulatedTime,'stable');

    simulatedData = simulatedData(uniqueIndices);

    simulatedCurrent(:,modelIndex) = interp1( ...
        simulatedTime, ...
        simulatedData, ...
        comparisonTime, ...
        'linear',NaN);
end

%% Calculate battery power

% Voltage [V] times current [A] gives power [W].
% Dividing by 1000 converts W to kW.

dynoPower_kW = ...
    comparisonDynoVoltage .* ...
    comparisonDynoCurrent / 1000;

simulatedPower_kW = ...
    simulatedVoltage .* ...
    simulatedCurrent / 1000;

%% Power-error metrics

Bias_kW = nan(numberOfModels,1);
MAE_kW = nan(numberOfModels,1);
RMSE_kW = nan(numberOfModels,1);
MaxAbsError_kW = nan(numberOfModels,1);
Correlation = nan(numberOfModels,1);

for modelIndex = 1:numberOfModels

    measurement = dynoPower_kW;
    simulation = simulatedPower_kW(:,modelIndex);

    valid = ...
        isfinite(measurement) & ...
        isfinite(simulation);

    measurement = measurement(valid);
    simulation = simulation(valid);

    powerError = simulation - measurement;

    Bias_kW(modelIndex) = mean(powerError);
    MAE_kW(modelIndex) = mean(abs(powerError));
    RMSE_kW(modelIndex) = ...
        sqrt(mean(powerError.^2));

    MaxAbsError_kW(modelIndex) = ...
        max(abs(powerError));

    measurementCentered = ...
        measurement - mean(measurement);

    simulationCentered = ...
        simulation - mean(simulation);

    Correlation(modelIndex) = ...
        sum(measurementCentered .* simulationCentered) / ...
        sqrt( ...
        sum(measurementCentered.^2) * ...
        sum(simulationCentered.^2));
end

PowerMetrics = table( ...
    modelLabels, ...
    Bias_kW, ...
    MAE_kW, ...
    RMSE_kW, ...
    MaxAbsError_kW, ...
    Correlation, ...
    'VariableNames',{ ...
    'Model', ...
    'Bias_kW', ...
    'MAE_kW', ...
    'RMSE_kW', ...
    'MaxAbsError_kW', ...
    'Correlation'});

%% Integrate power to calculate energy

allLabels = ["EV6 dyno";modelLabels];

allPower_kW = [
    dynoPower_kW, ...
    simulatedPower_kW
    ];

numberOfCases = size(allPower_kW,2);

NetEnergy_kWh = nan(numberOfCases,1);
PositiveEnergy_kWh = nan(numberOfCases,1);
RegenEnergyMagnitude_kWh = nan(numberOfCases,1);

for caseIndex = 1:numberOfCases

    currentPower = allPower_kW(:,caseIndex);

    valid = ...
        isfinite(comparisonTime) & ...
        isfinite(currentPower);

    currentTime = comparisonTime(valid);
    currentPower = currentPower(valid);

    NetEnergy_kWh(caseIndex) = ...
        trapz(currentTime,currentPower) / 3600;

    PositiveEnergy_kWh(caseIndex) = ...
        trapz(currentTime,max(currentPower,0)) / 3600;

    RegenEnergyMagnitude_kWh(caseIndex) = ...
        -trapz(currentTime,min(currentPower,0)) / 3600;
end

NetEnergyError_Wh = ...
    1000 * (NetEnergy_kWh - NetEnergy_kWh(1));

PositiveEnergyError_pct = ...
    100 * (PositiveEnergy_kWh - PositiveEnergy_kWh(1)) ...
    / PositiveEnergy_kWh(1);

RegenEnergyError_pct = ...
    100 * (RegenEnergyMagnitude_kWh - ...
    RegenEnergyMagnitude_kWh(1)) ...
    / RegenEnergyMagnitude_kWh(1);

EnergyMetrics = table( ...
    allLabels, ...
    NetEnergy_kWh, ...
    PositiveEnergy_kWh, ...
    RegenEnergyMagnitude_kWh, ...
    NetEnergyError_Wh, ...
    PositiveEnergyError_pct, ...
    RegenEnergyError_pct, ...
    'VariableNames',{ ...
    'Model', ...
    'NetEnergy_kWh', ...
    'PositiveEnergy_kWh', ...
    'RegenEnergyMagnitude_kWh', ...
    'NetEnergyError_Wh', ...
    'PositiveEnergyError_pct', ...
    'RegenEnergyError_pct'});

fprintf('\n===== RUN 004 BATTERY POWER: 5-60 SECONDS =====\n');
disp(PowerMetrics);

fprintf('\n===== RUN 004 BATTERY ENERGY: 5-60 SECONDS =====\n');
disp(EnergyMetrics);

%% Create figure

figureHandle = figure( ...
    'Color','white', ...
    'Name','Run 004 Battery Power and Energy');

layout = tiledlayout(3,1, ...
    'TileSpacing','compact', ...
    'Padding','compact');

title(layout, ...
    'Run 004: EV6 Battery Power and Energy, 5-60 Seconds');

colors = [
    0.0000 0.4470 0.7410
    0.8500 0.3250 0.0980
    0.4660 0.6740 0.1880
    ];

%% Power plot

nexttile;

plot(comparisonTime,dynoPower_kW, ...
    'k','LineWidth',1.3);

hold on;

for modelIndex = 1:numberOfModels

    plot(comparisonTime, ...
        simulatedPower_kW(:,modelIndex), ...
        'Color',colors(modelIndex,:), ...
        'LineWidth',1.0);
end

grid on;
ylabel('Power [kW]');
title('Battery power');

legend( ...
    ["EV6 dyno";modelLabels], ...
    'Location','best');

%% Power-error plot

nexttile;

for modelIndex = 1:numberOfModels

    plot(comparisonTime, ...
        simulatedPower_kW(:,modelIndex) - dynoPower_kW, ...
        'Color',colors(modelIndex,:), ...
        'LineWidth',1.0);

    hold on;
end

yline(0,'k--');
grid on;
ylabel('Error [kW]');
title('Simulation power minus dyno power');
legend(modelLabels,'Location','best');

%% Cumulative energy plot

nexttile;

dynoCumulativeEnergy_Wh = ...
    1000*cumtrapz(comparisonTime,dynoPower_kW)/3600;

plot(comparisonTime,dynoCumulativeEnergy_Wh, ...
    'k','LineWidth',1.3);

hold on;

for modelIndex = 1:numberOfModels

    cumulativeEnergy_Wh = ...
        1000*cumtrapz( ...
        comparisonTime, ...
        simulatedPower_kW(:,modelIndex)) / 3600;

    plot(comparisonTime,cumulativeEnergy_Wh, ...
        'Color',colors(modelIndex,:), ...
        'LineWidth',1.0);
end

grid on;
xlabel('Time [s]');
ylabel('Net energy [Wh]');
title('Cumulative net battery energy');

legend( ...
    ["EV6 dyno";modelLabels], ...
    'Location','best');

%% Save outputs

figureFile = fullfile( ...
    outputFolder, ...
    'EV6_Run004_BatteryPowerEnergy_ThreeCase_5to60s.png');

powerFile = fullfile( ...
    outputFolder, ...
    'EV6_Run004_BatteryPower_ThreeCase_5to60s.csv');

energyFile = fullfile( ...
    outputFolder, ...
    'EV6_Run004_BatteryEnergy_ThreeCase_5to60s.csv');

exportgraphics(figureHandle,figureFile, ...
    'Resolution',300);

writetable(PowerMetrics,powerFile);
writetable(EnergyMetrics,energyFile);

fprintf('\n===== POWER AND ENERGY ANALYSIS COMPLETE =====\n');
fprintf('Figure:\n%s\n\n',figureFile);
fprintf('Power metrics:\n%s\n\n',powerFile);
fprintf('Energy metrics:\n%s\n',energyFile);
fprintf('==============================================\n');