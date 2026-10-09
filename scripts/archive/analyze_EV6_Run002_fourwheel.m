%% EV6 RUN 002 FOUR-WHEEL BASELINE VS CALIBRATED ANALYSIS
% Compares:
%   EV6 measured wheel torque
%   Simulink baseline wheel torque
%   Simulink calibrated-candidate wheel torque
%
% The first five seconds are excluded, matching Run 001.

projectRoot = ['C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\Vehicles_24a\Vehicles\' ...
    'VehicleProjects\Bolt_EV'];

outputFolder = fullfile(projectRoot,'Run002_Professor_Figures');

if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

%% 1. LOAD RUN 002 REFERENCE DATA IF NEEDED

referenceFile = fullfile(projectRoot,'EV6_Run002_ReferenceData.mat');

if ~exist('t002','var') || ...
   ~exist('measLF002','var') || ...
   ~exist('measRF002','var') || ...
   ~exist('measLR002','var') || ...
   ~exist('measRR002','var')

    assert(isfile(referenceFile), ...
        'Run 002 reference-data file was not found:\n%s',referenceFile);

    load(referenceFile);

    fprintf('Loaded Run 002 reference data from:\n%s\n',referenceFile);
end

t002      = double(t002(:));
measLF002 = double(measLF002(:));
measRF002 = double(measRF002(:));
measLR002 = double(measLR002(:));
measRR002 = double(measRR002(:));

assert(numel(t002) == numel(measLF002), ...
    'Measured LF length does not match time.');
assert(numel(t002) == numel(measRF002), ...
    'Measured RF length does not match time.');
assert(numel(t002) == numel(measLR002), ...
    'Measured LR length does not match time.');
assert(numel(t002) == numel(measRR002), ...
    'Measured RR length does not match time.');

%% 2. FIND BASELINE AND CALIBRATED SDI RUNS

baselineRunName  = 'Run002_FourWheel_Baseline';
candidateRunName = 'Run002_FourWheel_CalibratedCandidate';

runIDs = Simulink.sdi.getAllRunIDs;

baselineRunID  = [];
candidateRunID = [];

fprintf('\n===== SEARCHING CURRENT SDI RUNS =====\n');

for k = 1:numel(runIDs)
    currentRun = Simulink.sdi.getRun(runIDs(k));
    currentName = string(currentRun.Name);

    fprintf('%d. %s\n',k,currentName);

    if currentName == baselineRunName
        baselineRunID = runIDs(k);
    end

    if currentName == candidateRunName
        candidateRunID = runIDs(k);
    end
end

fprintf('======================================\n');

assert(~isempty(baselineRunID), ...
    ['Run002_FourWheel_Baseline was not found in SDI. ' ...
     'Load EV6_Run002_FourWheel_Baseline.mldatx.']);

assert(~isempty(candidateRunID), ...
    ['Run002_FourWheel_CalibratedCandidate was not found in SDI. ' ...
     'Load EV6_Run002_FourWheel_CalibratedCandidate.mldatx.']);

baselineRun  = Simulink.sdi.getRun(baselineRunID);
candidateRun = Simulink.sdi.getRun(candidateRunID);

%% 3. EXTRACT FOUR-WHEEL SIMULATION SIGNALS

wheelSignalNames = [
    "SimWhlTrq_LF_Nm"
    "SimWhlTrq_RF_Nm"
    "SimWhlTrq_LR_Nm"
    "SimWhlTrq_RR_Nm"
    ];

baselineTS  = cell(4,1);
candidateTS = cell(4,1);

for k = 1:4
    signalName = char(wheelSignalNames(k));

    baselineSignalIDs = ...
        baselineRun.getSignalIDsByName(signalName);

    candidateSignalIDs = ...
        candidateRun.getSignalIDsByName(signalName);

    assert(~isempty(baselineSignalIDs), ...
        'Baseline signal %s was not found.',signalName);

    assert(~isempty(candidateSignalIDs), ...
        'Candidate signal %s was not found.',signalName);

    baselineTS{k} = ...
        Simulink.sdi.getSignal(baselineSignalIDs(1)).Values;

    candidateTS{k} = ...
        Simulink.sdi.getSignal(candidateSignalIDs(1)).Values;
