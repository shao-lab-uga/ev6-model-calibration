%% EV6 BATTERY LEAST-SQUARES PARAMETER IDENTIFICATION
%
% Model:
%
%   V(t) = V0_run + K_run*DeltaAh(t) - Rpack*I(t)
%
% V0_run = estimated zero-current voltage at start of each run
% K_run  = voltage change per discharged amp-hour
% Rpack  = common effective pack resistance
%
% Positive battery current is treated as discharge.

%% 1. PATHS AND DATA

projectRoot = ['C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\Vehicles_24a\Vehicles\' ...
    'VehicleProjects\Bolt_EV'];

trainingFile = fullfile( ...
    projectRoot,'EV6_Battery_TrainingData_Runs001_003.mat');

assert(isfile(trainingFile), ...
    'Battery training-data file was not found:\n%s',trainingFile);

load(trainingFile,'BatteryTrainingData');

parameterFile = fullfile( ...
    projectRoot,'Original_Battery_ResolvedParameters.mat');

if ~exist('OriginalBatteryData','var')
    assert(isfile(parameterFile), ...
        'Original battery parameter file was not found:\n%s', ...
        parameterFile);

    parameterData = load(parameterFile,'OriginalBatteryData');
    OriginalBatteryData = parameterData.OriginalBatteryData;
end

outputFolder = fullfile(projectRoot,'Battery_Calibration');

if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

runNames = ["Run001";"Run002";"Run003"];
numberOfRuns = numel(runNames);

%% 2. PREPROCESSING SETTINGS

excludeInitialTime_s = 5;

% Original data is sampled at approximately 1000 Hz.
% A 100-point moving average and decimation of 100 produce
% approximately 10-Hz fitting data.
movingAverageSamples = 100;
decimationFactor = 100;

FitData = struct;

fprintf('\n===== PREPARING LEAST-SQUARES DATA =====\n');

totalFitSamples = 0;

for runIndex = 1:numberOfRuns

    runName = runNames(runIndex);
    currentRun = BatteryTrainingData.(runName);

    t = double(currentRun.Time_s(:));
    I = double(currentRun.Current_A(:));
    V = double(currentRun.Voltage_V(:));

    valid = ...
        isfinite(t) & ...
        isfinite(I) & ...
        isfinite(V) & ...
        t >= excludeInitialTime_s;

    t = t(valid);
    I = I(valid);
    V = V(valid);

    % Start each run's fit at zero elapsed time
    t = t - t(1);

    % Reduce high-frequency measurement noise
    I_filtered = movmean(I,movingAverageSamples);
    V_filtered = movmean(V,movingAverageSamples);

    % Positive current increases discharged amp-hours
    dischargedAh = cumtrapz(t,I_filtered)/3600;
    dischargedAh = dischargedAh - dischargedAh(1);

    sampleIndex = (1:decimationFactor:numel(t))';

    FitData.(runName).Time_s = t(sampleIndex);
    FitData.(runName).Current_A = I_filtered(sampleIndex);
    FitData.(runName).Voltage_V = V_filtered(sampleIndex);
    FitData.(runName).DischargedAh = dischargedAh(sampleIndex);

    numberOfFitSamples = numel(sampleIndex);
    totalFitSamples = totalFitSamples + numberOfFitSamples;

    fprintf('%s fitting samples = %d\n', ...
        runName,numberOfFitSamples);
end

fprintf('Total fitting samples = %d\n',totalFitSamples);
fprintf('==========================================\n');

%% 3. BUILD COMBINED LEAST-SQUARES MATRIX
%
% Columns:
%   1-3 = separate voltage intercept for each run
%   4-6 = separate voltage/Ah slope for each run
%   7   = common pack resistance

numberOfParameters = 2*numberOfRuns + 1;

X = zeros(totalFitSamples,numberOfParameters);
measuredVoltage = zeros(totalFitSamples,1);
sampleRunIndex = zeros(totalFitSamples,1);

firstRow = 1;

