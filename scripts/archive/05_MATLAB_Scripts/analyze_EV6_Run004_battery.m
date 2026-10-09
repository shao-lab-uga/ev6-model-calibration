%% EV6 RUN 004 BATTERY POWER AND ENERGY VALIDATION

assert(exist('tBattery','var') == 1, ...
    'Run the Run 004 battery precheck first.');

outputFolder = fullfile( ...
    projectRoot,'Run004_Professor_Figures');

if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

%% Calculate instantaneous power

dynoPower_kW = ...
    dynoVoltage .* dynoCurrent / 1000;

baselinePower_kW = ...
    baselineVoltage .* baselineCurrent / 1000;

candidatePower_kW = ...
    candidateVoltage .* candidateCurrent / 1000;

%% Calculate current, voltage and power metrics

signalName = [
    "Battery Current"
    "Battery Current"
    "Battery Voltage"
    "Battery Voltage"
    "Battery Power"
    "Battery Power"
];

modelName = [
    "LUT-only baseline"
    "LUT + gains"
    "LUT-only baseline"
    "LUT + gains"
    "LUT-only baseline"
    "LUT + gains"
];

units = [
    "A"
    "A"
    "V"
    "V"
    "kW"
    "kW"
];

referenceSignals = {
    dynoCurrent
    dynoCurrent
    dynoVoltage
    dynoVoltage
    dynoPower_kW
    dynoPower_kW
};

simulationSignals = {
    baselineCurrent
    candidateCurrent
    baselineVoltage
    candidateVoltage
    baselinePower_kW
    candidatePower_kW
};

numberOfRows = numel(signalName);

Bias = zeros(numberOfRows,1);
MAE = zeros(numberOfRows,1);
RMSE = zeros(numberOfRows,1);
MaxAbsError = zeros(numberOfRows,1);
Correlation = zeros(numberOfRows,1);

for k = 1:numberOfRows
    reference = double(referenceSignals{k}(:));
    simulation = double(simulationSignals{k}(:));

    valid = isfinite(reference) & isfinite(simulation);

    reference = reference(valid);
    simulation = simulation(valid);

    errorSignal = simulation - reference;

    Bias(k) = mean(errorSignal);
    MAE(k) = mean(abs(errorSignal));
    RMSE(k) = sqrt(mean(errorSignal.^2));
    MaxAbsError(k) = max(abs(errorSignal));

    correlationMatrix = corrcoef(reference,simulation);
    Correlation(k) = correlationMatrix(1,2);
end

BatteryMetrics004 = table( ...
    signalName,modelName,units, ...
    Bias,MAE,RMSE,MaxAbsError,Correlation, ...
    'VariableNames',{ ...
    'Signal','Model','Unit','Bias','MAE','RMSE', ...
    'MaxAbsError','Correlation'});

fprintf('\n===== RUN 004 BATTERY METRICS =====\n');
disp(BatteryMetrics004);

%% Calculate signed, positive and negative energy

dynoNetEnergy_kWh = ...
    trapz(tBattery,dynoPower_kW)/3600;

baselineNetEnergy_kWh = ...
    trapz(tBattery,baselinePower_kW)/3600;

candidateNetEnergy_kWh = ...
    trapz(tBattery,candidatePower_kW)/3600;

dynoPositiveEnergy_kWh = ...
    trapz(tBattery,max(dynoPower_kW,0))/3600;

baselinePositiveEnergy_kWh = ...
    trapz(tBattery,max(baselinePower_kW,0))/3600;

candidatePositiveEnergy_kWh = ...
    trapz(tBattery,max(candidatePower_kW,0))/3600;

dynoNegativeEnergy_kWh = ...
    -trapz(tBattery,min(dynoPower_kW,0))/3600;

baselineNegativeEnergy_kWh = ...
    -trapz(tBattery,min(baselinePower_kW,0))/3600;

candidateNegativeEnergy_kWh = ...
    -trapz(tBattery,min(candidatePower_kW,0))/3600;

datasetName = [
    "EV6 dyno"
    "LUT-only baseline"
    "LUT + gains"
];