end

%% 4. DEFINE COMMON COMPARISON TIME

comparisonStart = 5.0;
comparisonEnd   = t002(end);

for k = 1:4
    comparisonEnd = min(comparisonEnd, ...
        double(baselineTS{k}.Time(end)));

    comparisonEnd = min(comparisonEnd, ...
        double(candidateTS{k}.Time(end)));
end

comparisonMask = ...
    t002 >= comparisonStart & t002 <= comparisonEnd;

tCompare = t002(comparisonMask);

assert(~isempty(tCompare), ...
    'No common comparison interval was found.');

fprintf('\nComparison begins at %.3f seconds.\n',tCompare(1));
fprintf('Comparison ends at %.3f seconds.\n',tCompare(end));
fprintf('Comparison samples = %d\n',numel(tCompare));

%% 5. INTERPOLATE SIMULATION RESULTS TO DYNO TIME GRID

baselineWheel  = nan(numel(tCompare),4);
candidateWheel = nan(numel(tCompare),4);

for k = 1:4
    % Baseline
    baselineTime = double(baselineTS{k}.Time(:));
    baselineData = double(baselineTS{k}.Data(:));

    [baselineTime,uniqueIndex] = unique( ...
        baselineTime,'stable');

    baselineData = baselineData(uniqueIndex);

    baselineWheel(:,k) = interp1( ...
        baselineTime,baselineData,tCompare,'linear');

    % Calibrated candidate
    candidateTime = double(candidateTS{k}.Time(:));
    candidateData = double(candidateTS{k}.Data(:));

    [candidateTime,uniqueIndex] = unique( ...
        candidateTime,'stable');

    candidateData = candidateData(uniqueIndex);

    candidateWheel(:,k) = interp1( ...
        candidateTime,candidateData,tCompare,'linear');
end

%% 6. BUILD WHEEL, AXLE AND TOTAL TORQUE MATRICES

measuredWheel = [
    measLF002(comparisonMask), ...
    measRF002(comparisonMask), ...
    measLR002(comparisonMask), ...
    measRR002(comparisonMask)
    ];

measuredComponents = [
    measuredWheel, ...
    measuredWheel(:,1) + measuredWheel(:,2), ...
    measuredWheel(:,3) + measuredWheel(:,4), ...
    sum(measuredWheel,2)
    ];

baselineComponents = [
    baselineWheel, ...
    baselineWheel(:,1) + baselineWheel(:,2), ...
    baselineWheel(:,3) + baselineWheel(:,4), ...
    sum(baselineWheel,2)
    ];

candidateComponents = [
    candidateWheel, ...
    candidateWheel(:,1) + candidateWheel(:,2), ...
    candidateWheel(:,3) + candidateWheel(:,4), ...
    sum(candidateWheel,2)
    ];

componentNames = [
    "Left Front Wheel"
    "Right Front Wheel"
    "Left Rear Wheel"
    "Right Rear Wheel"
    "Front Axle Sum"
    "Rear Axle Sum"
    "Four-Wheel Total"
    ];

numberComponents = numel(componentNames);

%% 7. CALCULATE BASELINE AND CALIBRATED METRICS

Samples = zeros(numberComponents,1);

MeasuredMin_Nm  = zeros(numberComponents,1);
MeasuredMax_Nm  = zeros(numberComponents,1);

BaselineMin_Nm  = zeros(numberComponents,1);
BaselineMax_Nm  = zeros(numberComponents,1);
BaselineBias_Nm = zeros(numberComponents,1);
BaselineMAE_Nm  = zeros(numberComponents,1);
BaselineRMSE_Nm = zeros(numberComponents,1);
BaselineMaxAbsError_Nm = zeros(numberComponents,1);
BaselineCorrelation = zeros(numberComponents,1);

