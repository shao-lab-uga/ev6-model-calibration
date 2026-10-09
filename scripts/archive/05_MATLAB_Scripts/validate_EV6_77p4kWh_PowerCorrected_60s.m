%% VALIDATE POWER-CORRECTED MODEL: RUN 004, 5-60 SECONDS

assert(exist('D004','var') == 1, ...
    'Run the session-resume script first.');

assert(exist('Original60Data','var') == 1, ...
    'Original 60-second data is not loaded.');

assert(exist('outPowerCorrected60','var') == 1, ...
    'Corrected full SimulationOutput is not loaded.');

outputFolder = fullfile( ...
    projectRoot,'Run004_Professor_Figures');

if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

%% Retrieve dyno battery signals

[tDynoCurrent,dynoCurrent_A,dynoCurrentName] = ...
    findDynoBatterySignal(D004,"current");

[tDynoVoltage,dynoVoltage_V,dynoVoltageName] = ...
    findDynoBatterySignal(D004,"voltage");

fprintf('\n===== DYNO BATTERY SIGNALS =====\n');
fprintf('Current signal = %s\n',dynoCurrentName);
fprintf('Voltage signal = %s\n',dynoVoltageName);
fprintf('Current range = %.3f to %.3f A\n', ...
    min(dynoCurrent_A),max(dynoCurrent_A));
fprintf('Voltage range = %.3f to %.3f V\n', ...
    min(dynoVoltage_V),max(dynoVoltage_V));
fprintf('================================\n');

%% Original 77.4-kWh model signals

originalCurrentTS = ...
    Original60Data.Run004_77p4_BattCurrentTS;

originalVoltageTS = ...
    Original60Data.Run004_77p4_BattVoltageTS;

%% Power-corrected model signals

correctedCurrentTS = ...
    outPowerCorrected60.get('battery_current');

correctedPowerTS = ...
    outPowerCorrected60.get('battery_power');

correctionCurrentTS = ...
    outPowerCorrected60.get('EV6CurrentCorrection_A');

correctionPowerTS = ...
    outPowerCorrected60.get('EV6PowerCorrection_kW');

%% Establish common comparison time

signalEndTimes = [ ...
    tDynoCurrent(end)
    tDynoVoltage(end)
    originalCurrentTS.Time(end)
    originalVoltageTS.Time(end)
    correctedCurrentTS.Time(end)
    correctedPowerTS.Time(end)];

comparisonStart_s = 5;
comparisonEnd_s = min([60;signalEndTimes]);

comparisonMask = ...
    tDynoCurrent >= comparisonStart_s & ...
    tDynoCurrent <= comparisonEnd_s;

tComparison = tDynoCurrent(comparisonMask);
dynoCurrentComparison_A = ...
    dynoCurrent_A(comparisonMask);

assert(numel(tComparison) > 100, ...
    'Too few comparison samples were found.');

%% Align voltage and simulation signals

dynoVoltageComparison_V = interpolateSignal( ...
    tDynoVoltage,dynoVoltage_V,tComparison);

originalCurrent_A = interpolateTimeseries( ...
    originalCurrentTS,tComparison);

originalVoltage_V = interpolateTimeseries( ...
    originalVoltageTS,tComparison);

correctedCurrent_A = interpolateTimeseries( ...
    correctedCurrentTS,tComparison);

correctedPowerRaw = interpolateTimeseries( ...
    correctedPowerTS,tComparison);

correctionCurrent_A = interpolateTimeseries( ...
    correctionCurrentTS,tComparison);

correctionPower_kW = interpolateTimeseries( ...
    correctionPowerTS,tComparison);

%% Interpret corrected battery-power units

if max(abs(correctedPowerRaw),[],'omitnan') > 1000
    correctedPower_kW = correctedPowerRaw/1000;
    correctedPowerInterpretation = "W divided by 1000";
else
    correctedPower_kW = correctedPowerRaw;
    correctedPowerInterpretation = "already kW";
end

%% Calculate battery power

dynoPower_kW = ...
    dynoCurrentComparison_A .* ...
    dynoVoltageComparison_V / 1000;

originalPower_kW = ...
    originalCurrent_A .* ...
    originalVoltage_V / 1000;

%% Recover corrected voltage from P = V*I

correctedVoltage_V = correctedPower_kW*1000 ./ ...
    correctedCurrent_A;

