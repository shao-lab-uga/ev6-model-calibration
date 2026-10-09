%% EV6 POWER/CURRENT RESIDUALS BY SPEED AND OPERATING MODE
% Uses the saved full simulation outputs. No Simulink parameters are changed.
% Runs 001-003 are treated as training data. Run 004 remains validation.

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
runLabels  = "Run" + compose('%03d',runNumbers);
runRoles   = ["Training";"Training";"Training";"Validation"];

dynoFiles = strings(4,1);
simFiles  = strings(4,1);

for k = 1:4
    runCode = compose('%03d',runNumbers(k));
    dynoFiles(k) = fullfile(dynoRoot, ...
        "standards_test_08142026_" + runCode + ".mat");
    simFiles(k) = fullfile(projectRoot, ...
        "EV6_Run" + runCode + ...
        "_77p4kWh_Corrected_Full_Output.mat");
end

for k = 1:4
    assert(isfile(dynoFiles(k)), ...
        'Dyno file was not found:\n%s',dynoFiles(k));
    assert(isfile(simFiles(k)), ...
        'Simulation output was not found:\n%s',simFiles(k));
end

comparisonStart_s = 5;
modeThreshold_kW = 0.5;
minimumPlotSamples = 1000;

% All four cycles remain below 30 m/s.
speedEdges_mps = [0 2.5 5 7.5 10 12.5 15 20 25 30];
speedCenters_mps = 0.5*(speedEdges_mps(1:end-1) + ...
    speedEdges_mps(2:end));

modeNames = ["Traction";"Regeneration";"Low-power/idle"];

resultRows = cell(0,14);

fprintf('\n===== POWER/CURRENT ERROR BY SPEED =====\n');

for runIndex = 1:4
    fprintf('\nLoading %s (%s)...\n', ...
        runLabels(runIndex),runRoles(runIndex));

    %% Load dyno data
    loadedDyno = load(dynoFiles(runIndex));
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
        'No dyno structure with X and Y fields was found in %s.', ...
        dynoFiles(runIndex));

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

    %% Load saved simulation output
    loadedSim = load(simFiles(runIndex));
    simulationOutput = findSimulationOutput(loadedSim);

    [tSimPower_s,simPowerRaw] = getOutputTimeseries( ...
        simulationOutput,'battery_power');
    [tSimCurrent_s,simCurrent_A] = getOutputTimeseries( ...
        simulationOutput,'battery_current');

    simPower_kW = double(simPowerRaw(:));
    finitePower = abs(simPower_kW(isfinite(simPower_kW)));
    assert(~isempty(finitePower), ...
        'The simulated battery-power signal contains no finite values.');

    % The present EV6 model stores battery_power in watts.
    if max(finitePower) > 1000
        simPower_kW = simPower_kW/1000;
    end

    simPowerAligned_kW = alignSignal( ...
        tSimPower_s,simPower_kW,tDyno_s);
    simCurrentAligned_A = alignSignal( ...
        tSimCurrent_s,simCurrent_A,tDyno_s);

    valid = tDyno_s >= comparisonStart_s & ...
        isfinite(dynoPower_kW) & ...
        isfinite(simPowerAligned_kW) & ...
        isfinite(dynoCurrent_A) & ...
        isfinite(simCurrentAligned_A) & ...
        isfinite(dynoSpeed_mps);

    t = tDyno_s(valid);
    speed = dynoSpeed_mps(valid);
    dynoPower = dynoPower_kW(valid);
    simPower = simPowerAligned_kW(valid);
    dynoCurrent = dynoCurrent_A(valid);
    simCurrent = simCurrentAligned_A(valid);

    powerError = simPower - dynoPower;
    currentError = simCurrent - dynoCurrent;

    modeMasks = { ...
        dynoPower > modeThreshold_kW, ...
        dynoPower < -modeThreshold_kW, ...
        abs(dynoPower) <= modeThreshold_kW};

    speedBin = discretize(speed,speedEdges_mps);
    validRunSamples = numel(t);

    for modeIndex = 1:numel(modeNames)
        for binIndex = 1:numel(speedCenters_mps)
            selected = modeMasks{modeIndex} & speedBin == binIndex;
            sampleCount = nnz(selected);

            if sampleCount == 0
                continue;
            end

            meanPowerError = mean(powerError(selected));
            meanCurrentError = mean(currentError(selected));

            speedText = sprintf('%.1f-%.1f', ...
                speedEdges_mps(binIndex), ...
                speedEdges_mps(binIndex+1));

            resultRows(end+1,:) = { ...
                runLabels(runIndex), ...
                runRoles(runIndex), ...
                modeNames(modeIndex), ...
                string(speedText), ...
                speedCenters_mps(binIndex), ...
                sampleCount, ...
                100*sampleCount/validRunSamples, ...
                meanPowerError, ...
                -meanPowerError, ...
                mean(abs(powerError(selected))), ...
                meanCurrentError, ...
                -meanCurrentError, ...
                mean(abs(currentError(selected))), ...
                mean(speed(selected))}; %#ok<SAGROW>
        end
    end

    fprintf('  Valid samples = %d\n',validRunSamples);
    fprintf('  Speed range = %.3f to %.3f m/s\n', ...
        min(speed),max(speed));