CandidateMin_Nm  = zeros(numberComponents,1);
CandidateMax_Nm  = zeros(numberComponents,1);
CandidateBias_Nm = zeros(numberComponents,1);
CandidateMAE_Nm  = zeros(numberComponents,1);
CandidateRMSE_Nm = zeros(numberComponents,1);
CandidateMaxAbsError_Nm = zeros(numberComponents,1);
CandidateCorrelation = zeros(numberComponents,1);

for k = 1:numberComponents
    measured  = measuredComponents(:,k);
    baseline  = baselineComponents(:,k);
    candidate = candidateComponents(:,k);

    valid = isfinite(measured) & ...
            isfinite(baseline) & ...
            isfinite(candidate);

    measured  = measured(valid);
    baseline  = baseline(valid);
    candidate = candidate(valid);

    Samples(k) = nnz(valid);

    baselineError  = baseline  - measured;
    candidateError = candidate - measured;

    MeasuredMin_Nm(k) = min(measured);
    MeasuredMax_Nm(k) = max(measured);

    BaselineMin_Nm(k) = min(baseline);
    BaselineMax_Nm(k) = max(baseline);
    BaselineBias_Nm(k) = mean(baselineError);
    BaselineMAE_Nm(k) = mean(abs(baselineError));
    BaselineRMSE_Nm(k) = sqrt(mean(baselineError.^2));
    BaselineMaxAbsError_Nm(k) = max(abs(baselineError));

    baselineCorrelationMatrix = corrcoef(measured,baseline);

    if numel(baselineCorrelationMatrix) >= 4
        BaselineCorrelation(k) = ...
            baselineCorrelationMatrix(1,2);
    else
        BaselineCorrelation(k) = NaN;
    end

    CandidateMin_Nm(k) = min(candidate);
    CandidateMax_Nm(k) = max(candidate);
    CandidateBias_Nm(k) = mean(candidateError);
    CandidateMAE_Nm(k) = mean(abs(candidateError));
    CandidateRMSE_Nm(k) = sqrt(mean(candidateError.^2));
    CandidateMaxAbsError_Nm(k) = max(abs(candidateError));

    candidateCorrelationMatrix = corrcoef(measured,candidate);

    if numel(candidateCorrelationMatrix) >= 4
        CandidateCorrelation(k) = ...
            candidateCorrelationMatrix(1,2);
    else
        CandidateCorrelation(k) = NaN;
    end
end

MAE_Improvement_pct = ...
    100*(BaselineMAE_Nm-CandidateMAE_Nm)./BaselineMAE_Nm;

RMSE_Improvement_pct = ...
    100*(BaselineRMSE_Nm-CandidateRMSE_Nm)./BaselineRMSE_Nm;

CorrelationChange = ...
    CandidateCorrelation-BaselineCorrelation;

%% 8. CREATE METRIC TABLES

run002BaselineMetrics = table( ...
    componentNames,Samples, ...
    MeasuredMin_Nm,MeasuredMax_Nm, ...
    BaselineMin_Nm,BaselineMax_Nm, ...
    BaselineBias_Nm,BaselineMAE_Nm, ...
    BaselineRMSE_Nm,BaselineMaxAbsError_Nm, ...
    BaselineCorrelation, ...
    'VariableNames',{ ...
    'Component','Samples', ...
    'MeasuredMin_Nm','MeasuredMax_Nm', ...
    'SimulatedMin_Nm','SimulatedMax_Nm', ...
    'Bias_Nm','MAE_Nm','RMSE_Nm', ...
    'MaxAbsError_Nm','Correlation'});

