%% FULL RUN 004 — POWER-CORRECTED 77.4-kWh MODEL

batteryModel = ...
    'EV6_LUT_FourWheel_EV6Battery77p4kWh_PowerCorrected';

outputFolder = ...
    'C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\OneDrive_1_8-28-2026\Vehicles_24a\Vehicles\VehicleProjects\Bolt_EV';

outputFile = fullfile(outputFolder, ...
    'EV6_Run004_77p4kWh_PowerCorrected_Full_Output.mat');
%% Load saved power-correction map

mapFile = fullfile( ...
    outputFolder, ...
    'Battery_Calibration', ...
    'EV6_SpeedMode_PowerCorrection_Results.mat');

assert(isfile(mapFile), ...
    'Correction-map results file was not found.');

mapData = load(mapFile);

requiredMapFields = { ...
    'speedCenters_mps', ...
    'correctionMap_kW', ...
    'modeThreshold_kW', ...
    'candidatePasses'};

for k = 1:numel(requiredMapFields)
    assert(isfield(mapData,requiredMapFields{k}), ...
        'Missing variable %s in the correction-map file.', ...
        requiredMapFields{k});
end

speedCenters_mps = mapData.speedCenters_mps;
correctionMap_kW = mapData.correctionMap_kW;
modeThreshold_kW = mapData.modeThreshold_kW;
candidatePasses = mapData.candidatePasses;

assert(candidatePasses, ...
    'The saved correction map did not pass its offline check.');

% Make the parameters available during Simulink compilation
assignin('base','speedCenters_mps',speedCenters_mps);
assignin('base','correctionMap_kW',correctionMap_kW);
assignin('base','modeThreshold_kW',modeThreshold_kW);

fprintf('\n===== POWER-CORRECTION MAP LOADED =====\n');
fprintf('Speed points = %d\n',numel(speedCenters_mps));
fprintf('Map size = %d modes by %d speed points\n', ...
    size(correctionMap_kW,1),size(correctionMap_kW,2));
fprintf('Mode threshold = %.3f kW\n',modeThreshold_kW);
fprintf('Candidate passed = %d\n',candidatePasses);
fprintf('=======================================\n');
%% Confirm required workspace variables

assert(exist('ts_Run004_VehSpd_mps','var') == 1, ...
    ['Run 004 speed input is missing. Run ' ...
     'resume_EV6_power_correction_session first.']);

assert(exist('ts_AccelPedal','var') == 1, ...
    'ts_AccelPedal is missing.');

assert(exist('ts_BrakePedal','var') == 1, ...
    'ts_BrakePedal is missing.');

assert(exist('ts_Steer','var') == 1, ...
    'ts_Steer is missing.');

assert(exist('EV6_TractionTorqueGain','var') == 1, ...
    'EV6_TractionTorqueGain is missing.');

assert(exist('EV6_RegenTorqueGain','var') == 1, ...
    'EV6_RegenTorqueGain is missing.');

assert(exist('speedCenters_mps','var') == 1 && ...
       exist('correctionMap_kW','var') == 1 && ...
       exist('modeThreshold_kW','var') == 1, ...
    'Power-correction map variables are missing.');

%% Prepare model

load_system(batteryModel);

speedBlock = [batteryModel '/From Workspace3'];

set_param(speedBlock, ...
    'VariableName','ts_Run004_VehSpd_mps');

run004StopTime_s = ...
    double(ts_Run004_VehSpd_mps.Time(end));

set_param(batteryModel, ...
    'StopTime',sprintf('%.15g',run004StopTime_s));

fprintf('\n===== FULL RUN 004 SETUP =====\n');
fprintf('Model = %s\n',batteryModel);
fprintf('Stop time = %.3f seconds\n',run004StopTime_s);
fprintf('Traction gain = %.12f\n',EV6_TractionTorqueGain);
fprintf('Regen gain = %.12f\n',EV6_RegenTorqueGain);
fprintf('================================\n');

%% Update before simulation

try
    set_param(batteryModel, ...
        'SimulationCommand','update');

    fprintf('Model update = SUCCESS\n');

catch updateError
    fprintf('\nModel update = FAILED\n');
    fprintf('%s\n',getReport( ...
        updateError,'extended','hyperlinks','off'));

    error('Stop here. Do not start the full simulation.');
end

%% Record current SDI runs

runIDsBefore = Simulink.sdi.getAllRunIDs;

%% Run full simulation

fprintf('\nStarting full Run 004 simulation...\n');
fprintf('Expected runtime is approximately 25-30 minutes.\n\n');

simulationTimer = tic;

outPowerCorrectedFull = sim( ...
    batteryModel, ...
    'StopTime',sprintf('%.15g',run004StopTime_s), ...
    'ReturnWorkspaceOutputs','on');

runtime_minutes = toc(simulationTimer)/60;

%% Rename the new SDI run

runIDsAfter = Simulink.sdi.getAllRunIDs;
newRunIDs = setdiff(runIDsAfter,runIDsBefore);

sdiRunName = ...
    'Run004_EV6Battery77p4kWh_PowerCorrected_Full';

if ~isempty(newRunIDs)
    newestRunID = newRunIDs(end);
    newestRun = Simulink.sdi.getRun(newestRunID);
    newestRun.Name = sdiRunName;
else
    warning('No new SDI run was detected automatically.');
end

%% Basic output check

requiredOutputs = [ ...
    "battery_current"
    "battery_power"
    "battery_soc"
    "EV6CurrentCorrection_A"
    "EV6PowerCorrection_kW"];

outputNames = string(outPowerCorrectedFull.who);

fprintf('\n===== FULL OUTPUT CHECK =====\n');

for k = 1:numel(requiredOutputs)
    if any(outputNames == requiredOutputs(k))
        fprintf('FOUND   %s\n',requiredOutputs(k));
    else
        fprintf('MISSING %s\n',requiredOutputs(k));
    end
end

fprintf('=============================\n');

%% Save results

save(outputFile, ...
    'outPowerCorrectedFull', ...
    'runtime_minutes', ...
    'run004StopTime_s', ...
    'sdiRunName', ...
    'EV6_TractionTorqueGain', ...
    'EV6_RegenTorqueGain', ...
    'speedCenters_mps', ...
    'correctionMap_kW', ...
    'modeThreshold_kW', ...
    '-v7.3');

fprintf('\n');
fprintf('===== FULL POWER-CORRECTED RUN 004 COMPLETE =====\n');
fprintf('Runtime = %.2f minutes\n',runtime_minutes);
fprintf('SDI run = %s\n',sdiRunName);
fprintf('Stop time = %.3f seconds\n',run004StopTime_s);
fprintf('\nSimulation output saved to:\n%s\n',outputFile);
fprintf('=================================================\n');