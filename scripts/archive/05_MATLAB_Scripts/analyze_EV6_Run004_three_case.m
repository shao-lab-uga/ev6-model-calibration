%% EV6 RUN 004 THREE-CASE COMPARISON
% Cases:
%   1. True pre-LUT baseline
%   2. EV6 LUT-only
%   3. EV6 LUT + calibrated gains
%
% First five seconds are excluded.

clearvars -except D004

projectRoot = ['C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\Vehicles_24a\Vehicles\' ...
    'VehicleProjects\Bolt_EV'];

outputFolder = fullfile( ...
    projectRoot,'Run004_Professor_Figures');

if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

%% 1. Load true pre-LUT results

trueBaselineFile = fullfile( ...
    projectRoot, ...
    'EV6_Run004_TruePreLUT_Baseline_Results.mat');

assert(isfile(trueBaselineFile), ...
    'True pre-LUT results file was not found.');

load(trueBaselineFile);

%% 2. Load Run 004 dyno data

if ~exist('D004','var')

    run004File = ['C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
        'OneDrive_1_8-28-2026\EV6_drivecycleData\' ...
        'standards_test_08142026_004.mat'];

    loadedRun004 = load(run004File);
    D004 = loadedRun004.standards_test_08142026_004;
end

channelNames004 = erase( ...
    string({D004.Y.Name}),["<",">"]);

%% 3. Find LUT-only and LUT-plus-gains SDI runs

lutOnlyRunName = ...
    "Run004_FourWheel_Baseline";

calibratedRunName = ...
    "Run004_FourWheel_CalibratedCandidate";

runIDs = Simulink.sdi.getAllRunIDs;

lutOnlyRunID = [];
calibratedRunID = [];

fprintf('\n===== SEARCHING CURRENT SDI RUNS =====\n');

for k = 1:numel(runIDs)

    currentRun = Simulink.sdi.getRun(runIDs(k));
    currentName = string(currentRun.Name);

    fprintf('%d. %s\n',k,currentName);

    if currentName == lutOnlyRunName
        lutOnlyRunID = runIDs(k);
    end

    if currentName == calibratedRunName
        calibratedRunID = runIDs(k);
    end
end

fprintf('======================================\n');

assert(~isempty(lutOnlyRunID), ...
    ['Run004_FourWheel_Baseline was not found. ' ...
     'Load its SDI file first.']);

assert(~isempty(calibratedRunID), ...
    ['Run004_FourWheel_CalibratedCandidate was not found. ' ...
     'Load its SDI file first.']);

%% 4. Establish common comparison time

commonTime = double(trueBaselineTime004(:));

assert(size(trueBaselineAxlTrq004,2) == 4, ...
    'True baseline AxlTrq does not contain four columns.');

truePreLUTWheelTorque = ...
    double(trueBaselineAxlTrq004);

%% 5. Extract dyno wheel torques

measuredChannelNames = [ ...
    "ActTqLF_Nm"
    "ActTqRF_Nm"
    "ActTqLR_Nm"
    "ActTqRR_Nm"];

measuredWheelTorque = nan( ...
    numel(commonTime),4);

for wheelIndex = 1:4

    signalIndex = find( ...
        channelNames004 == ...
        measuredChannelNames(wheelIndex), ...
        1,'first');

    assert(~isempty(signalIndex), ...
        'Dyno channel %s was not found.', ...
        measuredChannelNames(wheelIndex));

    timeIndex = D004.Y(signalIndex).XIndex;

    measuredTime = double( ...
        D004.X(timeIndex).Data(:));

    measuredData = double( ...
        D004.Y(signalIndex).Data(:));

    validMeasured = ...
        isfinite(measuredTime) & ...
        isfinite(measuredData);

    measuredTime = measuredTime(validMeasured);
    measuredData = measuredData(validMeasured);

    [measuredTime,uniqueIndices] = ...
        unique(measuredTime,'stable');

    measuredData = measuredData(uniqueIndices);

    measuredWheelTorque(:,wheelIndex) = ...
        interp1( ...
        measuredTime,measuredData, ...
        commonTime,'linear',NaN);