run002CandidateMetrics = table( ...
    componentNames,Samples, ...
    MeasuredMin_Nm,MeasuredMax_Nm, ...
    CandidateMin_Nm,CandidateMax_Nm, ...
    CandidateBias_Nm,CandidateMAE_Nm, ...
    CandidateRMSE_Nm,CandidateMaxAbsError_Nm, ...
    CandidateCorrelation, ...
    'VariableNames',{ ...
    'Component','Samples', ...
    'MeasuredMin_Nm','MeasuredMax_Nm', ...
    'SimulatedMin_Nm','SimulatedMax_Nm', ...
    'Bias_Nm','MAE_Nm','RMSE_Nm', ...
    'MaxAbsError_Nm','Correlation'});

run002ComparisonMetrics = table( ...
    componentNames, ...
    BaselineMAE_Nm,CandidateMAE_Nm,MAE_Improvement_pct, ...
    BaselineRMSE_Nm,CandidateRMSE_Nm,RMSE_Improvement_pct, ...
    BaselineCorrelation,CandidateCorrelation,CorrelationChange, ...
    'VariableNames',{ ...
    'Component', ...
    'Baseline_MAE_Nm','Candidate_MAE_Nm', ...
    'MAE_Improvement_pct', ...
    'Baseline_RMSE_Nm','Candidate_RMSE_Nm', ...
    'RMSE_Improvement_pct', ...
    'Baseline_Correlation','Candidate_Correlation', ...
    'Correlation_Change'});

fprintf('\n===== RUN 002 BASELINE FOUR-WHEEL METRICS =====\n');
disp(run002BaselineMetrics);

fprintf('===== RUN 002 CALIBRATED FOUR-WHEEL METRICS =====\n');
disp(run002CandidateMetrics);

fprintf('===== RUN 002 BASELINE VS CALIBRATED =====\n');
disp(run002ComparisonMetrics);

fprintf('Positive improvement means lower error.\n');
fprintf('Positive bias means simulation exceeds measurement.\n');
fprintf('First five seconds excluded.\n');

%% 9. SAVE TABLES

baselineCSV = fullfile(outputFolder, ...
    'EV6_Run002_Baseline_Metrics.csv');

candidateCSV = fullfile(outputFolder, ...
    'EV6_Run002_Calibrated_Metrics.csv');

comparisonCSV = fullfile(outputFolder, ...
    'EV6_Run002_Baseline_vs_Calibrated_Metrics.csv');

writetable(run002BaselineMetrics,baselineCSV);
writetable(run002CandidateMetrics,candidateCSV);
writetable(run002ComparisonMetrics,comparisonCSV);

save(fullfile(projectRoot, ...
    'EV6_Run002_FourWheel_BaselineMetrics.mat'), ...
    'run002BaselineMetrics');

save(fullfile(projectRoot, ...
    'EV6_Run002_FourWheel_CandidateMetrics.mat'), ...
    'run002CandidateMetrics');

save(fullfile(projectRoot, ...
    'EV6_Run002_FourWheel_ComparisonMetrics.mat'), ...
    'run002ComparisonMetrics');

%% 10. CREATE MEASURED/BASELINE/CALIBRATED OVERLAY FIGURE

plotStep = max(1,floor(numel(tCompare)/15000));
plotIndex = 1:plotStep:numel(tCompare);

figureOverlay = figure( ...
    'Color','w', ...
    'Position',[50 50 1600 1050]);

tiledlayout(4,2, ...
    'TileSpacing','compact', ...
    'Padding','compact');

for k = 1:numberComponents
    nexttile;

    plot(tCompare(plotIndex), ...
        measuredComponents(plotIndex,k), ...
        'k','LineWidth',0.9);
    hold on;

    plot(tCompare(plotIndex), ...
        baselineComponents(plotIndex,k), ...
        'Color',[0 0.35 0.9], ...
        'LineWidth',0.8);

    plot(tCompare(plotIndex), ...
        candidateComponents(plotIndex,k), ...
        'Color',[0.9 0.15 0.1], ...
        'LineWidth',0.8);

    grid on;
    title(componentNames(k));
    xlabel('Time [s]');
    ylabel('Torque [N·m]');

    legend('EV6 measured','Baseline','Calibrated', ...
        'Location','best');