validCorrectedVoltage = ...
    isfinite(correctedVoltage_V) & ...
    abs(correctedCurrent_A) > 0.05 & ...
    correctedVoltage_V > 600 & ...
    correctedVoltage_V < 850;

assert(nnz(validCorrectedVoltage) > 100, ...
    'Corrected battery voltage could not be reconstructed.');

correctedVoltage_V = interpolateSignal( ...
    tComparison(validCorrectedVoltage), ...
    correctedVoltage_V(validCorrectedVoltage), ...
    tComparison);

fprintf('\nCorrected battery-power interpretation: %s\n', ...
    correctedPowerInterpretation);

%% Remove any remaining invalid samples

validComparison = ...
    isfinite(tComparison) & ...
    isfinite(dynoCurrentComparison_A) & ...
    isfinite(dynoVoltageComparison_V) & ...
    isfinite(dynoPower_kW) & ...
    isfinite(originalCurrent_A) & ...
    isfinite(originalVoltage_V) & ...
    isfinite(originalPower_kW) & ...
    isfinite(correctedCurrent_A) & ...
    isfinite(correctedVoltage_V) & ...
    isfinite(correctedPower_kW);

tComparison = tComparison(validComparison);

dynoCurrentComparison_A = ...
    dynoCurrentComparison_A(validComparison);

dynoVoltageComparison_V = ...
    dynoVoltageComparison_V(validComparison);

dynoPower_kW = dynoPower_kW(validComparison);

originalCurrent_A = ...
    originalCurrent_A(validComparison);

originalVoltage_V = ...
    originalVoltage_V(validComparison);

originalPower_kW = ...
    originalPower_kW(validComparison);

correctedCurrent_A = ...
    correctedCurrent_A(validComparison);

correctedVoltage_V = ...
    correctedVoltage_V(validComparison);

correctedPower_kW = ...
    correctedPower_kW(validComparison);

correctionCurrent_A = ...
    correctionCurrent_A(validComparison);

correctionPower_kW = ...
    correctionPower_kW(validComparison);

%% Electrical metrics

originalCurrentMetrics = calculateMetrics( ...
    dynoCurrentComparison_A,originalCurrent_A);

correctedCurrentMetrics = calculateMetrics( ...
    dynoCurrentComparison_A,correctedCurrent_A);

originalVoltageMetrics = calculateMetrics( ...
    dynoVoltageComparison_V,originalVoltage_V);

correctedVoltageMetrics = calculateMetrics( ...
    dynoVoltageComparison_V,correctedVoltage_V);

originalPowerMetrics = calculateMetrics( ...
    dynoPower_kW,originalPower_kW);

correctedPowerMetrics = calculateMetrics( ...
    dynoPower_kW,correctedPower_kW);

Signal = [ ...
    "Battery Current"
    "Battery Current"
    "Battery Voltage"
    "Battery Voltage"
    "Battery Power"
    "Battery Power"];

Model = [ ...
    "Original 77.4-kWh"
    "Power-corrected 77.4-kWh"
    "Original 77.4-kWh"
    "Power-corrected 77.4-kWh"
    "Original 77.4-kWh"
    "Power-corrected 77.4-kWh"];

Unit = ["A";"A";"V";"V";"kW";"kW"];

metricMatrix = [ ...
    originalCurrentMetrics
    correctedCurrentMetrics
    originalVoltageMetrics
    correctedVoltageMetrics
    originalPowerMetrics
    correctedPowerMetrics];

ElectricalMetrics = table( ...
    Signal,Model,Unit, ...
    metricMatrix(:,1), ...
    metricMatrix(:,2), ...
    metricMatrix(:,3), ...
    metricMatrix(:,4), ...
    metricMatrix(:,5), ...
    'VariableNames',{ ...
    'Signal','Model','Unit','Bias', ...
    'MAE','RMSE','MaxAbsError','Correlation'});

fprintf('\n===== RUN 004 POWER-CORRECTED ELECTRICAL METRICS =====\n');
disp(ElectricalMetrics);

%% Energy calculations

dynoEnergy = calculateEnergy( ...
    tComparison,dynoPower_kW);

originalEnergy = calculateEnergy( ...
    tComparison,originalPower_kW);

correctedEnergy = calculateEnergy( ...
    tComparison,correctedPower_kW);