end

%% 6. Extract LUT-only and calibrated wheel torques

simulatedSignalNames = [ ...
    "SimWhlTrq_LF_Nm"
    "SimWhlTrq_RF_Nm"
    "SimWhlTrq_LR_Nm"
    "SimWhlTrq_RR_Nm"];

lutOnlyWheelTorque = nan(numel(commonTime),4);
calibratedWheelTorque = nan(numel(commonTime),4);

for wheelIndex = 1:4

    [signalTime,signalData] = getSDISignal( ...
        lutOnlyRunID, ...
        simulatedSignalNames(wheelIndex));

    lutOnlyWheelTorque(:,wheelIndex) = ...
        interp1(signalTime,signalData, ...
        commonTime,'linear',NaN);

    [signalTime,signalData] = getSDISignal( ...
        calibratedRunID, ...
        simulatedSignalNames(wheelIndex));

    calibratedWheelTorque(:,wheelIndex) = ...
        interp1(signalTime,signalData, ...
        commonTime,'linear',NaN);
end

%% 7. Assemble wheel, axle and total signals

componentNames = [ ...
    "Left Front Wheel"
    "Right Front Wheel"
    "Left Rear Wheel"
    "Right Rear Wheel"
    "Front Axle Sum"
    "Rear Axle Sum"
    "Four-Wheel Total"];

measuredComponents = [ ...
    measuredWheelTorque, ...
    sum(measuredWheelTorque(:,1:2),2), ...
    sum(measuredWheelTorque(:,3:4),2), ...
    sum(measuredWheelTorque,2)];

truePreLUTComponents = [ ...
    truePreLUTWheelTorque, ...
    sum(truePreLUTWheelTorque(:,1:2),2), ...
    sum(truePreLUTWheelTorque(:,3:4),2), ...
    sum(truePreLUTWheelTorque,2)];

lutOnlyComponents = [ ...
    lutOnlyWheelTorque, ...
    sum(lutOnlyWheelTorque(:,1:2),2), ...
    sum(lutOnlyWheelTorque(:,3:4),2), ...
    sum(lutOnlyWheelTorque,2)];

calibratedComponents = [ ...
    calibratedWheelTorque, ...
    sum(calibratedWheelTorque(:,1:2),2), ...
    sum(calibratedWheelTorque(:,3:4),2), ...
    sum(calibratedWheelTorque,2)];

modelNames = [ ...
    "True pre-LUT"
    "LUT-only"
    "LUT + gains"];

modelData = { ...
    truePreLUTComponents, ...
    lutOnlyComponents, ...
    calibratedComponents};

%% 8. Calculate all torque metrics

numberOfRows = ...
    numel(modelNames)*numel(componentNames);

Model = strings(numberOfRows,1);
Component = strings(numberOfRows,1);
Samples = zeros(numberOfRows,1);
Bias_Nm = zeros(numberOfRows,1);
MAE_Nm = zeros(numberOfRows,1);
RMSE_Nm = zeros(numberOfRows,1);
MaxAbsError_Nm = zeros(numberOfRows,1);
Correlation = zeros(numberOfRows,1);

rowIndex = 0;