for runIndex = 1:numberOfRuns

    runName = runNames(runIndex);

    I = FitData.(runName).Current_A;
    V = FitData.(runName).Voltage_V;
    dischargedAh = FitData.(runName).DischargedAh;

    numberOfSamples = numel(V);
    rows = firstRow:(firstRow + numberOfSamples - 1);

    % Run-specific voltage intercept
    X(rows,runIndex) = 1;

    % Run-specific voltage change per discharged Ah
    X(rows,numberOfRuns + runIndex) = dischargedAh;

    % Common resistance term: V = ... - I*R
    X(rows,end) = -I;

    measuredVoltage(rows) = V;
    sampleRunIndex(rows) = runIndex;

    firstRow = firstRow + numberOfSamples;
end

%% 4. SOLVE ORDINARY LEAST SQUARES

parameterVector = X \ measuredVoltage;

initialOCV_V = parameterVector(1:numberOfRuns);
voltageSlope_V_per_Ah = ...
    parameterVector(numberOfRuns+1:2*numberOfRuns);

commonPackResistance_Ohm = parameterVector(end);

fittedVoltage = X*parameterVector;
voltageError = fittedVoltage - measuredVoltage;

%% 5. CALCULATE RUN-BY-RUN METRICS

Bias_V = zeros(numberOfRuns,1);
MAE_V = zeros(numberOfRuns,1);
RMSE_V = zeros(numberOfRuns,1);
MaxAbsError_V = zeros(numberOfRuns,1);
Correlation = zeros(numberOfRuns,1);

for runIndex = 1:numberOfRuns

    runMask = sampleRunIndex == runIndex;

    measuredRun = measuredVoltage(runMask);
    fittedRun = fittedVoltage(runMask);
    errorRun = fittedRun - measuredRun;

    Bias_V(runIndex) = mean(errorRun);
    MAE_V(runIndex) = mean(abs(errorRun));
    RMSE_V(runIndex) = sqrt(mean(errorRun.^2));
    MaxAbsError_V(runIndex) = max(abs(errorRun));

    correlationMatrix = corrcoef(measuredRun,fittedRun);

    if size(correlationMatrix,1) == 2
        Correlation(runIndex) = correlationMatrix(1,2);
    else
        Correlation(runIndex) = NaN;
    end
end

PackResistance_Ohm = repmat( ...
    commonPackResistance_Ohm,numberOfRuns,1);

BatteryLeastSquaresResults = table( ...
    runNames, ...
    initialOCV_V, ...
    voltageSlope_V_per_Ah, ...
    PackResistance_Ohm, ...
    Bias_V, ...
    MAE_V, ...
    RMSE_V, ...
    MaxAbsError_V, ...
    Correlation, ...
    'VariableNames',{ ...
    'Run', ...
    'EstimatedInitialOCV_V', ...
    'VoltageSlope_V_per_Ah', ...
    'PackResistance_Ohm', ...
    'Bias_V', ...
    'MAE_V', ...
    'RMSE_V', ...
    'MaxAbsError_V', ...
    'Correlation'});

%% 6. COMPARE WITH CURRENT MODEL RESISTANCE

currentInitialSOC = ...
    OriginalBatteryData.InitStates( ...
    OriginalBatteryData.TestScnrioCycleNum).BattSoc;

assumedTemperature_K = 298.1;

currentCellResistance_Ohm = interp2( ...
    OriginalBatteryData.BattResistSocBpts, ...
    OriginalBatteryData.BattResistTempBpts, ...
    OriginalBatteryData.BattResistTbl, ...
    currentInitialSOC, ...
    assumedTemperature_K, ...
    'linear');

currentModelPackResistance_Ohm = ...
    OriginalBatteryData.BattNumCellsSeries / ...
    OriginalBatteryData.BattNumCellsParallel * ...
    currentCellResistance_Ohm;

%% 7. ESTIMATE INITIAL SOC FOR POSSIBLE SERIES COUNTS

seriesCandidates = (174:2:200)';
estimatedSOC = NaN(numel(seriesCandidates),numberOfRuns);

for runIndex = 1:numberOfRuns

    requiredCellOCV = ...
        initialOCV_V(runIndex)./seriesCandidates;

    estimatedSOC(:,runIndex) = interp1( ...
        OriginalBatteryData.BattOpenVoltTbl, ...
        OriginalBatteryData.BattOpenVoltCapBpts, ...
        requiredCellOCV, ...
        'linear',NaN);