Dataset = [ ...
    "EV6 dyno"
    "Original 77.4-kWh"
    "Power-corrected 77.4-kWh"];

NetEnergy_kWh = [ ...
    dynoEnergy(1)
    originalEnergy(1)
    correctedEnergy(1)];

PositiveEnergy_kWh = [ ...
    dynoEnergy(2)
    originalEnergy(2)
    correctedEnergy(2)];

RegenEnergyMagnitude_kWh = [ ...
    dynoEnergy(3)
    originalEnergy(3)
    correctedEnergy(3)];

EnergyMetrics = table( ...
    Dataset,NetEnergy_kWh, ...
    PositiveEnergy_kWh, ...
    RegenEnergyMagnitude_kWh);

fprintf('\n===== RUN 004 ENERGY: 5-60 SECONDS =====\n');
disp(EnergyMetrics);

originalNetError_Wh = ...
    1000*(originalEnergy(1)-dynoEnergy(1));

correctedNetError_Wh = ...
    1000*(correctedEnergy(1)-dynoEnergy(1));

originalPositiveError_pct = ...
    100*(originalEnergy(2)-dynoEnergy(2)) / ...
    dynoEnergy(2);

correctedPositiveError_pct = ...
    100*(correctedEnergy(2)-dynoEnergy(2)) / ...
    dynoEnergy(2);

originalRegenError_pct = ...
    100*(originalEnergy(3)-dynoEnergy(3)) / ...
    dynoEnergy(3);

correctedRegenError_pct = ...
    100*(correctedEnergy(3)-dynoEnergy(3)) / ...
    dynoEnergy(3);

fprintf('\n===== ENERGY-ERROR COMPARISON =====\n');
fprintf('Original net-energy difference = %.4f Wh\n', ...
    originalNetError_Wh);
fprintf('Corrected net-energy difference = %.4f Wh\n', ...
    correctedNetError_Wh);

fprintf('\nOriginal positive-energy error = %.3f %%\n', ...
    originalPositiveError_pct);
fprintf('Corrected positive-energy error = %.3f %%\n', ...
    correctedPositiveError_pct);

fprintf('\nOriginal regen-energy error = %.3f %%\n', ...
    originalRegenError_pct);
fprintf('Corrected regen-energy error = %.3f %%\n', ...
    correctedRegenError_pct);
fprintf('===================================\n');

%% Improvement summary

currentMAEImprovement_pct = 100 * ...
    (originalCurrentMetrics(2) - ...
     correctedCurrentMetrics(2)) / ...
    originalCurrentMetrics(2);

powerMAEImprovement_pct = 100 * ...
    (originalPowerMetrics(2) - ...
     correctedPowerMetrics(2)) / ...
    originalPowerMetrics(2);

absoluteEnergyImprovement_Wh = ...
    abs(originalNetError_Wh) - ...
    abs(correctedNetError_Wh);

fprintf('\n===== IMPLEMENTATION IMPROVEMENT =====\n');
fprintf('Current MAE improvement = %.3f %%\n', ...
    currentMAEImprovement_pct);
fprintf('Power MAE improvement = %.3f %%\n', ...
    powerMAEImprovement_pct);
fprintf('Absolute net-energy improvement = %.4f Wh\n', ...
    absoluteEnergyImprovement_Wh);
fprintf('Corrected current correlation = %.5f\n', ...
    correctedCurrentMetrics(5));
fprintf('======================================\n');

implementationPasses = ...
    absoluteEnergyImprovement_Wh > 0 && ...
    correctedCurrentMetrics(5) > 0.95 && ...
    correctedCurrentMetrics(2) <= ...
        originalCurrentMetrics(2) + 0.10;

if implementationPasses
    fprintf(['RESULT: PASS. The physical Simulink correction ' ...
        'improves energy without materially degrading current.\n']);
else
    fprintf(['RESULT: REVIEW. Inspect the metrics before ' ...
        'starting a full-cycle simulation.\n']);
end

%% Cumulative energy

dynoCumulativeEnergy_Wh = ...
    cumtrapz(tComparison,dynoPower_kW)/3.6;

originalCumulativeEnergy_Wh = ...
    cumtrapz(tComparison,originalPower_kW)/3.6;

correctedCumulativeEnergy_Wh = ...
    cumtrapz(tComparison,correctedPower_kW)/3.6;

%% Figure