for modelIndex = 1:numel(modelNames)

    currentModelData = modelData{modelIndex};

    for componentIndex = 1:numel(componentNames)

        rowIndex = rowIndex + 1;

        measuredSignal = ...
            measuredComponents(:,componentIndex);

        simulatedSignal = ...
            currentModelData(:,componentIndex);

        validComparison = ...
            commonTime >= 5 & ...
            commonTime <= 619.400 & ...
            isfinite(measuredSignal) & ...
            isfinite(simulatedSignal);

        measuredComparison = ...
            measuredSignal(validComparison);

        simulatedComparison = ...
            simulatedSignal(validComparison);

        errorSignal = ...
            simulatedComparison - measuredComparison;

        measuredCentered = ...
            measuredComparison - mean(measuredComparison);

        simulatedCentered = ...
            simulatedComparison - mean(simulatedComparison);

        correlationDenominator = sqrt( ...
            sum(measuredCentered.^2) * ...
            sum(simulatedCentered.^2));

        Model(rowIndex) = modelNames(modelIndex);
        Component(rowIndex) = componentNames(componentIndex);
        Samples(rowIndex) = numel(errorSignal);
        Bias_Nm(rowIndex) = mean(errorSignal);
        MAE_Nm(rowIndex) = mean(abs(errorSignal));
        RMSE_Nm(rowIndex) = sqrt(mean(errorSignal.^2));
        MaxAbsError_Nm(rowIndex) = max(abs(errorSignal));

        if correlationDenominator > 0
            Correlation(rowIndex) = ...
                sum(measuredCentered .* simulatedCentered) / ...
                correlationDenominator;
        else
            Correlation(rowIndex) = NaN;
        end
    end
end

ThreeCaseTorqueMetrics = table( ...
    Model,Component,Samples,Bias_Nm,MAE_Nm, ...
    RMSE_Nm,MaxAbsError_Nm,Correlation);

fprintf('\n===== RUN 004 THREE-CASE TORQUE METRICS =====\n');
disp(ThreeCaseTorqueMetrics);
fprintf('First five seconds excluded.\n');
fprintf('==============================================\n');

%% 9. Four-wheel-total summary

totalRows = ...
    ThreeCaseTorqueMetrics.Component == ...
    "Four-Wheel Total";

FourWheelSummary = ...
    ThreeCaseTorqueMetrics(totalRows,:);

preIndex = find( ...
    FourWheelSummary.Model == "True pre-LUT");

lutIndex = find( ...
    FourWheelSummary.Model == "LUT-only");

gainIndex = find( ...
    FourWheelSummary.Model == "LUT + gains");

preMAE = FourWheelSummary.MAE_Nm(preIndex);
lutMAE = FourWheelSummary.MAE_Nm(lutIndex);
gainMAE = FourWheelSummary.MAE_Nm(gainIndex);

preRMSE = FourWheelSummary.RMSE_Nm(preIndex);
lutRMSE = FourWheelSummary.RMSE_Nm(lutIndex);
gainRMSE = FourWheelSummary.RMSE_Nm(gainIndex);

lutMAEImprovement = ...
    100*(preMAE-lutMAE)/preMAE;

gainMAEImprovement = ...
    100*(preMAE-gainMAE)/preMAE;

gainOverLUTMAEImprovement = ...
    100*(lutMAE-gainMAE)/lutMAE;

lutRMSEImprovement = ...
    100*(preRMSE-lutRMSE)/preRMSE;

gainRMSEImprovement = ...
    100*(preRMSE-gainRMSE)/preRMSE;

gainOverLUTRMSEImprovement = ...
    100*(lutRMSE-gainRMSE)/lutRMSE;

fprintf('\n===== FOUR-WHEEL TOTAL IMPROVEMENTS =====\n');
fprintf('True pre-LUT MAE = %.3f N*m\n',preMAE);
fprintf('LUT-only MAE = %.3f N*m\n',lutMAE);
fprintf('LUT + gains MAE = %.3f N*m\n',gainMAE);
fprintf('\n');
fprintf('LUT-only MAE improvement over pre-LUT = %.3f %%\n', ...
    lutMAEImprovement);
fprintf('LUT + gains MAE improvement over pre-LUT = %.3f %%\n', ...
    gainMAEImprovement);
fprintf('Gain improvement beyond LUT-only = %.3f %%\n', ...
    gainOverLUTMAEImprovement);