NetEnergy_kWh = [
    dynoNetEnergy_kWh
    baselineNetEnergy_kWh
    candidateNetEnergy_kWh
];

PositiveEnergy_kWh = [
    dynoPositiveEnergy_kWh
    baselinePositiveEnergy_kWh
    candidatePositiveEnergy_kWh
];

NegativeEnergyMagnitude_kWh = [
    dynoNegativeEnergy_kWh
    baselineNegativeEnergy_kWh
    candidateNegativeEnergy_kWh
];

EnergyResults004 = table( ...
    datasetName, ...
    NetEnergy_kWh, ...
    PositiveEnergy_kWh, ...
    NegativeEnergyMagnitude_kWh, ...
    'VariableNames',{ ...
    'Dataset','NetEnergy_kWh', ...
    'PositiveEnergy_kWh', ...
    'NegativeEnergyMagnitude_kWh'});

fprintf('\n===== RUN 004 BATTERY ENERGY =====\n');
disp(EnergyResults004);

%% Calculate energy errors

baselineNetEnergyError_pct = ...
    100*(baselineNetEnergy_kWh-dynoNetEnergy_kWh) / ...
    max(abs(dynoNetEnergy_kWh),eps);

candidateNetEnergyError_pct = ...
    100*(candidateNetEnergy_kWh-dynoNetEnergy_kWh) / ...
    max(abs(dynoNetEnergy_kWh),eps);

baselinePositiveEnergyError_pct = ...
    100*(baselinePositiveEnergy_kWh-dynoPositiveEnergy_kWh) / ...
    max(abs(dynoPositiveEnergy_kWh),eps);

candidatePositiveEnergyError_pct = ...
    100*(candidatePositiveEnergy_kWh-dynoPositiveEnergy_kWh) / ...
    max(abs(dynoPositiveEnergy_kWh),eps);

baselineNegativeEnergyError_pct = ...
    100*(baselineNegativeEnergy_kWh-dynoNegativeEnergy_kWh) / ...
    max(abs(dynoNegativeEnergy_kWh),eps);

candidateNegativeEnergyError_pct = ...
    100*(candidateNegativeEnergy_kWh-dynoNegativeEnergy_kWh) / ...
    max(abs(dynoNegativeEnergy_kWh),eps);

fprintf('\n===== RUN 004 ENERGY ERRORS =====\n');
fprintf('Baseline net-energy error = %.3f %%\n', ...
    baselineNetEnergyError_pct);
fprintf('Candidate net-energy error = %.3f %%\n', ...
    candidateNetEnergyError_pct);

fprintf('Baseline positive-energy error = %.3f %%\n', ...
    baselinePositiveEnergyError_pct);
fprintf('Candidate positive-energy error = %.3f %%\n', ...
    candidatePositiveEnergyError_pct);

fprintf('Baseline negative-energy error = %.3f %%\n', ...
    baselineNegativeEnergyError_pct);
fprintf('Candidate negative-energy error = %.3f %%\n', ...
    candidateNegativeEnergyError_pct);
fprintf('=================================\n');

%% Calculate cumulative energy

dynoCumulativeEnergy_kWh = ...
    cumtrapz(tBattery,dynoPower_kW)/3600;

baselineCumulativeEnergy_kWh = ...
    cumtrapz(tBattery,baselinePower_kW)/3600;

candidateCumulativeEnergy_kWh = ...
    cumtrapz(tBattery,candidatePower_kW)/3600;

%% Produce professor figure

figureHandle = figure( ...
    'Color','white', ...
    'Position',[80 50 1450 900]);

tiledlayout(3,2, ...
    'TileSpacing','compact', ...
    'Padding','compact');

plotStep = max(1,round(numel(tBattery)/100000));
plotIndices = 1:plotStep:numel(tBattery);

nexttile;
plot(tBattery(plotIndices), ...
    dynoCurrent(plotIndices),'k','LineWidth',1);
hold on;
plot(tBattery(plotIndices), ...
    baselineCurrent(plotIndices),'b','LineWidth',0.8);
plot(tBattery(plotIndices), ...
    candidateCurrent(plotIndices),'r','LineWidth',0.8);