end

SpeedBinMetrics = cell2table(resultRows, ...
    'VariableNames',{ ...
    'Run','Role','Mode','SpeedBin_mps','SpeedCenter_mps', ...
    'Samples','RunTimeFraction_pct','MeanPowerError_kW', ...
    'RequiredPowerCorrection_kW','PowerMAE_kW', ...
    'MeanCurrentError_A','RequiredCurrentCorrection_A', ...
    'CurrentMAE_A','MeanSpeed_mps'});

SpeedBinMetrics = sortrows(SpeedBinMetrics, ...
    {'Mode','SpeedCenter_mps','Run'});

%% Weighted Runs 001-003 training summary
summaryRows = cell(0,10);

for modeIndex = 1:numel(modeNames)
    for binIndex = 1:numel(speedCenters_mps)
        selected = SpeedBinMetrics.Role == "Training" & ...
            SpeedBinMetrics.Mode == modeNames(modeIndex) & ...
            SpeedBinMetrics.SpeedCenter_mps == speedCenters_mps(binIndex);

        if ~any(selected)
            continue;
        end

        subTable = SpeedBinMetrics(selected,:);
        weights = subTable.Samples;
        totalSamples = sum(weights);

        weightedPowerError = sum( ...
            weights.*subTable.MeanPowerError_kW)/totalSamples;
        weightedPowerMAE = sum( ...
            weights.*subTable.PowerMAE_kW)/totalSamples;
        weightedCurrentError = sum( ...
            weights.*subTable.MeanCurrentError_A)/totalSamples;
        weightedCurrentMAE = sum( ...
            weights.*subTable.CurrentMAE_A)/totalSamples;

        speedText = sprintf('%.1f-%.1f', ...
            speedEdges_mps(binIndex),speedEdges_mps(binIndex+1));

        summaryRows(end+1,:) = { ...
            modeNames(modeIndex),string(speedText), ...
            speedCenters_mps(binIndex),totalSamples, ...
            weightedPowerError,-weightedPowerError, ...
            weightedPowerMAE,weightedCurrentError, ...
            -weightedCurrentError,weightedCurrentMAE}; %#ok<SAGROW>
    end
end

TrainingSpeedBinSummary = cell2table(summaryRows, ...
    'VariableNames',{ ...
    'Mode','SpeedBin_mps','SpeedCenter_mps','Samples', ...
    'MeanPowerError_kW','RequiredPowerCorrection_kW', ...
    'PowerMAE_kW','MeanCurrentError_A', ...
    'RequiredCurrentCorrection_A','CurrentMAE_A'});