fprintf('\nTrue pre-LUT RMSE = %.3f N*m\n',preRMSE);
fprintf('LUT-only RMSE = %.3f N*m\n',lutRMSE);
fprintf('LUT + gains RMSE = %.3f N*m\n',gainRMSE);
fprintf('\n');
fprintf('LUT-only RMSE improvement over pre-LUT = %.3f %%\n', ...
    lutRMSEImprovement);
fprintf('LUT + gains RMSE improvement over pre-LUT = %.3f %%\n', ...
    gainRMSEImprovement);
fprintf('Gain improvement beyond LUT-only = %.3f %%\n', ...
    gainOverLUTRMSEImprovement);
fprintf('==========================================\n');

%% 10. Speed metrics

speedIndex = find( ...
    channelNames004 == "VEH_vEgo",1,'first');

speedTimeIndex = D004.Y(speedIndex).XIndex;

dynoSpeedTime = double( ...
    D004.X(speedTimeIndex).Data(:));

dynoSpeedData = double( ...
    D004.Y(speedIndex).Data(:));

[dynoSpeedTime,uniqueIndices] = ...
    unique(dynoSpeedTime,'stable');

dynoSpeedData = dynoSpeedData(uniqueIndices);

dynoSpeed = interp1( ...
    dynoSpeedTime,dynoSpeedData, ...
    commonTime,'linear',NaN);

[lutSpeedTime,lutSpeedData] = ...
    getSDISignal(lutOnlyRunID,"VehSpdActual_mps");

lutSpeed = interp1( ...
    lutSpeedTime,lutSpeedData, ...
    commonTime,'linear',NaN);

[gainSpeedTime,gainSpeedData] = ...
    getSDISignal(calibratedRunID,"VehSpdActual_mps");

gainSpeed = interp1( ...
    gainSpeedTime,gainSpeedData, ...
    commonTime,'linear',NaN);

speedModelData = { ...
    trueBaselineSpeed004(:), ...
    lutSpeed, ...
    gainSpeed};

SpeedModel = modelNames;
SpeedBias_mps = zeros(3,1);
SpeedMAE_mps = zeros(3,1);
SpeedRMSE_mps = zeros(3,1);
SpeedCorrelation = zeros(3,1);

for modelIndex = 1:3

    simulatedSpeed = speedModelData{modelIndex};

    validSpeed = ...
        commonTime >= 5 & ...
        commonTime <= 619.400 & ...
        isfinite(dynoSpeed) & ...
        isfinite(simulatedSpeed);

    measuredSpeed = dynoSpeed(validSpeed);
    comparedSpeed = simulatedSpeed(validSpeed);

    speedError = comparedSpeed-measuredSpeed;

    SpeedBias_mps(modelIndex) = mean(speedError);
    SpeedMAE_mps(modelIndex) = mean(abs(speedError));
    SpeedRMSE_mps(modelIndex) = ...
        sqrt(mean(speedError.^2));

    measuredCentered = measuredSpeed-mean(measuredSpeed);
    simulatedCentered = comparedSpeed-mean(comparedSpeed);

    SpeedCorrelation(modelIndex) = ...
        sum(measuredCentered.*simulatedCentered) / ...
        sqrt(sum(measuredCentered.^2) * ...
        sum(simulatedCentered.^2));
end

ThreeCaseSpeedMetrics = table( ...
    SpeedModel,SpeedBias_mps,SpeedMAE_mps, ...
    SpeedRMSE_mps,SpeedCorrelation);

fprintf('\n===== RUN 004 SPEED METRICS =====\n');
disp(ThreeCaseSpeedMetrics);

%% 11. Wheel-torque comparison figure

plotIndices = find( ...
    commonTime >= 5 & commonTime <= 619.400);

plotIndices = plotIndices(1:10:end);

figure( ...
    'Color','white', ...
    'Name','Run 004 Three-Case Wheel Torque');