validationFigure = figure( ...
    'Color','w', ...
    'Name','EV6 Power-Corrected 60-Second Validation');

tiledlayout(3,2, ...
    'TileSpacing','compact', ...
    'Padding','compact');

nexttile([1 2]);

plot(tComparison,dynoCurrentComparison_A, ...
    'k','LineWidth',1.2);
hold on;

plot(tComparison,originalCurrent_A, ...
    'b','LineWidth',0.9);

plot(tComparison,correctedCurrent_A, ...
    'r','LineWidth',0.9);

grid on;
xlabel('Time [s]');
ylabel('Current [A]');
title('Battery current');
legend('EV6 dyno','Original 77.4-kWh', ...
    'Power-corrected 77.4-kWh', ...
    'Location','best');

nexttile;

plot(tComparison,dynoVoltageComparison_V, ...
    'k','LineWidth',1.2);
hold on;

plot(tComparison,originalVoltage_V, ...
    'b','LineWidth',0.9);

plot(tComparison,correctedVoltage_V, ...
    'r','LineWidth',0.9);

grid on;
xlabel('Time [s]');
ylabel('Voltage [V]');
title('Battery voltage');

nexttile;

plot(tComparison,dynoPower_kW, ...
    'k','LineWidth',1.2);
hold on;

plot(tComparison,originalPower_kW, ...
    'b','LineWidth',0.9);

plot(tComparison,correctedPower_kW, ...
    'r','LineWidth',0.9);

grid on;
xlabel('Time [s]');
ylabel('Power [kW]');
title('Battery power');

nexttile;

plot(tComparison,correctionPower_kW, ...
    'm','LineWidth',1);

yline(0,'k--');

grid on;
xlabel('Time [s]');
ylabel('Correction [kW]');
title('Applied power correction');

nexttile;

plot(tComparison,dynoCumulativeEnergy_Wh, ...
    'k','LineWidth',1.2);
hold on;

plot(tComparison,originalCumulativeEnergy_Wh, ...
    'b','LineWidth',0.9);

plot(tComparison,correctedCumulativeEnergy_Wh, ...
    'r','LineWidth',0.9);

grid on;
xlabel('Time [s]');
ylabel('Net energy [Wh]');
title('Cumulative net battery energy');
legend('EV6 dyno','Original','Power-corrected', ...
    'Location','best');

sgtitle( ...
    'Run 004: 77.4-kWh Power-Correction Validation, 5-60 Seconds');

%% Save results

figureFile = fullfile( ...
    outputFolder, ...
    'EV6_Run004_77p4kWh_PowerCorrected_Validation_5to60s.png');

electricalMetricsFile = fullfile( ...
    outputFolder, ...
    'EV6_Run004_77p4kWh_PowerCorrected_ElectricalMetrics_5to60s.csv');

energyMetricsFile = fullfile( ...
    outputFolder, ...
    'EV6_Run004_77p4kWh_PowerCorrected_EnergyMetrics_5to60s.csv');

validationResultFile = fullfile( ...
    outputFolder, ...
    'EV6_Run004_77p4kWh_PowerCorrected_Validation_5to60s.mat');

exportgraphics(validationFigure,figureFile, ...
    'Resolution',300);

writetable(ElectricalMetrics, ...
    electricalMetricsFile);

writetable(EnergyMetrics, ...
    energyMetricsFile);

save(validationResultFile, ...
    'ElectricalMetrics', ...
    'EnergyMetrics', ...
    'implementationPasses', ...
    'originalNetError_Wh', ...
    'correctedNetError_Wh', ...
    'currentMAEImprovement_pct', ...
    'powerMAEImprovement_pct', ...
    'absoluteEnergyImprovement_Wh', ...
    'tComparison', ...
    'dynoCurrentComparison_A', ...
    'originalCurrent_A', ...
    'correctedCurrent_A', ...
    'dynoVoltageComparison_V', ...
    'originalVoltage_V', ...
    'correctedVoltage_V', ...
    'dynoPower_kW', ...
    'originalPower_kW', ...
    'correctedPower_kW', ...
    'correctionPower_kW', ...
    '-v7.3');

fprintf('\n===== VALIDATION COMPLETE =====\n');
fprintf('Figure:\n%s\n',figureFile);
fprintf('\nElectrical metrics:\n%s\n', ...
    electricalMetricsFile);