end

BatteryArchitectureSOC = table( ...
    seriesCandidates, ...
    estimatedSOC(:,1), ...
    estimatedSOC(:,2), ...
    estimatedSOC(:,3), ...
    'VariableNames',{ ...
    'SeriesCells', ...
    'EstimatedSOC_Run001', ...
    'EstimatedSOC_Run002', ...
    'EstimatedSOC_Run003'});

%% 8. DISPLAY RESULTS

fprintf('\n===== EV6 BATTERY LEAST-SQUARES RESULTS =====\n');
disp(BatteryLeastSquaresResults);

fprintf('Common fitted pack resistance = %.6f ohm\n', ...
    commonPackResistance_Ohm);

fprintf('Current model pack resistance at %.1f K and %.1f%% SOC = %.6f ohm\n', ...
    assumedTemperature_K, ...
    100*currentInitialSOC, ...
    currentModelPackResistance_Ohm);

fprintf('Resistance difference = %.2f %%\n', ...
    100*(commonPackResistance_Ohm - ...
    currentModelPackResistance_Ohm)/ ...
    currentModelPackResistance_Ohm);

fprintf('\n===== SERIES-CELL/SOC ESTIMATES =====\n');
disp(BatteryArchitectureSOC);
fprintf('=====================================\n');

%% 9. CREATE VALIDATION FIGURE

figure( ...
    'Color','white', ...
    'Name','EV6 Battery Least-Squares Identification', ...
    'Position',[100 100 1500 900]);

layout = tiledlayout(numberOfRuns,2, ...
    'TileSpacing','compact', ...
    'Padding','compact');

title(layout, ...
    'EV6 Battery Least-Squares Identification: Runs 001-003');

for runIndex = 1:numberOfRuns

    runName = runNames(runIndex);
    runMask = sampleRunIndex == runIndex;

    t = FitData.(runName).Time_s;
    measuredRun = measuredVoltage(runMask);
    fittedRun = fittedVoltage(runMask);
    errorRun = fittedRun - measuredRun;

    nexttile;

    plot(t,measuredRun,'k','LineWidth',1);
    hold on;
    plot(t,fittedRun,'r','LineWidth',1);
    grid on;

    xlabel('Time [s]');
    ylabel('Voltage [V]');
    title(sprintf('%s measured and fitted voltage',runName));
    legend('EV6 dyno','Least-squares fit', ...
        'Location','best');

    nexttile;

    plot(t,errorRun,'b','LineWidth',0.8);
    yline(0,'k--');
    grid on;

    xlabel('Time [s]');
    ylabel('Voltage error [V]');
    title(sprintf('%s voltage error',runName));
end

figureFile = fullfile( ...
    outputFolder, ...
    'EV6_Battery_LeastSquares_Runs001_003.png');

exportgraphics(gcf,figureFile,'Resolution',300);

%% 10. SAVE RESULTS

resultsCSV = fullfile( ...
    outputFolder, ...
    'EV6_Battery_LeastSquares_Metrics.csv');

architectureCSV = fullfile( ...
    outputFolder, ...
    'EV6_Battery_Series_SOC_Candidates.csv');

resultsMAT = fullfile( ...
    outputFolder, ...
    'EV6_Battery_LeastSquares_Results.mat');

writetable(BatteryLeastSquaresResults,resultsCSV);
writetable(BatteryArchitectureSOC,architectureCSV);

save(resultsMAT, ...
    'BatteryLeastSquaresResults', ...
    'BatteryArchitectureSOC', ...
    'commonPackResistance_Ohm', ...
    'currentModelPackResistance_Ohm', ...
    'initialOCV_V', ...
    'voltageSlope_V_per_Ah', ...
    'parameterVector', ...
    'FitData');

fprintf('\n===== BATTERY IDENTIFICATION COMPLETE =====\n');
fprintf('Figure:\n%s\n',figureFile);
fprintf('Metrics:\n%s\n',resultsCSV);
fprintf('Architecture table:\n%s\n',architectureCSV);
fprintf('MAT results:\n%s\n',resultsMAT);
fprintf('No Simulink parameters were changed.\n');
fprintf('===========================================\n');