tiledlayout(2,2, ...
    'TileSpacing','compact', ...
    'Padding','compact');

plotTitles = { ...
    'Left-front wheel torque', ...
    'Right-front wheel torque', ...
    'Left-rear wheel torque', ...
    'Right-rear wheel torque'};

for wheelIndex = 1:4

    nexttile;

    plot(commonTime(plotIndices), ...
        measuredWheelTorque(plotIndices,wheelIndex), ...
        'k','LineWidth',1.1);

    hold on;

    plot(commonTime(plotIndices), ...
        truePreLUTWheelTorque(plotIndices,wheelIndex), ...
        'Color',[0.85 0.33 0.10], ...
        'LineWidth',0.8);

    plot(commonTime(plotIndices), ...
        lutOnlyWheelTorque(plotIndices,wheelIndex), ...
        'b','LineWidth',0.8);

    plot(commonTime(plotIndices), ...
        calibratedWheelTorque(plotIndices,wheelIndex), ...
        'r','LineWidth',0.8);

    grid on;
    title(plotTitles{wheelIndex});
    xlabel('Time [s]');
    ylabel('Torque [N*m]');

    legend( ...
        'EV6 dyno', ...
        'True pre-LUT', ...
        'LUT-only', ...
        'LUT + gains', ...
        'Location','best');
end

sgtitle('Run 004: Three-Case Wheel-Torque Comparison');

wheelFigureFile = fullfile( ...
    outputFolder, ...
    'EV6_Run004_ThreeCase_WheelTorque.png');

exportgraphics(gcf,wheelFigureFile,'Resolution',200);

%% 12. Summary figure

maeMatrix = zeros(7,3);
rmseMatrix = zeros(7,3);

for componentIndex = 1:7
    for modelIndex = 1:3

        metricRow = ...
            ThreeCaseTorqueMetrics.Component == ...
            componentNames(componentIndex) & ...
            ThreeCaseTorqueMetrics.Model == ...
            modelNames(modelIndex);

        maeMatrix(componentIndex,modelIndex) = ...
            ThreeCaseTorqueMetrics.MAE_Nm(metricRow);

        rmseMatrix(componentIndex,modelIndex) = ...
            ThreeCaseTorqueMetrics.RMSE_Nm(metricRow);
    end
end

figure( ...
    'Color','white', ...
    'Name','Run 004 Three-Case Summary');

tiledlayout(2,2, ...
    'TileSpacing','compact', ...
    'Padding','compact');

nexttile;

plot(commonTime(plotIndices),dynoSpeed(plotIndices), ...
    'k','LineWidth',1.1);
hold on;
plot(commonTime(plotIndices), ...
    trueBaselineSpeed004(plotIndices), ...
    'Color',[0.85 0.33 0.10]);
plot(commonTime(plotIndices),lutSpeed(plotIndices),'b');
plot(commonTime(plotIndices),gainSpeed(plotIndices),'r');
grid on;
title('Vehicle speed');
xlabel('Time [s]');
ylabel('Speed [m/s]');
legend('EV6 dyno','True pre-LUT','LUT-only', ...
    'LUT + gains','Location','best');

nexttile;

plot(commonTime(plotIndices), ...
    measuredComponents(plotIndices,7), ...
    'k','LineWidth',1.1);
hold on;
plot(commonTime(plotIndices), ...
    truePreLUTComponents(plotIndices,7), ...
    'Color',[0.85 0.33 0.10]);
plot(commonTime(plotIndices), ...
    lutOnlyComponents(plotIndices,7),'b');
plot(commonTime(plotIndices), ...
    calibratedComponents(plotIndices,7),'r');
grid on;
title('Four-wheel total torque');
xlabel('Time [s]');
ylabel('Torque [N*m]');
legend('EV6 dyno','True pre-LUT','LUT-only', ...
    'LUT + gains','Location','best');

