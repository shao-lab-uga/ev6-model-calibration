%% RUN 004: 2023 EV6 77.4-kWh BATTERY 60-SECOND CHECK

projectRoot = ['C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
    'OneDrive_1_8-28-2026\Vehicles_24a\Vehicles\' ...
    'VehicleProjects\Bolt_EV'];

batteryModel = ...
    'EV6_LUT_FourWheel_EV6Battery77p4kWh';

%% Ensure required gains exist

EV6_TractionTorqueGain = 1.223989;
EV6_RegenTorqueGain = 1.348705;

%% Load Run 004 dyno data if necessary

if ~exist('D004','var')

    run004File = ['C:\Users\ssl35511\Documents\MATLAB\ev6 dyno data\' ...
        'OneDrive_1_8-28-2026\EV6_drivecycleData\' ...
        'standards_test_08142026_004.mat'];

    loadedRun004 = load(run004File);

    D004 = ...
        loadedRun004.standards_test_08142026_004;
end

%% Create corrected Run 004 speed input

channelNames004 = erase( ...
    string({D004.Y.Name}),["<",">"]);

speedIndex = find( ...
    channelNames004 == "VEH_vEgo",1,'first');

assert(~isempty(speedIndex), ...
    'VEH_vEgo was not found.');

speedTimeIndex = D004.Y(speedIndex).XIndex;

run004Time_s = double( ...
    D004.X(speedTimeIndex).Data(:));

run004Speed_mps = double( ...
    D004.Y(speedIndex).Data(:));

validSpeed = ...
    isfinite(run004Time_s) & ...
    isfinite(run004Speed_mps);

run004Time_s = run004Time_s(validSpeed);
run004Speed_mps = run004Speed_mps(validSpeed);

run004Speed_mps = max(run004Speed_mps,0);

ts_Run004_VehSpd_mps = timeseries( ...
    run004Speed_mps,run004Time_s);

% Compatibility variables
ts_VehSpdDmd = ts_Run004_VehSpd_mps;
ts_VehSpd = ts_Run004_VehSpd_mps;
ts_US06VehSpdDmd = ts_Run004_VehSpd_mps;

%% Open model and locate top-level speed input

load_system(batteryModel);

fromBlocks = find_system( ...
    batteryModel, ...
    'SearchDepth',1, ...
    'BlockType','FromWorkspace');

speedBlock = '';

for blockIndex = 1:numel(fromBlocks)

    variableName = string(get_param( ...
        fromBlocks{blockIndex}, ...
        'VariableName'));

    if contains(lower(variableName),"vehspd")
        speedBlock = fromBlocks{blockIndex};
        break
    end
end

assert(~isempty(speedBlock), ...
    'The top-level vehicle-speed input was not found.');

set_param(speedBlock, ...
    'VariableName','ts_Run004_VehSpd_mps');

%% Configure and update

set_param(batteryModel,'StopTime','60');

try
    set_param(batteryModel, ...
        'SimulationCommand','update');

    fprintf('\n77.4-kWh model update = SUCCESS\n');

catch updateError

    fprintf('\n%s\n',getReport( ...
        updateError,'extended', ...
        'hyperlinks','off'));

    error('Stop here. Do not start the simulation.');
end

%% Run simulation

runIDsBefore = Simulink.sdi.getAllRunIDs;

simulationTimer = tic;

out004EV6Battery77p4_60s = sim( ...
    batteryModel, ...
    'ReturnWorkspaceOutputs','on');

runtimeMinutes = toc(simulationTimer)/60;

%% Find and rename new SDI run

runIDsAfter = Simulink.sdi.getAllRunIDs;

newRunIDs = runIDsAfter( ...
    ~ismember(runIDsAfter,runIDsBefore));

assert(~isempty(newRunIDs), ...
    'No new SDI run was created.');

newRunID = newRunIDs(end);
newRun = Simulink.sdi.getRun(newRunID);

newRun.Name = ...
    'Run004_EV6Battery77p4kWh_Corrected_60s';

%% Find battery signals

signalIDs = newRun.getAllSignalIDs;
signalNames = strings(numel(signalIDs),1);

for signalIndex = 1:numel(signalIDs)

    currentSignal = Simulink.sdi.getSignal( ...
        signalIDs(signalIndex));

    signalNames(signalIndex) = ...
        string(currentSignal.Name);
end

currentIndex = find( ...
    strcmpi(signalNames, ...
    "SimMonitor.Veh.Batt.BattCurr"), ...
    1,'first');

voltageIndex = find( ...
    strcmpi(signalNames, ...
    "SimMonitor.Veh.Batt.BattVolt"), ...
    1,'first');

if isempty(currentIndex)
    currentIndex = find( ...
        contains(lower(signalNames),"battcurr"), ...
        1,'first');
end

if isempty(voltageIndex)
    voltageIndex = find( ...
        contains(lower(signalNames),"battvolt"), ...
        1,'first');
end

assert(~isempty(currentIndex), ...
    'Battery-current signal was not found.');

assert(~isempty(voltageIndex), ...
    'Battery-voltage signal was not found.');

Run004_77p4_BattCurrentTS = ...
    Simulink.sdi.getSignal( ...
    signalIDs(currentIndex)).Values;

Run004_77p4_BattVoltageTS = ...
    Simulink.sdi.getSignal( ...
    signalIDs(voltageIndex)).Values;

Run004_77p4_BattSocTS = ...
    out004EV6Battery77p4_60s.battery_soc;

%% Print ranges

fprintf('\n===== 2023 EV6 77.4-kWh 60-SECOND CHECK =====\n');
fprintf('Runtime = %.2f minutes\n',runtimeMinutes);
fprintf('SDI run = %s\n',string(newRun.Name));

fprintf('\nBattery current range:\n');
fprintf('%.3f to %.3f A\n', ...
    min(Run004_77p4_BattCurrentTS.Data(:)), ...
    max(Run004_77p4_BattCurrentTS.Data(:)));

fprintf('\nBattery voltage range:\n');
fprintf('%.3f to %.3f V\n', ...
    min(Run004_77p4_BattVoltageTS.Data(:)), ...
    max(Run004_77p4_BattVoltageTS.Data(:)));

fprintf('\nBattery SOC range:\n');
fprintf('%.6f to %.6f\n', ...
    min(Run004_77p4_BattSocTS.Data(:)), ...
    max(Run004_77p4_BattSocTS.Data(:)));

%% Save compact results

compactFile = fullfile( ...
    projectRoot, ...
    'EV6_Run004_77p4kWh_Corrected_60s_Battery.mat');

save(compactFile, ...
    'Run004_77p4_BattCurrentTS', ...
    'Run004_77p4_BattVoltageTS', ...
    'Run004_77p4_BattSocTS', ...
    '-v7.3');

fprintf('\nSaved compact results:\n%s\n', ...
    compactFile);

fprintf('================================================\n');