end

sgtitle('Run 002: Measured, Baseline and Calibrated Wheel Torque');

overlayPNG = fullfile(outputFolder, ...
    'EV6_Run002_Measured_Baseline_Calibrated_Overlay.png');

overlayFIG = fullfile(outputFolder, ...
    'EV6_Run002_Measured_Baseline_Calibrated_Overlay.fig');

exportgraphics(figureOverlay,overlayPNG,'Resolution',200);
savefig(figureOverlay,overlayFIG);

%% 11. CREATE METRIC COMPARISON FIGURE

figureMetrics = figure( ...
    'Color','w', ...
    'Position',[80 80 1500 850]);

componentCategories = categorical(componentNames);
componentCategories = reordercats( ...
    componentCategories,cellstr(componentNames));

tiledlayout(2,2, ...
    'TileSpacing','compact', ...
    'Padding','compact');

nexttile;
bar(componentCategories, ...
    [BaselineMAE_Nm CandidateMAE_Nm]);
grid on;
ylabel('MAE [N·m]');
title('Mean Absolute Error');
legend('Baseline','Calibrated','Location','northwest');
xtickangle(25);

nexttile;
bar(componentCategories, ...
    [BaselineRMSE_Nm CandidateRMSE_Nm]);
grid on;
ylabel('RMSE [N·m]');
title('Root Mean Square Error');
legend('Baseline','Calibrated','Location','northwest');
xtickangle(25);

nexttile;
bar(componentCategories,MAE_Improvement_pct);
yline(0,'k-');
grid on;
ylabel('Improvement [%]');
title('MAE Improvement');
xtickangle(25);

nexttile;
bar(componentCategories,RMSE_Improvement_pct);
yline(0,'k-');
grid on;
ylabel('Improvement [%]');
title('RMSE Improvement');
xtickangle(25);

sgtitle('Run 002: Baseline Versus Calibrated Metrics');

metricsPNG = fullfile(outputFolder, ...
    'EV6_Run002_Baseline_vs_Calibrated_Metrics.png');

metricsFIG = fullfile(outputFolder, ...
    'EV6_Run002_Baseline_vs_Calibrated_Metrics.fig');

exportgraphics(figureMetrics,metricsPNG,'Resolution',200);
savefig(figureMetrics,metricsFIG);

%% 12. PRINT FINAL SUMMARY

totalRow = componentNames == "Four-Wheel Total";

fprintf('\n============================================\n');
fprintf('EV6 RUN 002 CALCULATIONS COMPLETE\n');
fprintf('============================================\n');
fprintf('Four-wheel total baseline MAE = %.3f N*m\n', ...
    BaselineMAE_Nm(totalRow));
fprintf('Four-wheel total calibrated MAE = %.3f N*m\n', ...
    CandidateMAE_Nm(totalRow));
fprintf('MAE improvement = %.3f %%\n', ...
    MAE_Improvement_pct(totalRow));

fprintf('\nFour-wheel total baseline RMSE = %.3f N*m\n', ...
    BaselineRMSE_Nm(totalRow));
fprintf('Four-wheel total calibrated RMSE = %.3f N*m\n', ...
    CandidateRMSE_Nm(totalRow));
fprintf('RMSE improvement = %.3f %%\n', ...
    RMSE_Improvement_pct(totalRow));

fprintf('\nBaseline correlation = %.5f\n', ...
    BaselineCorrelation(totalRow));
fprintf('Calibrated correlation = %.5f\n', ...
    CandidateCorrelation(totalRow));

fprintf('\nOutput folder:\n%s\n',outputFolder);
fprintf('============================================\n');