shortLabels = { ...
    'LF','RF','LR','RR','Front axle','Rear axle','Total'};

nexttile;
bar(maeMatrix);
grid on;
title('Mean absolute error');
ylabel('MAE [N*m]');
set(gca,'XTick',1:7,'XTickLabel',shortLabels);
xtickangle(30);
legend(modelNames,'Location','best');

nexttile;
bar(rmseMatrix);
grid on;
title('Root-mean-square error');
ylabel('RMSE [N*m]');
set(gca,'XTick',1:7,'XTickLabel',shortLabels);
xtickangle(30);
legend(modelNames,'Location','best');

sgtitle('Run 004: True Baseline, LUT-Only and LUT + Gains');

summaryFigureFile = fullfile( ...
    outputFolder, ...
    'EV6_Run004_ThreeCase_Summary.png');

exportgraphics(gcf,summaryFigureFile,'Resolution',200);

%% 13. Save results

torqueMetricsFile = fullfile( ...
    outputFolder, ...
    'EV6_Run004_ThreeCase_Torque_Metrics.csv');

speedMetricsFile = fullfile( ...
    outputFolder, ...
    'EV6_Run004_ThreeCase_Speed_Metrics.csv');

summaryFile = fullfile( ...
    outputFolder, ...
    'EV6_Run004_ThreeCase_FourWheel_Summary.csv');

resultsMATFile = fullfile( ...
    outputFolder, ...
    'EV6_Run004_ThreeCase_Results.mat');

writetable(ThreeCaseTorqueMetrics,torqueMetricsFile);
writetable(ThreeCaseSpeedMetrics,speedMetricsFile);
writetable(FourWheelSummary,summaryFile);

save(resultsMATFile, ...
    'ThreeCaseTorqueMetrics', ...
    'ThreeCaseSpeedMetrics', ...
    'FourWheelSummary', ...
    'lutMAEImprovement', ...
    'gainMAEImprovement', ...
    'gainOverLUTMAEImprovement', ...
    'lutRMSEImprovement', ...
    'gainRMSEImprovement', ...
    'gainOverLUTRMSEImprovement');

fprintf('\n===== THREE-CASE ANALYSIS COMPLETE =====\n');
fprintf('Wheel figure:\n%s\n\n',wheelFigureFile);
fprintf('Summary figure:\n%s\n\n',summaryFigureFile);
fprintf('Torque metrics:\n%s\n\n',torqueMetricsFile);
fprintf('Speed metrics:\n%s\n\n',speedMetricsFile);
fprintf('MAT results:\n%s\n',resultsMATFile);
fprintf('========================================\n');

%% LOCAL FUNCTION

function [signalTime,signalData] = ...
    getSDISignal(runID,targetName)

    runObject = Simulink.sdi.getRun(runID);
    signalIDs = getAllSignalIDs(runObject);

    bestSamples = -1;
    signalTime = [];
    signalData = [];

    for signalIndex = 1:numel(signalIDs)

        signalObject = ...
            Simulink.sdi.getSignal(signalIDs(signalIndex));

        if string(signalObject.Name) ~= string(targetName)
            continue
        end

        values = signalObject.Values;

        currentTime = double(values.Time(:));
        currentData = double(values.Data);

        if size(currentData,2) > 1
            currentData = currentData(:,1);
        end

        currentData = currentData(:);

        if numel(currentData) > bestSamples
            bestSamples = numel(currentData);
            signalTime = currentTime;
            signalData = currentData;
        end
    end

    assert(bestSamples > 0, ...
        'Signal %s was not found in SDI run %s.', ...
        targetName,string(runObject.Name));

    validSignal = ...
        isfinite(signalTime) & isfinite(signalData);

    signalTime = signalTime(validSignal);
    signalData = signalData(validSignal);

    [signalTime,uniqueIndices] = ...
        unique(signalTime,'stable');

    signalData = signalData(uniqueIndices);
end