fprintf('\nEnergy metrics:\n%s\n', ...
    energyMetricsFile);
fprintf('\nMAT results:\n%s\n', ...
    validationResultFile);
fprintf('===============================\n');

%% Local functions

function [time,data,matchedName] = ...
    findDynoBatterySignal(D,signalType)

    names = erase(string({D.Y.Name}),["<",">"]);
    lowerNames = lower(names);

    scores = -inf(numel(names),1);

    for k = 1:numel(names)

        currentName = lowerNames(k);
        score = 0;

        try
            currentData = double(D.Y(k).Data(:));
        catch
            continue
        end

        currentData = currentData(isfinite(currentData));

        if isempty(currentData)
            continue
        end

        if contains(currentName,"batt") || ...
           contains(currentName,"battery")
            score = score + 8;
        end

        if contains(currentName,"hv")
            score = score + 3;
        end

        switch signalType

            case "current"

                if contains(currentName,"curr") || ...
                   contains(currentName,"current")
                    score = score + 10;
                else
                    continue
                end

                if contains(currentName,"volt")
                    score = score - 20;
                end

                maximumMagnitude = ...
                    max(abs(currentData));

                if maximumMagnitude > 5 && ...
                   maximumMagnitude < 1000
                    score = score + 4;
                end

            case "voltage"

                if contains(currentName,"volt") || ...
                   contains(currentName,"voltage")
                    score = score + 10;
                else
                    continue
                end

                if contains(currentName,"curr")
                    score = score - 20;
                end

                medianValue = median(currentData);

                if medianValue > 500 && ...
                   medianValue < 1000
                    score = score + 8;
                end
        end

        scores(k) = score;
    end

    [bestScore,bestIndex] = max(scores);

    assert(isfinite(bestScore) && bestScore > 5, ...
        'A dyno battery %s signal could not be identified.', ...
        signalType);

    matchedName = names(bestIndex);

    timeIndex = D.Y(bestIndex).XIndex;

    time = double(D.X(timeIndex).Data(:));
    data = double(D.Y(bestIndex).Data(:));

    valid = isfinite(time) & isfinite(data);

    time = time(valid);
    data = data(valid);

    [time,uniqueIndices] = unique(time,'stable');
    data = data(uniqueIndices);
end

function values = interpolateTimeseries(signal,tQuery)

    assert(isa(signal,'timeseries'), ...
        'Expected a timeseries but received %s.', ...
        class(signal));

    time = double(signal.Time(:));
    data = double(signal.Data(:));

    values = interpolateSignal(time,data,tQuery);
end

function values = interpolateSignal(time,data,tQuery)

    time = double(time(:));
    data = double(data(:));
    tQuery = double(tQuery(:));

    valid = isfinite(time) & isfinite(data);

    time = time(valid);
    data = data(valid);

    [time,uniqueIndices] = unique(time,'stable');
    data = data(uniqueIndices);

    assert(numel(time) >= 2, ...
        'Signal has too few valid samples.');

    values = interp1( ...
        time,data,tQuery,'linear','extrap');
end

function metrics = calculateMetrics(reference,simulation)

    reference = double(reference(:));
    simulation = double(simulation(:));

    error = simulation-reference;

    bias = mean(error);
    mae = mean(abs(error));
    rmse = sqrt(mean(error.^2));
    maxAbsError = max(abs(error));

    referenceCentered = ...
        reference-mean(reference);

    simulationCentered = ...
        simulation-mean(simulation);

    denominator = sqrt( ...
        sum(referenceCentered.^2) * ...
        sum(simulationCentered.^2));

    if denominator > 0
        correlation = sum( ...
            referenceCentered .* ...
            simulationCentered) / denominator;
    else
        correlation = NaN;
    end

    metrics = [ ...
        bias,mae,rmse,maxAbsError,correlation];
end

function energy = calculateEnergy(time,power_kW)

    time = double(time(:));
    power_kW = double(power_kW(:));

    netEnergy_kWh = ...
        trapz(time,power_kW)/3600;

    positiveEnergy_kWh = ...
        trapz(time,max(power_kW,0))/3600;

    regenEnergyMagnitude_kWh = ...
        trapz(time,max(-power_kW,0))/3600;

    energy = [ ...
        netEnergy_kWh, ...
        positiveEnergy_kWh, ...
        regenEnergyMagnitude_kWh];
end