%% Plot power and current corrections
figure('Color','w','Name','EV6 speed-binned residual diagnostic');
tiledlayout(3,2,'TileSpacing','compact','Padding','compact');

runColors = lines(4);

for modeIndex = 1:numel(modeNames)
    nexttile;
    hold on;

    for runIndex = 1:4
        selected = SpeedBinMetrics.Run == runLabels(runIndex) & ...
            SpeedBinMetrics.Mode == modeNames(modeIndex) & ...
            SpeedBinMetrics.Samples >= minimumPlotSamples;
        plotStyle = '-o';
        if runIndex == 4
            plotStyle = '--s';
        end
        plot(SpeedBinMetrics.SpeedCenter_mps(selected), ...
            SpeedBinMetrics.RequiredPowerCorrection_kW(selected), ...
            plotStyle,'Color',runColors(runIndex,:), ...
            'LineWidth',1.2,'MarkerSize',4, ...
            'DisplayName',runLabels(runIndex));
    end

    yline(0,'k:','HandleVisibility','off');
    grid on;
    ylabel('Power correction [kW]');
    title(modeNames(modeIndex));
    if modeIndex == 3
        xlabel('Dyno vehicle speed [m/s]');
    end
    if modeIndex == 1
        legend('Location','best');
    end

    nexttile;
    hold on;

    for runIndex = 1:4
        selected = SpeedBinMetrics.Run == runLabels(runIndex) & ...
            SpeedBinMetrics.Mode == modeNames(modeIndex) & ...
            SpeedBinMetrics.Samples >= minimumPlotSamples;
        plotStyle = '-o';
        if runIndex == 4
            plotStyle = '--s';
        end
        plot(SpeedBinMetrics.SpeedCenter_mps(selected), ...
            SpeedBinMetrics.RequiredCurrentCorrection_A(selected), ...
            plotStyle,'Color',runColors(runIndex,:), ...
            'LineWidth',1.2,'MarkerSize',4, ...
            'DisplayName',runLabels(runIndex));
    end

    yline(0,'k:','HandleVisibility','off');
    grid on;
    ylabel('Current correction [A]');
    title(modeNames(modeIndex));
    if modeIndex == 3
        xlabel('Dyno vehicle speed [m/s]');
    end
end

sgtitle(['EV6 power/current residuals by speed: ' ...
    'Runs 001-003 training, Run 004 validation']);

figureFile = fullfile(outputFolder, ...
    'EV6_PowerCurrent_Error_BySpeed.png');
metricsFile = fullfile(outputFolder, ...
    'EV6_PowerCurrent_Error_BySpeed_AllRuns.csv');
summaryFile = fullfile(outputFolder, ...
    'EV6_PowerCurrent_Error_BySpeed_TrainingSummary.csv');
resultsFile = fullfile(outputFolder, ...
    'EV6_PowerCurrent_Error_BySpeed_Results.mat');

exportgraphics(gcf,figureFile,'Resolution',200);
writetable(SpeedBinMetrics,metricsFile);
writetable(TrainingSpeedBinSummary,summaryFile);
save(resultsFile,'SpeedBinMetrics','TrainingSpeedBinSummary', ...
    'speedEdges_mps','modeThreshold_kW');

fprintf('\n===== SPEED-BINNED DIAGNOSTIC COMPLETE =====\n');
fprintf('Positive correction means the model needs more battery power/current.\n');
fprintf('Run 004 is validation and was not used in the training summary.\n\n');
disp(TrainingSpeedBinSummary);
fprintf('Figure:\n%s\n\n',figureFile);
fprintf('All-run metrics:\n%s\n\n',metricsFile);
fprintf('Training summary:\n%s\n\n',summaryFile);
fprintf('MAT results:\n%s\n',resultsFile);
fprintf('No Simulink parameters were changed.\n');
fprintf('=============================================\n');

%% Local functions
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