grid on;
title('Battery current');
xlabel('Time [s]');
ylabel('Current [A]');
legend('EV6 dyno','LUT-only','LUT + gains');

nexttile;
plot(tBattery(plotIndices), ...
    dynoVoltage(plotIndices),'k','LineWidth',1);
hold on;
plot(tBattery(plotIndices), ...
    baselineVoltage(plotIndices),'b','LineWidth',0.8);
plot(tBattery(plotIndices), ...
    candidateVoltage(plotIndices),'r','LineWidth',0.8);
grid on;
title('Battery voltage');
xlabel('Time [s]');
ylabel('Voltage [V]');
legend('EV6 dyno','LUT-only','LUT + gains');

nexttile;
plot(tBattery(plotIndices), ...
    dynoPower_kW(plotIndices),'k','LineWidth',1);
hold on;
plot(tBattery(plotIndices), ...
    baselinePower_kW(plotIndices),'b','LineWidth',0.8);
plot(tBattery(plotIndices), ...
    candidatePower_kW(plotIndices),'r','LineWidth',0.8);
grid on;
title('Battery power');
xlabel('Time [s]');
ylabel('Power [kW]');
legend('EV6 dyno','LUT-only','LUT + gains');

nexttile;
plot(tBattery(plotIndices), ...
    baselineCurrent(plotIndices)-dynoCurrent(plotIndices), ...
    'b','LineWidth',0.8);
hold on;
plot(tBattery(plotIndices), ...
    candidateCurrent(plotIndices)-dynoCurrent(plotIndices), ...
    'r','LineWidth',0.8);
yline(0,'k--');
grid on;
title('Battery-current error');
xlabel('Time [s]');
ylabel('Error [A]');
legend('LUT-only','LUT + gains');

nexttile;
plot(tBattery(plotIndices), ...
    baselineVoltage(plotIndices)-dynoVoltage(plotIndices), ...
    'b','LineWidth',0.8);
hold on;
plot(tBattery(plotIndices), ...
    candidateVoltage(plotIndices)-dynoVoltage(plotIndices), ...
    'r','LineWidth',0.8);
yline(0,'k--');
grid on;
title('Battery-voltage error');
xlabel('Time [s]');
ylabel('Error [V]');
legend('LUT-only','LUT + gains');

nexttile;
plot(tBattery(plotIndices), ...
    dynoCumulativeEnergy_kWh(plotIndices), ...
    'k','LineWidth',1.2);
hold on;
plot(tBattery(plotIndices), ...
    baselineCumulativeEnergy_kWh(plotIndices), ...
    'b','LineWidth',1);
plot(tBattery(plotIndices), ...
    candidateCumulativeEnergy_kWh(plotIndices), ...
    'r','LineWidth',1);
grid on;
title('Cumulative battery energy');
xlabel('Time [s]');
ylabel('Energy [kWh]');
legend('EV6 dyno','LUT-only','LUT + gains');

sgtitle('Run 004: EV6 Battery Validation');

figureFile = fullfile(outputFolder, ...
    'EV6_Run004_Battery_Validation.png');

exportgraphics(figureHandle,figureFile, ...
    'Resolution',300);

%% Save tables

metricsFile = fullfile(outputFolder, ...
    'EV6_Run004_Battery_Metrics.csv');

energyFile = fullfile(outputFolder, ...
    'EV6_Run004_Battery_Energy.csv');

writetable(BatteryMetrics004,metricsFile);
writetable(EnergyResults004,energyFile);

save(fullfile(outputFolder, ...
    'EV6_Run004_Battery_Results.mat'), ...
    'BatteryMetrics004', ...
    'EnergyResults004', ...
    'dynoPower_kW', ...
    'baselinePower_kW', ...
    'candidatePower_kW', ...
    'tBattery');

fprintf('\n===== BATTERY ANALYSIS COMPLETE =====\n');
fprintf('Figure:\n%s\n',figureFile);
fprintf('Metrics:\n%s\n',metricsFile);
fprintf('Energy:\n%s\n',energyFile);
fprintf('=====================================\n');